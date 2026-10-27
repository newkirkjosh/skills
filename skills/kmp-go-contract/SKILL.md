---
name: kmp-go-contract
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Governs the API contract between a KMP client and a Go backend: defining or changing endpoints and choosing transport and serialization conventions between the two stacks."
metadata:
  type: flexible
---

# KMP–Go Contract

## When to Use
- Adding a new endpoint that a KMP client will call
- Changing request/response shape of an existing endpoint
- Deciding on transport protocol, serialization format, or error shape
- Reviewing consistency between what the Go service exposes and what the KMP client expects

## Principles

**Transport:** HTTP/REST as default. gRPC only if bidirectional streaming or strict schema enforcement is a hard requirement — it adds tooling complexity.

**Serialization:** JSON as default. Use `kotlinx.serialization` on the KMP side and Go's `encoding/json` (or `json-iterator` for performance) on the backend. Keep field names snake_case in JSON — both sides handle the mapping.

**Endpoint naming:** REST resource naming: nouns, plural, lowercase, hyphen-separated. `GET /habits`, `POST /habit-checkins`, not `GET /getHabits`.

**Error shape:** All error responses use a consistent envelope:
```json
{ "code": "RESOURCE_NOT_FOUND", "message": "human-readable detail" }
```
The KMP client maps `code` to a sealed class. Never expose stack traces.

**Versioning:** Path prefix versioning: `/v1/resource`. Bump version on breaking changes only. Additive changes (new optional fields) do not require a version bump.

**Nullability contract:** If a field can be absent in the response, it must be nullable on the KMP side (`String?`). Never use default values to paper over absent fields — make the contract explicit.

## Constraints
- Both sides of the contract must be updated in the same design decision — never change one without considering the other
- Error codes must be defined as a shared enum or constant set (in the design doc) before implementation
- Do not use different field names on Go and KMP sides — the JSON serialization layer handles casing, not renaming

## Examples
*Not required for flexible skills.*
