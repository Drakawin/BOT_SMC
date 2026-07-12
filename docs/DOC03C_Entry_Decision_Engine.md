# DOC03C — Entry Decision Engine
## Official Specification for Final Entry Decision

> **Document status:** AUTHORITATIVE — Official specification for the **Entry Decision Engine**.
> **Phase:** Phase 3 (Trading Intelligence) — Final Decision (Part C).
> **This is NOT a trading-rule document.** This document defines the **architecture** of the final decision engine. It does NOT define which specific conditions determine LONG vs SHORT. It defines HOW the final decision is made, not WHAT conditions trigger LONG or SHORT.
> **Scope of this document:** Entry Decision Logic, Decision Pipeline Stage 4, Decision Output Object, Audit Information, Decision Lifecycle.
> **Explicitly out of scope:** BUY logic, SELL logic, Execution, Risk Management, Position Management, Order Placement, specific entry conditions (those are defined in DOC00–DOC02 and validated by DOC03B).
> **Relationship to prior documents:**
> - **Implements** Stage 4 (Final Decision) of the Decision Pipeline defined in **DOC03A_Trading_Intelligence_Blueprint.md**.
> - **Consumes** the Confluence Result Object (from DOC03B Stage 3).
> - **Produces** the Decision Output Object consumed by DOC04 (Execution).
> - **Conforms** to DOC00 (strategy rules), DOC00_PATCH_001 (timeframes), DOC01 (architecture), DOC02A–F (detection engines), DOC03A (Trading Intelligence Blueprint), and DOC03B (Confluence Engine).
> **Priority rule:** If anything here appears to conflict with DOC00–DOC03B, those documents prevail. DOC03C governs only the Entry Decision Engine architecture.

---

# Design Decision Record (DDR)

## Decision: Deterministic Decision Logic

**Decision:** The Entry Decision Engine uses **deterministic decision logic** based on the Confluence Result Object and Bias Context. The decision is a pure function of the inputs.

**Alternatives Rejected:**
1. **Heuristic-based** — decision based on heuristics or rules of thumb.
2. **Machine learning** — decision based on ML model predictions.
3. **Probabilistic** — decision based on probabilities.
4. **Adaptive** — decision logic adapts based on performance.

**Reason:**
1. **Determinism** — identical inputs ⇒ identical output. No ambiguity, no interpretation.
2. **Auditability** — every decision is fully reconstructable from inputs.
3. **Simplicity** — no complex logic, no models to train, no parameters to tune.
4. **Repeatability** — backtests are fully reproducible.
5. **Consistency with DOC03B** — DOC03B uses STRICT AND; DOC03C continues with deterministic logic.
6. **No hidden subjectivity** — heuristics, ML, and probabilistic systems introduce hidden subjectivity.

**Impact on future modules:**
- Future DOC03 modules that define specific entry conditions must define them as deterministic rules.
- The decision logic is a pure function; no hidden state.
- All decisions are fully auditable.

---

# Entry Decision Engine — Architectural Specification

## Purpose
The Entry Decision Engine makes the final entry decision: ENTER_LONG, ENTER_SHORT, or NO_ENTRY. It does NOT execute the trade. It only decides whether to enter and in which direction.

## Architectural Role
- **Input:** Confluence Result Object (from DOC03B), Bias Context (from Trade Context Object).
- **Output:** Decision Output Object (to DOC04 Execution).
- **Lifetime:** One Decision Output Object per closed M15 bar; immutable after creation; archived for audit.
- **Position in Pipeline:** Stage 4 of the Decision Pipeline (DOC03A).

## Responsibilities
1. **Decide** whether to enter a trade and in which direction.
2. **Produce** a Decision Output Object with full audit trail.
3. **Never** execute the trade (that is DOC04's responsibility).

---

# Decision Logic

## Decision Model
The Entry Decision Engine uses a **deterministic decision model** based on:
1. **Confluence Result** — whether the Trade Context is accepted (from DOC03B).
2. **Bias Context** — the current bias (BULLISH / BEARISH / UNKNOWN) from the Trade Context Object.

## Decision Rules (architectural, not specific conditions)
The decision logic follows these rules:

### Rule 1: Confluence Check
- If Confluence Result status ≠ ACCEPTED → decision = NO_ENTRY.
- Rationale: if confluence validation failed, no trade should be taken.

### Rule 2: Bias Check
- If Bias Context is UNKNOWN → decision = NO_ENTRY.
- Rationale: if bias is unknown, no directional trade should be taken.

### Rule 3: Direction Assignment
- If Confluence Result status = ACCEPTED and Bias Context = BULLISH → decision = ENTER_LONG.
- If Confluence Result status = ACCEPTED and Bias Context = BEARISH → decision = ENTER_SHORT.

### Rule 4: Default
- If none of the above rules apply → decision = NO_ENTRY.

## Decision Logic Flow
```
1. Check Confluence Result status
   - If ≠ ACCEPTED → NO_ENTRY (exit)
2. Check Bias Context
   - If UNKNOWN → NO_ENTRY (exit)
3. Assign direction
   - If BULLISH → ENTER_LONG
   - If BEARISH → ENTER_SHORT
4. Return decision
```

## Determinism
- The decision is a **pure function** of the Confluence Result Object and Bias Context.
- Identical inputs ⇒ identical output.
- No hidden state, no randomness, no learning.

---

# Decision Output Object

## Structure
The Decision Output Object is the **output** of the Entry Decision Engine. It contains:

| Field | Type | Description |
|---|---|---|
| **Decision** | Enum | ENTER_LONG / ENTER_SHORT / NO_ENTRY |
| **Direction** | Enum | LONG / SHORT / NONE |
| **Timestamp** | DateTime | Bar close time (M15) |
| **Confluence Result Reference** | Object | Reference to the Confluence Result Object used |
| **Bias Context Reference** | Object | Reference to the Bias Context used |
| **Decision Logic Trace** | Object | Full trace of decision logic execution |
| **Audit Trail** | Object | Full audit information (see Audit Trail section) |

## Field Details

### Decision
- **ENTER_LONG:** decision to enter a long trade.
- **ENTER_SHORT:** decision to enter a short trade.
- **NO_ENTRY:** decision not to enter a trade.

### Direction
- **LONG:** long direction (for ENTER_LONG).
- **SHORT:** short direction (for ENTER_SHORT).
- **NONE:** no direction (for NO_ENTRY).

### Timestamp
- The M15 bar close time when the decision was made.

### Confluence Result Reference
- Reference to the Confluence Result Object from DOC03B.
- Enables full reconstruction of the decision.

### Bias Context Reference
- Reference to the Bias Context from the Trade Context Object.
- Enables full reconstruction of the decision.

### Decision Logic Trace
- Full trace of decision logic execution:
  - Rule 1 result (confluence check)
  - Rule 2 result (bias check)
  - Rule 3 result (direction assignment)
  - Rule 4 result (default, if reached)

### Audit Trail
- Full audit information (see Audit Trail section).

## Immutability
- The Decision Output Object is **immutable** after creation.
- No field can be modified after the object is created.

## Lifecycle
- **Created:** at the end of each closed M15 bar evaluation.
- **Consumed:** by DOC04 (Execution).
- **Archived:** for audit (FIFO retention).

---

# Audit Trail

## Audit Information
Every Decision Output Object includes a full audit trail:

| Field | Description |
|---|---|
| **Bar Timestamp** | M15 bar close time |
| **Trade Context Snapshot Reference** | Reference to the Trade Context Object used |
| **Confluence Result Reference** | Reference to the Confluence Result Object used |
| **Bias Context Reference** | Reference to the Bias Context used |
| **Decision Start Time** | When decision logic began |
| **Decision End Time** | When decision logic ended |
| **Decision Duration** | Time taken (for performance analysis) |
| **Rule Execution Trace** | For each rule: rule ID, result, context |
| **Final Decision** | The decision value |
| **Final Direction** | The direction value |
| **Error Details** | (If INVALID) Full error details: type, message, stack trace (if available) |

## Audit Purpose
The audit trail enables:
1. **Reconstruction:** any decision can be fully reconstructed from the audit trail.
2. **Debugging:** decisions can be traced to specific rules and contexts.
3. **Backtesting:** historical decisions can be replayed exactly.
4. **Compliance:** all decisions are fully documented.

---

# Decision Lifecycle

## Lifecycle States
The Entry Decision Engine has the following lifecycle:

### INITIALIZATION
- **Purpose:** Initialize decision logic.
- **Actions:** Load decision rules; validate rule dependencies.
- **Exit:** READY (if valid) or INVALID (if invalid).

### READY
- **Purpose:** Ready to make decisions.
- **Actions:** Make a decision for each Confluence Result Object as it arrives.
- **Exit:** None (terminal state for normal operation).

### INVALID
- **Purpose:** Defensive state (initialization failed).
- **Actions:** Return NO_ENTRY for all inputs.
- **Exit:** None (terminal state; requires manual intervention).

## Lifecycle Guarantees
- The engine is in READY state during normal operation.
- The engine produces exactly one Decision Output Object per Confluence Result Object.
- The engine never modifies the Confluence Result Object or Trade Context Object.
- The engine never executes trades.

---

# Determinism

## Deterministic Guarantees
1. **Identical inputs ⇒ identical outputs:** the same Confluence Result Object and Bias Context always produce the same Decision Output Object.
2. **No randomness:** no random number generation, no probabilistic logic.
3. **No learning:** no adaptation, no historical performance feedback.
4. **No hidden state:** all state is in the inputs.
5. **Reproducible:** backtests are fully reproducible.

## Determinism Enforcement
- All inputs are from the frozen Trade Context Object.
- All evaluations are pure functions (no side effects).
- All results are immutable after creation.

---

# Repeatability

## Repeatability Guarantees
1. **Backtest repeatability:** historical decisions can be replayed exactly.
2. **Forward-test repeatability:** live decisions can be replayed from logs.
3. **Cross-platform repeatability:** the same logic on different platforms produces the same results.

## Repeatability Enforcement
- All inputs are logged (Confluence Result Object, Bias Context).
- All outputs are logged (Decision Output Object).
- All decision logic is deterministic.

---

# Implementation Constraints

## Maximum CPU Cost
- **Per decision:** O(1) (simple rule checks).
- **Per bar:** O(1) (one decision per closed M15 bar).
- **Worst case:** O(1).
- **Average case:** O(1).

## Maximum Memory Cost
- **Per decision:** O(1) (store decision result).
- **Per bar:** O(1) (one Decision Output Object per bar).
- **Retention:** bounded by FIFO archival (keep most recent N results).

## Caching
- **Not applicable:** decision logic is O(1); no caching needed.

## Synchronization
- **Single-threaded:** the Entry Decision Engine is single-threaded (no concurrent decisions).
- **Immutable inputs:** the Confluence Result Object and Bias Context are immutable during decision.

## Update Frequency
- **Once per closed M15 bar:** the Entry Decision Engine makes exactly one decision per closed M15 bar.
- **Never on ticks:** no tick-based decisions.

---

# Performance

## Worst Case
- **All rules evaluated:** O(1).
- **Time:** typically < 0.1 ms per decision.
- **Memory:** O(1) per decision.

## Average Case
- **All rules evaluated:** O(1).
- **Time:** typically < 0.1 ms per decision.
- **Memory:** O(1) per decision.

## Complexity
- **Time complexity:** O(1).
- **Space complexity:** O(1) per decision.

## Scalability
- **Constant scaling:** performance is constant regardless of the number of conditions or bars.
- **Bounded:** decision logic is simple and fast.

---

# Cross-Document Consistency

| Concern | How DOC03C respects it |
|---|---|
| DOC00 (strategy rules) | DOC03C defines **no trading rules**; it provides the architectural framework where DOC00's entry conditions are applied. |
| DOC00_PATCH_001 (timeframes) | Decision is per closed M15 bar. |
| DOC01 (architecture) | DOC03C implements Stage 4 of the Decision Pipeline (DOC03A). |
| DOC02A–F (detection engines) | DOC03C consumes DOC02A–F outputs read-only via the Trade Context Object; it never modifies them. |
| DOC03A (Trading Intelligence Blueprint) | DOC03C implements Stage 4 (Final Decision) of the Decision Pipeline defined in DOC03A. |
| DOC03B (Confluence Engine) | DOC03C consumes the Confluence Result Object from DOC03B; it never modifies it. |

---

# Self Review Result

Before finalising, the document was checked against the required checklist. Findings and resolutions:

- **No trading rules defined:** DOC03C defines **only architecture** (decision logic, decision output object, audit trail). No BUY logic, no SELL logic, no specific conditions. All conditions are deferred to future DOC03 modules. *(Pass)*
- **No BUY logic:** DOC03C does not define specific BUY conditions. It only defines the architectural framework for making the decision. *(Pass)*
- **No SELL logic:** DOC03C does not define specific SELL conditions. It only defines the architectural framework for making the decision. *(Pass)*
- **No repaint:** Eliminated. All inputs from closed bars; Confluence Result Object and Bias Context are immutable; Decision Output Object is immutable after creation. *(Pass)*
- **No look-ahead bias:** Eliminated. All inputs from closed bars; decision is per closed M15 bar. *(Pass)*
- **No circular dependency:** Decision logic is a pure function of inputs; no circular dependencies. *(Pass)*
- **Consistency with DOC03A:** DOC03C implements Stage 4 (Final Decision) of the Decision Pipeline; it produces the Decision Output Object as defined in DOC03A. *(Pass)*
- **Consistency with DOC03B:** DOC03C consumes the Confluence Result Object from DOC03B; it never modifies it. *(Pass)*
- **Consistency with DOC02:** DOC03C consumes DOC02A–F outputs read-only via the Trade Context Object; it never modifies them. *(Pass)*
- **Consistency with DOC01:** DOC03C conforms to DOC01's architecture (layering, immutability, closed-bar discipline, frozen snapshot). *(Pass)*
- **Implementation feasibility:** All inputs via Confluence Result Object and Bias Context; O(1) complexity; bounded memory; single-threaded; deterministic. *(Pass)*

**Scope boundaries respected:** No trading rules defined. No BUY/SELL logic. No Execution logic. No Risk Management. No Position Management. No Order Placement.

**Design Decision Record (DDR):** Documented why deterministic decision logic is adopted and why alternatives are rejected.

**Outcome:** No blocking issues. DOC03C is internally consistent, deterministic, non-repainting, look-ahead-safe, circular-dependency-free, and fully conforms to DOC00–DOC03B.

---

# Final Notes

1. **Architecture only.** This document specifies the Entry Decision Engine architecture and nothing else. No trading rules, no BUY/SELL logic, no specific conditions.
2. **Deterministic logic only.** The Entry Decision Engine uses deterministic decision logic based on the Confluence Result Object and Bias Context. All alternatives are rejected.
3. **Consumer discipline.** The Entry Decision Engine consumes the Confluence Result Object and Bias Context read-only and never mutates them. It produces the Decision Output Object.
4. **Simple decision rules.** The decision logic is a pure function: check confluence, check bias, assign direction. No complexity.
5. **Full audit trail.** Every decision is fully reconstructable from the audit trail.
6. **Deterministic + repeatable.** Identical inputs ⇒ identical outputs; backtests are fully reproducible.
7. **Downstream consumers** (DOC04 Execution) consume the Decision Output Object; they must not redefine the decision architecture or mutate the output.

This document is now the official specification for the Entry Decision Engine.
