# DOC02EB — Order Block Engine
## Official Specification for Order Block Creation, Lifecycle, Mitigation, and Invalidation (H1)

> **Document status:** AUTHORITATIVE — Official specification for the **Order Block Engine only**.
> **Phase:** Module Specification (Phase 2, Part E-B).
> **Scope of this document:** Bullish Order Block, Bearish Order Block, Order Block Creation, Validation, Lifecycle, Mitigation, Invalidation, Expiration, Active Order Blocks, Historical Order Blocks, and Order Block States.
> **Explicitly out of scope (future documents):** Fair Value Gap, Entry Strategy, Risk Management, Trade Management, and **Breaker Block** promotion. An invalidated OB is recorded and archived here; its possible promotion to a Breaker (DOC00 §19) is owned by a future document and is **not** designed here.
> **Relationship to prior documents:**
> - Implements **DOC00_Strategy_Validation.md §14 (Order Block)** and **§15 (Mitigation)** without modification to their definitions or constants.
> - Operationalises the recommendation confirmed in **DOC02EA_OrderBlock_Reference_Validation.md** (the DOC00 OB methodology is the official definition; TW-strict, single-candle, full-range, body-based lifecycle).
> - Conforms to **DOC00_PATCH_001.md**: Order Blocks are created and lifecycle-managed on the **Market Structure Timeframe (H1)**.
> - Realises the **Order Block Engine** module defined in **DOC01_System_Architecture.md** (Layer 2), writing into the *OrderBlocks* section of the Structural Context. It is the sole writer of that section.
> - Consumes **only** the outputs of **DOC02A** (Confirmed Swing Data, Market Structure State), **DOC02B** (Confirmed BOS), **DOC02C** (Confirmed CHoCH, Prevailing Direction), and **DOC02D** (Liquidity Events). It creates or modifies **none** of those records.
> **Priority rule:** If anything here appears to conflict with DOC00–DOC02EA, those documents prevail. DOC02EB governs only the Order Block Engine details.

---

# Reported Items (reported, not changed)

Per the standing instruction to *report* rather than silently change, the following are flagged. Each defines a **new operational construct** required by this document's scope that is **not present in DOC00**, defined deterministically and consistently with DOC00. **No approved document was modified.**

| # | Item | Status |
|---|---|---|
| R-1 | **Order Block States / Lifecycle machine** (Candidate/Confirmed/Active/Mitigated/Invalidated/Expired/Archived) — DOC00 §14/§15 specify only *creation* (on BOS/CHoCH), *mitigation* (body into zone), and *invalidation* (body closes beyond far edge). DOC00 does not name a state machine, nor the Candidate/Active/Expired/Archived states. DOC02EB designs the requested lifecycle as the operational realisation of DOC00's creation/mitigation/invalidation semantics, plus deterministic supersession (Expired) and archival (Archived). It is a DOC02EB design element, not a DOC00 redefinition. | Reported — extension, consistent with DOC00 §14/§15. |
| R-2 | **Order Block Expiration** — DOC00 has no expiration concept for OBs (an OB only changes via mitigation or invalidation). DOC02EB defines **Expired** as **supersession**: an unmitigated, uninvalidated ACTIVE OB becomes EXPIRED when a newer OB of the **same direction** is confirmed (created). This bounds the active set to the most recent same-direction OB and is fully deterministic. It introduces no arbitrary time constant. | Reported — extension, consistent with DOC00 (which is silent on coexistence of multiple same-direction OBs). |
| R-3 | **Active vs Historical Order Blocks** — DOC00 refers to "active targets" only for liquidity (DOC02D). DOC02EB defines **Active Order Blocks** (the current, consumable OBs) and **Historical Order Blocks** (mitigated/invalidated/expired/archived records retained for audit and potential future Breaker promotion). This is an organisational distinction, not a new SMC rule. | Reported — extension, no contradiction. |
| R-4 | **Near Edge / Far Edge naming** — DOC00 §15 uses "near edge" and "far edge" without pinning which candle extreme each is. DOC02EB pins them precisely from DOC00 §23 (Stop Loss Logic): for a **bullish** OB the far edge is the **Low** (stop placed below it) and the near edge is the **High**; for a **bearish** OB the far edge is the **High** (stop above it) and the near edge is the **Low**. This is the only interpretation consistent with DOC00 §23. | Reported — clarification, derived from DOC00 §23. |
| R-5 | **Liquidity Events as optional context, not a creation requirement.** DOC02EA recommendation #8 and DOC00 §14 confirm the OB definition does **not** require a liquidity sweep or displacement gate. DOC02EB therefore consumes Liquidity Events (DOC02D) only as **optional quality context** attached to an OB record (e.g., "created after a sweep"), never as a condition for OB creation. | Reported — consistent with DOC00 §14 + DOC02EA. |
| R-6 | **Zone = full range (High-to-Low).** DOC02EA Reported Difference D-3 confirmed DOC00's locked choice differs from TW's recommended open-to-low variant. DOC02EB uses candle **High/Low** for the zone edges, per DOC00 §14. Not re-litigated. | Reported — DOC00 prevails (DOC02EA D-3). |
| R-7 | **Consumability / look-ahead guard.** DOC00 §14 states the EA must not assume an OB existed before its confirming BOS/CHoCH close. DOC02EB encodes this as a hard rule: an OB is consumable by downstream modules **only after** its confirming close timestamp; before that it is a Candidate (not exposed for entries). | Reported — operationalisation of DOC00 §14. |

No approved document was modified.

---

# Conformance Summary

DOC02EB introduces **no new SMC definition** that contradicts DOC00. The DOC00 definitions are reproduced with operational detail; the new constructs (States, Expiration, Active/Historical, edge naming) are operational layers. Constants/decisions in force:

| Constant / Decision | Value | Source |
|---|---|---|
| Qualifying impulse | Confirmed **BOS or CHoCH** (body close, DOC02B/DOC02C) | DOC00 §14 |
| Candle selection | **One** candle — the **last opposite-body candle** before the impulse | DOC00 §14 |
| Zone marking | Candle **High-to-Low** (full range) | DOC00 §14, R-6 |
| Near edge (bullish) | Zone **High** | R-4 (from DOC00 §23) |
| Far edge (bullish) | Zone **Low** (stop below; invalidation on body close < Low) | DOC00 §15, §23, R-4 |
| Near edge (bearish) | Zone **Low** | R-4 |
| Far edge (bearish) | Zone **High** (stop above; invalidation on body close > High) | DOC00 §15, §23, R-4 |
| Validation instant | At the **confirming BOS/CHoCH body close** | DOC00 §14 |
| Immutability | OB record never edited after creation (lock timestamp) | DOC00 §14, DOC01 |
| Mitigation trigger | Closed candle **body** reaches into the zone | DOC00 §15 |
| Invalidation trigger | Closed candle **body closes beyond the far edge** | DOC00 §15 |
| Same-candle mitigation+invalidation | **Invalidation wins** (failure, not usable mitigation) | DOC00 §15 edge case |
| Wick-only into zone | **Not mitigation** | DOC00 §15 |
| Detection timeframe | **H1** (Market Structure Timeframe) | PATCH_001 |

---

# Concept 1 — Bullish Order Block

- **Definition:** A **Bullish Order Block** is the **last down-closing (bearish-body) H1 candle** before an up-impulse that produces a confirmed **bullish BOS or bullish CHoCH**. Its zone spans that candle's **High-to-Low**. It is validated only once the qualifying BOS/CHoCH is confirmed by body close. (DOC00 §14, unchanged.)
- **Purpose:** The institutional re-entry zone where price is expected to return (from above) and react; defines the long-entry reference zone and the stop-loss anchor (far edge = Low).
- **Relationship with previous documents:** Reproduces DOC00 §14 (bullish). Consumes DOC02B/DOC02C confirming events and DOC02A swings read-only. Written into the *OrderBlocks* section of the Structural Context (DOC01); this engine is the sole writer.
- **Inputs:** A confirmed bullish BOS or bullish CHoCH event (DOC02B/DOC02C); the impulse candles (closed H1 bars from the OB candle through the confirming candle); the OB candle's High/Low.
- **Outputs:** A Bullish OB record (direction, source candle timestamp, zone High, zone Low, near edge, far edge, confirming event reference, creation timestamp, lock timestamp, state, optional liquidity context).
- **Dependencies:** DOC02A (swings, for optional Internal/External context), DOC02B (BOS), DOC02C (CHoCH), DOC02D (optional sweep context), DOC01 Market Data Access (closed H1 OHLC), Utility, Logger.
- **Validation Rules:** (see *Order Block Validation*)
- **Creation Rules:** (see *Order Block Creation*)
- **Confirmation Rules:** Confirmed at the qualifying BOS/CHoCH body close. No second stage.
- **Failure Conditions:** No opposite-body candle exists in the impulse (gap move) → no OB recorded (DOC00 §14 edge case).
- **Edge Cases:** (see *Edge Cases*)
- **Automation Challenges:** (see *Automation Challenges*)
- **Recommended Deterministic Implementation:** (see *Recommended Deterministic Implementation*)
- **Computational Complexity:** (see *Performance Constraints*)
- **Memory Requirement:** (see *Performance Constraints*)
- **Update Frequency:** Evaluated on each confirmed BOS/CHoCH event (closed H1 bars). Never on ticks.
- **Lifecycle:** (see *Lifecycle*)

---

# Concept 2 — Bearish Order Block

- **Definition:** A **Bearish Order Block** is the **last up-closing (bullish-body) H1 candle** before a down-impulse that produces a confirmed **bearish BOS or bearish CHoCH**. Its zone spans that candle's **High-to-Low**. Validated only once the qualifying BOS/CHoCH is confirmed by body close. (DOC00 §14, unchanged.)
- **Purpose:** The institutional re-entry zone where price is expected to return (from below) and react; defines the short-entry reference zone and the stop-loss anchor (far edge = High).
- **Relationship with previous documents:** Mirror of Bullish OB. DOC00 §14.
- **Inputs:** A confirmed bearish BOS or bearish CHoCH; impulse candles; OB candle High/Low.
- **Outputs:** A Bearish OB record (mirrored fields).
- **Dependencies:** Same as Bullish OB.
- **Validation/Creation/Confirmation Rules:** Mirror of Bullish.
- **Failure Conditions:** No opposite-body candle in the impulse → no OB.
- **Edge Cases / Automation / Implementation / Complexity / Memory / Update / Lifecycle:** Mirror of Bullish.

---

# Order Block Creation — Detailed

### Required BOS
- A **confirmed Bullish BOS** (DOC02B) qualifies as the up-impulse for a Bullish OB.
- A **confirmed Bearish BOS** (DOC02B) qualifies as the down-impulse for a Bearish OB.
- The BOS must be a confirmed, immutable event (body close beyond the reference swing, per DOC02B).

### Required CHoCH
- A **confirmed Bullish CHoCH** (DOC02C) also qualifies as the up-impulse for a Bullish OB (DOC00 §14 accepts "BOS or CHoCH").
- A **confirmed Bearish CHoCH** qualifies as the down-impulse for a Bearish OB.
- Both BOS and CHoCH are equally deterministic (DOC02B/DOC02C); accepting both captures continuation and reversal OB origins.

### Required Candle
- Exactly **one** candle: the **last opposite-body candle** before the impulse.
- For a Bullish OB: the last candle whose body is bearish (`close < open`) encountered when scanning backward from the confirming candle through the impulse.
- For a Bearish OB: the last candle whose body is bullish (`close > open`) scanned backward from the confirming candle.
- DOC00 §14: "Two opposite candles before the impulse → only the last one is the OB." Scanning stops at the **first** opposite-body candle found (the most recent). (No multi-candle groups; DOC02EA D-6.)
- DOC00 §14 edge case: "The impulse contains no opposite-colour candle (rare gap move) → no OB is recorded."

### Required Timeframe
- **H1 only** (Market Structure Timeframe, PATCH_001). The confirming event, the impulse candles, and the OB candle are all H1 closed bars. No OB on H4 or M15.

### Required Confirmation
- The qualifying BOS/CHoCH must be **confirmed by body close** (DOC02B/DOC02C). Until that close, no OB is created.

### Creation Timestamp
- The **creation timestamp** = the close time of the OB (source) candle (the candle whose High/Low define the zone). This records *where* the OB sits in history.

### Lock Timestamp
- The **lock timestamp** = the close time of the **confirming BOS/CHoCH candle** (the instant the OB becomes valid and immutable). This records *when* the OB became a confirmed fact.
- The lock timestamp is always **≥** the creation timestamp (the confirming candle closes after the OB candle).

### Immutable Rules
1. Once created (at the lock timestamp), the OB record's zone (High/Low), source candle, and confirming event are **never edited**. (DOC00 §14; DOC01 immutability.)
2. Only the **state** field may change thereafter, and only via the defined lifecycle transitions (mitigation/invalidation/expiration/archival), each on a closed bar.
3. No later candle may "move," "resize," or "re-select" the OB candle. (Prevents repaint — DOC02EA non-repaint analysis.)

### Rejected Candidate Rules
A candidate OB is **rejected** (never created) when:
- The confirming event is not a confirmed BOS or CHoCH (e.g., a wick-only break, or an unconfirmed structure event).
- Scanning the impulse yields **no opposite-body candle** (gap move).
- The OB candle cannot be certified as a closed H1 bar (history gap / invalid bar).
- The confirming event references a candle on a timeframe other than H1.
Rejected candidates leave no record and emit no error (silent non-event, logged at DEBUG).

---

# Order Block Zone — Detailed

### Near Edge
- **Bullish OB:** Near edge = zone **High** (the edge price reaches first when returning from above after the up-impulse). (R-4.)
- **Bearish OB:** Near edge = zone **Low** (the edge price reaches first when returning from below after the down-impulse).
- The near edge is the "proximal" edge (closest to the return direction); it is where mitigation begins.

### Far Edge
- **Bullish OB:** Far edge = zone **Low**. The stop-loss anchor (DOC00 §23: long stop = far edge − SL Buffer, below the Low). Invalidation occurs when a body closes **below** this edge.
- **Bearish OB:** Far edge = zone **High**. Stop anchor (short stop = far edge + SL Buffer, above the High). Invalidation when a body closes **above** this edge. (R-4.)

### High
- The OB candle's **High** price (full-range top), recorded exactly (no rounding).

### Low
- The OB candle's **Low** price (full-range bottom), recorded exactly.

### Zone Width
- Width = |High − Low| of the OB candle. Computed once at creation; immutable.
- Width is informational. DOC00 has no minimum/maximum OB width; however, the **risk sanity cap** in DOC00 (MaxRiskPerTradePoints) operates downstream at entry (a too-wide OB leads to skipping the trade, not to rejecting the OB). The OB Engine does **not** filter by width.

### Zone Precision
- All zone prices use the symbol's native precision (XAUUSD, typically 2–3 decimals on Exness). No rounding.

### Body Relationship
- The zone is the **full range** (High-to-Low), not the body. The OB candle's body direction (bearish for a Bullish OB; bullish for a Bearish OB) is used **only** to select the candle during creation, not to define the zone bounds. (R-6; DOC02EA D-3.)

### Wick Relationship
- Both wicks are included in the zone (full range). The near-edge wick and far-edge wick are both part of the zone. (R-6.)

### Zone Lifetime
- The zone (High/Low) is fixed at creation and never changes for the life of the record. Only the OB's state changes.

---

# Order Block Validation

A created OB record is valid only if **all** hold:
- A confirmed BOS or CHoCH (DOC02B/DOC02C) exists as the qualifying impulse.
- Exactly one opposite-body H1 candle was selected as the source (the first opposite-body candle scanning backward from the confirming candle).
- The source candle is a certified closed H1 bar.
- Zone High = source candle High; Zone Low = source candle Low (exact).
- Creation timestamp = source candle close time; Lock timestamp = confirming candle close time; Lock ≥ Creation.
- Direction matches the qualifying event (bullish impulse → Bullish OB; bearish impulse → Bearish OB).
- All consumed records (BOS/CHoCH/swings) are unmodified and confirmed.

---

# Mitigation — Detailed

### Definition
Mitigation is the event of price **returning to** an OB zone after the OB-creating impulse. An OB is **mitigated** when a closed candle's **body** reaches into the zone. (DOC00 §15.)

### Validation
- For a **Bullish OB** (price returns from above): mitigation when a closed candle's body overlaps the zone, i.e., the candle's body has any portion within [Low, High]. Operationally: `min(open,close) ≤ High AND max(open,close) ≥ Low` (body intersects the zone), reached from above.
- For a **Bearish OB** (price returns from below): the same body-intersection test, reached from below.
- A **wick-only** entry into the zone (body does not intersect) is **not** mitigation. (DOC00 §15.)

### Closed Candle Requirement
- Evaluated only on **closed H1 candles**. Never on the forming candle.

### Body Requirement
- The test uses the candle **body** (open-to-close range), not the wicks. (DOC00 §15.)

### Partial Mitigation
- DOC00 §15 defines mitigation as a single boolean (body reaches the zone). There is no "partial" mitigation state in DOC00. DOC02EB therefore records mitigation as **all-or-nothing**: the first closed candle whose body intersects the zone marks the OB **Mitigated**. (No 50% threshold — DOC02EA D-4 rejected the discretionary Mean Threshold.)

### Multiple Mitigation
- Once an OB is Mitigated, it remains Mitigated. A second body-intersection on a later candle does **not** create a new state; it is simply noted in the audit log. (DOC00 has no "double mitigation.")

### Repeated Mitigation
- Same as Multiple Mitigation: the state is monotonic (Unmitigated → Mitigated). Repeated body intersections are logged but do not change state further.

### Mitigation Timestamp
- The close time of the first closed candle whose body intersects the zone.

### Mitigation State
- The OB transitions ACTIVE → MITIGATED at the mitigation timestamp. It remains consumable downstream (a mitigated OB is the entry-reference event per DOC00 §15), but its lifecycle state is MITIGATED.

---

# Invalidation — Detailed

### Definition
An OB is **invalidated (failed)** when a closed candle's **body closes beyond the far edge** of the zone. (DOC00 §15.) Once invalidated, the OB is no longer a usable re-entry zone.

### Body Close Requirement
- Uses the candle **close** price vs. the far edge (not the wick).
- Bullish OB: invalidation when `close < Low` (body closes below the far edge).
- Bearish OB: invalidation when `close > High` (body closes above the far edge).

### Far Edge Rule
- The far edge is the Low (bullish) / High (bearish), per R-4. A body close strictly beyond it invalidates the OB. Equality (close exactly at the edge) does **not** invalidate (strict).

### Gap Handling
- **Gap through the far edge:** if a candle opens already beyond the far edge and closes beyond it, it is an invalidation (body close beyond). (DOC00 §15.)
- **Same-candle mitigation + invalidation** (price gaps straight through the zone on open, body both entering and closing beyond): per DOC00 §15 edge case, this is treated as **invalidation (failure)**, not a usable mitigation. The OB → INVALIDATED directly (ACTIVE → INVALIDATED), skipping MITIGATED.
- **Missing candle (history gap) containing the invalidating close:** no invalidation recorded for the missing candle; the OB remains in its current state and is re-evaluated on the next clean closed candle. If a later closed candle still satisfies invalidation, it is applied then.

### Invalidation Timestamp
- The close time of the closed candle whose body closed beyond the far edge.

### Invalidation State
- The OB transitions its current state → INVALIDATED at the invalidation timestamp. An invalidated OB is archived (→ ARCHIVED) and is no longer consumable. (Its potential promotion to a Breaker Block — DOC00 §19 — is a **future-document** concern, out of scope here.)

---

# Lifecycle — Complete State Machine

Each Order Block has exactly one state at any time. Transitions occur only on closed H1 bars. The machine realises DOC00 §14/§15 semantics plus deterministic supersession (R-1, R-2).

### States

#### CANDIDATE
- **Purpose:** A qualifying BOS/CHoCH has been confirmed; the engine is scanning for the opposite-body source candle. Pre-publication state. (R-1.)
- **Entry Conditions:** A confirmed BOS or CHoCH is received (DOC02B/DOC02C).
- **Exit Conditions:** Source candle found → CONFIRMED; no source candle found (gap move) → rejected (no record persists).
- **Allowed Transitions:** → CONFIRMED, → (rejected/no record).
- **Forbidden Transitions:** → ACTIVE, MITIGATED, INVALIDATED (cannot be acted upon before confirmation).
- **Recovery:** CANDIDATE is transient (resolved within the same bar evaluation); no persistence needed.

#### CONFIRMED
- **Purpose:** The OB candle has been selected and the record created/locked. It is now an immutable fact but not yet "active" until the creation finalisation step (which also handles supersession of prior same-direction OBs).
- **Entry Conditions:** From CANDIDATE, when the opposite-body source candle is found and all Validation Rules pass.
- **Exit Conditions:** Finalisation → ACTIVE.
- **Allowed Transitions:** → ACTIVE.
- **Forbidden Transitions:** → MITIGATED, INVALIDATED, EXPIRED (these require the OB to be ACTIVE first; a brand-new OB supersedes others, it is not itself superseded at birth).
- **Recovery:** None needed; CONFIRMED→ACTIVE is automatic at finalisation.

#### ACTIVE
- **Purpose:** The OB is a live, consumable re-entry zone of its direction; eligible for mitigation/invalidation checks and for downstream consumption (after the look-ahead guard, R-7).
- **Entry Conditions:** From CONFIRMED (finalisation). At most one ACTIVE OB per direction at a time (R-2): when a new OB becomes ACTIVE, the previous same-direction ACTIVE OB (if unmitigated) → EXPIRED.
- **Exit Conditions:** Mitigated (→ MITIGATED), Invalidated (→ INVALIDATED), or superseded (→ EXPIRED).
- **Allowed Transitions:** → MITIGATED, → INVALIDATED, → EXPIRED, → ARCHIVED (retention), → INVALID (defensive).
- **Forbidden Transitions:** → CANDIDATE, → CONFIRMED.
- **Recovery:** If the underlying records are later found inconsistent → INVALID; rebuild from immutable histories.

#### MITIGATED
- **Purpose:** A closed candle's body has intersected the zone (DOC00 §15). The OB has been "used" as a re-entry reference. (R-1.)
- **Entry Conditions:** From ACTIVE, on the first body-intersection of the zone.
- **Exit Conditions:** Invalidated (→ INVALIDATED) or superseded/archived (→ ARCHIVED). A mitigated OB may still be invalidated later if price closes beyond the far edge.
- **Allowed Transitions:** → INVALIDATED, → EXPIRED (if superseded while mitigated — rare), → ARCHIVED.
- **Forbidden Transitions:** → ACTIVE (mitigation is monotonic; an OB cannot become "un-mitigated").
- **Recovery:** None; monotonic.

#### INVALIDATED
- **Purpose:** A closed candle's body closed beyond the far edge (DOC00 §15). The OB has failed. (R-1.)
- **Entry Conditions:** From ACTIVE or MITIGATED, on a body close beyond the far edge. (Same-candle case: ACTIVE → INVALIDATED directly, DOC00 §15.)
- **Exit Conditions:** → ARCHIVED (after audit). Potential future → BREAKER promotion is **out of scope** (future document).
- **Allowed Transitions:** → ARCHIVED.
- **Forbidden Transitions:** → ACTIVE, MITIGATED, EXPIRED, CONFIRMED (a failed OB never recovers within this engine).
- **Recovery:** None within the OB Engine. (Breaker promotion, if ever implemented, is a separate future object, not a state recovery.)

#### EXPIRED
- **Purpose:** An unmitigated/uninvalidated OB that has been **superseded** by a newer same-direction ACTIVE OB (R-2). It is no longer the primary re-entry zone for its direction. Deterministic retirement without invalidating it (it did not fail; it was simply overtaken).
- **Entry Conditions:** From ACTIVE, when a newer same-direction OB is created and becomes ACTIVE.
- **Exit Conditions:** → ARCHIVED.
- **Allowed Transitions:** → ARCHIVED. (An EXPIRED OB is not re-evaluated for mitigation/invalidation — it is retired. If price later reaches an expired OB, that is not recorded here; expired OBs are out of the active evaluation set.)
- **Forbidden Transitions:** → ACTIVE, MITIGATED, INVALIDATED (expiration is terminal before archival).
- **Recovery:** None; deterministic supersession.

#### ARCHIVED
- **Purpose:** Terminal storage for MITIGATED/INVALIDATED/EXPIRED records retained for audit, backtest reconstruction, and potential future Breaker promotion. Removed from the active evaluation set. Subject to retention pruning (oldest first).
- **Entry Conditions:** From MITIGATED, INVALIDATED, or EXPIRED (after their audit fields are finalised), or directly from ACTIVE under retention pruning.
- **Exit Conditions:** None (terminal), except removal by retention pruning.
- **Allowed Transitions:** → (removed by retention pruning).
- **Forbidden Transitions:** → any active state (archived records never return).
- **Recovery:** None.

#### INVALID (defensive)
- **Purpose:** An OB whose records are internally inconsistent (corrupted source/confirming references, non-monotonic timestamps). Defensive only.
- **Entry Conditions:** Detection of an internal inconsistency.
- **Exit Conditions:** Rebuild from immutable histories yields a consistent state.
- **Allowed Transitions:** → recomputed state (ARCHIVED typically).
- **Forbidden Transitions:** None (recovery entry point).
- **Recovery:** Rebuild the record from the immutable BOS/CHoCH/swing histories; re-derive zone and state deterministically; if unrecoverable, remain INVALID and exclude from consumption.

### State Machine Guarantees
- An OB is consumable (for entries, future) **only** in ACTIVE or MITIGATED, and only **after** its lock timestamp (look-ahead guard, R-7).
- Mitigation is monotonic (Unmitigated → Mitigated, never back).
- Invalidation is terminal (failed OBs never recover within this engine).
- At most one ACTIVE OB per direction at a time (supersession bounds the active set).
- All transitions occur on closed H1 bars; the record (zone, source, confirming event) is immutable after the lock timestamp.

---

# Active Order Blocks vs Historical Order Blocks

- **Active Order Blocks:** OBs in ACTIVE (and MITIGATED, which remains a live entry reference per DOC00 §15) states, not yet archived. These are the consumable set. At most one ACTIVE (unmitigated) OB per direction; plus any recently-MITIGATED OBs still within the evaluation window before archival.
- **Historical Order Blocks:** OBs in INVALIDATED, EXPIRED, or ARCHIVED states. Retained for audit, backtest reconstruction, and potential future Breaker promotion (out of scope). Read-only to all consumers.
- **Design intent:** keep the Active set small and bounded; grow the Historical set only up to the retention cap, then prune oldest-first. (R-3.)

---

# Dependencies (consumer only)

The Order Block Engine consumes **only** the following, read-only:

| Consumed from | Used for |
|---|---|
| DOC02B: Confirmed BOS events | Qualifying impulse (continuation OB origin) |
| DOC02C: Confirmed CHoCH events | Qualifying impulse (reversal OB origin) |
| DOC02C: Prevailing Direction | Optional context (informational; not a creation gate) |
| DOC02A: Confirmed Swing Data | Optional Internal/External context (dealing range); not a creation gate |
| DOC02A: Market Structure State | Optional context |
| DOC02D: Liquidity Events | **Optional** quality context attached to the OB (e.g., "created after a sweep"); never a creation requirement (R-5) |
| DOC01: Market Data Access | Closed H1 OHLC for impulse scanning and mitigation/invalidation tests |

The Order Block Engine **must not**:
- Create, modify, or delete any swing, HH/HL/LH/LL label, or Structure State (DOC02A).
- Create, modify, or delete any BOS record (DOC02B).
- Create, modify, or delete any CHoCH record or the Prevailing Direction (DOC02C).
- Create, modify, or delete any Liquidity record (DOC02D).
- Create or modify Fair Value Gap, Entry, Risk, or Trade Management data.
- Design or promote Breaker Blocks (future document).
- Read forming bars or any timeframe other than H1.

It is a **consumer only** with respect to all upstream data, and the **sole writer** of the *OrderBlocks* section (OB records, states, zones, mitigation/invalidation/expiration).

---

# Implementation Constraints (MetaTrader 5)

### Maximum recommended candle lookback (creation scan)
- The backward scan for the opposite-body source candle is bounded by the **impulse length** (the number of candles from the confirming candle back to the source). Cap the scan at a fixed maximum (e.g., the project's initialisation lookback depth constant from DOC01). If the cap is reached without finding an opposite-body candle, no OB is created (treated as a gap/strong impulse with no OB).

### Maximum active Order Blocks
- At most **one ACTIVE (unmitigated) OB per direction** (supersession, R-2) → at most 2 truly-active OBs at any time. Plus a small bounded set of recently-MITIGATED OBs pending archival. Recommend an overall active-set cap of a small fixed constant (e.g., 8–16) to bound memory; overflow moves the oldest MITIGATED → ARCHIVED.

### Recommended caching strategy
- Cache the latest closed H1 bar and the most-recent BOS/CHoCH confirmations (already cached upstream). OB creation scans only on a new confirmed structure event, not per tick. Mitigation/invalidation checks iterate only the active set (tiny).

### Recommended invalidation strategy
- On each closed H1 bar, test only the **active set** (≤ a handful of OBs) against the body-close-beyond-far-edge rule. O(active) per bar. Historical/archived OBs are not re-tested.

### Recommended cleanup strategy
- FIFO retention pruning of ARCHIVED records beyond a fixed cap (e.g., keep the most recent N archived OBs). Pruning removes the oldest; it never touches active records.

### Recommended update timing
- OB creation: on a confirmed BOS/CHoCH event (closed H1 bar).
- Mitigation/invalidation/expiration: on each closed H1 bar, after DOC02A/DOC02B/DOC02C/DOC02D have updated for that bar (frozen snapshot, DOC01).

### When scanning should occur
- Only on closed H1 bars, within the bar-scoped analysis pipeline, reading the frozen Structural Context snapshot.

### When scanning must never occur
- Never on ticks. Never on the forming bar. Never across timeframes other than H1. Never by re-reading already-archived records.

---

# Performance Constraints

### CPU Complexity
- **Creation:** O(k) per confirmed structure event, where k = impulse length (small; capped). Amortised O(1) over a bar.
- **Mitigation/invalidation check:** O(A) per closed H1 bar, where A = active-set size (≤ small constant). Effectively O(1).
- **Initialisation (cold start replay):** O(N) over a bounded lookback of N H1 bars, each O(1).

### Memory Complexity
- O(A + H) where A = active set (bounded small) and H = archived set (bounded by retention cap). Bounded overall.

### Worst Case
- A long impulse (k near the scan cap) on creation, plus a full active-set scan — still O(k + A), bounded and infrequent.

### Average Case
- k small (1–3 candles typically), A ≤ a few. Near-constant per bar.

### Expected Number of Active Order Blocks
- At most 2 truly-active (one per direction) plus a few recently-mitigated pending archival. Very small.

### Expected Scan Cost
- One pass over the active set per closed bar; negligible.

### Optimization Recommendations
- Keep the active set as a small fixed-capacity structure; archived records in a separate bounded ring/log. Test mitigation before invalidation on each candle (short-circuit). Skip archived records entirely.

---

# MQL5 Implementation Feasibility

(No code. Engineering risks and safeguards only.)

### Potential implementation risks
- Acting on an OB before its confirming close (look-ahead). Mitigated by the CANDIDATE→CONFIRMED→ACTIVE gating and the look-ahead guard (R-7).
- Re-selecting the OB candle on a later bar (repaint). Mitigated by immutability after the lock timestamp.
- Conflating mitigation (body-intersection) with invalidation (body-close-beyond-far-edge). Mitigated by strict, distinct tests.

### Broker data issues
- Symbol precision changes or `_Point` differences affect zone comparisons. Safeguard: compare in the symbol's native precision; validate `_Point` at init (DOC01).

### Weekend gaps
- A weekend gap can open beyond an OB's far edge → invalidation on the opening candle's close if it closes beyond. Handled by the standard gap rule (DOC00 §15). No special-case logic required.

### Missing candles
- A missing candle in the impulse prevents source selection (no OB created for that move). A missing candle at mitigation/invalidation defers the check to the next clean closed bar. Safeguard: the closed-bar guard (DOC01 Market Data Access) certifies bars before use.

### Historical synchronization
- H1 history must be continuous and synchronised for deterministic replay. Safeguard: at init, verify history continuity within the lookback; do not fabricate missing bars (DOC01 Automation Challenges).

### Memory growth
- Bounded by the active-set cap and the archived-retention cap (FIFO). Safeguard: enforce caps; prune oldest-first.

### CPU spikes
- Bounded by O(k + A) per event/bar; no per-tick heavy work. Safeguard: all structural work is bar-scoped (DOC01).

### Recommended engineering safeguards
1. Closed-bar chokepoint (DOC01 Market Data Access) as the only candle source.
2. Immutable OB records after the lock timestamp (enforced by data structure).
3. Look-ahead guard: consumable only after lock timestamp.
4. Bounded active + archived caps with FIFO pruning.
5. Full audit logging of every state transition (DOC01 logging philosophy) for bar-by-bar backtest reconstruction.
6. Defensive INVALID state + deterministic rebuild from immutable histories.

---

# Design Principles (conformance)

| Principle | How DOC02EB satisfies it |
|---|---|
| Deterministic | Every OB is a pure function of confirmed BOS/CHoCH + closed H1 candles; identical data ⇒ identical OBs. |
| Non-Repainting | OB locked at the confirming close; immutable thereafter; CANDIDATE never exposed. |
| Immutable after confirmation | Zone/source/confirming-event never edited; only state changes via defined transitions. |
| Low CPU usage | O(k + A) per event/bar; bar-scoped only. |
| Low memory usage | Bounded active + archived caps. |
| Easy to debug | Each OB carries source candle, zone, confirming event, and full state history — fully auditable. |
| Easy to backtest | Pure closed-bar + confirmed-event function; reproducible in the MT5 tester. |
| Easy to maintain | One concern (OB lifecycle); clean consumer-only boundaries. |
| Suitable for future multi-symbol support | All comparisons use the symbol's native `_Point`; no XAUUSD-specific logic in the rules (only in the inherited constants, which are per-symbol). |

---

# Cross-Document Consistency

| Concern | How DOC02EB respects it |
|---|---|
| DOC00 §14 OB definition | Reproduced verbatim: last opposite-body candle before BOS/CHoCH impulse; zone High-to-Low; validated on body close; immutable. |
| DOC00 §15 Mitigation/Invalidation | Body-into-zone = mitigation; body-close-beyond-far-edge = invalidation; same-candle → invalidation; wick-only not mitigation. |
| DOC00 §23 Stop Loss (far edge) | Far edge pinned from §23: bullish far edge = Low; bearish far edge = High. |
| DOC00 §19 Breaker (out of scope) | Invalidated OBs archived; Breaker promotion deferred to a future document. Not designed here. |
| DOC02EA recommendation | Confirmed as official: single-candle, full-range, body-based, no displacement gate, immutable, look-ahead-guarded. |
| PATCH_001 timeframes | OB on H1 only. |
| DOC01 module ownership | OB Engine is sole writer of *OrderBlocks* section; closed-bar discipline; immutable records; frozen per-bar snapshot; bounded retention. |
| DOC02A primacy | Swings/Structure State consumed read-only; never modified. |
| DOC02B/DOC02C primacy | BOS/CHoCH/Prevailing Direction consumed read-only; both BOS and CHoCH accepted as qualifying impulses (DOC00 §14). |
| DOC02D primacy | Liquidity Events consumed read-only as optional context; never a creation requirement. |

---

# Self Review Result

Before finalising, the document was checked against the required checklist. Findings and resolutions:

- **Consistency with every previous document:** DOC00 §14/§15/§23 reproduced exactly; DOC02EA recommendation confirmed; PATCH_001 (H1) honoured; DOC01 module ownership and immutability honoured; DOC02A/B/C/D consumed read-only only. *(Pass)*
- **No subjective language:** Avoided. No "strong," "significant," "prominent," "displacement" as definitional terms (only when quoting sources in DOC02EA). All rules are fixed comparisons. *(Pass)*
- **No repaint possibility:** Eliminated. OB locked at the confirming close; immutable thereafter; CANDIDATE never exposed; zone never re-selected. *(Pass)*
- **No look-ahead bias:** Eliminated. Consumable only after the lock timestamp (R-7); only confirmed events and closed bars used. *(Pass)*
- **No circular dependency:** The OB Engine depends only on lower-layer/already-published data (DOC02A/B/C/D) and writes only its own section. It does not feed back into structure/liquidity. *(Pass)*
- **No undefined terminology:** OB, near/far edge, zone, creation/lock timestamp, mitigation, invalidation, expiration, supersession, active/historical, all states — defined. *(Pass)*
- **No unnecessary complexity:** Lifecycle has exactly the requested states; no discretionary thresholds (50%, displacement); single-candle selection; one-active-per-direction. *(Pass)*
- **Implementation feasibility:** All inputs available via DOC01 Market Data Access + Structural Context; O(k + A) cost; bounded memory. *(Pass)*
- **Performance feasibility:** Near-constant per bar; tiny active set; FIFO-bounded archives. *(Pass)*
- **Maintainability:** Single concern; clean consumer-only boundaries; full audit trail. *(Pass)*

**Scope boundaries respected:** Fair Value Gap, Entry Strategy, Risk Management, Trade Management, and **Breaker Block promotion** are **not** designed here. An invalidated OB is archived; its Breaker future is a separate document.

**Reported items (R-1…R-7)** are operational extensions consistent with DOC00; none redefines an approved concept.

**Outcome:** No blocking issues. DOC02EB is internally consistent, deterministic, non-repainting, look-ahead-safe, circular-dependency-free, and fully conforms to DOC00–DOC02EA.

---

# Final Notes

1. **Order Blocks only.** This document specifies the Order Block Engine and nothing else. No FVG, Entry, Risk, Trade Management, or Breaker logic.
2. **Consumer discipline.** The OB Engine consumes DOC02A/DOC02B/DOC02C/DOC02D outputs read-only and never mutates them. It is the sole writer of the *OrderBlocks* section.
3. **DOC00 fidelity.** DOC00 §14/§15 (and §23 far-edge) are preserved exactly. New constructs (States, Expiration, Active/Historical, edge naming) are operational extensions, reported and consistent.
4. **Non-repainting + look-ahead-safe** by construction: lock-at-confirming-close + immutability + consumable-only-after-lock.
5. **One ACTIVE OB per direction** (supersession) bounds the active set deterministically.
6. **Breaker promotion is out of scope.** Invalidated OBs are archived for a future Breaker document; this engine does not promote them.
7. **Downstream consumers** (Entry, future Trade Decision) may read the *OrderBlocks* section read-only, respecting the look-ahead guard; they must not redefine OBs or mutate OB records.

This document is now the official specification for the Order Block Engine.
