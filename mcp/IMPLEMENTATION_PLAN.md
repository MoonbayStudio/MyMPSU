# MyMPSU Schedule MCP: technical plan for milestones 1-2

## Existing MyMPSU contract

The iOS and Android apps both call the public MyMPSU schedule API directly at
`https://api.mympsu.moonbaystudio.ru/schedule/v1` without a MyMPSU account token.

- `GET /groups` returns group `id`, `name`, and `faculty_id`.
- `GET /faculties` returns faculty/institute `id` and `name`.
- `GET /schedule` accepts `group_id`, `start_date`, `end_date`, and
  `exam_only`.
- Schedule rows contain ISO `start_time`/`end_time`, subject `name`, lesson
  `type`, and optional `teacher_id`, `room_id`, `sub_group_id`, and
  `class_url`.
- `GET /teachers?teacher_ids=...`, `GET /rooms?room_ids=...`, and
  `GET /buildings?building_ids=...` enrich schedule rows with names and the
  building address/name.

The MCP provider intentionally mirrors this proven flow. It does not call the
MyMPSU account/assistant backend and does not require a bearer token.

## Implementation

1. Keep transport and upstream details separate: MCP tools depend only on the
   `ScheduleProvider` interface.
2. Run stateless Streamable HTTP on `POST /mcp`; expose `GET /health`.
3. Implement `search_groups` from groups plus faculties, with normalized
   Unicode/case-insensitive matching and deterministic exact-first ranking.
4. Implement `get_schedule` with exact group resolution, explicit ambiguity
   errors, Moscow date defaults, a bounded date range, and normalized lessons.
5. Enrich only IDs present in the returned lessons and never expose the large
   upstream response.
6. Validate tool inputs, bound upstream time/response size, rate-limit MCP
   requests, and return stable machine-readable error codes.
7. Verify provider behavior with fixtures and verify the real MCP lifecycle over
   HTTP: initialize, list tools, call tools, and reject invalid input.

Milestones 3-8 (public deployment, source registry, crawler/search, and OAuth)
remain outside this first implementation.
