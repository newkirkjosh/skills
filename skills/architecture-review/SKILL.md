---
name: architecture-review
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Stack-agnostic review of system design decisions: module boundaries, layer responsibilities, dependency direction and architectural trade-offs, for questions about how to structure something rather than what to build."
metadata:
  type: flexible
---

# Architecture Review

## When to Use
- Request involves how to structure a system, module, or service
- Evaluating whether a proposed design is sound
- Deciding between approaches with structural implications
- Reviewing existing code for architectural problems (layer violations, tight coupling, unclear boundaries)

## Principles

**Module boundaries:** Each module has one clear purpose. You should be able to answer "what does this do?" without reading its internals. If a module's name requires an "and," it does too much.

**Dependency direction:** Dependencies flow inward. Domain/business logic depends on nothing external. Infrastructure (DB, network, UI) depends on the domain, never the reverse. Violations create fragility.

**Layer responsibilities:**
- UI layer: display state, dispatch events — no business logic
- Domain/use-case layer: business rules — no framework dependencies
- Data layer: data fetching/persistence — implements domain interfaces

**Trade-off analysis:** Always present options as a table of trade-offs. Never recommend a single option without naming what is being traded away. The dimensions to evaluate: simplicity, testability, scalability, maintainability.

**YAGNI enforcement:** If a design element exists for a hypothetical future requirement, name it explicitly and challenge whether it earns its complexity now.

## Constraints
- Always present at least 2 options before making a recommendation
- Always name what is sacrificed by the recommended option
- Do not propose unrelated refactoring alongside the architecture review
- Flag over-engineering but do not unilaterally remove it — surface it to the user

## Examples
*Not required for flexible skills, but illustrative:*

Request: "Should I put my Ktor client in `:shared` or `:androidApp`?"
Review approach: Identify what depends on the Ktor client (repository, which is shared logic) → dependency direction says the client belongs in `:shared`. Present trade-off: `:shared` = reusable across platforms, requires Ktor multiplatform artifact; `:androidApp` = simpler setup, blocks iOS reuse. Recommend `:shared` if iOS is in scope.
