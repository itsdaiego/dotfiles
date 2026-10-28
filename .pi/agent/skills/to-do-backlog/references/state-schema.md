# Backlog state schema

Store UTF-8 JSON at `/Users/daiego/.local/state/to-do-backlog/backlog.json`.

```json
{
  "version": 1,
  "updated_at": "2026-10-28T00:00:00Z",
  "sources": {
    "slack": {"status": "pending", "last_success_at": null, "backfill_before": "2026-09-28T00:00:00Z", "backfill_complete": false, "oldest_scanned_at": null, "error": null},
    "notion": {"status": "pending", "last_success_at": null, "backfill_before": "2026-09-28T00:00:00Z", "backfill_complete": false, "oldest_scanned_at": null, "error": null},
    "linear": {"status": "pending", "last_success_at": null, "backfill_before": "2026-09-28T00:00:00Z", "backfill_complete": false, "oldest_scanned_at": null, "error": null},
    "gitlab": {"status": "pending", "last_success_at": null, "backfill_before": "2026-09-28T00:00:00Z", "backfill_complete": false, "oldest_scanned_at": null, "error": null}
  },
  "items": []
}
```

Each item has this shape:

```json
{
  "id": "slack:workspace:channel:thread_ts",
  "source": "slack",
  "source_key": "workspace:channel:thread_ts",
  "action": "Review the deployment plan",
  "from": "Alex Kim",
  "requested_at": "2026-04-02T15:10:00Z",
  "last_activity_at": "2026-04-02T15:10:00Z",
  "last_checked_at": "2026-10-28T12:00:00Z",
  "url": "https://example.invalid/source-link",
  "status": "open",
  "kind": "explicit_request",
  "evidence": "Short paraphrase of the concrete ask",
  "resolved_at": null,
  "resolution_evidence": null
}
```

Allowed `source` values are `slack`, `notion`, `linear`, and `gitlab`. Allowed `status` values are `open` and `resolved`. Allowed `kind` values are `explicit_request` and `code_review`.

Keep `action`, `evidence`, and `resolution_evidence` short and paraphrased. Do not cache full message bodies, page contents, or secrets. Preserve source URLs and timestamps exactly.

Write atomically by creating a temporary sibling file, validating that it parses as JSON with `version: 1`, then renaming it over `backlog.json`. Do not replace a valid state file with partial data after a source failure.
