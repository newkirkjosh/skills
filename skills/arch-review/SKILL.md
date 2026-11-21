---
name: arch-review
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Stack-agnostic review of system design decisions: module boundaries, layer responsibilities, dependency direction and architectural trade-offs, for questions about how to structure something rather than what to build."
metadata:
  type: flexible
---

# Arch Review

**Explicit use only.** The user names this skill, or an already-active, explicitly invoked workflow calls it by name for a structural decision. It returns a design recommendation; it does not implement the design or start a lifecycle. Its rules end at that report.

## Step 1: Frame the structural decision

1. Read the caller’s scope, current design and relevant project instructions.
2. Name the boundary or dependency under decision, the requirements it must satisfy and the constraints already fixed by the user.
3. Identify the modules and callers affected. Inspect only what is needed to understand those relationships; ask about a missing constraint only when it could change the recommendation.

**Result:** a concrete design question and the evidence needed to compare answers.

## Step 2: Trace the existing responsibilities

1. Map each affected module to its current purpose and public responsibilities.
2. Trace the relevant dependency direction and layer responsibilities using the principles below.
3. Identify the demonstrated coupling, layer violation or unclear ownership. Separate observed problems from hypothetical future needs.

**Result:** the specific structural problem and the boundaries a solution must preserve.

## Step 3: Compare options and recommend

1. Present at least two concrete options as a trade-off table. Compare simplicity, testability, scalability and maintainability against the stated requirements.
2. Challenge any element added only for a hypothetical future requirement.
3. Recommend one option, name what it sacrifices, and explain when the alternative would be preferable.

**Result:** a reasoned choice, its cost and any unresolved decision the user must make.

## Step 4: Return the design

Report the proposed boundaries, responsibility and dependency changes, the comparison and the recommendation. Keep unrelated refactoring out of the report. Surface over-engineering without removing it yourself. When `spec-writer` is the caller, return the design text for its `design.md`; the caller owns artifact creation and approval.

**Result:** an actionable recommendation or a clearly stated missing decision. Stop here.

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

## Gotchas

- Do not turn a structural review into implementation or a neighboring cleanup. The caller owns those actions.
- A familiar pattern is not a reason by itself; show which requirement earns its trade-off.

## Examples
*Not required for flexible skills, but illustrative:*

Request: "Should I put my Ktor client in `:shared` or `:androidApp`?"
Review approach: Identify what depends on the Ktor client (repository, which is shared logic) → dependency direction says the client belongs in `:shared`. Present trade-off: `:shared` = reusable across platforms, requires Ktor multiplatform artifact; `:androidApp` = simpler setup, blocks iOS reuse. Recommend `:shared` if iOS is in scope.
