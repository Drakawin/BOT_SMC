# DOC02D — Liquidity Engine
## Official Specification for Liquidity, Equal Highs/Lows, and Liquidity Sweeps (H1)

> **Document status:** AUTHORITATIVE — Official specification for the **Liquidity Engine only**.
> **Phase:** Module Specification (Phase 2, Part D).
> **Scope of this document:** Liquidity, Liquidity Pool, Buy-side Liquidity (BSL), Sell-side Liquidity (SSL), Equal High (EQH), Equal Low (EQL), Liquidity Sweep, Liquidity Consumption, Internal Liquidity, External Liquidity, and the deterministic Liquidity State machine.
> **Explicitly out of scope (future documents):** Order Block, Fair Value Gap, Mitigation, Entry Confirmation, Risk Management, Position Management. These are **not** defined, behaviourally referenced, or implemented here.
> **Relationship to prior documents:**
> - Implements **DOC00_Strategy_Validation.md §10 (Liquidity), §11 (EQH), §12 (EQL), §13 (Liquidity Sweep)** without modification to their definitions or constants.
> - Conforms to **DOC00_PATCH_001.md**: liquidity is detected on the **Market Structure Timeframe (H1)**.
> - Realises the **Liquidity Engine** module defined in **DOC01_System_Architecture.md** (Layer 2), writing into the *Liquidity* section of the Structural Context. It is the sole writer of that section.
> - Consumes **only** the outputs of **DOC02A** (Confirmed Swing High, Confirmed Swing Low, HH, HL, LH, LL, Structure State), **DOC02B** (BOS Events), and **DOC02C** (CHoCH Events, Prevailing Direction). It creates or modifies **none** of those records.
> **Priority rule:** If anything here appears to conflict with DOC00, PATCH_001, DOC01, DOC02A, DOC02B, or DOC02C, those documents prevail. DOC02D governs only the Liquidity Engine details.

---

# Reported Items (reported, not changed)

Per the standing instruction to *report* rather than silently change, the following are flagged. Each defines a **new operational construct** requested by this document's scope that is **not present in DOC00**. They are defined deterministically here in a way that is fully consistent with (and never contradicts) DOC00. **No approved document was modified.**

| # | Item | Status |
|---|---|---|
| R-1 | **Liquidity Pool** — DOC00 §10 uses "pool" only informally ("a buy-side liquidity pool"). DOC02D defines **Liquidity Pool** operationally as the set of one or more liquidity levels that share a common role (BSL or SSL) and a common relationship to the current Dealing Range (Internal or External). It is a grouping/organising concept over already-defined levels, not a new SMC concept. | Reported — extension, consistent with DOC00 §10. |
| R-2 | **Liquidity Consumption** — DOC00 §13 implies consumption ("liquidity has been taken", "the swept level is retired") but does not name a "Consumption" event/state. DOC02D defines **Liquidity Consumption** as the deterministic transition of a level from an active target to a retired, archived state, occurring via sweep or via supersession. This operationalises DOC00's "retired" language; it does not change it. | Reported — extension, consistent with DOC00 §13. |
| R-3 | **Internal Liquidity** and **External Liquidity** — DOC00 does **not** define these terms. They are standard ICT distinctions. DOC02D defines them deterministically using the **Dealing Range** already established in DOC00 (Premium/Discount): External = liquidity at the range-bounding swings; Internal = liquidity at swings strictly inside the range. This classification is derived purely from DOC02A confirmed swings and the Dealing Range; it adds no new SMC rule. | Reported — extension, consistent with DOC00 Dealing Range. |
| R-4 | **Liquidity State machine** (UNKNOWN/BUILDING/ACTIVE/SWEPT/CONSUMED/INVALID) — DOC00 does **not** contain a liquidity state machine; DOC00 only states levels are "added/removed only when swings are confirmed" and "the swept level is retired." DOC02D designs the requested state machine as the operational lifecycle of each liquidity level, realising DOC00's add/remove/retire semantics deterministically. It is a DOC02D design element, not a DOC00 redefinition. | Reported — extension, consistent with DOC00 §10/§13. |
| R-5 | DOC00 §13 states a sweep requires the wick to exceed the level by **more than** ELT points (strictly `> ELT`), while EQH/EQL uses **≤ ELT** for "equal." DOC02D preserves both exactly: the sweep threshold is strict `>` ELT beyond the level; the equality tolerance is `≤` ELT between two swings. These are two distinct comparisons on two distinct pairs of values; no conflict. | Reported — clarification, no contradiction. |
| R-6 | DOC00 §13 defines a sweep by reference to "the level" and notes a candle may "sweep multiple levels in one bar." DOC02D specifies that each swept level produces its own sweep record and transitions independently; one candle may therefore produce multiple sweep records. This operationalises the DOC00 edge case without changing it. | Reported — clarification, consistent with DOC00 §13. |
| R-7 | DOC00 §10 says the engine "keeps the most recent relevant BSL above price and SSL below price as the active targets" and recomputes "only on new confirmed swings." DOC02D preserves this: the **active target set** is recomputed only on confirmed swing events (not on ticks), and consists of the nearest BSL above and nearest SSL below the current price at that recomputation. Internal/External classification is layered on top of, not in place of, this rule. | Reported — clarification, consistent with DOC00 §10. |

No approved document was modified.

---

# Conformance Summary

DOC02D introduces **no new SMC definition** that contradicts DOC00. The DOC00 definitions are reproduced with operational detail; the new constructs (Pool, Consumption, Internal/External, State machine) are operational layers over DOC00 concepts. The constants and decisions in force:

| Constant / Decision | Value | Source |
|---|---|---|
| Equal-Level Tolerance (ELT) | **20 points** (XAUUSD) | DOC00 Deterministic Rules |
| EQH/EQL comparison | `abs(swingA − swingB) ≤ ELT` (inclusive) | DOC00 §11/§12 |
| Sweep beyond-level threshold | wick beyond level by **strictly `> ELT`** points | DOC00 §13, R-5 |
| BSL location | above confirmed Swing Highs / EQH (price level = swing wick extreme) | DOC00 §10 |
| SSL location | below confirmed Swing Lows / EQL (price level = swing wick extreme) | DOC00 §10 |
| EQH pool price | the **higher** of the grouped swing highs | DOC00 §11 |
| EQL pool price | the **lower** of the grouped swing lows | DOC00 §12 |
| Sweep confirmation | on the **close** of the sweeping candle; wick beyond `> ELT`, close back inside (not a BOS/CHoCH body close beyond) | DOC00 §13 |
| Active target recomputation | only on new confirmed swings | DOC00 §10, R-7 |
| Detection timeframe | **H1** (Market Structure Timeframe) | PATCH_001 |
| Level repaint | None — levels derived only from confirmed swings; sweeps confirmed only on closed candles | DOC00 §10/§13 |

---

# Concept 1 — Liquidity

- **Definition:** Resting buy/sell interest represented as **labelled price levels** derived from confirmed swings: **Buy-side Liquidity (BSL)** levels lie **above** confirmed Swing Highs / Equal Highs; **Sell-side Liquidity (SSL)** levels lie **below** confirmed Swing Lows / Equal Lows. Each level's price equals the swing's wick extreme. (DOC00 §10, unchanged.)
- **Purpose:** Provide objective, finite targets where stops are expected to cluster, used for sweep detection (DOC00 §13) and, downstream, as entry context (out of scope).
- **Relationship with previous documents:** Reproduces DOC00 §10. Consumes DOC02A confirmed swings read-only. Written into the *Liquidity* section of the Structural Context (DOC01). The Liquidity Engine is the sole writer of this section.
- **Inputs:** Confirmed Swing Highs and Confirmed Swing Lows from DOC02A (price + confirmation time).
- **Outputs:** BSL and SSL level records (price, type, source swing(s), classification Internal/External, state).
- **Dependencies:** DOC02A (swings); Utility (precision/tolerance); Logger. No dependency on OB/FVG/Entry/Risk.
- **Deterministic Rules:**
  1. Levels are derived **only** from confirmed swings (DOC02A). Unconfirmed/pending swings never produce a level.
  2. A BSL is created at the **high** price of a confirmed Swing High (and at EQH pool prices). An SSL is created at the **low** price of a confirmed Swing Low (and at EQL pool prices).
  3. Levels are added/removed only on confirmed-swing events (R-7).
  4. Each level is tagged BSL or SSL, never both.
  5. Levels are immutable once created except for their lifecycle state transitions (see Liquidity State).
- **Validation Rules:** Level price equals the source swing's recorded price (no rounding); source swing confirmation time is valid; type tag matches the source swing type.
- **Confirmation Rules:** A level is confirmed at the moment its source swing is confirmed (DOC02A confirmation instant). No separate liquidity confirmation.
- **Invalid Conditions:** A level is never created from a non-confirmed swing; a level with a source swing later found inconsistent is moved to INVALID (defensive).
- **Failure Conditions:** Source swing record missing/corrupted → no level created.
- **Edge Cases:** Many overlapping levels in ranging markets; mitigated by the active-target rule (nearest BSL above, nearest SSL below) and by retention pruning.
- **False Detection Cases:** Treating every minor confirmed swing as a significant level — inherent; mitigated by H1 timeframe (PATCH_001) and downstream filters, not by changing the rule.
- **Market Noise Considerations:** SFS = 2 on H1 already filters single-bar noise at the swing source. Liquidity adds no further noise filter (that would be subjective); it represents all confirmed-swing-derived levels.
- **Automation Challenges:** Keeping the active-target set consistent across bar boundaries; ensuring immutability of created levels; avoiding tick-driven recomputation.
- **Recommended Deterministic Implementation:** On each confirmed-swing event, derive the corresponding BSL/SSL level(s), tag and classify them, and recompute the active-target set (nearest BSL above, nearest SSL below). Never recompute on ticks.
- **Computational Complexity:** O(1) per confirmed swing (a few comparisons to classify/insert); O(L) to recompute active targets where L is the bounded level list (small). Initialisation: O(N) replay.
- **Memory Requirement:** One record per level, bounded by retention pruning (FIFO of oldest CONSUMED/retired records).
- **Update Frequency:** Only on confirmed-swing events (closed H1 bars). Never on ticks.
- **Lifecycle:** See *Liquidity State*.

---

# Concept 2 — Liquidity Pool

- **Definition:** A **Liquidity Pool** is the organising grouping of liquidity levels that share (a) the same side — BSL or SSL — and (b) the same Dealing-Range relationship — Internal or External. A pool is a **set of levels**, not a new price. (R-1.)
- **Purpose:** Provide a deterministic way to refer to "the buy-side external pool" or "the sell-side internal pool" without ambiguity, for sweep and (future) entry logic.
- **Relationship with previous documents:** Operationalises DOC00 §10's informal "pool" language. Uses the DOC00 Dealing Range. No new SMC rule.
- **Inputs:** The set of active BSL/SSL levels; the current Dealing Range (from DOC02A: range-bounding swing high and swing low).
- **Outputs:** Four named pools (at most): BSL-External, BSL-Internal, SSL-External, SSL-Internal, each a (possibly empty) set of level references.
- **Dependencies:** DOC02A (swings, Dealing Range); this engine's levels.
- **Deterministic Rules:**
  1. A level belongs to exactly one pool, determined by its side (BSL/SSL) and its Internal/External classification.
  2. Pool membership is recomputed when levels are added/removed or when the Dealing Range changes (both closed-bar events).
  3. Pools contain only ACTIVE levels (non-retired).
- **Validation Rules:** Every ACTIVE level appears in exactly one pool; no ACTIVE level is orphaned.
- **Confirmation Rules:** Pool membership is derived; no separate confirmation.
- **Invalid Conditions:** A level whose Dealing-Range relationship cannot be determined (no range established) is classified **External** by default (safest: treat unbounded levels as external). (See Internal/External.)
- **Failure Conditions:** Dealing Range undefined (DOC02A UNKNOWN/INITIAL) → all levels classified External; pools still maintained.
- **Edge Cases:** A level exactly at a range bound → classified by the bound it sits at (a BSL at the range-high swing = External; see Internal/External).
- **False Detection Cases:** Mis-grouping due to a stale Dealing Range snapshot — prevented by frozen per-bar snapshot (DOC01).
- **Market Noise Considerations:** Pools may contain many internal levels in choppy markets; the active-target rule keeps the working set small.
- **Automation Challenges:** Keeping pool membership consistent with level lifecycle (retired levels leave pools).
- **Recommended Deterministic Implementation:** Maintain level records with side + classification tags; derive pools as filtered views each time levels or the range change.
- **Computational Complexity:** O(L) to (re)derive all pools; L is small and bounded.
- **Memory Requirement:** Pools are views (references) over the level list; negligible extra memory.
- **Update Frequency:** On confirmed-swing events and on Dealing-Range changes (closed H1 bars).
- **Lifecycle:** Pools exist as long as the engine runs; their contents follow level lifecycles.

---

# Concept 3 — Buy-side Liquidity (BSL)

(Full detail in the dedicated *Buy-side Liquidity* section below.)

- **Definition:** A liquidity level located **above** price, derived from a confirmed Swing High (or an EQH pool), at the swing's high price. Represents resting buy-side interest (stops above highs). (DOC00 §10.)
- **Purpose:** Primary upward sweep target; also the reference whose body-close breach (by a candle) is a bullish structure event (BOS/CHoCH, DOC02B/DOC02C) — but that classification is **not** performed here.

---

# Concept 4 — Sell-side Liquidity (SSL)

(Full detail in the dedicated *Sell-side Liquidity* section below.)

- **Definition:** A liquidity level located **below** price, derived from a confirmed Swing Low (or an EQL pool), at the swing's low price. Represents resting sell-side interest (stops below lows). (DOC00 §10.)
- **Purpose:** Primary downward sweep target.

---

# Concept 5 — Equal High (EQH)

(Full detail in the dedicated *Equal High / Equal Low* section below.)

- **Definition:** Two or more confirmed Swing Highs whose high prices differ by **≤ ELT (20 points)**. The EQH pool price is the **higher** of the grouped highs. (DOC00 §11.)

---

# Concept 6 — Equal Low (EQL)

(Full detail in the dedicated *Equal High / Equal Low* section below.)

- **Definition:** Two or more confirmed Swing Lows whose low prices differ by **≤ ELT (20 points)**. The EQL pool price is the **lower** of the grouped lows. (DOC00 §12.)

---

# Concept 7 — Liquidity Sweep

(Full detail in the dedicated *Liquidity Sweep* section below.)

- **Definition:** A candle whose **wick** exceeds a BSL (above) or SSL (below) by **strictly more than ELT** points, while the candle **closes back inside** the level (the close is **not** a BOS/CHoCH body close beyond the level). Confirmed only on the **close** of the sweeping candle. (DOC00 §13.)

---

# Concept 8 — Liquidity Consumption

- **Definition:** **Liquidity Consumption** is the deterministic transition of a liquidity level from an active target to a retired, archived state. Consumption occurs via exactly two paths: (a) **Sweep consumption** — the level is swept (DOC00 §13); (b) **Supersession consumption** — the level is superseded as an active target by a more recent, more relevant level of the same side, per the active-target rule. (R-2.)
- **Purpose:** Realise DOC00's "the swept level is retired" and "keeps the most recent relevant … levels" as explicit, auditable state transitions.
- **Relationship with previous documents:** Operationalises DOC00 §10/§13 retirement language. No new SMC rule.
- **Inputs:** Sweep events (this engine); confirmed-swing events that change the active-target set (DOC02A).
- **Outputs:** Level state transitions ACTIVE → SWEPT → CONSUMED, or ACTIVE → CONSUMED (supersession).
- **Dependencies:** This engine's levels and sweeps; DOC02A swings.
- **Deterministic Rules:**
  1. A level can only be consumed if it is currently ACTIVE.
  2. Sweep consumption: on a confirmed sweep of a level, the level transitions ACTIVE → SWEPT, then immediately SWEPT → CONSUMED (same bar close).
  3. Supersession consumption: when the active-target recomputation determines a level is no longer the nearest relevant target of its side and pool, it transitions ACTIVE → CONSUMED.
  4. Once CONSUMED, a level is archived and never returns to ACTIVE.
- **Validation Rules:** The consuming event (sweep record or supersession recomputation) must be valid and timestamped; the level's state history must be monotonic.
- **Confirmation Rules:** Consumption is confirmed at the close of the bar on which the consuming event occurred.
- **Invalid Conditions:** Attempting to consume a non-ACTIVE level is rejected (no-op, logged).
- **Failure Conditions:** Consuming event references a missing level → no transition, logged.
- **Edge Cases:** A level swept and simultaneously superseded on the same bar → sweep consumption takes precedence (SWEPT → CONSUMED).
- **False Detection Cases:** Premature supersession due to a stale price snapshot — prevented by closed-bar recomputation.
- **Market Noise Considerations:** Frequent supersession in choppy markets retires many minor levels quickly; this is correct and bounded.
- **Automation Challenges:** Ensuring monotonic state history; preventing a consumed level from being re-activated by a later (buggy) recomputation.
- **Recommended Deterministic Implementation:** Append-only state history per level; recomputation derives the active set and marks superseded levels CONSUMED in one pass.
- **Computational Complexity:** O(L) per recomputation pass.
- **Memory Requirement:** Archived (CONSUMED) levels retained per retention pruning; state history is a few bytes per level.
- **Update Frequency:** On sweep events and confirmed-swing events (closed H1 bars).
- **Lifecycle:** ACTIVE → SWEPT → CONSUMED (sweep) or ACTIVE → CONSUMED (supersession). Terminal: CONSUMED.

---

# Concept 9 — Internal Liquidity

- **Definition:** **Internal Liquidity** consists of BSL/SSL levels whose source swings lie **strictly inside** the current Dealing Range (strictly below the range-bounding swing high and strictly above the range-bounding swing low). (R-3.)
- **Purpose:** Identify intra-range liquidity targets (minor reaction points) distinct from the major range-bounding targets.
- **Relationship with previous documents:** Uses the DOC00 Dealing Range (Premium/Discount). No new SMC rule.
- **Inputs:** Active levels; the Dealing Range bounds (DOC02A).
- **Outputs:** The Internal classification tag on qualifying levels.
- **Dependencies:** DOC02A (range bounds, swings).
- **Deterministic Rules:**
  1. A BSL is Internal iff its source swing high price is **strictly less than** the range-bounding swing high price.
  2. An SSL is Internal iff its source swing low price is **strictly greater than** the range-bounding swing low price.
  3. Classification is recomputed when the range or levels change (closed-bar events).
- **Validation Rules:** Range bounds must be confirmed swings; classification is consistent with strict inequalities.
- **Confirmation Rules:** Derived; no separate confirmation.
- **Invalid Conditions:** Range undefined → no Internal classification possible; all levels default External.
- **Failure Conditions:** Range bounds missing → classify all External (safe default).
- **Edge Cases:** A swing exactly at a bound → not Internal (it is the bound → External).
- **False Detection Cases:** Stale range snapshot — prevented by frozen per-bar context.
- **Market Noise Considerations:** Many internal levels in wide ranges; bounded by retention.
- **Automation Challenges:** Keeping classification consistent with level/range changes.
- **Recommended Deterministic Implementation:** Tag each level Internal/External during the recomputation pass using the strict inequalities above.
- **Computational Complexity:** O(L) per pass.
- **Memory Requirement:** One tag per level.
- **Update Frequency:** On range or level changes (closed H1 bars).
- **Lifecycle:** Classification follows the level's lifecycle; a level's Internal/External tag may change if the range changes while the level is ACTIVE.

---

# Concept 10 — External Liquidity

- **Definition:** **External Liquidity** consists of BSL/SSL levels whose source swings are **at or beyond** the current Dealing Range bounds — specifically, the range-bounding swing high (the BSL that caps the range) and the range-bounding swing low (the SSL that floors the range). Also the default classification when no range is established. (R-3.)
- **Purpose:** Identify the major structural liquidity targets (the most significant stops above/below the current leg).
- **Relationship with previous documents:** Uses the DOC00 Dealing Range. No new SMC rule.
- **Inputs:** Active levels; the Dealing Range bounds.
- **Outputs:** The External classification tag on qualifying levels.
- **Dependencies:** DOC02A (range bounds, swings).
- **Deterministic Rules:**
  1. A BSL is External iff its source swing high price is **equal to** the range-bounding swing high price (i.e., it is the range high), **or** if no range is established (default).
  2. An SSL is External iff its source swing low price is **equal to** the range-bounding swing low price (i.e., it is the range low), **or** if no range is established (default).
  3. (Levels strictly beyond the current range — e.g., from an earlier, wider leg — are also External; they are outside the current range bounds.)
- **Validation Rules:** Consistent with Internal's strict-inequality mirror.
- **Confirmation Rules:** Derived.
- **Invalid Conditions:** None (External is always a valid classification, including the default).
- **Failure Conditions:** None.
- **Edge Cases:** Range undefined → all External (correct default).
- **False Detection Cases:** Stale snapshot — prevented by frozen context.
- **Market Noise Considerations:** External levels are the most significant and fewest; low noise.
- **Automation Challenges:** None beyond Internal's mirror.
- **Recommended Deterministic Implementation:** External = NOT Internal (per the strict definitions), plus the no-range default.
- **Computational Complexity:** O(L) per pass.
- **Memory Requirement:** One tag per level.
- **Update Frequency:** On range or level changes.
- **Lifecycle:** Follows level lifecycle; tag may change with the range.

---

# Buy-side Liquidity (BSL) — Detailed

### Definition
A BSL is a liquidity level located **above** price, at the high price of a confirmed Swing High (DOC02A) or at the pool price of an EQH. Represents resting buy-side interest (stop orders above highs). (DOC00 §10.)

### Detection Rules
1. When a Swing High is confirmed (DOC02A), a BSL level is created at that swing's high price.
2. When an EQH pool forms (see EQH section), a single BSL level is created at the pool price (the higher high); the individual constituent BSLs are superseded/retired (consumed by supersession) to avoid duplicate levels at near-equal prices.
3. A BSL is tagged with its source (single swing or EQH pool) and its Internal/External classification.
4. BSLs are added only on confirmed-swing events.

### Validation Rules
- BSL price = source swing high (or EQH pool price), exactly.
- Source swing is confirmed (confirmation time valid).
- BSL is above the price at the time of its active-target membership (a BSL is, by definition, an above-price target; if price rises above a BSL without a sweep, that BSL is superseded/consumed).

### Equal High relationship
- An EQH pool produces a single BSL at the higher high (DOC00 §11). The individual swing-high BSLs that compose the EQH are retired (consumed) so that one representative BSL remains. This prevents two near-equal BSL levels (R-1).
- A BSL not part of any EQH remains a standalone level.

### Bullish Structure relationship
- In a bullish structure (DOC02A: HH+HL), the most significant BSL is typically the range-bounding swing high (External BSL) — the next upward target. Internal BSLs (minor HHs within the range) are secondary.
- The Liquidity Engine does **not** decide bias; it only classifies and exposes levels. How bullish structure uses BSL is an Entry/decision concern (out of scope).

### Bearish Structure relationship
- In a bearish structure (LH+LL), BSLs above price are profit-target / stop-loss liquidity for shorts (DOC00 context). The engine records them as targets; it does not act on them.

### Failure Cases
- Source swing later found inconsistent → BSL moved to INVALID.
- BSL price not above current price at recomputation and not swept → superseded/consumed.

### Edge Cases
- Two BSLs within ELT that were not grouped as EQH (e.g., non-adjacent swings) → both remain standalone; EQH grouping applies only to adjacent confirmed swing highs (see EQH).
- A BSL exactly at price → boundary; treated as above-or-equal; if price has reached it without a sweep close-back-inside, it is evaluated for sweep on the relevant candle.

### Automation considerations
- BSL creation is a pure function of confirmed swings; deterministic and non-repainting.
- Active-target selection (nearest BSL above price) is O(L) and recomputed only on closed-bar swing events.

---

# Sell-side Liquidity (SSL) — Detailed

### Definition
An SSL is a liquidity level located **below** price, at the low price of a confirmed Swing Low (DOC02A) or at the pool price of an EQL. Represents resting sell-side interest (stop orders below lows). (DOC00 §10.)

### Detection Rules
1. When a Swing Low is confirmed, an SSL level is created at that swing's low price.
2. When an EQL pool forms, a single SSL level is created at the pool price (the lower low); constituent SSLs are consumed by supersession.
3. SSL is tagged with source and Internal/External classification.
4. SSLs are added only on confirmed-swing events.

### Validation Rules
- SSL price = source swing low (or EQL pool price), exactly.
- Source swing confirmed.
- SSL is below the price at the time of active-target membership.

### Equal Low relationship
- An EQL pool produces a single SSL at the lower low (DOC00 §12). Constituent swing-low SSLs are retired. (R-1.)

### Bullish Structure relationship
- In a bullish structure, SSLs below price are stop-loss/profit liquidity for longs. The engine records them; it does not act.

### Bearish Structure relationship
- In a bearish structure, the most significant SSL is typically the range-bounding swing low (External SSL) — the next downward target. Internal SSLs are secondary.

### Failure Cases
- Source swing inconsistent → INVALID.
- SSL not below current price and not swept → superseded/consumed.

### Edge Cases
- Two SSLs within ELT, non-adjacent → both standalone.
- SSL exactly at price → boundary handling as per sweep evaluation.

### Automation considerations
- Mirror of BSL; deterministic, non-repainting, O(L) active-target selection.

---

# Equal High / Equal Low — Detailed

### Detection Method
- **EQH:** After a new Swing High is confirmed (DOC02A), compare its high price to the **immediately preceding confirmed Swing High's** high price. If `abs(newHigh − prevHigh) ≤ ELT`, the two form an EQH pool. (DOC00 §11.)
- **EQL:** After a new Swing Low is confirmed, compare its low to the immediately preceding confirmed Swing Low's low. If `abs(newLow − prevLow) ≤ ELT`, the two form an EQL pool. (DOC00 §12.)
- Comparison is always between **consecutive confirmed swings of the same type** (adjacent in that type's sequence).

### Tolerance Rules
- ELT = **20 points** (DOC00 constant), expressed in the symbol's `_Point`.
- Comparison is **inclusive** (`≤ ELT`). A difference of exactly ELT qualifies as equal. (R-5.)

### Price Precision
- All comparisons use the symbol's native price precision (XAUUSD, typically 2–3 decimals on Exness). No rounding is applied; the raw swing prices are compared.

### Minimum Distance
- The minimum distance for "equal" is 0 (identical prices qualify). There is no lower bound excluding zero.

### Maximum Distance
- The maximum distance for "equal" is **ELT (20 points)**. Any difference strictly greater than ELT does **not** form an EQH/EQL.

### Lifetime
- An EQH/EQL pool exists from the confirmation of its second (forming) member until it is consumed (swept or superseded). Its pool-level BSL/SSL follows the standard level lifecycle.

### Replacement Rules
- When a third consecutive swing qualifies as equal to the pool (within ELT of the pool price), it is **added to the pool**; the pool price is updated to the highest (EQH) / lowest (EQL) of all members. (DOC00 §11 edge case: "three near-equal highs; the group is treated as one EQH liquidity level at the highest of the group.")
- The pool's representative BSL/SSL level price is updated accordingly. Former constituent levels remain consumed.

### Invalidation Rules
- A pool is invalidated (consumed) when its representative level is swept or superseded (standard level lifecycle).
- A pool is **not** invalidated merely because a later, non-equal swing forms; the pool simply stops growing.

### Multiple Equal High handling
- Only **adjacent** confirmed swing highs can join a pool. Non-adjacent highs (separated by a non-equal high) form separate pools or remain standalone.
- Multiple distinct EQH pools may coexist (e.g., at different price bands); each produces its own BSL level.

### Multiple Equal Low handling
- Mirror of Multiple Equal High handling, for EQL/SSL.

### Noise Filtering
- EQH/EQL uses no magnitude/volume filter — only the fixed ELT. "Approximately equal" is precisely `≤ ELT`. Any subjective "significance" filter is excluded (consistent with DOC00's deterministic philosophy).

---

# Liquidity Sweep — Detailed

### Definition
A **Liquidity Sweep** occurs when a candle's **wick** exceeds a BSL (by going above it) or an SSL (by going below it) by **more than ELT** points, but the candle **closes back inside** the level — i.e., the close is **not** a confirming BOS/CHoCH body close beyond the level. Confirmed only on the **close** of the sweeping candle. (DOC00 §13.)

### Required Conditions
1. The candle is **closed** (historical H1 bar).
2. There is an **ACTIVE** BSL above price (for a bullish-direction sweep of buy-side liquidity) or an **ACTIVE** SSL below price (for a bearish-direction sweep of sell-side liquidity).
3. **BSL sweep:** the candle's **high** exceeds the BSL price by **strictly more than ELT**: `high > BSL_price + ELT`.
4. **SSL sweep:** the candle's **low** exceeds the SSL price by **strictly more than ELT** (on the downside): `low < SSL_price − ELT`.
5. **Close-back-inside:**
   - BSL sweep: `close ≤ BSL_price` (the close did not close above the BSL → not a bullish BOS/CHoCH body close beyond).
   - SSL sweep: `close ≥ SSL_price` (the close did not close below the SSL → not a bearish BOS/CHoCH body close beyond).

### Closed Candle Requirements
- Sweeps are evaluated **only** on closed H1 candles. The forming candle is never evaluated. (DOC00 §13; enforced via Market Data Access chokepoint, DOC01.)

### Body Close Requirements
- The **body close** (`close` price) is used **only** for the close-back-inside test (condition 5). The **wick** (high/low) is used for the beyond-level test (conditions 3/4). This is the precise operational meaning of DOC00 §13's "wick exceeds … but closes back inside." (R-5.)
- A candle whose **body close** is beyond the level (close > BSL for a BSL; close < SSL for an SSL) is **not** a sweep — it is a BOS/CHoCH structure event (DOC02B/DOC02C). The Liquidity Engine does **not** classify it as a sweep; it leaves structure classification to DOC02B/DOC02C.

### Sweep Confirmation
- A sweep is confirmed **at the close** of the sweeping candle. At that instant, the swept level transitions ACTIVE → SWEPT → CONSUMED (retired). (DOC00 §13: "the swept level is retired.")

### False Sweep Detection
- A wick beyond the level by **≤ ELT** is **not** a sweep (threshold is strict `> ELT`). (R-5.)
- A wick beyond by `> ELT` but with a body close beyond the level is **not** a sweep (it is a structure event).
- A wick beyond by `> ELT` on a **forming** candle that later retracts is **not** a sweep (not evaluated until close; no repaint).
- Acting on a still-forming wick is the primary false-sweep source; eliminated by closed-candle evaluation.

### Valid Sweep
- A sweep is valid iff all five Required Conditions hold at the closed candle. It produces one immutable sweep record and retires the swept level.

### Invalid Sweep
- Any candidate failing one or more conditions is **not** recorded. No "created-then-invalidated" sweep records exist.

### Bullish Sweep
- A **Bullish Sweep** (sweep of sell-side liquidity) occurs when an ACTIVE SSL is swept: `low < SSL_price − ELT` AND `close ≥ SSL_price`. It signals sell-side liquidity was taken (stops below grabbed) and a reversal upward is a context. The swept SSL is retired. (Direction naming follows the implied reversal direction, consistent with DOC00 §13 "reversal is probable.")

### Bearish Sweep
- A **Bearish Sweep** (sweep of buy-side liquidity) occurs when an ACTIVE BSL is swept: `high > BSL_price + ELT` AND `close ≤ BSL_price`. It signals buy-side liquidity was taken (stops above grabbed) and a reversal downward is a context. The swept BSL is retired.

### Gap Handling
- **Gap through the level on open and the wick/close satisfy the conditions:** a candle that gaps beyond a level and closes back inside, with its extreme (high/low) beyond by `> ELT`, is a valid sweep. The candle's open is irrelevant; only high/low (wick) and close are tested.
- **Gap beyond and closes beyond:** not a sweep (body close beyond → structure event).
- **Missing candle (history gap) containing the sweep:** no sweep recorded for the missing candle; the level remains ACTIVE and is evaluated on subsequent clean closed candles. (If a later closed candle re-tests the level, it is evaluated normally.)

### Multiple Sweep Handling
- One candle may sweep **multiple levels** (DOC00 §13 edge case, R-6): e.g., a single candle's high exceeds two nearby BSLs by `> ELT` each, closing back inside both. Each swept level produces its **own** sweep record and transitions independently to CONSUMED. Multiple sweep records may share the same sweeping candle.
- A candle cannot sweep the same level twice (a level is swept at most once; after CONSUMED it is no longer ACTIVE).

### Lifecycle
- Sweep event lifecycle: detected on closed candle → confirmed at close → immutable record created → swept level ACTIVE → SWEPT → CONSUMED.
- The sweep record itself is immutable and permanent (subject only to retention pruning of ancient records).

---

# Liquidity State — Deterministic State Machine

Each liquidity level (BSL or SSL) has exactly one state at any time. The state machine realises DOC00's add/remove/retire semantics deterministically (R-4). State is persisted conceptually per level; transitions occur only on closed-bar events.

### States

#### UNKNOWN
- **Purpose:** No confirmed swing establishes this level yet (pre-existence / not yet created).
- **Entry Conditions:** N/A — a level does not exist in UNKNOWN; UNKNOWN is the conceptual "no level" state used before a level is created.
- **Exit Conditions:** A confirmed swing (DOC02A) creates the level → BUILDING or ACTIVE.
- **Allowed Transitions:** → BUILDING (EQH/EQL candidate awaiting partner) or → ACTIVE (standalone swing level).
- **Forbidden Transitions:** → SWEPT/CONSUMED/INVALID (cannot sweep/consume a non-existent level).
- **Failure Conditions:** N/A.
- **Recovery Strategy:** N/A.

#### BUILDING
- **Purpose:** An EQH/EQL pool candidate exists — the first swing is confirmed, awaiting a potential equal (within ELT) partner. Applies only to EQH/EQL pool formation, not to standalone levels.
- **Entry Conditions:** First swing of a potential EQH/EQL pair confirmed; no partner yet.
- **Exit Conditions:** Second swing confirmed within ELT → pool forms → ACTIVE; or second swing confirmed outside ELT → candidate dissolved (no pool; first swing becomes a standalone ACTIVE level).
- **Allowed Transitions:** → ACTIVE (pool formed, or dissolved to standalone).
- **Forbidden Transitions:** → SWEPT/CONSUMED (a BUILDING pool is not yet an active sweep target; if price reaches it, it is handled when it becomes ACTIVE).
- **Failure Conditions:** First swing invalidated → candidate dissolved.
- **Recovery Strategy:** Dissolve to standalone or remove; deterministic from swing data.

#### ACTIVE
- **Purpose:** The level is a confirmed, live liquidity target (above price for BSL, below for SSL), eligible for sweep detection and active-target selection.
- **Entry Conditions:** From UNKNOWN (standalone swing confirmed) or BUILDING (EQH/EQL pool formed).
- **Exit Conditions:** Swept (→ SWEPT) or superseded (→ CONSUMED).
- **Allowed Transitions:** → SWEPT, → CONSUMED, → INVALID (defensive).
- **Forbidden Transitions:** → UNKNOWN, → BUILDING.
- **Failure Conditions:** Source swing invalidated → → INVALID.
- **Recovery Strategy:** If the underlying data is corrected and the swing is valid, → ACTIVE; else remain INVALID.

#### SWEPT
- **Purpose:** The level has been hit by a qualifying sweep (wick beyond `> ELT`, close back inside). Records the "taking" event.
- **Entry Conditions:** From ACTIVE, on a confirmed sweep.
- **Exit Conditions:** Immediately → CONSUMED (retirement), same bar close.
- **Allowed Transitions:** → CONSUMED.
- **Forbidden Transitions:** → ACTIVE, → BUILDING, → UNKNOWN (a swept level never becomes active again).
- **Failure Conditions:** Sweep record later found invalid → defensive review; if truly invalid, restore → ACTIVE (rare, defensive only).
- **Recovery Strategy:** Sweep records are immutable and validated at creation; recovery is essentially never needed. If a corruption is detected, rebuild from immutable histories (as in DOC02A INVALID recovery).

#### CONSUMED
- **Purpose:** The level is retired and archived — no longer an active target. Terminal state. Realises DOC00's "the swept level is retired" and supersession.
- **Entry Conditions:** From SWEPT (post-sweep) or directly from ACTIVE (supersession).
- **Exit Conditions:** None (terminal within the active set); subject only to retention pruning (archival/removal of oldest records).
- **Allowed Transitions:** → (archived/removed by retention pruning).
- **Forbidden Transitions:** → ACTIVE, → SWEPT, → BUILDING, → UNKNOWN (consumed levels never return).
- **Failure Conditions:** None.
- **Recovery Strategy:** If a level was incorrectly consumed (e.g., supersession due to a stale snapshot), the rebuild from immutable histories will re-derive the correct state. Under normal closed-bar discipline this does not occur.

#### INVALID
- **Purpose:** Defensive state for a level whose records are internally inconsistent (e.g., source swing corrupted, non-monotonic state history).
- **Entry Conditions:** Detection of an internal inconsistency.
- **Exit Conditions:** Rebuild from immutable histories yields a consistent state.
- **Allowed Transitions:** → recomputed state (ACTIVE/SWEPT/CONSUMED) after rebuild.
- **Forbidden Transitions:** None (it is a recovery entry point).
- **Failure Conditions:** Underlying data uncorrectable → remain INVALID; do not expose the level as a target.
- **Recovery Strategy:** Rebuild the level and its state history from the immutable confirmed-swing and sweep records; re-derive classification and state deterministically.

### State Machine Guarantees
- A level is sweepable **only** in ACTIVE.
- A consumed/swept level **never** returns to ACTIVE (no resurrection).
- Transitions occur only on closed-bar events (sweep confirmation or confirmed-swing recomputation).
- State history per level is monotonic and append-only, enabling deterministic rebuild.

---

# Dependencies (consumer only)

The Liquidity Engine consumes **only** the following, read-only:

| Consumed from | Used for |
|---|---|
| DOC02A: Confirmed Swing High (price, time) | BSL source; EQH detection |
| DOC02A: Confirmed Swing Low (price, time) | SSL source; EQL detection |
| DOC02A: HH, HL, LH, LL labels | Structure context (classification reasoning) |
| DOC02A: Structure State (BULLISH/BEARISH/UNKNOWN/INITIAL) | Dealing Range availability; context |
| DOC02A: Dealing Range bounds | Internal/External classification |
| DOC02B: BOS Events | Context (a body-close beyond a level is a BOS, not a sweep — boundary disambiguation) |
| DOC02C: CHoCH Events | Context (a body-close beyond against direction is a CHoCH, not a sweep) |
| DOC02C: Prevailing Direction | Context (not used to gate liquidity; informational) |
| DOC01: Market Data Access | Closed H1 candle OHLC (for sweep wick/close tests) |

The Liquidity Engine **must not**:
- Create, modify, or delete any swing, HH/HL/LH/LL label, or Structure State (DOC02A).
- Create, modify, or delete any BOS record (DOC02B).
- Create, modify, or delete any CHoCH record or the Prevailing Direction (DOC02C).
- Create or modify Order Block, Fair Value Gap, Entry, or Risk data.
- Read forming bars or any timeframe other than H1 for liquidity purposes.

It is a **consumer only** with respect to swing/structure/BOS/CHoCH data, and the **sole writer** of the *Liquidity* section (levels, EQH/EQL pools, sweeps, consumption, Internal/External tags).

### Boundary with BOS/CHoCH (disambiguation)
- A candle's **body close** beyond a swing level is a **structure event** (BOS/DOC02B or CHoCH/DOC02C), **not** a sweep. The Liquidity Engine detects this case (close beyond the level) and **does not** classify it as a sweep; the level is not retired by the Liquidity Engine on a body-close beyond. Whether such a level is subsequently superseded is handled by the active-target recomputation.
- A candle's **wick** beyond by `> ELT` with **close back inside** is a **sweep** (this engine). This is the precise DOC00 §13 disambiguation.

---

# Design Constraints (future compatibility)

The Liquidity Engine is designed so future modules consume its output **without modifying it**:

- **Order Block Engine** (future) may read BSL/SSL levels and sweep events (e.g., a sweep may contextually qualify an OB). It must not modify liquidity records.
- **Fair Value Gap Engine** (future) is independent of liquidity but may co-reference timestamps; it must not modify liquidity records.
- **Trade Decision Engine** (future) reads the active target set, sweep history, and Internal/External classification; it must not modify liquidity records.

To preserve this:
1. All liquidity outputs are **immutable** except for lifecycle state transitions owned solely by this engine.
2. The *Liquidity* section of the Structural Context is written **only** by the Liquidity Engine.
3. The engine exposes a **read-only view** to consumers (levels, pools, sweeps, states, classifications).
4. The engine remains **independent**: it depends only on DOC02A/DOC02B/DOC02C outputs and closed H1 candles — never on OB/FVG/Entry/Risk.

---

# Cross-Document Consistency

| Concern | How DOC02D respects it |
|---|---|
| DOC00 §10 Liquidity | Reproduced verbatim: labelled price levels above/below confirmed swings; nearest BSL above / SSL below as active targets; recomputed only on confirmed swings. |
| DOC00 §11 EQH | `≤ ELT`, pool at higher high; adjacent swings; three-or-more grouped at the highest. |
| DOC00 §12 EQL | `≤ ELT`, pool at lower low; mirror of EQH. |
| DOC00 §13 Sweep | Wick beyond `> ELT`, close back inside, confirmed on close; swept level retired; multiple levels per candle allowed. |
| DOC00 ELT = 20 pts | Used unchanged for both equality and sweep threshold (different comparisons, R-5). |
| PATCH_001 timeframes | Liquidity on H1 only. |
| DOC01 module ownership | Liquidity Engine is sole writer of *Liquidity* section; closed-bar discipline via Market Data Access; immutable records; frozen per-bar snapshot consumed. |
| DOC02A swing primacy | DOC02A remains sole owner of swings/structure/range. Liquidity consumes read-only and never mutates them. |
| DOC02B/DOC02C boundary | Body-close beyond = structure event (BOS/CHoCH), not a sweep; wick-beyond-close-inside = sweep. Disambiguation explicit. |
| Deterministic philosophy | No magnitude/volume/significance filters; only fixed ELT and strict/closed-bar rules. |

---

# Self Review Result

Before finalising, the document was checked against the required checklist. Findings and resolutions:

- **Consistency with DOC00:** All liquidity definitions (§10–§13) reproduced with operational detail; ELT = 20 pts unchanged; sweep threshold strict `> ELT`; EQH/EQL `≤ ELT`; active-target rule preserved. No contradiction. *(Pass)*
- **Consistency with DOC01:** Liquidity Engine is the sole writer of the *Liquidity* section; reads closed bars via Market Data Access; emits immutable records; consumes frozen per-bar snapshot. *(Pass)*
- **Consistency with DOC02A:** Consumes swings/labels/Structure State/Dealing Range read-only; never mutates them. Internal/External classification uses DOC02A's Dealing Range. *(Pass)*
- **Consistency with DOC02B:** Body-close beyond a level is a BOS (not a sweep); disambiguation explicit; BOS History consumed read-only. *(Pass)*
- **Consistency with DOC02C:** Body-close beyond against direction is a CHoCH (not a sweep); CHoCH/Prevailing Direction consumed read-only. *(Pass)*
- **Logical contradictions:** None. BSL/SSL are mirrors; EQH/EQL are mirrors; sweep conditions are symmetric; state machine is monotonic (no resurrection of consumed levels); consumption via sweep vs supersession is disjoint. *(Pass)*
- **Undefined terminology:** Liquidity, Liquidity Pool, BSL, SSL, EQH, EQL, Liquidity Sweep, Liquidity Consumption, Internal/External Liquidity, Dealing Range (referenced from DOC00), active-target set, supersession, retention pruning — all defined. *(Pass)*
- **Subjective language:** Removed/avoided. No "significant," "strong," "likely" (except where quoting DOC00's "likely to be swept" purpose language), "clear." All rules are fixed-threshold comparisons. *(Pass)*
- **Automation limitations:** None blocking. All inputs finite/typed; O(1)/O(L) complexity; closed-bar discipline enforced at the chokepoint. *(Pass)*
- **Repaint possibility:** Eliminated. Levels derived only from confirmed swings; sweeps confirmed only on closed candles; states monotonic; active-target set recomputed only on closed-bar events. *(Pass)*
- **Look-ahead bias:** Eliminated. Only confirmed swings (DOC02A) and closed candles used; no forming-bar data; no future data. *(Pass)*
- **Future compatibility:** Output is read-only to future consumers (OB/FVG/Trade Decision); immutability and sole-writer rules preserve independence. *(Pass)*

**Scope boundaries respected:** Order Block, Fair Value Gap, Mitigation, Entry Confirmation, Risk Management, and Position Management are **not** defined or implemented. The new constructs (Pool, Consumption, Internal/External, State machine) are operational layers over DOC00 concepts, reported as R-1 through R-4, and introduce no SMC redefinition.

**Outcome:** No blocking issues. DOC02D is internally consistent, deterministic, measurable, programmable, non-repainting, independent, and fully conforms to DOC00, PATCH_001, DOC01, DOC02A, DOC02B, and DOC02C.

---

# Final Notes

1. **Liquidity only.** This document specifies the Liquidity Engine and nothing else. No OB, FVG, Mitigation, Entry, Risk, or Position logic.
2. **Consumer discipline.** The Liquidity Engine consumes DOC02A/DOC02B/DOC02C outputs read-only and never mutates them. It is the sole writer of the *Liquidity* section.
3. **DOC00 fidelity.** All DOC00 §10–§13 definitions and the ELT = 20 pts constant are preserved exactly. New constructs (Pool, Consumption, Internal/External, State machine) are operational extensions, reported and consistent.
4. **Sweep vs structure disambiguation.** Wick-beyond-`> ELT`-with-close-back-inside = sweep (this engine). Body-close-beyond = BOS/CHoCH (DOC02B/DOC02C). This boundary is explicit and mutually exclusive.
5. **Non-repainting by construction.** Confirmed-swing-derived levels + closed-candle sweep confirmation + monotonic state machine = identical data ⇒ identical liquidity output.
6. **Downstream consumers** (OB, FVG, Trade Decision, future docs) may read the *Liquidity* section read-only; they must not redefine liquidity concepts or mutate liquidity records.

This document is now the official specification for the Liquidity Engine.
