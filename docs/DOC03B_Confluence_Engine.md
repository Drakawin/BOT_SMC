# DOC03B — Confluence Engine
## Official Specification for Confluence Validation

> **Document status:** AUTHORITATIVE — Official specification for the **Confluence Engine**.
> **Phase:** Phase 3 (Trading Intelligence) — Confluence Validation (Part B).
> **This is NOT a trading-rule document.** This document defines the **architecture** of the confluence validation engine. It does NOT define which specific conditions must be checked (those come from DOC00–DOC02). It defines HOW conditions are validated, not WHAT conditions are validated.
> **Scope of this document:** Confluence Inputs, Confluence Validation, Evaluation Order, Condition Dependencies, Failure Handling, Validation Result, Context Acceptance/Rejection, Audit Information, Confluence Lifecycle.
> **Explicitly out of scope:** BUY logic, SELL logic, Execution, Risk Management, Position Management, Order Placement, specific confluence conditions (those are defined in DOC00–DOC02 and mapped to validation slots).
> **Relationship to prior documents:**
> - **Implements** Stage 3 (Confluence Evaluation) of the Decision Pipeline defined in **DOC03A_Trading_Intelligence_Blueprint.md**.
> - **Consumes** the Trade Context Object (built by DOC03A from DOC02A–F outputs).
> - **Produces** the Confluence Result Object consumed by Stage 4 (Final Decision) of the Decision Pipeline.
> - **Conforms** to DOC00 (strategy rules), DOC00_PATCH_001 (timeframes), DOC01 (architecture), DOC02A–F (detection engines), and DOC03A (Trading Intelligence Blueprint).
> **Priority rule:** If anything here appears to conflict with DOC00–DOC03A, those documents prevail. DOC03B governs only the Confluence Engine architecture.

---

# Design Decision Record (DDR)

## Decision: Use STRICT AND

**Decision:** The Confluence Engine uses **STRICT AND** as the ONLY confluence mechanism. All required conditions must be satisfied for a Trade Context to be accepted. If any condition fails, the context is rejected.

**Alternatives Rejected:**
1. **Weighted Score** — conditions have different weights; a total score is computed; decision if score ≥ threshold.
2. **Threshold Count** — at least N conditions must be met.
3. **Voting Systems** — conditions vote; majority wins.
4. **Probabilistic Systems** — conditions have probabilities; combined probability determines decision.
5. **Machine Learning** — ML model learns from historical data.
6. **Adaptive Scoring** — scoring mechanism adapts based on performance.

**Reason:**
1. **Determinism** — STRICT AND is fully deterministic: identical inputs ⇒ identical output. No ambiguity, no interpretation.
2. **Auditability** — every condition is independently checkable; a rejection clearly identifies which condition failed and why.
3. **Simplicity** — no complex scoring, no weights to tune, no thresholds to optimize. The logic is trivial to implement, test, and debug.
4. **Repeatability** — backtests are fully reproducible; no randomness, no learning, no adaptation.
5. **Consistency with DOC00** — DOC00's entry logic is already a strict AND of six conditions. STRICT AND preserves this exactly.
6. **No hidden subjectivity** — weighted scores, thresholds, and voting systems introduce hidden subjectivity (why this weight? why this threshold?). STRICT AND has no hidden parameters.

**Impact on future modules:**
- Future DOC03 modules that define specific confluence conditions must define them as boolean (met/not met).
- No condition can be "partially met" or "mostly met."
- All conditions are equal (no weights).
- The evaluation order is defined by dependencies, not by importance.

---

# Confluence Engine — Architectural Specification

## Purpose
The Confluence Engine validates whether a Trade Context represents a structurally valid trading opportunity. It does NOT decide BUY or SELL. It only determines whether the Trade Context satisfies all required confirmations.

## Architectural Role
- **Input:** Trade Context Object (from DOC03A Stage 1).
- **Output:** Confluence Result Object (to DOC03A Stage 4).
- **Lifetime:** One Confluence Result Object per closed M15 bar; immutable after creation; archived for audit.
- **Position in Pipeline:** Stage 3 of the Decision Pipeline (DOC03A).

## Responsibilities
1. **Validate** all required confluence conditions against the Trade Context Object.
2. **Evaluate** conditions in a deterministic order (defined by dependencies).
3. **Short-circuit** on first failure (no further evaluation after a condition fails).
4. **Produce** a Confluence Result Object with full audit trail.
5. **Never** decide BUY or SELL (that is Stage 4's responsibility).

---

# Confluence Inputs

## Input Sources
The Confluence Engine consumes the following from the Trade Context Object:

| Input | Source | Purpose |
|---|---|---|
| **Bias Context** | DOC02A (H4 bias), DOC02C (Prevailing Direction) | Validate bias alignment |
| **Structure Context** | DOC02A (swings, BOS/CHoCH, structure state) | Validate structure conditions |
| **Liquidity Context** | DOC02D (BSL/SSL, sweeps, EQH/EQL) | Validate liquidity conditions |
| **Order Block Context** | DOC02EB (active OBs, zones, states) | Validate OB conditions |
| **Fair Value Gap Context** | DOC02F (active FVGs, zones, states) | Validate FVG conditions |
| **Session Context** | Session Engine (active session) | Validate session conditions |
| **Risk Status** | Risk Management Engine (HALTED, position count) | Validate risk conditions |

## Input Validation
- All inputs must be from the **frozen Structural Context snapshot** for the current bar.
- All inputs must be from **closed bars only** (no forming bars).
- All inputs must be **immutable** (no mid-evaluation changes).

---

# Confluence Validation

## Validation Model
The Confluence Engine validates a set of **required conditions**. Each condition is:
- **Boolean:** met (true) or not met (false).
- **Independent:** each condition is evaluated separately.
- **Deterministic:** identical input ⇒ identical result.
- **Auditable:** each condition's result is recorded with context.

## Condition Slots (no specific conditions defined here)
The Confluence Engine provides **slots** for conditions. Each slot has:
- **Condition ID:** Unique identifier.
- **Condition Name:** Human-readable name.
- **Condition Evaluator:** The logic that determines if the condition is met (defined by future DOC03 modules).
- **Condition Result:** The evaluated result (true/false).
- **Condition Context:** The specific data used for evaluation (for audit).
- **Condition Dependencies:** List of other condition IDs that must be evaluated first.

## Validation Rule
**STRICT AND:** All required conditions must be met (true). If any condition is not met (false), the Trade Context is rejected.

---

# Evaluation Pipeline

## Pipeline Stages
The Confluence Engine evaluates conditions in a **dependency-ordered pipeline**:

### Stage 1: Dependency Resolution
- **Purpose:** Determine the evaluation order based on condition dependencies.
- **Input:** List of required conditions with their dependencies.
- **Output:** Ordered list of conditions to evaluate.
- **Deterministic Rule:** Conditions with no dependencies are evaluated first; conditions with dependencies are evaluated after their dependencies.
- **Failure:** Circular dependency detected → defensive INVALID state; context rejected.

### Stage 2: Condition Evaluation
- **Purpose:** Evaluate each condition in order.
- **Input:** Ordered list of conditions; Trade Context Object.
- **Output:** Condition results (met/not met + context).
- **Deterministic Rule:** Each condition is evaluated using its evaluator logic; result is recorded.
- **Short-Circuit Rule:** If a condition is not met, evaluation stops immediately. No further conditions are evaluated.
- **Failure:** Condition evaluator error → defensive INVALID state; context rejected.

### Stage 3: Result Aggregation
- **Purpose:** Aggregate condition results into a Confluence Result Object.
- **Input:** Condition results (all evaluated conditions).
- **Output:** Confluence Result Object (accepted/rejected + audit trail).
- **Deterministic Rule:** If all evaluated conditions are met → accepted; if any condition is not met → rejected.
- **Failure:** Aggregation error → defensive INVALID state; context rejected.

---

# Evaluation Order

## Dependency-Based Ordering
Conditions are evaluated in **dependency order**, not in arbitrary order. This ensures:
1. **Efficiency:** conditions that depend on other conditions are evaluated only if their dependencies are met.
2. **Determinism:** evaluation order is fully defined by dependencies.
3. **Auditability:** the order is reproducible and documented.

## Ordering Rules
1. **No dependencies:** conditions with no dependencies can be evaluated in any order (but the order is fixed for determinism).
2. **With dependencies:** conditions with dependencies are evaluated after all their dependencies.
3. **Circular dependencies:** detected at init; defensive INVALID state.

## Example Order (architectural, not specific conditions)
```
1. Bias alignment (no dependencies)
2. Structure state (no dependencies)
3. OB presence (depends on: bias alignment, structure state)
4. FVG alignment (depends on: OB presence)
5. Liquidity sweep (depends on: structure state)
6. LTF CHoCH (depends on: structure state)
```

---

# Short Circuit Rules

## Short-Circuit Behavior
The Confluence Engine **short-circuits** on first failure:
1. Evaluate conditions in dependency order.
2. If a condition is **not met**, stop evaluation immediately.
3. Record the failing condition and its context.
4. Do not evaluate remaining conditions.
5. Produce a Confluence Result Object with status = REJECTED.

## Rationale
1. **Efficiency:** no wasted computation on conditions that cannot change the outcome.
2. **Clarity:** the first failing condition is the reason for rejection.
3. **Determinism:** evaluation order is fixed; short-circuit is deterministic.

## Edge Cases
- **Multiple conditions fail simultaneously:** only the first failing condition (in evaluation order) is recorded.
- **Dependency fails:** dependent conditions are not evaluated (short-circuit propagates).

---

# Dependency Rules

## Dependency Model
Each condition may depend on zero or more other conditions. Dependencies are:
- **Explicit:** defined in the condition's dependency list.
- **Hard:** if a dependency is not met, the dependent condition is not evaluated (short-circuit).
- **Transitive:** if A depends on B and B depends on C, then A transitively depends on C.

## Dependency Validation
- **Circular dependencies:** detected at init; defensive INVALID state.
- **Missing dependencies:** detected at init; defensive INVALID state.
- **Self-dependencies:** detected at init; defensive INVALID state.

---

# Validation Result

## Confluence Result Object
The Confluence Result Object is the **output** of the Confluence Engine. It contains:

| Field | Type | Description |
|---|---|---|
| **Status** | Enum | ACCEPTED / REJECTED / INVALID |
| **Timestamp** | DateTime | Bar close time (M15) |
| **Evaluated Conditions** | List | List of evaluated conditions (ID, name, result, context) |
| **Failing Condition** | Object | (If REJECTED) The first failing condition (ID, name, context, reason) |
| **Evaluation Order** | List | The order in which conditions were evaluated |
| **Short-Circuit Point** | Integer | (If REJECTED) The index in the evaluation order where short-circuit occurred |
| **Audit Trail** | Object | Full audit information (see Audit Trail section) |

## Status Values
- **ACCEPTED:** all required conditions are met.
- **REJECTED:** at least one condition is not met.
- **INVALID:** defensive state (error, circular dependency, etc.).

---

# Failure Result

## Failure Modes
1. **Condition not met:** a required condition is false → REJECTED.
2. **Condition evaluator error:** an error occurs during evaluation → INVALID.
3. **Circular dependency:** detected at init → INVALID.
4. **Missing dependency:** detected at init → INVALID.
5. **Aggregation error:** error during result aggregation → INVALID.

## Failure Handling
- **REJECTED:** produce Confluence Result Object with status = REJECTED; record failing condition.
- **INVALID:** produce Confluence Result Object with status = INVALID; record error reason.

---

# Context Acceptance

## Acceptance Criteria
A Trade Context is **accepted** if and only if:
1. All required conditions are evaluated.
2. All evaluated conditions are met (true).
3. No errors occurred during evaluation.

## Acceptance Result
- **Status:** ACCEPTED.
- **Evaluated Conditions:** all conditions (all met).
- **Failing Condition:** null.
- **Short-Circuit Point:** null.

---

# Context Rejection

## Rejection Criteria
A Trade Context is **rejected** if:
1. At least one required condition is not met (false).
2. Evaluation short-circuits at the first failing condition.

## Rejection Result
- **Status:** REJECTED.
- **Evaluated Conditions:** all conditions up to and including the failing condition.
- **Failing Condition:** the first failing condition (ID, name, context, reason).
- **Short-Circuit Point:** the index in the evaluation order where short-circuit occurred.

---

# Audit Trail

## Audit Information
Every Confluence Result Object includes a full audit trail:

| Field | Description |
|---|---|
| **Bar Timestamp** | M15 bar close time |
| **Trade Context Snapshot** | Reference to the Trade Context Object used |
| **Evaluation Start Time** | When evaluation began |
| **Evaluation End Time** | When evaluation ended |
| **Evaluation Duration** | Time taken (for performance analysis) |
| **Condition Results** | For each evaluated condition: ID, name, result (met/not met), context (specific data used) |
| **Failing Condition Details** | (If REJECTED) Full details of the failing condition: ID, name, context, reason for failure |
| **Evaluation Order** | The order in which conditions were evaluated |
| **Short-Circuit Point** | (If REJECTED) The index where short-circuit occurred |
| **Error Details** | (If INVALID) Full error details: type, message, stack trace (if available) |

## Audit Purpose
The audit trail enables:
1. **Reconstruction:** any decision can be fully reconstructed from the audit trail.
2. **Debugging:** failures can be traced to specific conditions and contexts.
3. **Backtesting:** historical decisions can be replayed exactly.
4. **Compliance:** all decisions are fully documented.

---

# Confluence Lifecycle

## Lifecycle States
The Confluence Engine has the following lifecycle:

### INITIALIZATION
- **Purpose:** Load required conditions and their dependencies.
- **Actions:** Validate dependencies (no circular, no missing, no self-dependencies); compute evaluation order.
- **Exit:** READY (if valid) or INVALID (if invalid).

### READY
- **Purpose:** Ready to evaluate Trade Context Objects.
- **Actions:** Evaluate each Trade Context Object as it arrives.
- **Exit:** None (terminal state for normal operation).

### INVALID
- **Purpose:** Defensive state (initialization failed).
- **Actions:** Reject all Trade Context Objects with status = INVALID.
- **Exit:** None (terminal state; requires manual intervention).

## Lifecycle Guarantees
- The engine is in READY state during normal operation.
- The engine produces exactly one Confluence Result Object per Trade Context Object.
- The engine never modifies the Trade Context Object.
- The engine never decides BUY or SELL.

---

# Determinism

## Deterministic Guarantees
1. **Identical inputs ⇒ identical outputs:** the same Trade Context Object always produces the same Confluence Result Object.
2. **No randomness:** no random number generation, no probabilistic logic.
3. **No learning:** no adaptation, no historical performance feedback.
4. **No hidden state:** all state is in the Trade Context Object and the condition definitions.
5. **Reproducible:** backtests are fully reproducible.

## Determinism Enforcement
- All inputs are from the frozen Structural Context snapshot.
- All evaluations are pure functions (no side effects).
- All results are immutable after creation.

---

# Repeatability

## Repeatability Guarantees
1. **Backtest repeatability:** historical decisions can be replayed exactly.
2. **Forward-test repeatability:** live decisions can be replayed from logs.
3. **Cross-platform repeatability:** the same logic on different platforms produces the same results.

## Repeatability Enforcement
- All inputs are logged (Trade Context Object).
- All outputs are logged (Confluence Result Object).
- All condition evaluators are deterministic.

---

# Implementation Constraints

## Maximum CPU Cost
- **Per evaluation:** O(C) where C = number of conditions (typically ≤ 10).
- **Per bar:** O(C) (one evaluation per closed M15 bar).
- **Worst case:** all conditions evaluated (no short-circuit) → O(C).
- **Average case:** short-circuit after first few conditions → O(1) to O(C/2).

## Maximum Memory Cost
- **Per evaluation:** O(C) (store condition results).
- **Per bar:** O(C) (one Confluence Result Object per bar).
- **Retention:** bounded by FIFO archival (keep most recent N results).

## Caching
- **Condition evaluators:** may cache intermediate results (e.g., OB zone lookups) within a single evaluation.
- **Cross-bar caching:** not allowed (each evaluation is independent).

## Synchronization
- **Single-threaded:** the Confluence Engine is single-threaded (no concurrent evaluations).
- **Immutable inputs:** the Trade Context Object is immutable during evaluation.

## Update Frequency
- **Once per closed M15 bar:** the Confluence Engine evaluates exactly one Trade Context Object per closed M15 bar.
- **Never on ticks:** no tick-based evaluation.

---

# Performance

## Worst Case
- **All conditions evaluated:** O(C) where C = number of conditions.
- **Time:** typically < 1 ms per evaluation (simple boolean checks).
- **Memory:** O(C) per evaluation.

## Average Case
- **Short-circuit after first few conditions:** O(1) to O(C/2).
- **Time:** typically < 0.5 ms per evaluation.
- **Memory:** O(1) to O(C/2) per evaluation.

## Complexity
- **Time complexity:** O(C) worst case, O(1) average case (with short-circuit).
- **Space complexity:** O(C) per evaluation.

## Scalability
- **Linear scaling:** performance scales linearly with the number of conditions.
- **Bounded:** the number of conditions is small (typically ≤ 10), so performance is effectively constant.

---

# Cross-Document Consistency

| Concern | How DOC03B respects it |
|---|---|
| DOC00 (strategy rules) | DOC03B defines **no trading rules**; it provides the architectural slots where DOC00's conditions are validated. |
| DOC00_PATCH_001 (timeframes) | Evaluation is per closed M15 bar. |
| DOC01 (architecture) | DOC03B implements Stage 3 of the Decision Pipeline (DOC03A). |
| DOC02A–F (detection engines) | DOC03B consumes DOC02A–F outputs read-only via the Trade Context Object; it never modifies them. |
| DOC03A (Trading Intelligence Blueprint) | DOC03B implements the Confluence Framework defined in DOC03A; it uses STRICT AND as the combination mechanism. |

---

# Self Review Result

Before finalising, the document was checked against the required checklist. Findings and resolutions:

- **No trading rules defined:** DOC03B defines **only architecture** (validation pipeline, evaluation order, short-circuit rules, dependency rules, validation result, audit trail). No BUY logic, no SELL logic, no specific conditions. All conditions are deferred to future DOC03 modules. *(Pass)*
- **No BUY logic:** DOC03B does not decide BUY. It only validates confluence. *(Pass)*
- **No SELL logic:** DOC03B does not decide SELL. It only validates confluence. *(Pass)*
- **No repaint:** Eliminated. All inputs from closed bars; Trade Context Object is immutable; Confluence Result Object is immutable after creation. *(Pass)*
- **No look-ahead bias:** Eliminated. All inputs from closed bars; evaluation is per closed M15 bar. *(Pass)*
- **No circular dependency:** Dependency validation detects circular dependencies at init; defensive INVALID state. *(Pass)*
- **Consistency with DOC03A:** DOC03B implements Stage 3 (Confluence Evaluation) of the Decision Pipeline; it uses STRICT AND as defined in DOC03A's Confluence Framework. *(Pass)*
- **Consistency with DOC02:** DOC03B consumes DOC02A–F outputs read-only via the Trade Context Object; it never modifies them. *(Pass)*
- **Consistency with DOC01:** DOC03B conforms to DOC01's architecture (layering, immutability, closed-bar discipline, frozen snapshot). *(Pass)*
- **Implementation feasibility:** All inputs via Trade Context Object; O(C) complexity; bounded memory; single-threaded; deterministic. *(Pass)*

**Scope boundaries respected:** No trading rules defined. No BUY/SELL logic. No Execution logic. No Risk Management. No Position Management. No Order Placement.

**Design Decision Record (DDR):** Documented why STRICT AND is adopted and why alternatives are rejected.

**Outcome:** No blocking issues. DOC03B is internally consistent, deterministic, non-repainting, look-ahead-safe, circular-dependency-free, and fully conforms to DOC00–DOC03A.

---

# Final Notes

1. **Architecture only.** This document specifies the Confluence Engine architecture and nothing else. No trading rules, no BUY/SELL logic, no specific conditions.
2. **STRICT AND only.** The Confluence Engine uses STRICT AND as the only confluence mechanism. All alternatives are rejected.
3. **Consumer discipline.** The Confluence Engine consumes the Trade Context Object read-only and never mutates it. It produces the Confluence Result Object.
4. **Short-circuit on first failure.** Evaluation stops at the first failing condition; no wasted computation.
5. **Full audit trail.** Every decision (accepted or rejected) is fully reconstructable from the audit trail.
6. **Deterministic + repeatable.** Identical inputs ⇒ identical outputs; backtests are fully reproducible.
7. **Downstream consumers** (DOC03A Stage 4) consume the Confluence Result Object; they must not redefine the confluence architecture or mutate the result.

This document is now the official specification for the Confluence Engine.
