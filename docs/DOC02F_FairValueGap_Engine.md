# DOC02F — Fair Value Gap Engine
## Official Specification for FVG Detection, Lifecycle, and Fill (H1)

> **Document status:** AUTHORITATIVE — Official specification for the **Fair Value Gap Engine only**.
> **Phase:** Module Specification (Phase 2, Part F).
> **Scope of this document:** Bullish Fair Value Gap, Bearish Fair Value Gap, Fair Value Gap Detection, Validation, Lifecycle, Fill (Partial/Complete), Invalidation, Active/Historical Fair Value Gaps, and Fair Value Gap States.
> **Explicitly out of scope (future documents):** Entry Strategy, Risk Management, Trade Management, Order Block Selection, and Liquidity Selection. The FVG Engine produces and lifecycle-manages FVG zones only; how an FVG is *selected* as a confluence for an entry is a future-document concern.
> **Relationship to prior documents:**
> - Implements **DOC00_Strategy_Validation.md §16 (Fair Value Gap)** without modification to its definition or constants.
> - Conforms to **DOC00_PATCH_001.md**: FVGs are detected and lifecycle-managed on the **Market Structure Timeframe (H1)**.
> - Realises the **Fair Value Gap Engine** module defined in **DOC01_System_Architecture.md** (Layer 2), writing into the *FVG* section of the Structural Context. It is the sole writer of that section.
> - Consumes **only** the outputs of **DOC02A** (Confirmed Swing Data, Market Structure State), **DOC02B** (Confirmed BOS), **DOC02C** (Confirmed CHoCH, Prevailing Direction), **DOC02D** (Liquidity Events), and **DOC02EB** (Confirmed Order Blocks). It creates or modifies **none** of those records.
> **Priority rule:** If anything here appears to conflict with DOC00–DOC02EB, those documents prevail. DOC02F governs only the Fair Value Gap Engine details.

---

# Reported Items (reported, not changed)

Per the standing instruction to *report* rather than silently change, the following are flagged. Each defines a **new operational construct** required by this document's scope that is **not present in DOC00**, defined deterministically and consistently with DOC00. **No approved document was modified.**

| # | Item | Status |
|---|---|---|
| R-1 | **FVG States / Lifecycle machine** (Candidate/Confirmed/Active/Partially Filled/Filled/Invalidated/Expired/Archived) — DOC00 §16 specifies only *detection* (3-candle pattern), *minimum size*, *merging of overlapping FVGs*, and *fill* (body fully trades through). DOC00 does not name a state machine, nor the Candidate/Partially Filled/Expired/Archived states. DOC02F designs the requested lifecycle as the operational realisation of DOC00's detect/fill semantics, plus deterministic partial-fill tracking, supersession (Expired), and archival (Archived). It is a DOC02F design element, not a DOC00 redefinition. | Reported — extension, consistent with DOC00 §16. |
| R-2 | **Partial Fill** — DOC00 §16 defines fill only as "a later closed candle's body fully trades through the gap" (i.e., DOC00's fill is the *complete* fill). DOC00 is silent on partial fills. DOC02F defines **Partial Fill** as the deterministic tracking of body penetration into an unfilled gap that does **not** fully close it: the gap's unfilled portion is tracked by adjusting the remaining boundary, while the original zone is preserved immutably for audit. Complete fill (DOC00 §16) remains the lifecycle-terminating event. This adds no subjective threshold. | Reported — extension, consistent with DOC00 §16. |
| R-3 | **FVG Expiration** — DOC00 has no expiration concept for FVGs (an FVG only changes via complete fill or, per DOC02F, invalidation). DOC02F defines **Expired** as **supersession**: an unfilled, uninvalidated ACTIVE FVG becomes EXPIRED when a newer FVG of the **same direction** is confirmed and the active-set cap for that direction is reached, or when superseded by a more recent, more relevant same-direction FVG per a fixed ordering rule. This bounds the active set deterministically. No arbitrary time constant is introduced. | Reported — extension (DOC00 is silent on coexistence caps). |
| R-4 | **Active vs Historical FVGs** — DOC00 does not distinguish "active" vs "historical" FVGs explicitly. DOC02F defines **Active FVGs** (the current, consumable unfilled/partially-filled set) and **Historical FVGs** (filled/invalidated/expired/archived records retained for audit). Organisational distinction, not a new SMC rule. | Reported — extension, no contradiction. |
| R-5 | **FVG Invalidation (gap collapse)** — DOC00 §16 does **not** define an "invalidation" event for FVGs (only fill). DOC02F defines **Invalidation** as the deterministic event where the gap **collapses to zero width** while still unfilled — i.e., the gap boundaries cease to define a positive-width zone — recorded only on a closed candle. This is distinct from fill (price passing *through* the gap) and is necessary for a complete lifecycle. The official fill rule (DOC00 §16: body fully trades through the gap) remains the primary terminal event; invalidation handles the degenerate case. | Reported — extension, consistent with DOC00 (DOC00's "tiny FVGs that never fill" is mitigated by FVG Min Size at creation; collapse handles the rare post-creation zero-width case). |
| R-6 | **Body-based vs Wick-based fill — official rule.** DOC00 §16 defines fill on the **body** ("a later closed candle's body fully trades through the gap"). DOC02F adopts **body-based fill** as the official, sole fill rule (Complete Fill). Wick-based fill is **not** adopted as an official state transition (a wick into the gap does not fill it); it is recorded only as optional audit context. This preserves DOC00 exactly and removes the wick-vs-body ambiguity. | Reported — clarification/decision, consistent with DOC00 §16. |
| R-7 | **Liquidity / OB / structure context as optional, not a creation requirement.** DOC00 §16 defines an FVG purely by the 3-candle pattern + minimum size; it does **not** require an OB, a sweep, a BOS, or a CHoCH to create an FVG. DOC02F therefore consumes these (DOC02B/C/D/EB) only as **optional quality context** attached to an FVG record, never as conditions for creation. | Reported — consistent with DOC00 §16. |
| R-8 | **Overlap merging is a creation-time operation.** DOC00 §16 edge case: "Overlapping FVGs → merge into one zone spanning the outer bounds." DOC02F operationalises this: at creation, if a new FVG overlaps an existing same-direction ACTIVE FVG, they are merged into a single FVG whose boundaries span the outer bounds, with a merged creation/lock provenance. This is performed once at creation and is immutable thereafter. | Reported — operationalisation of DOC00 §16 edge case. |

No approved document was modified.

---

# Conformance Summary

DOC02F introduces **no new SMC definition** that contradicts DOC00. The DOC00 definition is reproduced with operational detail; new constructs (States, Partial Fill, Expiration, Active/Historical, Invalidation/collapse) are operational layers. Constants/decisions in force:

| Constant / Decision | Value | Source |
|---|---|---|
| Pattern | **3 consecutive closed candles**, ordered 1-2-3 left to right by close time | DOC00 §16 |
| Bullish FVG gap | `low(candle 3) > high(candle 1)` (strict) | DOC00 §16 |
| Bearish FVG gap | `high(candle 3) < low(candle 1)` (strict) | DOC00 §16 |
| Bullish FVG zone | bounded by `high(candle 1)` (lower) and `low(candle 3)` (upper) | DOC00 §16 |
| Bearish FVG zone | bounded by `low(candle 1)` (upper) and `high(candle 3)` (lower) | DOC00 §16 |
| Confirmation instant | after **candle 3 closes** | DOC00 §16 |
| FVG Min Size | **10 points** (XAUUSD); gaps smaller than this are ignored (not created) | DOC00 Deterministic Rules |
| Overlap handling | overlapping same-direction FVGs → **merge** into outer bounds | DOC00 §16 edge case, R-8 |
| Complete fill rule | a later closed candle's **body** fully trades through the gap | DOC00 §16, R-6 |
| Detection timeframe | **H1** (Market Structure Timeframe) | PATCH_001 |
| Repaint | none — confirmed on candle 3 close; immutable thereafter | DOC00 §16 |

---

# Concept 1 — Bullish Fair Value Gap

- **Definition:** A **Bullish FVG** is a three-candle pattern where the **low of candle 3** is **strictly greater than** the **high of candle 1** (candles ordered 1-2-3 left to right by close time). The gap (imbalance zone) between `high(candle 1)` and `low(candle 3)` is the FVG zone. Evaluated only after candle 3 closes. (DOC00 §16, unchanged.)
- **Purpose:** Mark an upward imbalance / inefficient price delivery that price tends to revisit; a confluence element (DOC00 Entry Confirmation) and, downstream, an entry context (out of scope here).
- **Relationship with previous documents:** Reproduces DOC00 §16 (bullish). Written into the *FVG* section of the Structural Context (DOC01); this engine is the sole writer.
- **Inputs:** Three consecutive closed H1 candles (their Highs/Lows).
- **Outputs:** A Bullish FVG record (direction, zone upper/lower boundaries, source candles 1 & 3 timestamps, creation timestamp, lock timestamp, state, optional context).
- **Dependencies:** DOC01 Market Data Access (closed H1 OHLC); Utility; Logger. Optional context from DOC02A/B/C/D/EB (never required for creation).
- **Validation/Detection/Confirmation Rules:** see respective sections.
- **Failure Conditions:** gap condition not met; gap < FVG Min Size; candle 3 not closed.
- **Edge Cases / Automation / Implementation / Complexity / Memory / Update / Lifecycle:** see respective sections.

---

# Concept 2 — Bearish Fair Value Gap

- **Definition:** A **Bearish FVG** is a three-candle pattern where the **high of candle 3** is **strictly less than** the **low of candle 1**. The gap between `low(candle 1)` and `high(candle 3)` is the FVG zone. Evaluated only after candle 3 closes. (DOC00 §16, unchanged.)
- **Purpose:** Mark a downward imbalance; mirror of Bullish.
- **Relationship with previous documents:** Mirror of Bullish. DOC00 §16.
- **Inputs/Outputs/Dependencies/Rules:** Mirror of Bullish.

---

# Fair Value Gap Detection — Detailed

### Required candle pattern
- Three consecutive closed H1 candles, ordered 1-2-3 left to right by close time (DOC00 §16). Candle 2 is the middle (impulse) candle; the gap is the displacement between candle 1 and candle 3.

### Gap definition
- **Bullish:** `low(candle 3) > high(candle 1)` — strict. The zone is `[high(candle 1), low(candle 3)]`.
- **Bearish:** `high(candle 3) < low(candle 1)` — strict. The zone is `[high(candle 3), low(candle 1)]`.

### Body relationship
- The FVG is defined by **Highs and Lows of candles 1 and 3**, not by their bodies. The body of candle 2 is irrelevant to gap existence (it is the impulse candle). Bodies are used only for **fill** (the official body-based fill rule, R-6).

### Wick relationship
- The gap uses the **wicks** of candles 1 and 3 (their Highs/Lows). This is inherent to DOC00 §16's definition (it references "high of candle 1" / "low of candle 3"). Wicks define the zone; bodies define fills.

### Minimum gap definition
- FVG Min Size = **10 points** (DOC00 constant). The gap width (`low(candle 3) − high(candle 1)` for bullish; `low(candle 1) − high(candle 3)` for bearish) must be **≥ FVG Min Size**. Smaller gaps are **not created** (DOC00 §16 false-signal mitigation).

### Gap precision
- All boundary prices use the symbol's native precision (XAUUSD, 2–3 decimals on Exness). No rounding. Comparisons in the symbol's `_Point`.

### Creation timestamp
- The **creation timestamp** = the close time of **candle 1** (the earliest candle contributing to the gap). Records where the imbalance began. (Pinned precisely here; DOC00 did not name it.)

### Lock timestamp
- The **lock timestamp** = the close time of **candle 3** (the confirmation instant, DOC00 §16). At this instant the FVG becomes a confirmed, immutable record. Lock timestamp is always **>** creation timestamp (candle 3 closes after candle 1).

### Immutable rules
1. Once created (at the lock timestamp), the FVG zone boundaries are **never edited**. (DOC00 §16; DOC01 immutability.)
2. Only the **state** and the **remaining unfilled boundary** (for Partial Fill tracking, R-2) may change, via defined lifecycle transitions on closed bars. The **original zone** is preserved immutably for audit.
3. No later candle may "move" or "re-select" the source candles. (Prevents repaint.)

### Rejected candidate rules
A candidate FVG is **rejected** (never created) when:
- Candle 3 is not closed (forming).
- The strict gap inequality fails (no gap; or equality, which is not strict).
- The gap width is **< FVG Min Size** (too small).
- Any of candles 1/2/3 cannot be certified as closed H1 bars (history gap/invalid).
- Overlap-merge with an existing same-direction ACTIVE FVG: the *new* candidate is merged into the existing record's outer bounds rather than created separately (R-8); the merged record's boundaries are the outer bounds of both.
Rejected candidates leave no standalone record and emit no error (silent non-event, logged at DEBUG).

---

# Fair Value Gap Zone — Detailed

### Upper Boundary
- **Bullish FVG:** Upper boundary = `low(candle 3)`.
- **Bearish FVG:** Upper boundary = `low(candle 1)`.

### Lower Boundary
- **Bullish FVG:** Lower boundary = `high(candle 1)`.
- **Bearish FVG:** Lower boundary = `high(candle 3)`.

### Gap Width
- Width = |Upper Boundary − Lower Boundary|. Computed once at creation; immutable. Must be ≥ FVG Min Size to be created.

### Zone Precision
- Symbol native precision; no rounding.

### Lifetime
- Zone boundaries (original) are fixed at creation and never change. For Partial Fill, a **separate "remaining" boundary** is tracked; the original zone is preserved.

### Modification Rules
- The **original zone is immutable**. The only mutable derived value is the remaining-unfilled boundary used for Partial Fill tracking. Merging (R-8) happens once at creation and produces a new immutable merged record; it is not a post-creation modification.

---

# Fair Value Gap Fill — Detailed

### Definition
Fill is the event of price returning into and **through** the FVG zone after creation. DOC00 §16 defines the **official fill** as a later closed candle's **body** fully trading through the gap. (R-6.)

### Partial Fill
- A **Partial Fill** occurs when a closed candle's body enters the gap but does **not** fully trade through it. The unfilled portion of the gap is tracked by adjusting the **remaining boundary** toward the intrusion, while the original zone is preserved. (R-2.)
- Bullish FVG (zone `[high(c1), low(c3)]`, price returning from above): if a closed candle's body penetrates below the current upper remaining boundary but its body does not reach the lower boundary, the remaining upper boundary is lowered to `min(open, close)` of that candle (the deepest body point), reducing the unfilled gap. The FVG state → PARTIALLY FILLED.
- Bearish FVG (price returning from below): mirror — the remaining lower boundary is raised to `max(open, close)` of the intruding candle.
- Partial fill tracking is **deterministic** and uses only closed-candle bodies. No threshold beyond the body geometry.

### Complete Fill
- A **Complete Fill** occurs when a closed candle's body **fully trades through the gap** — i.e., the body spans the entire (remaining) gap, covering both boundaries. (DOC00 §16.) The FVG state → FILLED.
- Bullish: body reaches the lower boundary (`min(open,close) ≤ lower boundary`). Bearish: body reaches the upper boundary (`max(open,close) ≥ upper boundary`).

### Body-based Fill
- The **official** fill rule (DOC00 §16, R-6). Both Partial and Complete Fill are evaluated on the **body** (open-to-close range) of closed candles.

### Wick-based Fill
- **Not an official fill.** A wick into the gap does **not** fill it (no state transition). It may be recorded as optional audit context only. (R-6.)

### Official fill rule
- **Body-based, closed-candle.** A later closed candle's body fully trading through the (remaining) gap = Complete Fill (terminal). Body entering but not fully traversing = Partial Fill (state, remaining boundary adjusted). Wick penetration = no fill. This is the single, deterministic fill rule for this project.

### Repeated fills
- Once an FVG is FILLED (complete), it is terminal (→ ARCHIVED). Repeated body penetrations of a PARTIALLY FILLED FVG are accumulated deterministically into the remaining boundary until either complete fill or invalidation.

### Gap reopening policy
- **Gaps do not reopen.** Once an FVG is FILLED (complete) or INVALIDATED, it is terminal; a later departure from the zone does not resurrect it. A *new* gap forming later is a new FVG record. (Consistent with immutability and the monotonic lifecycle.)

---

# Fair Value Gap Invalidation — Detailed

### Definition
Invalidation is the deterministic event where an unfilled (or partially filled) FVG's gap **collapses to zero (or negative) effective width** while still un-filled — the boundaries cease to define a positive-width unfilled zone. (R-5.)

### Required Conditions
- The FVG is in ACTIVE or PARTIALLY FILLED state.
- On a closed candle, the remaining gap width becomes ≤ 0 (the remaining upper boundary is no longer strictly above the remaining lower boundary for a bullish FVG; mirror for bearish). This occurs when price action between the boundaries has eliminated the gap without a single complete-fill candle.

### Body Close Requirement
- Invalidation is evaluated on **closed candles** (the same closed-candle evaluation as fill). The collapse is determined from the sequence of body-based partial-fill adjustments; when the remaining width hits ≤ 0, the FVG is INVALIDATED (not FILLED), because no single candle's body fully traversed the original gap — the gap simply ceased to exist as a positive-width zone.

### Gap Collapse
- "Gap collapse" = remaining width ≤ 0. Recorded on the closed candle where this is first true.

### Invalidation Timestamp
- The close time of the closed candle where collapse is first detected.

### Invalidation State
- The FVG transitions ACTIVE/PARTIALLY FILLED → INVALIDATED → ARCHIVED. An invalidated FVG is no longer consumable. (Note: in practice, Complete Fill is the common terminal event; invalidation handles the rare degenerate collapse, per R-5.)

---

# Fair Value Gap Lifecycle — Complete State Machine

Each FVG has exactly one state at any time. Transitions occur only on closed H1 bars. (R-1.)

### States

#### CANDIDATE
- **Purpose:** Three candles 1-2-3 are being evaluated; candle 3 is closing/closed. Pre-publication.
- **Entry Conditions:** Candle 3 of a candidate trio has closed (or is being evaluated at bar close).
- **Exit Conditions:** Gap condition + FVG Min Size satisfied and no merge → CONFIRMED; merge with existing same-direction ACTIVE FVG → that record is updated (merged) and the candidate is absorbed; conditions fail → rejected (no record).
- **Allowed Transitions:** → CONFIRMED; → (merged into existing); → (rejected).
- **Forbidden Transitions:** → ACTIVE, FILLED, etc. (cannot be acted upon before confirmation).
- **Recovery:** Transient; resolved within the same bar evaluation.

#### CONFIRMED
- **Purpose:** The FVG zone has been created/locked (at candle 3 close, or merged). Immutable record now exists.
- **Entry Conditions:** From CANDIDATE when validation passes.
- **Exit Conditions:** Finalisation → ACTIVE.
- **Allowed Transitions:** → ACTIVE.
- **Forbidden Transitions:** → FILLED, INVALIDATED, EXPIRED (require ACTIVE first).
- **Recovery:** Automatic finalisation.

#### ACTIVE
- **Purpose:** The FVG is a live, consumable unfilled gap; eligible for fill/invalidation checks and downstream consumption.
- **Entry Conditions:** From CONFIRMED. Active-set cap enforced per direction (R-3): if a new same-direction FVG is created and the cap is exceeded, the oldest ACTIVE same-direction FVG → EXPIRED.
- **Exit Conditions:** Partial fill (→ PARTIALLY FILLED), complete fill (→ FILLED), invalidation (→ INVALIDATED), supersession (→ EXPIRED).
- **Allowed Transitions:** → PARTIALLY FILLED, FILLED, INVALIDATED, EXPIRED, ARCHIVED (retention), INVALID (defensive).
- **Forbidden Transitions:** → CANDIDATE, CONFIRMED.
- **Recovery:** Rebuild from immutable histories on inconsistency.

#### PARTIALLY FILLED
- **Purpose:** A closed candle's body has entered the gap but not fully traversed it; the remaining unfilled boundary is tracked. (R-2.)
- **Entry Conditions:** From ACTIVE (or remains here on further partial fills) on the first body penetration that does not complete the fill.
- **Exit Conditions:** Complete fill (→ FILLED), invalidation/collapse (→ INVALIDATED), supersession/archival (→ EXPIRED/ARCHIVED).
- **Allowed Transitions:** → FILLED, INVALIDATED, EXPIRED, ARCHIVED.
- **Forbidden Transitions:** → ACTIVE (partial fill is monotonic; an FVG does not become "un-partially-filled"). Note: the remaining boundary may move further with more partial fills, but the state stays PARTIALLY FILLED.
- **Recovery:** None; monotonic.

#### FILLED
- **Purpose:** A closed candle's body fully traded through the gap (DOC00 §16 complete fill). Terminal (the gap is consumed).
- **Entry Conditions:** From ACTIVE or PARTIALLY FILLED on a complete-fill body.
- **Exit Conditions:** → ARCHIVED.
- **Allowed Transitions:** → ARCHIVED.
- **Forbidden Transitions:** → any active state (filled FVGs never reopen).
- **Recovery:** None.

#### INVALIDATED
- **Purpose:** Gap collapse (remaining width ≤ 0) without a complete fill. (R-5.)
- **Entry Conditions:** From ACTIVE or PARTIALLY FILLED on collapse detection.
- **Exit Conditions:** → ARCHIVED.
- **Allowed Transitions:** → ARCHIVED.
- **Forbidden Transitions:** → any active state.
- **Recovery:** None.

#### EXPIRED
- **Purpose:** An unfilled/uninvalidated FVG superseded by newer same-direction FVGs (active-set cap) or by a more recent relevant same-direction FVG. (R-3.)
- **Entry Conditions:** From ACTIVE (or PARTIALLY FILLED) on supersession.
- **Exit Conditions:** → ARCHIVED.
- **Allowed Transitions:** → ARCHIVED.
- **Forbidden Transitions:** → active states (expiration is terminal before archival).
- **Recovery:** None.

#### ARCHIVED
- **Purpose:** Terminal storage for FILLED/INVALIDATED/EXPIRED records; subject to retention pruning (oldest first).
- **Entry Conditions:** From FILLED, INVALIDATED, EXPIRED, or directly from ACTIVE under retention pruning.
- **Exit Conditions:** None (except pruning).
- **Allowed Transitions:** → (removed by retention pruning).
- **Forbidden Transitions:** → any active state.
- **Recovery:** None.

#### INVALID (defensive)
- **Purpose:** Inconsistent record (corrupted source candles/boundaries, non-monotonic timestamps). Defensive only.
- **Entry Conditions:** Detection of internal inconsistency.
- **Exit Conditions:** Rebuild from immutable histories yields a consistent state.
- **Allowed Transitions:** → recomputed state (typically ARCHIVED).
- **Forbidden Transitions:** None (recovery entry).
- **Recovery:** Rebuild zone/state from immutable candle histories; if unrecoverable, remain INVALID and exclude from consumption.

### State Machine Guarantees
- An FVG is consumable **only** in ACTIVE or PARTIALLY FILLED, and only **after** its lock timestamp (look-ahead guard: candle 3 close).
- Fill is monotonic toward complete (unfilled → partially → filled); gaps never reopen.
- At most a bounded number of ACTIVE FVGs per direction (supersession/expiry cap).
- All transitions on closed H1 bars; the zone (original) is immutable after the lock timestamp.

---

# Active vs Historical Fair Value Gaps

- **Active FVGs:** FVGs in ACTIVE or PARTIALLY FILLED states. The consumable set. Bounded per direction by the active-set cap (R-3).
- **Historical FVGs:** FVGs in FILLED, INVALIDATED, EXPIRED, or ARCHIVED states. Retained for audit/backtest. Read-only to all consumers.
- **Design intent:** keep the Active set small and bounded; Historical set grows to the retention cap, then prunes oldest-first. (R-4.)

---

# Dependencies (consumer only)

The FVG Engine consumes **only** the following, read-only:

| Consumed from | Used for |
|---|---|
| DOC02A: Confirmed Swing Data | Optional context (alignment with structure) |
| DOC02A: Market Structure State | Optional context |
| DOC02B: Confirmed BOS | Optional context (impulse alignment) |
| DOC02C: Confirmed CHoCH | Optional context |
| DOC02C: Prevailing Direction | Optional context |
| DOC02D: Liquidity Events | Optional context (sweep alignment) |
| DOC02EB: Confirmed Order Blocks | Optional context (FVG-inside-OB alignment, relevant to future Entry) |
| DOC01: Market Data Access | Closed H1 OHLC for detection and fill/invalidation tests |

The FVG Engine **must not**:
- Create, modify, or delete any swing, BOS, CHoCH, Prevailing Direction, liquidity, or Order Block record.
- Create or modify Entry, Risk, or Trade Management data.
- Read forming bars or any timeframe other than H1.

It is a **consumer only** with respect to all upstream data, and the **sole writer** of the *FVG* section (FVG records, states, zones, fills, invalidations).

---

# Implementation Constraints (MetaTrader 5)

### Maximum recommended candle lookback
- Detection is a fixed 3-candle window evaluated at each closed bar — no unbounded lookback for detection. Initialisation replays a bounded history (the project lookback depth, DOC01) to reconstruct the FVG history deterministically.

### Maximum active Fair Value Gaps
- Bounded per direction by the active-set cap (R-3). Recommend a small fixed cap (e.g., 3–5 per direction); overflow expires the oldest same-direction ACTIVE FVG. Overall active set thus ≤ ~10.

### Caching strategy
- Cache the last few closed H1 bars (for the 3-candle window) and the active FVG set. Detection and fill checks run only on closed bars, not ticks.

### Cleanup strategy
- FIFO retention pruning of ARCHIVED records beyond a fixed cap (keep most recent N archived FVGs). Pruning removes oldest; never touches active records.

### Update timing
- Detection: on each closed H1 bar (evaluating the trio ending at that bar). Fill/invalidation/expiration: on each closed H1 bar, after upstream modules updated (frozen snapshot, DOC01).

### Scan timing
- Only on closed H1 bars, within the bar-scoped pipeline, reading the frozen Structural Context.

### When scanning must never occur
- Never on ticks. Never on the forming bar. Never across timeframes other than H1. Never by re-reading archived records.

---

# Performance Constraints

### CPU Complexity
- **Detection:** O(1) per closed H1 bar (fixed 3-candle window + min-size check + overlap check against the small active set).
- **Fill/invalidation check:** O(A) per closed bar, A = active-set size (≤ ~10). Effectively O(1).
- **Initialisation:** O(N) over bounded lookback, each O(1).

### Memory Complexity
- O(A + H): A active (bounded small) + H archived (bounded by retention cap). Bounded overall.

### Worst Case
- Many overlapping FVGs triggering merges at creation + a full active-set scan — still O(A) per bar, bounded and infrequent.

### Average Case
- Near-constant per bar; tiny active set.

### Expected Active Gap Count
- ≤ a handful per direction; very small.

### Expected Scan Cost
- One pass over the active set per closed bar; negligible.

### Optimization Recommendations
- Fixed-capacity active set per direction (expiry on overflow); archived records in a bounded ring/log; short-circuit fill checks (test complete fill before partial); skip archived records entirely.

---

# MQL5 Implementation Feasibility

### Potential implementation risks
- Acting on an FVG before candle 3 closes (look-ahead). Mitigated by CANDIDATE→CONFIRMED→ACTIVE gating and the lock-timestamp look-ahead guard.
- Re-selecting source candles later (repaint). Mitigated by immutability after lock.
- Conflating wick-fill with body-fill. Mitigated by the official body-based fill rule (R-6).
- Floating-point/precision drift in boundary comparisons. Mitigated by symbol-native precision and `_Point`-based comparisons.

### Historical synchronization
- H1 history must be continuous for deterministic replay. Safeguard: verify continuity at init; do not fabricate missing bars.

### Weekend gaps
- A weekend gap may itself create or skip a 3-candle pattern; the engine simply evaluates whatever closed bars exist. No special-case logic.

### Broker precision issues
- `_Point`/symbol precision differences affect boundary comparisons. Safeguard: compare in native precision; validate `_Point` at init.

### Memory growth
- Bounded by active-set cap + archived retention cap (FIFO).

### CPU spikes
- Bounded by O(A) per bar; no per-tick heavy work. All structural work is bar-scoped.

### Recommended engineering safeguards
1. Closed-bar chokepoint (DOC01 Market Data Access) as the only candle source.
2. Immutable FVG records (original zone) after the lock timestamp.
3. Look-ahead guard: consumable only after candle 3 close.
4. Bounded active + archived caps with FIFO pruning.
5. Body-based fill as the sole official fill rule.
6. Full audit logging of every state transition for bar-by-bar backtest reconstruction.
7. Defensive INVALID state + deterministic rebuild from immutable histories.

---

# Design Principles (conformance)

| Principle | How DOC02F satisfies it |
|---|---|
| Deterministic | Every FVG is a pure function of closed H1 candles; identical data ⇒ identical FVGs. |
| Non-Repainting | FVG locked at candle 3 close; immutable thereafter; CANDIDATE never exposed. |
| Immutable after confirmation | Original zone never edited; only state + remaining (partial-fill) boundary change. |
| Low CPU usage | O(1)/O(A) per bar; bar-scoped only. |
| Low memory usage | Bounded active + archived caps. |
| Easy to debug | Each FVG carries source candles, zone, and full state history — fully auditable. |
| Easy to backtest | Pure closed-bar function; reproducible in the MT5 tester. |
| Easy to maintain | One concern (FVG lifecycle); clean consumer-only boundaries. |
| Suitable for future multi-symbol support | All comparisons use the symbol's `_Point`; no XAUUSD-specific logic in the rules. |

---

# Cross-Document Consistency

| Concern | How DOC02F respects it |
|---|---|
| DOC00 §16 FVG definition | Reproduced verbatim: 3-candle pattern, strict inequalities, candle-3-close confirmation, FVG Min Size, overlap merge, body-based complete fill. |
| DOC00 FVG Min Size = 10 pts | Used unchanged. |
| PATCH_001 timeframes | FVG on H1 only. |
| DOC01 module ownership | FVG Engine is sole writer of *FVG* section; closed-bar discipline; immutable records; frozen per-bar snapshot; bounded retention. |
| DOC02A/B/C/D/EB primacy | All upstream records consumed read-only; never modified. Upstream data is optional context, never a creation requirement (R-7). |
| DOC02EB lifecycle pattern | DOC02F mirrors the DOC02EB lifecycle approach (Candidate→Confirmed→Active→…→Archived) for consistency across engines. |

---

# Self Review Result

Before finalising, the document was checked against the required checklist. Findings and resolutions:

- **Consistency with DOC00:** §16 reproduced exactly (3-candle, strict, candle-3-close, FVG Min Size = 10 pts, overlap merge, body complete fill). No contradiction. *(Pass)*
- **Consistency with DOC01:** FVG Engine is sole writer of *FVG* section; closed-bar discipline; immutable records; frozen per-bar snapshot. *(Pass)*
- **Consistency with DOC02A/B/C/D/EB:** All upstream records consumed read-only; upstream data is optional context only (R-7); never modified. *(Pass)*
- **Consistency with DOC02EA:** No OB-definition dependency; FVG does not require an OB (consistent with DOC00 §16). *(Pass)*
- **No subjective language:** Avoided. No "significant," "strong," "imbalance" as a judgement (used only as DOC00's descriptive term). All rules are fixed comparisons. *(Pass)*
- **No repaint possibility:** Eliminated. FVG locked at candle 3 close; immutable thereafter; CANDIDATE never exposed. *(Pass)*
- **No look-ahead bias:** Eliminated. Only closed candles; consumable only after candle 3 close. *(Pass)*
- **No circular dependency:** FVG Engine depends only on lower-layer/already-published data and writes only its own section; no feedback into structure/liquidity/OB. *(Pass)*
- **Implementation feasibility:** All inputs via DOC01 Market Data Access + Structural Context; O(1)/O(A) cost; bounded memory. *(Pass)*
- **Performance feasibility:** Near-constant per bar; tiny active set; FIFO-bounded archives. *(Pass)*
- **Maintainability:** Single concern; clean consumer-only boundaries; full audit trail. *(Pass)*

**Scope boundaries respected:** Entry Strategy, Risk Management, Trade Management, Order Block Selection, and Liquidity Selection are **not** designed here. The FVG Engine produces and lifecycle-manages FVG zones only.

**Reported items (R-1…R-8)** are operational extensions consistent with DOC00; none redefines an approved concept.

**Outcome:** No blocking issues. DOC02F is internally consistent, deterministic, non-repainting, look-ahead-safe, circular-dependency-free, and fully conforms to DOC00–DOC02EB.

---

# Final Notes

1. **Fair Value Gaps only.** This document specifies the FVG Engine and nothing else. No Entry, Risk, Trade Management, OB Selection, or Liquidity Selection logic.
2. **Consumer discipline.** The FVG Engine consumes DOC02A/B/C/D/EB outputs read-only and never mutates them. It is the sole writer of the *FVG* section.
3. **DOC00 fidelity.** DOC00 §16 is preserved exactly. New constructs (States, Partial Fill, Expiration, Active/Historical, Invalidation/collapse) are operational extensions, reported and consistent.
4. **Body-based fill is the official fill rule.** Wick penetration does not fill an FVG (R-6).
5. **Non-repainting + look-ahead-safe** by construction: lock-at-candle-3-close + immutability + consumable-only-after-lock.
6. **Bounded active set per direction** (supersession/expiry) keeps memory and scan cost near-constant.
7. **Downstream consumers** (Entry, future Trade Decision) may read the *FVG* section read-only, respecting the look-ahead guard; they must not redefine FVGs or mutate FVG records.

This document is now the official specification for the Fair Value Gap Engine.
