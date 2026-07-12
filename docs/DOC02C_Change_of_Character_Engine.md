# DOC02C — Change of Character (CHoCH) Engine
## Official Specification for CHoCH Detection (H1)

> **Document status:** AUTHORITATIVE — Official specification for the **Change of Character (CHoCH) Engine only**.
> **Phase:** Module Specification (Phase 2, Part C).
> **Scope of this document:** Change of Character (CHoCH) — definition, detection, confirmation, validation, bullish/bearish mechanics, the CHoCH event lifecycle, and the **Prevailing Direction** used to classify reversals.
> **Explicitly out of scope (future documents):** Liquidity, Order Block, Fair Value Gap, Entry Logic, Risk Management. These are **not** defined, behaviourally referenced, or implemented here. Where a topic implicitly borders on BOS (a break *in* the prevailing direction), DOC02C defers to DOC02B and does not redefine BOS.
> **Terminology lock:** This project uses **CHoCH** exclusively (DOC00 §9). "MSS" is a non-preferred synonym and must not appear as a defined term or code symbol.
> **Relationship to prior documents:**
> - Implements **DOC00_Strategy_Validation.md §9 (Change of Character)** without modification to its definition or constants.
> - Conforms to **DOC00_PATCH_001.md**: CHoCH is detected on the **Market Structure Timeframe (H1)**. H4 (Primary Trend Timeframe) permits swing-sequence classification only — **no CHoCH on H4**.
> - Realises the **Market Structure Engine** responsibilities for CHoCH within **DOC01_System_Architecture.md** (Layer 2), writing CHoCH events into the *Structure* section of the Structural Context.
> - Consumes **only** the outputs of **DOC02A_MarketStructure_Foundation.md** (Confirmed Swing High, Confirmed Swing Low, HH, HL, LH, LL, Structure State) and **DOC02B_Break_of_Structure_Engine.md** (BOS History). It creates or modifies **none** of those records. It is a consumer only, and the sole writer of CHoCH records.
> **Priority rule:** If anything here appears to conflict with DOC00, PATCH_001, DOC01, DOC02A, or DOC02B, those documents prevail. DOC02C governs only the CHoCH Engine details.

---

# Reported Items (reported, not changed)

Per the standing instruction to *report* rather than silently change, the following are flagged. Each is a clarification needed to keep DOC02C internally consistent with DOC00 and with DOC02A/DOC02B. **No approved document was modified.**

| # | Item | Status |
|---|---|---|
| R-1 | DOC00 §9 describes CHoCH as the event that "flips the structural bias," and the whipsaw edge case states "the bias simply flips each time a qualifying close occurs — there is no hysteresis." This requires a **fast-flipping directional character** that responds immediately to each CHoCH. **DOC02A's Structure State is a slow, pure swing-sequence label** (HH+HL → BULLISH, LH+LL → BEARISH) that only changes when new swings confirm SFS bars later. The two cannot be the same quantity: after a CHoCH, the swing-sequence label lags while DOC00's bias has already flipped. DOC02C therefore introduces a derived **Prevailing Direction** (defined in *State Transition Rules*) to realise DOC00's fast-flipping behaviour deterministically. The **DOC02A Structure State remains the sole owner of the swing-sequence label** and is consumed read-only; CHoCH never modifies it. | Reported — consistent with DOC00 + DOC02A R-1. |
| R-2 | DOC02B gates BOS detection on the **DOC02A Structure State** directly, and explicitly defers anti-structure breaks ("out of scope — CHoCH") to this document. For CHoCH and BOS to be **mutually consistent in whipsaw sequences** (DOC00 §9 edge case), both should ultimately classify against a single shared directional authority. DOC02C defines that authority — the **Prevailing Direction** — for **reversal (CHoCH)** classification only. **DOC02B's BOS gating is not changed here.** A future reconciliation/patch may align DOC02B's continuation classification to the same Prevailing Direction; until then, the only observable effect is a possible short lag in post-CHoCH continuation BOS detection (until the DOC02A swing-sequence label catches up). This is a timing refinement, not a contradictory signal. | Reported — flagged for future patch; DOC02B unchanged. |
| R-3 | DOC00 §9 refers to "the most recent confirmed Swing Low / Swing High" as the break reference. DOC02C pins this precisely: at the moment a candle closes, the reference is the **most recent confirmed swing of the opposing type** (Swing Low for a bearish CHoCH out of a bullish prevailing direction; Swing High for a bullish CHoCH out of a bearish prevailing direction), as published by DOC02A at that instant. Because swings confirm only on closed bars (DOC02A), the reference is always well-defined. | Reported — clarification, no contradiction. |
| R-4 | DOC00 §9 states "bias is switched … **only** by a CHoCH." Consistent with this, the Prevailing Direction is flipped **only** by confirmed CHoCH events; BOS events reinforce (do not flip) it. This is encoded in the *State Transition Rules*. | Reported — consistent with DOC00. |
| R-5 | CHoCH, like BOS, is defined by DOC00 relative to a prevailing directional structure. Therefore a CHoCH cannot occur when no directional character exists (Prevailing Direction = UNDEFINED). DOC02C encodes this gate explicitly. | Reported — consistent with DOC00 + DOC02A. |

---

# Conformance Summary

DOC02C introduces **no new SMC definition**. The CHoCH definition is DOC00 §9 stated with full operational detail. The constants and decisions in force:

| Constant / Decision | Value | Source |
|---|---|---|
| CHoCH confirmation method | **Body close only** — compare the candle `close` price (not high, not low, not wick) | DOC00 §9, Ambiguous Rule A2 |
| Comparison operator | **Strict** — bearish CHoCH: `close < swingLowPrice`; bullish CHoCH: `close > swingHighPrice` | DOC00 §9 |
| Event type | **Reversal** (against the Prevailing Direction) | DOC00 §9 |
| Direction authority | **Prevailing Direction** (seeded from DOC02A Structure State; flipped only by CHoCH) | DOC00 §9, R-1, R-4 |
| Detection timeframe | **H1** (Market Structure Timeframe) | PATCH_001, R-2 |
| Break reference | Most recent confirmed Swing Low (bearish CHoCH) / Swing High (bullish CHoCH) from DOC02A | DOC00 §9, R-3 |
| Closed-bar requirement | CHoCH evaluated only on **closed** H1 candles | DOC00 §9, DOC02A |
| Bias-flip authority | Prevailing Direction flips **only** on CHoCH | DOC00 §9, R-4 |
| Repaint | None — closed candle body is final; CHoCH records immutable | DOC00 §9 |

---

# CHoCH Engine — Full Specification

## Definition

A **Change of Character (CHoCH)** is a **reversal** structural event. It occurs when a **closed H1 candle's body close** breaches the **most recent confirmed swing of the opposing type** **against the Prevailing Direction**:

- When the Prevailing Direction is **BULLISH**, a **Bearish CHoCH** occurs when a closed H1 candle's `close` is **strictly less than** the most recent confirmed **Swing Low** price. This reverses the character to **BEARISH**.
- When the Prevailing Direction is **BEARISH**, a **Bullish CHoCH** occurs when a closed H1 candle's `close` is **strictly greater than** the most recent confirmed **Swing High** price. This reverses the character to **BULLISH**.

A wick beyond the level that does **not** close beyond it is **not** a CHoCH. (DOC00 §9, unchanged.) The Prevailing Direction is defined precisely in *State Transition Rules*.

## Purpose

To objectively record the **first confirmed sign of structural reversal**, by identifying the exact candle that closed against the prevailing direction beyond its most recent opposing swing, and to flip the Prevailing Direction on that event.

## Relationship with DOC00

This is DOC00 §9 reproduced with operational detail. No semantic change. The body-close-only decision (DOC00 Ambiguous Rule A2), the strict-inequality comparison, the "bias switched only by a CHoCH" rule (R-4), and the no-hysteresis whipsaw behaviour are all preserved exactly.

## Relationship with DOC01

Implemented inside the **Market Structure Engine** (DOC01 Layer 2). CHoCH events are written into the **Structure** section of the **Structural Context**. The CHoCH logic is the **sole writer** of CHoCH records and of the Prevailing Direction value used for reversal classification. It reads only from Market Data Access (closed H1 candles), from DOC02A swing/structure data, and from DOC02B BOS History. No other module writes CHoCH records; no other concern reads forming bars.

## Relationship with DOC02A

The CHoCH Engine is a **pure consumer** of DOC02A outputs:

| Consumed from DOC02A | Used for |
|---|---|
| Confirmed Swing High (price, time) | Bullish CHoCH break reference |
| Confirmed Swing Low (price, time) | Bearish CHoCH break reference |
| HH / HL / LH / LL labels | Context (structure reasoning) |
| Structure State (BULLISH / BEARISH / UNKNOWN / INITIAL) | **Seed** for the Prevailing Direction when no prior structural event exists |

The CHoCH Engine **must not** create, modify, relabel, or delete any swing, any HH/HL/LH/LL label, or the DOC02A Structure State. (Mandatory consumer-only constraint, R-1.)

## Relationship with DOC02B

The CHoCH Engine consumes DOC02B's **BOS History** (read-only) and is the structural counterpart of BOS:

| Aspect | BOS (DOC02B) | CHoCH (DOC02C) |
|---|---|---|
| Event type | Continuation | Reversal |
| Direction vs Prevailing | Same as Prevailing | Against Prevailing |
| Effect on Prevailing Direction | Reinforces (no flip) | **Flips** |
| Break reference | Most recent confirmed swing in the continuation direction | Most recent confirmed swing of the opposing type |
| Confirmation | Body close, strict, closed H1 | Body close, strict, closed H1 |

DOC02B explicitly deferred anti-structure breaks to this document. DOC02C defines them: a body close **against** the Prevailing Direction, beyond the opposing swing, is a CHoCH. Together, BOS and CHoCH partition all qualifying structural body-close breaks (continuation vs reversal). The cross-engine consistency point (R-2) is reported, not changed.

## Inputs

1. The **Prevailing Direction** (derived; defined in *State Transition Rules*), which itself is a pure function of: the DOC02A Structure State, the DOC02B BOS History, and this engine's own CHoCH History.
2. The **most recent confirmed Swing Low** (price + confirmation time) — for bearish CHoCH.
3. The **most recent confirmed Swing High** (price + confirmation time) — for bullish CHoCH.
4. The **newly closed H1 candle** under evaluation: `close`, open time, close time, and confirmation that it is a closed (historical) bar.
5. The **DOC02B BOS History** and **CHoCH History** — used to derive the Prevailing Direction (see *State Transition Rules*).

## Outputs

A **CHoCH event record** (only when a CHoCH is confirmed), containing:
- **Type:** Bullish CHoCH or Bearish CHoCH.
- **Reversal direction:** the new Prevailing Direction after the flip (BULLISH for a bullish CHoCH; BEARISH for a bearish CHoCH).
- **Breaking candle:** open time, close time, open price, close price.
- **Break reference:** the opposing swing record that was breached (type, price, original confirmation time).
- **Break price:** the reference swing's price.
- **Confirmation time:** the close time of the breaking candle.
- **Prevailing Direction before the event:** the direction that was reversed.
- **Status:** immutable `CONFIRMED`.

Additionally, the engine exposes the current **Prevailing Direction** value (derived, recomputed per closed bar) for consumers.

When no CHoCH occurs on a closed candle, **no** record is produced (and the Prevailing Direction is unchanged).

## Dependencies

- **Market Data Access** (DOC01): closed H1 candle data (the single closed-bar chokepoint).
- **DOC02A outputs** (read-only): confirmed swings + Structure State.
- **DOC02B outputs** (read-only): BOS History.
- **Utility** (DOC01): time/precision helpers.
- **Logger** (DOC01): event logging.

The CHoCH Engine has **no** dependency on Liquidity, Order Block, FVG, Entry, Risk, or Session logic. It depends on no detection engine other than reading DOC02A/DOC02B outputs.

## Deterministic Rules

1. **Closed-candle only.** CHoCH is evaluated exclusively on **closed** H1 candles. The forming candle is never evaluated.
2. **Body close only.** The test uses the candle `close` price only. High, low, open, and wicks are **not** used.
3. **Strict inequality.** Bearish CHoCH: `close < swingLowPrice`. Bullish CHoCH: `close > swingHighPrice`. Equality is **not** a break.
4. **Reversal only.** A CHoCH is emitted only when the break is **against** the Prevailing Direction. A break in the same direction is continuation (BOS territory, DOC02B) and is **not** a CHoCH.
5. **Directional gate.** No CHoCH is emitted when the Prevailing Direction is UNDEFINED (nothing to reverse) (R-5).
6. **Single reference.** The break reference is exactly one swing: the most recent confirmed swing of the opposing type at the instant the candle closes (R-3).
7. **One event per candle.** A single closed candle can produce **at most one** CHoCH event.
8. **Flip authority.** A confirmed CHoCH flips the Prevailing Direction. **Only** a CHoCH flips it (R-4).
9. **Immutability.** Once a CHoCH record is created it is never edited, relabelled, or invalidated by this engine.
10. **No mutation of consumed records.** The engine never creates or modifies DOC02A swings/labels/Structure State or DOC02B BOS records.

## Validation Rules

A CHoCH record is valid only if **all** of the following hold at creation:
- The breaking candle is confirmed closed (historical).
- The Prevailing Direction was directional (BULLISH or BEARISH) at that candle's close.
- The break is **against** that Prevailing Direction.
- The break reference is a confirmed swing from DOC02A (confirmation time ≤ breaking candle close time).
- The strict body-close inequality holds against the recorded break price.
- The breaking candle's close time is consistent with the recorded confirmation time.

Any record failing these is never created.

## Confirmation Rules

- A CHoCH is **confirmed at the close** of the breaking H1 candle. There is no second-stage confirmation, no minimum distance beyond the level, and no "wait N bars" rule.
- Confirmation is **instantaneous and final** at that close. The Prevailing Direction flips at that same instant.
- A CHoCH cannot be "un-confirmed" by later price action. A later reversal is a **separate, later CHoCH** event (the whipsaw case), not a retroactive invalidation (DOC00 §9: "no hysteresis").

## Failure Conditions

A CHoCH is **not** produced (and no record is created; the Prevailing Direction is unchanged) when:
- The candle is not closed (forming).
- The Prevailing Direction is UNDEFINED.
- The break is in the same direction as the Prevailing Direction (continuation — BOS territory).
- The close merely equals the reference (tie) — strict inequality fails.
- Only the wick exceeded the level but the close did not.
- No confirmed swing of the opposing type exists yet.
- Market Data Access reports the candle/bar as invalid or uncertifiable (closed-bar guard rejects it).

These are **silent non-events**, not errors. They produce no record and no error.

## Edge Cases

- **Gap beyond the opposing swing (valid CHoCH).** A candle that **opens** already beyond the reference and closes beyond it is a valid CHoCH — the body close is beyond the level. (Mirrors DOC00 §8 / DOC02B gap rule.)
- **Opens beyond, closes back inside (not a CHoCH).** A candle that opens beyond the reference but closes back on the pre-break side is **not** a CHoCH — the close is not beyond.
- **Wick beyond, close inside (not a CHoCH).** A wick spike beyond the level with a close back inside is explicitly not a CHoCH.
- **Exact close at the level (not a CHoCH).** Equality fails strict inequality.
- **Multiple opposing levels breached in one candle.** The candle closes beyond several historical opposing swings simultaneously. It produces **one** CHoCH event referencing the **most recent** confirmed swing of the opposing type. Breaching older swings is incidental.
- **CHoCH on the same bar a new swing confirms.** Swing confirmation (DOC02A) occurs SFS bars after the swing centre; CHoCH occurs on a closed candle's close. These are distinct events on distinct bars; no conflict.
- **Breaking candle later confirmed as a swing.** A breaking candle may itself become a confirmed swing SFS bars later (DOC02A). That later swing confirmation is a DOC02A event and does **not** retroactively change the CHoCH record. The CHoCH remains immutable.
- **Whipsaw (DOC00 §9).** A CHoCH immediately followed by a break back the other way: the Prevailing Direction simply flips on each qualifying CHoCH close. No hysteresis, no suppression. The sequence is fully reconstructable from the immutable CHoCH history.
- **History gap at the breaking candle.** If the closed-bar guard cannot certify the candle, no CHoCH is produced; evaluation resumes when clean closed history is available.

## False CHoCH Scenarios

- **Stop-run close then reversal.** A candle closes just beyond the opposing swing and the next bars reverse sharply. Per DOC00 §9, this is a **valid CHoCH** (the close was real); whether it leads to a sustained reversal is a separate question. DOC02C does **not** soften the CHoCH rule to filter these — false CHoCHs are handled downstream by zone/session/entry filters (future docs), not by the CHoCH Engine.
- **Low-liquidity wick-driven close.** A thin-market candle whose close barely exceeds/below the level. Still a valid CHoCH by the rule. Magnitude is irrelevant to CHoCH validity.
- **Premature CHoCH in a strong trend.** A single counter-trend close flips the Prevailing Direction even if the broader trend resumes immediately. This is the no-hysteresis behaviour DOC00 mandates; the resumption would be recorded as a subsequent CHoCH back.

## Closed Candle Requirements

- CHoCH evaluation occurs **only** on a candle whose H1 bar has fully closed (MT5 reports it as historical / non-forming).
- The breaking candle, the reference swing, the Prevailing Direction inputs, and the BOS History must all be evaluable from **closed** data only.
- Enforced via the Market Data Access chokepoint (DOC01), not by convention.

## Timeframe Requirements

- **Detection timeframe: H1 only** (Market Structure Timeframe, PATCH_001).
- The break reference swings are H1 confirmed swings (DOC02A on H1).
- **No CHoCH on H4** (Primary Trend Timeframe: bias-only; PATCH_001 forbids CHoCH there).
- **No CHoCH on M15** (Execution Timeframe: entry/management only; PATCH_001).
- H1 candle `close` and H1 swing prices share the same timeframe, so no cross-timeframe alignment ambiguity exists.

## State Transition Rules

This section defines the **Prevailing Direction** — the operational realisation of DOC00's "structural bias" for reversal classification (R-1). It is a **derived** value: a pure function of consumed inputs (DOC02A Structure State, DOC02B BOS History) and this engine's own output (CHoCH History). It is **not** a new SMC concept and **not** a modification of the DOC02A Structure State.

### Prevailing Direction — definition

The Prevailing Direction at any closed-bar evaluation instant is derived as follows:

1. Let the **structural event timeline** be the time-ordered union of all DOC02B BOS events and all CHoCH events, each tagged with its established direction:
   - A **Bullish BOS** establishes **BULLISH** (continuation).
   - A **Bearish BOS** establishes **BEARISH** (continuation).
   - A **Bullish CHoCH** establishes **BULLISH** (reversal flip).
   - A **Bearish CHoCH** establishes **BEARISH** (reversal flip).
2. **If at least one structural event exists:** the Prevailing Direction = the established direction of the **most recent** event in the timeline.
3. **If no structural event exists yet:** the Prevailing Direction is **seeded** from the DOC02A Structure State:
   - DOC02A = BULLISH → Prevailing = BULLISH.
   - DOC02A = BEARISH → Prevailing = BEARISH.
   - DOC02A = INITIAL or UNKNOWN → Prevailing = **UNDEFINED**.

This derivation is deterministic, uses only closed-bar data, and is reproducible: identical swing/structure/BOS/CHoCH history ⇒ identical Prevailing Direction.

### Why this satisfies DOC00

- "Bias switched only by a CHoCH" (R-4): BOS establishes the same direction (reinforces); only a CHoCH establishes the **opposite** direction (flip). Hence only a CHoCH changes the Prevailing Direction from one direction to the other.
- "Flips each time a qualifying close occurs — no hysteresis" (whipsaw): each CHoCH immediately becomes the most recent event, so the Prevailing Direction flips instantly and repeatedly. No suppression, no minimum interval.
- Seed from DOC02A Structure State honours the pre-event phase: before any BOS/CHoCH, the swing-sequence label provides the initial character.

### CHoCH detection decision table (per closed H1 candle)

| Prevailing Direction | Close vs most-recent Swing High | Close vs most-recent Swing Low | CHoCH output | New Prevailing Direction |
|---|---|---|---|---|
| BULLISH | (any) | `close < SwingLow` | **Bearish CHoCH** | BEARISH |
| BULLISH | `close > SwingHigh` | (any) | No CHoCH (continuation — BOS territory, DOC02B) | BULLISH (unchanged) |
| BEARISH | `close > SwingHigh` | (any) | **Bullish CHoCH** | BULLISH |
| BEARISH | (any) | `close < SwingLow` | No CHoCH (continuation — BOS territory, DOC02B) | BEARISH (unchanged) |
| UNDEFINED | (any) | (any) | No CHoCH (nothing to reverse) | UNDEFINED (unchanged) |

Note the symmetry with DOC02B's decision table: DOC02B emits BOS for continuation breaks; DOC02C emits CHoCH for reversal breaks. A given closed candle is, at most, a BOS or a CHoCH — never both, never ambiguous — **relative to the Prevailing Direction**. (See R-2 for the reported cross-engine consistency nuance with DOC02B's DOC02A-State-based gating.)

## Automation Challenges

- **Enforcing closed-bar discipline** so no path evaluates a forming candle — handled by the Market Data Access chokepoint (DOC01).
- **Snapshot consistency:** the Prevailing Direction, the most-recent opposing swing, and the BOS History used for the CHoCH test must be the values in effect at the breaking candle's close. The DOC01 "frozen Structural Context per bar" guarantees this — CHoCH reads the frozen snapshot for that bar.
- **Pure derivation of Prevailing Direction:** it must be a pure function of immutable histories, never stored in a way that can drift. Recompute (or append-only update) per closed bar.
- **Immutability of records** so later bars cannot rewrite a CHoCH — enforced by data structure, not convention.
- **Avoiding BOS/CHoCH conflation:** the engine must emit CHoCH only for reversal breaks and must never emit a continuation break as a CHoCH. The decision table encodes this.
- **Whipsaw correctness:** the no-hysteresis rule must be honoured exactly; the engine must not suppress rapid flips or deduplicate legitimate consecutive reversals.

## Recommended Deterministic Implementation

On each **closed H1 bar**, in the frozen-snapshot evaluation step of the Market Structure Engine (after DOC02A structure and DOC02B BOS have updated for that bar):

1. Derive the **Prevailing Direction** from the structural event timeline (BOS History + CHoCH History), seeded from the DOC02A Structure State if no event exists. If UNDEFINED, stop (no CHoCH).
2. If Prevailing = BULLISH: read the most recent confirmed Swing Low price. If `close < swingLowPrice` (strict), emit one immutable **Bearish CHoCH** record; the new Prevailing Direction = BEARISH.
3. If Prevailing = BEARISH: read the most recent confirmed Swing High price. If `close > swingHighPrice` (strict), emit one immutable **Bullish CHoCH** record; the new Prevailing Direction = BULLISH.
4. Record the breaking candle, the break reference, the break price, the confirmation time, the direction before the event, and the reversal direction. Mark the record `CONFIRMED` and immutable.
5. Do not, under any condition, evaluate the forming candle, use wicks/high/low, mutate DOC02A or DOC02B records, emit a continuation break as a CHoCH, or apply any hysteresis.

(Process description only — no algorithm, pseudo-code, or flowchart is specified.)

## Computational Complexity

- Per closed H1 bar: **O(1)** — derive Prevailing Direction from the most recent event (an append-only timeline; only the tail is inspected), one direction check, and one strict comparison against a single known swing price.
- Initialisation: **O(N)** over a bounded lookback of N H1 bars (replaying closed history to reconstruct the CHoCH event sequence and the Prevailing Direction), each bar O(1).
- Complexity analysis only; no algorithm specified.

## Memory Requirement

- One immutable record per confirmed CHoCH event.
- The structural event timeline is derived from the already-stored BOS History (DOC02B) plus this engine's CHoCH History; no separate full copy is required — only the most recent event's direction is needed per evaluation, plus bounded retention of CHoCH records.
- Bounded by retention pruning: keep the most recent M CHoCH records (a fixed constant); older records are archived/dropped from the oldest end. M must be sufficient for downstream consumers; the exact M is set in future documents. Within this engine, pruning is FIFO and never touches recent records.
- Constant per-bar working memory.

## Update Frequency

- Evaluated **once per closed H1 bar**, within the bar-scoped analysis pipeline (DOC01), after DOC02A and DOC02B have updated for that bar.
- **Never** on ticks. CHoCH is a structural, bar-close event.

---

# Bullish CHoCH — Detailed

A **Bullish CHoCH** is a reversal from a **BEARISH** Prevailing Direction to a **BULLISH** one.

### Required prevailing direction
- The Prevailing Direction must be **BEARISH** at the breaking candle's close (R-5). This is the "character" being changed.

### Required candle close
- A **closed** H1 candle whose **`close` price** is **strictly greater than** the break-reference swing high price.
- Body close only; wicks ignored; strict inequality (equality is not a break).

### Required break level
- The price of the **most recent confirmed Swing High** (the opposing type), as published by DOC02A at the candle close (R-3).

### Effect
- Emits one immutable Bullish CHoCH record; the Prevailing Direction flips to **BULLISH**.

### Invalid bullish CHoCH
A would-be bullish CHoCH is **not** created when any of these hold:
- Prevailing Direction is not BEARISH (UNDEFINED or BULLISH).
- The candle is not closed.
- `close ≤ swingHighPrice` (tie or below).
- Only the wick exceeded the level.
- The candle opened beyond but closed back inside (close not beyond).
- No confirmed swing high exists.

There are no "created-then-invalidated" bullish CHoCH records; invalid candidates are simply never created.

### Gap handling
- **Gap up beyond the swing high and closes beyond** → valid Bullish CHoCH.
- **Gap up beyond but closes back below the swing high** → not a Bullish CHoCH.
- A gap that skips the breaking candle → no CHoCH for the missing candle; the next clean closed candle is evaluated independently.

### Whipsaw handling
- After a Bullish CHoCH (Prevailing now BULLISH), a subsequent close below the most recent Swing Low is a **Bearish CHoCH** (another flip) — emitted normally, no suppression.
- A subsequent close above the most recent Swing High is continuation (BOS territory), not a Bullish CHoCH.

---

# Bearish CHoCH — Detailed

A **Bearish CHoCH** is a reversal from a **BULLISH** Prevailing Direction to a **BEARISH** one.

### Required prevailing direction
- The Prevailing Direction must be **BULLISH** at the breaking candle's close (R-5).

### Required candle close
- A **closed** H1 candle whose **`close` price** is **strictly less than** the break-reference swing low price.
- Body close only; wicks ignored; strict inequality.

### Required break level
- The price of the **most recent confirmed Swing Low** (the opposing type), as published by DOC02A at the candle close (R-3).

### Effect
- Emits one immutable Bearish CHoCH record; the Prevailing Direction flips to **BEARISH**.

### Invalid bearish CHoCH
A would-be bearish CHoCH is **not** created when any of these hold:
- Prevailing Direction is not BULLISH.
- The candle is not closed.
- `close ≥ swingLowPrice` (tie or above).
- Only the wick went below the level.
- The candle opened below but closed back above (close not beyond).
- No confirmed swing low exists.

### Gap handling
- **Gap down beyond the swing low and closes beyond** → valid Bearish CHoCH.
- **Gap down beyond but closes back above the swing low** → not a Bearish CHoCH.
- A gap that skips the breaking candle → no CHoCH for the missing candle.

### Whipsaw handling
- After a Bearish CHoCH (Prevailing now BEARISH), a subsequent close above the most recent Swing High is a **Bullish CHoCH** (another flip) — emitted normally.
- A subsequent close below the most recent Swing Low is continuation (BOS territory), not a Bearish CHoCH.

---

# Validation — CHoCH Lifecycle

### When CHoCH becomes valid
- A CHoCH becomes valid **instantly at the close** of the breaking H1 candle, provided the Prevailing Direction is directional and the strict body-close test holds against the opposing swing. There is no pending state and no second confirmation stage. The Prevailing Direction flips at the same instant.

### When CHoCH becomes invalid
- **Never.** A confirmed CHoCH is an immutable historical fact. Later price action (reversal, retest, a subsequent opposite CHoCH) does **not** invalidate it. The only "invalid CHoCH" is a candidate that never met the confirmation criteria — and such candidates are never created as records.

### When CHoCH expires
- A CHoCH has **no expiry** within this engine. It is a permanent historical record, subject only to **retention pruning** of the oldest records (fixed-capacity, FIFO eviction of the most ancient CHoCH events). Pruning removes a record from active memory; it does not "invalidate" the event. Because the Prevailing Direction is derived from the **most recent** event, pruning ancient events does not change the current Prevailing Direction as long as the most recent event is retained.

### Whether CHoCH can be replaced
- **No.** A CHoCH record, once created, is never overwritten or replaced. Each distinct breaking candle that satisfies the rules produces a **new, additional** CHoCH record.

### Whether CHoCH can overlap
- CHoCH records are distinct events, each tied to a specific breaking candle and a specific reference swing. At most one CHoCH is emitted per closed candle, so no two CHoCH events share a breaking candle. They may, in a whipsaw, reference the same opposing swing at different candle closes — each is still a separate, immutable event keyed by its breaking candle.

### Whether multiple CHoCH can exist simultaneously
- **Yes.** Multiple CHoCH records coexist as an ordered historical sequence (a series of reversals over time). This is the normal case in choppy or whipsawing markets. The engine maintains all of them (up to the retention cap). The Prevailing Direction always reflects the **most recent** one.

### Relationship to the Prevailing Direction over time
- The Prevailing Direction is the running output of the CHoCH/BOS event stream. Each CHoCH flips it; each BOS reinforces it. It is never stored as authoritative mutable state — it is always re-derivable from the immutable histories, guaranteeing reproducibility across restarts.

---

# Cross-Document Consistency

| Concern | How DOC02C respects it |
|---|---|
| DOC00 §9 CHoCH definition | Reproduced verbatim in semantics: reversal, body-close, strict, wick-not-counted, gap rules, "bias switched only by CHoCH," no-hysteresis whipsaw. No change. |
| DOC00 Ambiguous Rule A2 (body-close) | Enforced as the only confirmation method. |
| DOC00 Ambiguous Rule A1 (CHoCH vs MSS) | "CHoCH" used exclusively; "MSS" banned as a defined term. |
| PATCH_001 timeframes | CHoCH on H1 only; none on H4 or M15. |
| DOC01 module ownership | CHoCH records + Prevailing Direction written solely by the Market Structure Engine into the *Structure* section; closed-bar discipline via Market Data Access; immutable records; frozen per-bar snapshot consumed. |
| DOC02A swing/structure primacy | DOC02A remains the sole owner of swings, HH/HL/LH/LL, and the swing-sequence Structure State. CHoCH consumes them read-only and never modifies them. The Prevailing Direction is a separate, derived quantity, not a redefinition of the DOC02A Structure State. |
| DOC02A R-1 (structure vs bias) | Resolved here: the swing-sequence label (DOC02A) and the fast-flipping Prevailing Direction (DOC02C) are distinct; the live trading-bias reconciliation consumed by Entry is a future-document concern. |
| DOC02B deferral | DOC02B's deferred anti-structure breaks are defined here as CHoCH. BOS History is consumed read-only. DOC02B is not modified. |
| DOC02B/DOC02C symmetry | BOS = continuation (same direction); CHoCH = reversal (against direction). Both body-close, strict, closed-H1, immutable. Together they partition qualifying structural breaks relative to the Prevailing Direction. |

---

# Self Review Result

Before finalising, the document was checked against the required checklist. Findings and resolutions:

- **Logical contradictions:** None. Bullish and Bearish CHoCH are strict mirrors; the reversal-only rule and the directional gate are applied symmetrically; the Prevailing Direction derivation is internally consistent (BOS reinforces, CHoCH flips, seed from DOC02A when no event exists); immutability and "never invalid" are consistent (an event fixed at a closed bar cannot later change). *(Pass)*
- **Conflict with DOC00:** None. Definition, body-close decision, strict inequality, "bias switched only by CHoCH," and the no-hysteresis whipsaw behaviour all match DOC00 §9 and Ambiguous Rules A1/A2. *(Pass)*
- **Conflict with DOC01:** None. CHoCH is produced by the Market Structure Engine, written to the Structure section, reads only closed bars via Market Data Access, and emits immutable records — all per DOC01. *(Pass)*
- **Conflict with DOC02A:** None. CHoCH consumes DOC02A outputs read-only and never mutates them. The Prevailing Direction is a new **derived operational quantity**, explicitly **not** a redefinition of the DOC02A Structure State; the distinction is documented (R-1) and DOC02A's ownership of the swing-sequence label is preserved. *(Pass)*
- **Conflict with DOC02B:** None in definitions. CHoCH consumes DOC02B's BOS History read-only and defines the anti-structure breaks DOC02B deferred. The one cross-engine nuance — that DOC02B gates on the DOC02A Structure State while CHoCH classifies against the Prevailing Direction — is **reported** (R-2) as a future reconciliation/patch opportunity, not silently changed. No contradictory signal arises: continuation and reversal are mutually exclusive relative to the Prevailing Direction. *(Pass with reported item R-2)*
- **Repaint possibility:** Eliminated. CHoCH is published once at a closed bar and is immutable; failed candidates are never published; the Prevailing Direction is re-derived from immutable histories. *(Pass)*
- **Look-ahead bias:** Eliminated. Only closed candles and already-confirmed swings (confirmation time ≤ breaking candle close) and already-confirmed BOS events are used. No future data. *(Pass)*
- **Subjective wording:** Removed/avoided. No "significant," "strong," "clear," "usually," "likely." All rules are strict comparisons. The word "bias" is used only where DOC00 uses it and is operationally pinned to the Prevailing Direction. *(Pass)*
- **Undefined terminology:** CHoCH, reversal, Prevailing Direction, body close, break reference, breaking candle, break price, confirmation time, opposing swing, retention pruning, immutability, structural event timeline, seed — all defined. *(Pass)*
- **Missing edge cases:** Covered — gaps (both directions), opens-beyond/closes-inside, wick-only, exact tie, multiple-level breach, breaking candle later becoming a swing, CHoCH and swing confirmation on related bars, whipsaw (no hysteresis), history gaps, UNDEFINED prevailing direction. *(Pass)*
- **Automation problems:** Addressed — closed-bar chokepoint, frozen snapshot consistency, pure (append-only) derivation of Prevailing Direction, immutability by structure, refusal to emit continuation breaks as CHoCH (decision table), exact no-hysteresis whipsaw handling. *(Pass)*

**Scope boundaries respected:** Liquidity, Order Block, Fair Value Gap, Entry Logic, and Risk Management are **not** defined or implemented. BOS is **not** redefined; DOC02B remains authoritative for continuation breaks. The live trading-bias reconciliation consumed by Entry is deferred to a future document (R-1).

**Outcome:** No blocking issues. DOC02C is internally consistent, deterministic, measurable, programmable, non-repainting, independent, and fully conforms to DOC00, PATCH_001, DOC01, DOC02A, and DOC02B.

---

# Final Notes

1. **CHoCH only.** This document specifies the Change of Character Engine and nothing else. No Liquidity, OB, FVG, entry, or risk logic. BOS is not redefined (DOC02B authoritative).
2. **Consumer discipline.** The CHoCH Engine consumes DOC02A swing/structure data and DOC02B BOS History read-only and never mutates them. It is the sole writer of CHoCH records and the Prevailing Direction.
3. **Reversal only.** CHoCH records a reversal against the Prevailing Direction. Continuation breaks belong to DOC02B (BOS).
4. **Prevailing Direction is derived, not a redefinition.** It is the operational realisation of DOC00's fast-flipping "structural bias," seeded from the DOC02A Structure State and flipped only by CHoCH. It does not modify or replace the DOC02A swing-sequence label.
5. **Body-close, strict, closed-bar, immutable, no hysteresis.** These five properties jointly guarantee determinism, non-repainting, and exact DOC00 whipsaw behaviour.
6. **Reported cross-engine item (R-2).** For perfect BOS/CHoCH symmetry in whipsaw sequences, a future patch may align DOC02B's continuation classification to the same Prevailing Direction. This is flagged, not applied; DOC02B is unchanged.
7. **Downstream consumers** (Entry, future doc) may read CHoCH records and the Prevailing Direction from the Structure section; they must not redefine CHoCH or mutate its records.

This document is now the official specification for the Change of Character Engine.
