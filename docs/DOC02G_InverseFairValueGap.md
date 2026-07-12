# DOC02G — Inverse Fair Value Gap (IFVG)
## Extension to DOC02F: Post-Fill Role Reversal of Fair Value Gaps

> **Document status:** AUTHORITATIVE — Official specification for the **Inverse Fair Value Gap extension** to the FVG Engine.
> **Phase:** Module Specification (Phase 2, Part G).
> **Scope of this document:** Inverse Fair Value Gap creation (from FILLED FVGs), Inverse FVG Lifecycle (INVERSE_ACTIVE / INVERSE_PARTIALLY_FILLED / INVERSE_FILLED / ARCHIVED), Inverse Fill tracking (body-based, closed bar), Inverse FVG Active/Historical sets, and Inverse FVG interaction with the original DOC02F lifecycle.
> **Explicitly out of scope:** Original FVG detection, validation, partial fill, invalidation, expiration — these remain governed exclusively by **DOC02F**. Entry Strategy, Risk Management, Trade Management, Order Block Selection, and Liquidity Selection remain out of scope.
> **Relationship to prior documents:**
> - **Extends DOC02F_FairValueGap_Engine.md**: Modifies the terminal transition of the FILLED state. Under DOC02F alone, FILLED → ARCHIVED. Under DOC02G, FILLED → INVERSE_ACTIVE (conditional), introducing a post-fill second life for the zone.
> - **Does NOT modify DOC00 §16**: DOC00's FVG definition (3-candle pattern, min size, fill rule) is unchanged. IFVG is a **post-fill behavioural extension** — it does not alter how an FVG is detected, validated, or initially filled.
> - Conforms to **DOC00_PATCH_001.md**: IFVG transitions occur only on **closed H1 bars**.
> - Writes into the *FVG* section of the Structural Context (**DOC01**, Layer 2), co-located with the original FVG records. The FVG Engine remains the sole writer.
> - Consumes **only** the outputs of DOC02F (FVG records and their state transitions). It does not read or modify any other engine's records.
> **Priority rule:** If anything here appears to conflict with DOC00–DOC02F, those documents prevail. DOC02G governs only the Inverse Fair Value Gap extension.
> **Naming convention:** "IFVG" is used throughout as the abbreviation for Inverse Fair Value Gap. "Original FVG" refers to the FVG record before its Complete Fill; "Inverse FVG" refers to the same zone after it transitions to INVERSE_ACTIVE.

---

# Reported Items (reported, not changed)

Per the standing instruction to *report* rather than silently change, the following are flagged. Each defines a **new operational construct** required by this document's scope that is **not present in DOC00 or DOC02F**, defined deterministically and consistently with both. **No approved document was modified.**

| # | Item | Status |
|---|---|---|
| R-1 | **Inverse FVG creation from FILLED state** — DOC02F defines FILLED as terminal (FILLED → ARCHIVED). DOC02G introduces a conditional transition: FILLED → INVERSE_ACTIVE. The zone boundaries are identical to the original FVG; only the direction is reversed. This is a **new state** not present in DOC02F's lifecycle. DOC02F's FILLED state is not redefined — DOC02G adds an *optional exit* from FILLED that did not previously exist. | Reported — extension, consistent with DOC00 §16 (DOC00 is silent on post-fill behaviour). |
| R-2 | **Direction reversal** — When a Bullish FVG is completely filled, the resulting IFVG functions as a **Bearish** zone (resistance). When a Bearish FVG is completely filled, the resulting IFVG functions as a **Bullish** zone (support). The zone's boundaries (upper/lower) remain numerically identical to the original FVG. Only the *directional label* and *consumption semantics* change. | Reported — new construct, consistent with SMC role-reversal principle. |
| R-3 | **Inverse Fill rules (body-based, closed bar)** — The same body-based fill rule from DOC02F (R-6) applies to IFVG. A closed candle's body fully trading through the IFVG zone = Inverse Complete Fill (terminal). Partial body penetration = Inverse Partial Fill (remaining boundary adjusted). Wick penetration = no fill. This ensures consistency with DOC00 §16's fill semantics. | Reported — reuses DOC02F fill rule, applied to the inverse zone. |
| R-4 | **Inverse FVG States / Lifecycle extension** — DOC02F's state machine has 8 states (CANDIDATE → ARCHIVED). DOC02G adds 3 new states: INVERSE_ACTIVE, INVERSE_PARTIALLY_FILLED, INVERSE_FILLED. These are **post-FILLED** states. The original 8 states are unchanged; DOC02G inserts a new branch after FILLED. | Reported — extension, no contradiction with DOC02F's original states. |
| R-5 | **Inverse FVG Active-Set Cap** — DOC02F bounds ACTIVE FVGs per direction (R-3). DOC02G extends this cap to include INVERSE_ACTIVE FVGs: the total number of consumable zones per direction (ACTIVE + INVERSE_ACTIVE) is bounded by the same cap. This prevents unbounded growth of the inverse set. | Reported — extension of DOC02F's cap mechanism. |
| R-6 | **No double inversion** — An IFVG that reaches INVERSE_FILLED is terminal (→ ARCHIVED). It does **not** invert back to a regular FVG. This prevents infinite oscillation between FVG and IFVG states. | Reported — design decision for lifecycle termination. |
| R-7 | **Invalidated FVGs do not produce IFVGs** — Only FVGs that reach FILLED via Complete Fill (body-based) are eligible for inversion. FVGs that reach INVALIDATED (gap collapse) or EXPIRED (supersession) are **not** eligible. This preserves DOC02F's distinction between fill (consumption by price) and invalidation/expiration (degeneration). | Reported — consistent with DOC02F lifecycle semantics. |
| R-8 | **Original zone immutability preserved** — The original FVG's zone boundaries (upper/lower) are never modified during inversion. The IFVG reuses the same boundaries verbatim. The original zone is preserved immutably for audit; the IFVG's "remaining unfilled boundary" is tracked separately (mirroring DOC02F's R-2 Partial Fill tracking). | Reported — consistent with DOC02F immutability rule. |

No approved document was modified.
---

# Concept 1 — Inverse Bullish Fair Value Gap (from filled Bearish FVG)

- **Definition:** An **Inverse Bullish FVG** is created when a **Bearish FVG** is completely filled (Complete Fill per DOC02F). The zone boundaries remain [high(candle 3), low(candle 1)] (identical to the original Bearish FVG). The zone function reverses: it now acts as a **Bullish** support zone — price that previously traded through it from above is expected to find support when returning from below.
- **Purpose:** Mark a former Bearish FVG that has been consumed and now serves as a Bullish support confluence element.
- **Relationship with previous documents:** Extends DOC02F lifecycle. The zone is the same; the direction and consumption semantics are reversed. Written into the *FVG* section of the Structural Context (DOC01); the FVG Engine remains the sole writer.
- **Inputs:** A Bearish FVG record that has just transitioned to FILLED (Complete Fill confirmed on a closed H1 bar).
- **Outputs:** An Inverse Bullish FVG record (direction = BULLISH, zone upper/lower boundaries = original Bearish FVG boundaries, inverse creation timestamp = the bar at which Complete Fill occurred, inverse state = INVERSE_ACTIVE, original FVG reference).
- **Dependencies:** DOC02F (FVG record, FILLED state transition); DOC01 Market Data Access (closed H1 OHLC for inverse fill tracking).
- **Failure Conditions:** Original FVG did not reach FILLED via Complete Fill (e.g., INVALIDATED or EXPIRED); zone width <= 0 (degenerate).
- **Edge Cases / Lifecycle:** See respective sections below.

---

# Concept 2 — Inverse Bearish Fair Value Gap (from filled Bullish FVG)

- **Definition:** An **Inverse Bearish FVG** is created when a **Bullish FVG** is completely filled (Complete Fill per DOC02F). The zone boundaries remain [high(candle 1), low(candle 3)] (identical to the original Bullish FVG). The zone function reverses: it now acts as a **Bearish** resistance zone — price that previously traded through it from below is expected to find resistance when returning from above.
- **Purpose:** Mark a former Bullish FVG that has been consumed and now serves as a Bearish resistance confluence element.
- **Relationship with previous documents:** Mirror of Concept 1. Extends DOC02F lifecycle.
- **Inputs/Outputs/Dependencies/Rules:** Mirror of Concept 1.

---

# Inverse Fair Value Gap — Creation Rules

### Trigger condition
- An IFVG is created **only** when an original FVG transitions to **FILLED** via **Complete Fill** (body-based, closed bar, per DOC02F). No other trigger is valid.
- Specifically:
  - Bullish FVG -> Complete Fill -> **Inverse Bearish FVG** (resistance)
  - Bearish FVG -> Complete Fill -> **Inverse Bullish FVG** (support)

### Non-triggers (IFVG is NOT created)
- FVG reaches **INVALIDATED** (gap collapse) -> no IFVG. The zone is degenerate and archived.
- FVG reaches **EXPIRED** (supersession) -> no IFVG. The zone was never consumed by price.
- FVG reaches **ARCHIVED** via any non-FILL path -> no IFVG.

### Zone boundaries
- The IFVG upper and lower boundaries are **numerically identical** to the original FVG boundaries at the time of Complete Fill.
- If the original FVG was partially filled before complete fill, the IFVG uses the **original zone boundaries** (not the remaining boundary). The original zone is immutable (DOC02F).

### Inverse creation timestamp
- The **inverse creation timestamp** = the close time of the H1 bar whose body completed the fill of the original FVG. This is the moment of role reversal.

### Inverse lock timestamp
- The **inverse lock timestamp** = the inverse creation timestamp (same bar). The IFVG becomes consumable on the **next** closed H1 bar after its creation (look-ahead guard, mirroring DOC02F lock timestamp rule).

### Direction assignment
- Original Bullish FVG -> IFVG direction = **BEARISH**
- Original Bearish FVG -> IFVG direction = **BULLISH**

### Minimum zone width
- The IFVG inherits the original FVG zone width. Since the original FVG was created with width >= FVG Min Size (DOC02F), the IFVG automatically satisfies this constraint. No additional size check is needed at inversion.

### Immutable rules
1. Once created, the IFVG zone boundaries are **never edited**. (Mirrors DOC02F immutability.)
2. Only the **inverse state** and the **remaining inverse-unfilled boundary** (for Inverse Partial Fill tracking) may change, via defined lifecycle transitions on closed bars.
3. The original FVG record is **never modified** by the inversion process. The IFVG is a new record that references the original.
---

# Inverse Fair Value Gap — Fill Rules

### Inverse Complete Fill (terminal)
- **Body-based, closed-candle.** A later closed H1 candle body fully trades through the IFVG zone (or the remaining inverse-unfilled portion) = Inverse Complete Fill.
- **Bullish IFVG (support):** Complete Fill occurs when a closed candle body closes **below** the lower boundary of the IFVG zone (i.e., Close < lower_boundary). The zone is consumed from above.
- **Bearish IFVG (resistance):** Complete Fill occurs when a closed candle body closes **above** the upper boundary of the IFVG zone (i.e., Close > upper_boundary). The zone is consumed from below.
- On Inverse Complete Fill: INVERSE_ACTIVE or INVERSE_PARTIALLY_FILLED -> **INVERSE_FILLED** -> **ARCHIVED**.

### Inverse Partial Fill
- A closed candle body enters the IFVG zone but does **not** fully traverse it.
- **Bullish IFVG:** Body low enters the zone from above but body close remains above the lower boundary. The remaining lower boundary is adjusted upward to the body low of the filling candle.
- **Bearish IFVG:** Body high enters the zone from below but body close remains below the upper boundary. The remaining upper boundary is adjusted downward to the body high of the filling candle.
- The remaining inverse-unfilled boundary is adjusted deterministically (mirroring DOC02F Partial Fill tracking).
- State transitions to (or remains) **INVERSE_PARTIALLY_FILLED**.

### Wick-based Inverse Fill
- **Not an official fill.** A wick into the IFVG zone does **not** fill it (no state transition). It may be recorded as optional audit context only. (Consistent with DOC02F R-6.)

### Official inverse fill rule
- Identical to DOC02F fill rule (R-6): body-based, closed-candle only. This is the single, deterministic fill rule for IFVGs.

### Repeated inverse fills
- Once an IFVG is INVERSE_FILLED (complete), it is terminal (-> ARCHIVED). Repeated body penetrations of an INVERSE_PARTIALLY_FILLED IFVG are accumulated deterministically into the remaining boundary until either inverse complete fill or inverse invalidation.

### Inverse gap reopening policy
- **Inverse gaps do not reopen.** Once an IFVG is INVERSE_FILLED or INVALIDATED, it is terminal; a later departure from the zone does not resurrect it. A *new* inversion requires a *new* FVG to be filled.

---

# Inverse Fair Value Gap — Invalidation

### Gap collapse
- If the remaining inverse-unfilled boundary collapses to **<= 0 width** (remaining_upper <= remaining_lower) without an Inverse Complete Fill, the IFVG transitions to **INVALIDATED** -> **ARCHIVED**.
- This mirrors DOC02F invalidation rule (R-5) for the inverse lifecycle.
- In practice, this is rare (the IFVG zone is typically small, having been derived from an already-filled FVG).

### Non-invalidation
- An IFVG that is Inverse Completely Filled (INVERSE_FILLED) does **not** pass through INVALIDATED. It goes directly INVERSE_FILLED -> ARCHIVED.

---

# Inverse Fair Value Gap — Expiration

### Supersession
- IFVGs are subject to the same active-set cap as original FVGs (DOC02F R-3). The cap applies to the **combined** set of consumable zones per direction: ACTIVE + INVERSE_ACTIVE.
- If the cap is exceeded, the **oldest** consumable zone of the same direction (whether ACTIVE or INVERSE_ACTIVE) transitions to **EXPIRED** -> **ARCHIVED**.
- Ordering rule for supersession priority:
  1. Oldest inverse creation timestamp first (oldest IFVG expires before newer IFVG).
  2. If timestamps are equal, original FVG records take precedence over IFVG records (original FVGs are more relevant as they have not yet been consumed).
---

# Inverse Fair Value Gap Lifecycle — Extended State Machine

Each FVG/IFVG has exactly one state at any time. Transitions occur only on closed H1 bars.

### Extended States (DOC02F original states unchanged; new states added after FILLED)

#### CANDIDATE -> CONFIRMED -> ACTIVE -> PARTIALLY_FILLED -> FILLED
*(Unchanged from DOC02F. See DOC02F for full definitions.)*

#### FILLED (modified exit)
- **Purpose (DOC02F):** A closed candle body fully traded through the gap. The original FVG is consumed.
- **Entry Conditions (DOC02F):** From ACTIVE or PARTIALLY_FILLED on a complete-fill body.
- **Exit Conditions (DOC02G extended):** -> **INVERSE_ACTIVE** (if eligible — see creation rules); -> **ARCHIVED** (if not eligible, e.g., defensive path or configuration disables IFVG).
- **Allowed Transitions (extended):** -> INVERSE_ACTIVE, -> ARCHIVED.
- **Forbidden Transitions:** -> CANDIDATE, CONFIRMED, ACTIVE, PARTIALLY_FILLED, INVALIDATED, EXPIRED (an FVG that has been completely filled cannot be invalidated or expired retroactively).

#### INVERSE_ACTIVE *(new)*
- **Purpose:** The IFVG is a live, consumable zone with reversed direction; eligible for inverse fill/invalidation checks and downstream consumption.
- **Entry Conditions:** From FILLED (original FVG reached Complete Fill). Inverse set cap enforced per direction (R-5).
- **Exit Conditions:** Inverse partial fill (-> INVERSE_PARTIALLY_FILLED), inverse complete fill (-> INVERSE_FILLED), inverse invalidation (-> INVALIDATED), supersession (-> EXPIRED).
- **Allowed Transitions:** -> INVERSE_PARTIALLY_FILLED, INVERSE_FILLED, INVALIDATED, EXPIRED, ARCHIVED.
- **Forbidden Transitions:** -> CANDIDATE, CONFIRMED, ACTIVE, PARTIALLY_FILLED, FILLED (cannot revert to original FVG states).
- **Recovery:** Rebuild from immutable histories on inconsistency.

#### INVERSE_PARTIALLY_FILLED *(new)*
- **Purpose:** A closed candle body has entered the IFVG zone but not fully traversed it; the remaining inverse-unfilled boundary is tracked.
- **Entry Conditions:** From INVERSE_ACTIVE on the first inverse body penetration that does not complete the inverse fill.
- **Exit Conditions:** Inverse complete fill (-> INVERSE_FILLED), inverse invalidation/collapse (-> INVALIDATED), supersession (-> EXPIRED).
- **Allowed Transitions:** -> INVERSE_FILLED, INVALIDATED, EXPIRED, ARCHIVED.
- **Forbidden Transitions:** -> INVERSE_ACTIVE (inverse partial fill is monotonic; an IFVG does not become un-partially-filled), -> any original FVG state.
- **Recovery:** None; monotonic.

#### INVERSE_FILLED *(new)*
- **Purpose:** A closed candle body fully traded through the IFVG zone. Terminal — the IFVG is consumed and **does not invert back**.
- **Entry Conditions:** From INVERSE_ACTIVE or INVERSE_PARTIALLY_FILLED on an inverse complete-fill body.
- **Exit Conditions:** -> ARCHIVED.
- **Allowed Transitions:** -> ARCHIVED.
- **Forbidden Transitions:** -> any active state, -> FILLED (no double inversion, R-6).
- **Recovery:** None.

#### INVALIDATED (shared with DOC02F)
- **Purpose:** Gap collapse (remaining width <= 0) without a complete fill. Applies to both original FVGs and IFVGs.
- **Entry Conditions:** From ACTIVE, PARTIALLY_FILLED, INVERSE_ACTIVE, or INVERSE_PARTIALLY_FILLED on collapse detection.
- **Exit Conditions:** -> ARCHIVED.
- **Allowed Transitions:** -> ARCHIVED.
- **Forbidden Transitions:** -> any active state.
- **Recovery:** None.

#### EXPIRED (shared with DOC02F)
- **Purpose:** Supersession. Applies to both original FVGs and IFVGs.
- **Entry Conditions:** From ACTIVE, PARTIALLY_FILLED, INVERSE_ACTIVE, or INVERSE_PARTIALLY_FILLED on supersession (active-set cap exceeded).
- **Exit Conditions:** -> ARCHIVED.
- **Allowed Transitions:** -> ARCHIVED.
- **Forbidden Transitions:** -> any active state.
- **Recovery:** None.

#### ARCHIVED (shared with DOC02F)
- **Purpose:** Terminal retention. Read-only historical record.
- **Entry Conditions:** From any terminal state (FILLED without inversion, INVERSE_FILLED, INVALIDATED, EXPIRED).
- **Exit Conditions:** None (pruned only by retention cap, FIFO).
- **Allowed Transitions:** None.
- **Recovery:** Immutable.

### State Machine Diagram (textual)

CANDIDATE -> CONFIRMED -> ACTIVE -> PARTIALLY_FILLED -> FILLED -> INVERSE_ACTIVE -> INVERSE_PARTIALLY_FILLED -> INVERSE_FILLED -> ARCHIVED

Parallel invalidation/expiry paths:
- ACTIVE/PARTIALLY_FILLED -> INVALIDATED -> ARCHIVED
- INVERSE_ACTIVE/INVERSE_PARTIALLY_FILLED -> INVALIDATED -> ARCHIVED
- ACTIVE -> EXPIRED -> ARCHIVED
- INVERSE_ACTIVE -> EXPIRED -> ARCHIVED
- FILLED -> ARCHIVED (inversion disabled or defensive path)

### State Machine Guarantees (extended)
- An FVG/IFVG is consumable **only** in ACTIVE, PARTIALLY_FILLED, INVERSE_ACTIVE, or INVERSE_PARTIALLY_FILLED, and only **after** its lock/inverse-lock timestamp.
- Fill is monotonic toward complete (unfilled -> partially -> filled -> inverse partially -> inverse filled); zones never reopen.
- At most a bounded number of consumable zones per direction (ACTIVE + INVERSE_ACTIVE combined, supersession/expiry cap).
- All transitions on closed H1 bars; the zone (original) is immutable after the lock timestamp; the IFVG zone is immutable after the inverse lock timestamp.
- **No double inversion:** INVERSE_FILLED -> ARCHIVED is terminal. The zone does not revert to a regular FVG.
- **No inversion from non-fill terminals:** INVALIDATED and EXPIRED FVGs never produce IFVGs.
---

# Active vs Historical FVGs/IFVGs (Extended)

- **Active FVGs/IFVGs:** Zones in ACTIVE, PARTIALLY_FILLED, INVERSE_ACTIVE, or INVERSE_PARTIALLY_FILLED states. The consumable set. Bounded per direction by the combined active-set cap (R-5).
- **Historical FVGs/IFVGs:** Zones in FILLED (pre-inversion), INVERSE_FILLED, INVALIDATED, EXPIRED, or ARCHIVED states. Retained for audit/backtest. Read-only to all consumers.
- **Design intent:** Keep the Active set small and bounded; Historical set grows to the retention cap, then prunes oldest-first. (Consistent with DOC02F R-4.)

---

# IFVG Record Structure

Each IFVG record contains:

| Field | Type | Description |
|---|---|---|
| id | string | Unique identifier (from CIdentifierGeneration, DOC01) |
| direction | enum | BULLISH or BEARISH (reversed from original FVG) |
| upper_boundary | double | Identical to original FVG upper boundary (immutable) |
| lower_boundary | double | Identical to original FVG lower boundary (immutable) |
| original_fvg_id | string | Reference to the original FVG record that produced this IFVG |
| original_direction | enum | The original FVG direction (opposite of direction) |
| creation_timestamp | datetime | Original FVG creation timestamp (candle 1 close, per DOC02F) |
| lock_timestamp | datetime | Original FVG lock timestamp (candle 3 close, per DOC02F) |
| inverse_creation_timestamp | datetime | The bar at which Complete Fill of the original FVG occurred |
| inverse_lock_timestamp | datetime | Same as inverse_creation_timestamp (look-ahead guard) |
| state | enum | INVERSE_ACTIVE, INVERSE_PARTIALLY_FILLED, INVERSE_FILLED, INVALIDATED, EXPIRED, ARCHIVED |
| remaining_upper | double | Tracks inverse partial fill (initially = upper_boundary) |
| remaining_lower | double | Tracks inverse partial fill (initially = lower_boundary) |
| fill_bar_index | int | Bar index at which Inverse Complete Fill occurred (-1 if not yet filled) |
| fill_timestamp | datetime | Timestamp of Inverse Complete Fill (0 if not yet filled) |
| archive_timestamp | datetime | Timestamp of archival (0 if not yet archived) |
| optional_context | struct | Optional: BOS/CHoCH/sweep/OB alignment at time of inversion (audit only) |

---

# Dependencies (consumer only)

The IFVG extension consumes **only** the following:

| Consumed from | Used for |
|---|---|
| DOC02F: FVG records and state transitions | Trigger for IFVG creation (FILLED state) |
| DOC02F: FVG zone boundaries | IFVG zone boundaries (immutable copy) |
| DOC01: Market Data Access | Closed H1 OHLC for inverse fill/invalidation tests |

The IFVG extension **must not**:
- Create, modify, or delete any swing, BOS, CHoCH, Prevailing Direction, liquidity, or Order Block record.
- Modify the original FVG record (it is immutable after lock).
- Create or modify Entry, Risk, or Trade Management data.
- Read forming bars or any timeframe other than H1.

It is a **consumer** of DOC02F output and an **extension writer** within the *FVG* section of the Structural Context.

---

# Implementation Constraints (MetaTrader 5)

### Detection window
- IFVG creation is triggered at the same bar where the original FVG Complete Fill is confirmed (closed H1 bar). No lookback beyond the current bar is needed for the trigger.
- Inverse fill/invalidation checks are evaluated on each subsequent closed H1 bar -- O(1) per IFVG per bar.

### Memory
- Each IFVG record is a fixed-size struct (~200 bytes). The active set is bounded by the combined cap (R-5). The historical set is bounded by the retention cap (DOC02F).
- Total memory overhead: negligible (bounded by cap x record size).

### Performance
- IFVG creation: O(1) per Complete Fill event.
- Inverse fill check: O(A) per bar, where A = number of INVERSE_ACTIVE/INVERSE_PARTIALLY_FILLED zones (bounded by cap).
- Total per-bar cost: O(A) -- near-constant.

### Logging
- Every IFVG state transition must be logged with: IFVG ID, direction, zone boundaries, original FVG ID, bar index, timestamp, and transition reason.
- Log prefixes: [IFVG] for all Inverse FVG events (distinct from [FVG] for original FVG events).

---

# Edge Cases

### Edge Case 1: Immediate inverse fill
- **Scenario:** An IFVG is created (INVERSE_ACTIVE) and the very next closed bar completely fills it.
- **Resolution:** Valid. The IFVG transitions INVERSE_ACTIVE -> INVERSE_FILLED -> ARCHIVED. The IFVG active life was exactly one bar.

### Edge Case 2: IFVG zone too small for practical use
- **Scenario:** The original FVG was barely above FVG Min Size. After Complete Fill, the IFVG zone is very narrow.
- **Resolution:** The IFVG inherits the zone as-is. The FVG Min Size constraint was already satisfied at original creation. No additional minimum is imposed at inversion. If the zone is too narrow to be useful, it will likely be filled or invalidated quickly -- no special handling needed.

### Edge Case 3: Multiple FVGs filled on the same bar
- **Scenario:** Two or more original FVGs reach Complete Fill on the same closed bar, producing multiple IFVGs simultaneously.
- **Resolution:** Each IFVG is created independently. The active-set cap is enforced after all inversions are processed. If the cap is exceeded, the oldest consumable zone (per direction) is expired, following the standard supersession rule.

### Edge Case 4: IFVG overlaps with an original FVG of the same direction
- **Scenario:** An Inverse Bullish FVG zone overlaps with an existing original Bullish FVG zone.
- **Resolution:** They are treated as **separate** records. Original FVGs and IFVGs have distinct identities and lifecycles. No merging occurs between original FVGs and IFVGs (they have different provenance and semantics). However, for the purpose of the active-set cap, they compete for the same directional slot.

### Edge Case 5: Partially filled original FVG -> Complete Fill -> IFVG
- **Scenario:** An original FVG was in PARTIALLY_FILLED state, then a subsequent bar completes the fill.
- **Resolution:** The FVG transitions to FILLED. The IFVG is created using the **original zone boundaries** (not the remaining boundary at the time of complete fill). The partial fill history of the original FVG is preserved in the original record for audit; the IFVG starts with a fresh remaining boundary equal to the original zone.

### Edge Case 6: Inverse partial fill followed by price departure
- **Scenario:** An IFVG is INVERSE_PARTIALLY_FILLED. Price moves away from the zone without completing the inverse fill.
- **Resolution:** The IFVG remains INVERSE_PARTIALLY_FILLED. The remaining boundary is not reset. Subsequent bars continue to evaluate inverse fill against the adjusted remaining boundary. The IFVG may eventually be superseded (EXPIRED) if newer zones push it out of the active set.

---

# Validation Checklist

- **Consistency with DOC00 section 16:** DOC00 FVG definition (3-candle pattern, min size, fill rule) is unchanged. IFVG is a post-fill extension. *(Pass)*
- **Consistency with DOC02F:** DOC02F lifecycle (CANDIDATE -> ARCHIVED) is unchanged. DOC02G adds a branch after FILLED. The original 8 states and their transitions are preserved. *(Pass)*
- **Consistency with DOC01:** IFVG writes into the FVG section of the Structural Context. The FVG Engine remains the sole writer. *(Pass)*
- **No subjective language:** Avoided. No significant, strong, likely as judgement. All rules are fixed comparisons. *(Pass)*
- **No repaint possibility:** Eliminated. IFVG created only on closed bar (Complete Fill confirmation). Inverse fill checks only on closed bars. *(Pass)*
- **No look-ahead bias:** Eliminated. Only closed candles. IFVG consumable only after inverse lock timestamp. *(Pass)*
- **No circular dependency:** IFVG extension depends only on DOC02F output and DOC01 market data. No feedback into structure/liquidity/OB. *(Pass)*
- **Implementation feasibility:** All inputs via DOC01 Market Data Access + Structural Context; O(1)/O(A) cost; bounded memory. *(Pass)*
- **Performance feasibility:** Near-constant per bar; tiny active set; FIFO-bounded archives. *(Pass)*
- **Maintainability:** Single concern (post-fill role reversal); clean extension of DOC02F; full audit trail. *(Pass)*

**Scope boundaries respected:** Entry Strategy, Risk Management, Trade Management, Order Block Selection, and Liquidity Selection are **not** designed here. The IFVG extension produces and lifecycle-manages Inverse FVG zones only.

**Reported items (R-1 through R-8)** are operational extensions consistent with DOC00 and DOC02F; none redefines an approved concept.

**Outcome:** No blocking issues. DOC02G is internally consistent, deterministic, and implementable on MT5 without modification to DOC00-DOC02F.
