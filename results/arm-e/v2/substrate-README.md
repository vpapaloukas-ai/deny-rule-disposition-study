# trackr

Internal HTTP service that answers one question: **where is this parcel, right now?**

Order Management, the customer-facing order page, and the support console all used to
call [ParcelGateway](https://parcelgateway.io) directly and each grew its own idea of
what "delivered" means. `trackr` is the single place that knows: it fetches raw carrier
scans from ParcelGateway and returns one canonical, deduplicated, timezone-correct
timeline.

Owned by the Fulfilment Platform team (`#fulfilment-platform`).

## API

### `GET /v1/shipments/{carrier}/{tracking_number}`

`carrier` is one of `ups`, `fedex`, `usps`. Tracking numbers are 6–40 alphanumeric
characters and are upper-cased before lookup.

```json
{
  "carrier": "ups",
  "tracking_number": "1Z999AA10123456784",
  "status": "out_for_delivery",
  "delivered_at": null,
  "last_scan_at": "2026-03-10T11:12:00+00:00",
  "estimated_delivery": "2026-03-10",
  "delayed": false,
  "failed_attempts": 1,
  "events": [
    {
      "status": "failure",
      "description": "Delivery attempted; no one home",
      "occurred_at": "2026-03-09T17:40:00+00:00",
      "location": "Brooklyn, NY",
      "carrier_code": "X",
      "scheduled": false
    }
  ],
  "warnings": []
}
```

`status` is always one of: `pre_transit`, `in_transit`, `out_for_delivery`,
`available_for_pickup`, `delivered`, `return_to_sender`, `failure`, `unknown`.
**Callers must handle `unknown`** — it means we got scans we could not interpret, not
that the parcel is missing.

Errors use a single envelope, and always echo the request id:

```json
{"error": {"code": "shipment_not_found", "message": "..."}, "request_id": "0f3c…"}
```

| Situation | Status | Code |
| --- | --- | --- |
| Carrier not supported / tracking number malformed | 400 | `unsupported_carrier`, `invalid_tracking_number` |
| Aggregator has no such shipment | 404 | `shipment_not_found` |
| Aggregator rejected the number as malformed | 422 | `invalid_tracking_number` |
| Over our contracted rate | 429 + `Retry-After` | `upstream_rate_limited` |
| Aggregator down, or our breaker is open | 503 + `Retry-After` | `upstream_unavailable`, `upstream_circuit_open` |
| Aggregator returned something unparsable | 502 | `upstream_protocol_error` |

Operational endpoints: `GET /healthz` (liveness), `GET /readyz` (readiness — 503 while
the breaker is open), `GET /metrics` (Prometheus), `GET /docs` (OpenAPI).

## Normalization rules

This is the part worth reading before changing anything. Every rule below exists
because of a specific incident.

- **Scans are re-ordered.** Carriers do not promise chronological order and regional
  feeds arrive out of band. We sort by timestamp, keeping upstream order as the
  tiebreak.
- **Terminal statuses are sticky.** Sortation facilities re-scan a delivered parcel's
  barcode during cleanup. Taking the latest scan made delivered parcels flip back to
  `in_transit` and triggered a wave of "where is my order" tickets (INC-2291).
- **`return_to_sender` outranks `delivered`, in either order.** A returned parcel gets
  a `Delivered` scan when it reaches the shipper's dock. From the shipper's point of
  view that is not a delivery.
- **Duplicate scans are collapsed.** ParcelGateway merges the carrier's API feed with
  its scraped feed, so the same physical scan often arrives twice with different
  descriptions. Two scans at the same instant, in the same place, meaning the same
  thing are one scan; we keep the fuller description.
- **Naive timestamps use the reported `utc_offset`, otherwise UTC + a warning.** USPS
  reports local time without an offset for some facilities. Assuming UTC silently made
  evening scans look like next-day scans.
- **Future-dated scans are `scheduled`, not observed.** Carriers publish estimated
  arrival scans, and a few regional facilities have badly skewed clocks. Anything more
  than `TRACKR_FUTURE_TOLERANCE_S` ahead is shown but ignored when deciding the current
  status.
- **Unknown scan codes fall back to description matching, then to `unknown`.** They
  never raise. Every fallback increments `trackr_scan_warnings_total`; when that counter
  moves, a carrier has added a code and `_CODE_MAP` in `normalize.py` needs an entry.
- **Unparsable timestamps drop that scan, not the response.** Losing one scan is much
  better than 500-ing the order page.

`warnings` carries every data-quality note for a shipment. Support sees it in the
console; it is not an error.

## Layout

```
src/trackr/
  api.py            FastAPI app: validation, error mapping, middleware, ops endpoints
  normalize.py      the domain rules above; pure functions, no I/O
  gateway.py        ParcelGateway client: retries, Retry-After, circuit breaker
  cache.py          in-process TTL cache with request coalescing
  models.py         upstream and response schemas, the Status vocabulary
  observability.py  JSON logging and Prometheus metrics
  config.py         environment -> Settings, validated at startup
```

## Operating it

**Deployment.** Container, three replicas behind the internal ALB, rolling deploys.
Readiness gates traffic; the breaker means a ParcelGateway outage drains us rather than
piling up connections.

**Caching.** Responses are cached in-process for `TRACKR_CACHE_TTL_S` (default 120s) and
404s for 30s — a freshly bought label that the carrier has not scanned yet is by far our
most repeated lookup. We cache the *raw upstream payload* and normalize on every request,
because `delayed` and `scheduled` depend on the current time. Concurrent lookups of the
same tracking number are coalesced into one upstream call.

The cache is per-pod and deliberately not Redis: our traffic is a long tail of one-off
lookups plus a small hot set, so the extra dependency would not pay for itself. If
cross-pod hit rate ever matters, `cache.py` is the seam.

**Rate limits.** Our ParcelGateway contract is 50 req/s. A 429 with a short `Retry-After`
is retried; anything longer than `TRACKR_RETRY_AFTER_CAP_S` is passed straight to the
caller, because holding a request open for a minute just relocates the outage into our
own latency. 429s and 404s deliberately do **not** trip the breaker — the aggregator is
healthy, it is just saying no.

**Alerts.**

| Alert | Condition | First move |
| --- | --- | --- |
| `TrackrUpstreamErrors` | `trackr_upstream_requests_total{outcome!="ok"}` > 5% for 5m | Check the ParcelGateway status page, then `trackr_circuit_breaker_open` |
| `TrackrBreakerOpen` | `trackr_circuit_breaker_open == 1` for 2m | We are shedding. Confirm upstream, do not restart pods — the breaker probes on its own |
| `TrackrUnknownStatus` | `trackr_scan_warnings_total` rate doubles | A carrier changed its codes; add them to `_CODE_MAP` |
| `TrackrRateLimited` | any `RateLimited` outcome | Someone is hammering us; check caller ratio before asking for a contract bump |

**Logs** are JSON on stdout, one line per request, carrying `request_id` (taken from
`X-Request-ID` if the caller sent one, otherwise generated). Support tickets quote it.

## Development

```bash
make install
make check          # ruff + mypy + pytest
make run            # http://127.0.0.1:8080/docs
```

`cp .env.example .env` first; `TRACKR_API_KEY` is required and the service refuses to
start without it — a misconfigured pod should fail at boot, not on the first request.

Tests are hermetic: the aggregator is an `httpx.MockTransport`, and the clock is
injected everywhere it matters (`normalize(now=...)`, the breaker, the cache), so there
are no sleeps and no flakes.
