# DOC02B — Break of Structure (BOS) Engine
## Official Specification for BOS Detection (H1)

> **Document status:** AUTHORITATIVE — Official specification for the **Break of Structure (BOS) Engine only**.
> **Phase:** Module Specification (Phase 2, Part B).
> **Scope of this document:** Break of Structure (BOS) — definition, detection, confirmation, validation, bullish/bearish mechanics, and the BOS event lifecycle.
> **Explicitly out of scope (future documents):** Change of Character (CHoCH), Liquidity, Order Block, Fair Value Gap, Entry Logic, Risk Management. These are **not** defined, behaviourally referenced, or implemented here. Where a topic implicitly borders on CHoCH (e.g., a break *against* the prevailing structure), DOC02B explicitly declines to classify it and defers to the future CHoCH document.
> **Relationship to prior documents:**
> - Implements **DOC00_Strategy_Validation.md §8 (Break of Structure)** without modification to its definition or constants.
> - Conforms to **DOC00_PATCH_001.md**: BOS is detected on the **Market Structure Timeframe (H1)**. H4 (Primary Trend Timeframe) permits swing-sequence classification only — **no BOS on H4**.
> - Realises the **Market Structure Engine** responsibilities for BOS within **DOC01_System_Architecture.md** (Layer 2), writing BOS events into the *Structure* section of the Structural Context.
> - Consumes **only** the outputs of **DOC02A_MarketStructure_Foundation.md**: Confirmed Swing High, Confirmed Swing Low, HH, HL, LH, LL. It creates or modifies **no** swing data.
> **Priority rule:** If anything here appears to conflict with DOC00, PATCH_001, DOC01, or DOC02A, those documents prevail. DOC02B governs only the BOS Engine details.

---

# Reported Items (reported, not changed)

Per the standing instruction to *report* rather than silently change, the following are flagged. None contradicts an approved document; each is a clarification needed to keep DOC02B internally consistent.

| # | Item | Status |
|---|---|---|
| R-1 | DOC00 §8 defines BOS as a **continuation** event ("In a bullish structure… / In a bearish structure…"). This requires a pre-existing directional structure. DOC02A's structure labelling state machine includes **INITIAL** and **UNKNOWN** states where no direction is established. DOC02B therefore specifies: a BOS is emitted **only** when the current DOC02A structure label is **BULLISH** or **BEARISH** and the break is in the **continuation direction**. A body close *against* the prevailing structure is **not** a BOS (it is CHoCH territory, out of scope here) and is **not** emitted by this engine. | Reported — consistent with DOC00 + DOC02A. |
| R-2 | DOC00 refers to BOS detection on "the HTF." PATCH_001 designates **H1** as the Market Structure Timeframe where BOS is detected, and **H4** as bias-only (no BOS). DOC02B fixes BOS detection to **H1 closed candles** and H1 confirmed swings only. No BOS is computed on H4 or M15. | Reported — consistent with PATCH_001. |
| R-3 | DOC00 §8 says the break reference is "the most recent confirmed Swing High/Low." DOC02B pins this precisely: at the moment a candle closes, the reference is the **most recent confirmed swing of the relevant type** (swing high for bullish BOS, swing low for bearish BOS) as published by DOC02A at that instant. Because swings confirm only on closed bars (SFS bars later, per DOC02A), the reference is always well-defined and never ambiguous. | Reported — clarification, no contradiction. |
| R-4 | DOC00 §8 notes the BOS candle's impulse is what "qualifies an Order Block." That qualification belongs to the future Order Block document. DOC02B **records** the BOS event and identifies the BOS candle and the impulse candles, but does **not** create, define, or validate any Order Block. | Reported — scope boundary, no change. |

No approved document was modified.

---

# Conformance Summary

DOC02B introduces **no new SMC definition**. The BOS definition is DOC00 §8 stated with full operational detail. The constants and decisions in force:

| Constant / Decision | Value | Source |
|---|---|---|
| BOS confirmation method | **Body close only** — compare the candle `close` price (not high, not low, not wick) | DOC00 §8 |
| Comparison operator | **Strict** — bullish: `close > swing high price`; bearish: `close < swing low price` | DOC00 §8 |
| Event type | **Continuation** (requires prevailing directional structure) | DOC00 §8, R-1 |
| Detection timeframe | **H1** (Market Structure Timeframe) | PATCH_001, R-2 |
| Break reference | Most recent confirmed Swing High (bullish) / Swing Low (bearish) from DOC02A | DOC00 §8, R-3 |
| Closed-bar requirement | BOS evaluated only on **closed** H1 candles | DOC00 §8, DOC02A |
| Repaint | None — closed candle body is final; BOS records immutable | DOC00 §8 |

---

# BOS Engine — Full Specification

## Definition

A **Break of Structure (BOS)** is a **continuation** structural event. It occurs when a **closed H1 candle's body close** is **strictly beyond** the **most recent confirmed swing** in the **direction of the prevailing structure**:

- In a **bullish** structure, a **Bullish BOS** occurs when a closed H1 candle's `close` is **strictly greater than** the most recent confirmed **Swing High** price.
- In a **bearish** structure, a **Bearish BOS** occurs when a closed H1 candle's `close` is **strictly less than** the most recent confirmed **Swing Low** price.

A wick beyond the level that does **not** close beyond it is **not** a BOS. (DOC00 §8, unchanged.)

## Purpose

To objectively confirm that the prevailing structure is **intact and extending**, by recording the exact candle that closed beyond the most recent structural extreme in the trend direction.

## Why BOS exists

Structure is defined by swings (DOC02A). A trend "continues" only when price closes beyond its most recent structural extreme in the trend direction. Without an objective BOS rule, "is the trend still going?" becomes a visual judgement. BOS turns trend continuation into a single, falsifiable, repeatable event.

## Relationship with DOC00

This is DOC00 §8 reproduced with operational detail. No semantic change. The body-close-only decision (DOC00 Ambiguous Rule A2) and the continuation-only nature are preserved exactly.

## Relationship with DOC01

Implemented inside the **Market Structure Engine** (DOC01 Layer 2). BOS events are written into the **Structure** section of the **Structural Context**. The BOS logic is the **sole writer** of BOS records. It reads only from Market Data Access (closed H1 candles) and from the DOC02A swing/structure data already in the Structure section. No other module writes BOS records; no other concern reads forming bars.

## Relationship with DOC02A

The BOS Engine is a **pure consumer** of DOC02A outputs:

| Consumed from DOC02A | Used for |
|---|---|
| Confirmed Swing High (price, time) | Bullish BOS break reference |
| Confirmed Swing Low (price, time) | Bearish BOS break reference |
| HH / HL labels → BULLISH structure | Gate: bullish BOS permitted only when structure is BULLISH |
| LH / LL labels → BEARISH structure | Gate: bearish BOS permitted only when structure is BEARISH |
| Structure state (INITIAL/UNKNOWN/BULLISH/BEARISH) | Gate: BOS permitted only in BULLISH or BEARISH |

The BOS Engine **must not** create, modify, relabel, or delete any swing, any HH/HL/LH/LL label, or the structure state. It is a consumer only. (Mandatory dependency constraint.)

## Inputs

1. The **structure label** currently published by DOC02A (BULLISH / BEARISH / UNKNOWN / INITIAL), evaluated at the close of the H1 candle under test.
2. The **most recent confirmed Swing High** (price + confirmation time) — for bullish BOS.
3. The **most recent confirmed Swing Low** (price + confirmation time) — for bearish BOS.
4. The **newly closed H1 candle** under evaluation: its `close` price, its open time, its close time, and confirmation that it is a closed (historical) bar.

## Outputs

A **BOS event record** (only when a BOS is confirmed), containing:
- **Direction:** Bullish or Bearish.
- **Breaking candle:** open time, close time, open price, close price (the candle whose body close triggered the BOS).
- **Break reference:** the swing record that was broken (type, price, original confirmation time).
- **Break price:** the reference swing's price (swing high price for bullish; swing low price for bearish).
- **Confirmation time:** the close time of the breaking candle (the instant the BOS becomes valid).
- **Prevailing structure at confirmation:** BULLISH or BEARISH.
- **Status:** immutable `CONFIRMED`.

When no BOS occurs on a closed candle, **no** record is produced.

## Dependencies

- **Market Data Access** (DOC01): closed H1 candle data (the single closed-bar chokepoint).
- **DOC02A outputs** (read-only): structure label + most recent confirmed swings.
- **Utility** (DOC01): time/precision helpers.
- **Logger** (DOC01): event logging.

The BOS Engine has **no** dependency on Liquidity, Order Block, FVG, Entry, Risk, Session, or CHoCH logic. It depends on no other detection engine.

## Deterministic Rules

1. **Closed-candle only.** BOS is evaluated exclusively on **closed** H1 candles. The forming candle is never evaluated.
2. **Body close only.** The test uses the candle `close` price only. High, low, open, and wicks are **not** used for the break test.
3. **Strict inequality.** Bullish: `close > swingHighPrice`. Bearish: `close < swingLowPrice`. Equality is **not** a break.
4. **Continuation only.** A BOS is emitted only when the prevailing DOC02A structure label is directional (BULLISH or BEARISH) **and** the break is in that direction. A break against the prevailing structure is **not** a BOS (out of scope — CHoCH).
5. **No BOS in INITIAL or UNKNOWN.** If the structure label is INITIAL or UNKNOWN at the candle close, no BOS is emitted for that candle, regardless of where price closed.
6. **Single reference.** The break reference is exactly one swing: the most recent confirmed swing of the relevant type at the instant the candle closes.
7. **One event per candle.** A single closed candle can produce **at most one** BOS event.
8. **Immutability.** Once a BOS record is created it is never edited, relabelled, or invalidated by this engine.
9. **No swing mutation.** The engine never creates or modifies swing data.

## Validation Rules

A BOS record is valid only if **all** of the following hold at creation:
- The breaking candle is confirmed closed (historical).
- The prevailing structure label was BULLISH (for a bullish BOS) or BEARISH (for a bearish BOS) at that candle's close.
- The break reference is a confirmed swing from DOC02A (confirmation time ≤ breaking candle close time).
- The strict body-close inequality holds against the recorded break price.
- The breaking candle's close time is consistent with the recorded confirmation time.

Any record failing these is never created.

## Confirmation Rules

- A BOS is **confirmed at the close** of the breaking H1 candle. There is no second-stage confirmation, no minimum distance beyond the level, and no "wait N bars" rule. The close beyond the reference is the confirmation.
- Confirmation is **instantaneous and final** at that close. The BOS cannot be "un-confirmed" by later price action (a later reversal is a separate event — CHoCH, out of scope — and does not retroactively invalidate the BOS).

## Failure Conditions

A BOS is **not** produced (and no record is created) when:
- The candle is not closed (forming).
- The structure label is INITIAL or UNKNOWN.
- The break is against the prevailing direction.
- The close merely equals the reference (tie) — strict inequality fails.
- Only the wick exceeded the level but the close did not.
- No confirmed swing of the relevant type exists yet.
- Market Data Access reports the candle/bar as invalid or gapped in a way that the closed-bar guard rejects (see Edge Cases for gap *through* the level, which is a different, valid case).

These are **silent non-events**, not errors. They produce no record and no error.

## Edge Cases

- **Gap beyond the level (valid BOS).** A candle that **opens** already beyond the reference and closes beyond it is a valid BOS — the body close is beyond the level. (DOC00 §8.)
- **Opens beyond, closes back inside (not a BOS).** A candle that opens beyond the reference but closes back on the pre-break side is **not** a BOS — the close is not beyond. (DOC00 §8.)
- **Wick beyond, close inside (not a BOS).** A wick spike beyond the level with a close back inside is explicitly not a BOS.
- **Exact close at the level (not a BOS).** Equality fails strict inequality.
- **Multiple swing levels breached in one candle.** The candle closes beyond several historical swings simultaneously. It produces **one** BOS event referencing the **most recent** confirmed swing of the relevant type. Breaching older swings is incidental and does not create additional BOS events for that candle.
- **Break candle is itself later confirmed as a swing.** A breaking candle may itself become a confirmed swing SFS bars later (DOC02A). That later swing confirmation is a DOC02A event and does **not** retroactively change the BOS record. The BOS remains immutable.
- **BOS on the same bar a new swing confirms.** Because swing confirmation occurs SFS bars after the swing centre and BOS occurs on a closed candle's close, these are distinct events on distinct bars; no conflict.
- **History gap at the breaking candle.** If the closed-bar guard cannot certify the candle, no BOS is produced; evaluation resumes when clean closed history is available. A gap that *contains* the break does not produce a BOS for the missing candle.

## False Break Scenarios

- **Stop-hunt close then reversal.** A candle closes just beyond the swing and the next bars reverse sharply. Per DOC00 §8, this is a **valid BOS** (the close was real); the reversal is a separate, later event (CHoCH, out of scope). DOC02B does **not** soften the BOS rule to filter these — false breaks are handled downstream by zone/session/entry filters, not by the BOS Engine.
- **Low-liquidity wick-driven close.** A thin-market candle whose close barely exceeds the level. Still a valid BOS by the rule. Magnitude is irrelevant to BOS validity.
- **Instantaneous BOS then immediate re-entry inside.** Not a BOS concept; BOS is final at the close.

## Market Noise Considerations

- SFS = 2 (DOC02A) on **H1** (PATCH_001) already filters single-bar noise at the swing level, so the reference swings are themselves stable. BOS adds a second filter: **body close** beyond the reference, which ignores wick noise entirely.
- DOC02B does **not** add magnitude, volume, or "strength" filters to BOS. Any such filter would be a subjective addition not present in DOC00 and is therefore excluded. BOS is purely the body-close test.
- Noise-induced minor swings can still produce BOS events that a discretionary trader might dismiss; this is accepted as the cost of determinism. Downstream filters (future docs) handle quality, not the BOS Engine.

## Closed Candle Requirements

- BOS evaluation occurs **only** on a candle whose H1 bar has fully closed (MT5 reports it as historical / non-forming).
- The breaking candle, the reference swing, and the structure label must all be evaluable from **closed** data only.
- This is enforced via the Market Data Access chokepoint (DOC01), not by convention.

## Timeframe Requirements

- **Detection timeframe: H1 only** (Market Structure Timeframe, PATCH_001).
- The break reference swings are H1 confirmed swings (DOC02A on H1).
- **No BOS on H4** (Primary Trend Timeframe: bias-only; PATCH_001 forbids BOS there).
- **No BOS on M15** (Execution Timeframe: entry/management only; PATCH_001).
- H1 candle `close` and H1 swing prices share the same timeframe, so no cross-timeframe alignment ambiguity exists.

## State Transition Rules

The BOS Engine itself is largely **stateless**: each closed H1 candle is evaluated against the current DOC02A structure label and the current most-recent confirmed swing. The only persistent state is the **immutable history of BOS records** (for downstream consumption and retention pruning).

Per-candle evaluation decision table:

| Structure label (at candle close) | Close vs most-recent Swing High | Close vs most-recent Swing Low | BOS output |
|---|---|---|---|
| BULLISH | `close > SwingHigh` | — | **Bullish BOS** emitted |
| BULLISH | `close ≤ SwingHigh` | (any) | No BOS (a close below the Swing Low is **not** a BOS here — out of scope) |
| BEARISH | — | `close < SwingLow` | **Bearish BOS** emitted |
| BEARISH | (any) | `close ≥ SwingLow` | No BOS (a close above the Swing High is **not** a BOS here — out of scope) |
| UNKNOWN | (any) | (any) | No BOS |
| INITIAL | (any) | (any) | No BOS |

Note: the cells marked "out of scope" are breaks **against** the prevailing structure. DOC02B deliberately does **not** classify them. They are neither emitted as BOS nor defined here; they belong to the future CHoCH document (R-1).

## Automation Challenges

- **Enforcing closed-bar discipline** so no path evaluates a forming candle — handled by the Market Data Access chokepoint (DOC01).
- **Snapshot consistency:** the structure label and the most-recent swing used for the BOS test must be the values in effect at the breaking candle's close. The DOC01 "frozen Structural Context per bar" guarantees this — BOS reads the frozen snapshot for that bar.
- **Immutability of records** so later bars cannot rewrite a BOS — enforced by data structure, not convention.
- **Avoiding CHoCH conflation** — the engine must refuse to emit breaks against the prevailing structure, even if a naive implementation would. The decision table above encodes this refusal.
- **Reference well-definedness** — the most-recent swing is always known because swings confirm deterministically on closed bars (DOC02A); there is never an ambiguous reference.

## Recommended Deterministic Implementation

On each **closed H1 bar**, in the frozen-snapshot evaluation step of the Market Structure Engine:

1. Read the prevailing structure label from DOC02A. If it is not BULLISH or BEARISH, stop (no BOS).
2. If BULLISH: read the most recent confirmed Swing High price. If `close > swingHighPrice` (strict), emit one immutable Bullish BOS record referencing that swing. Else, emit nothing.
3. If BEARISH: read the most recent confirmed Swing Low price. If `close < swingLowPrice` (strict), emit one immutable Bearish BOS record referencing that swing. Else, emit nothing.
4. Record the breaking candle, the break reference, the break price, the confirmation time, and the prevailing structure. Mark the record `CONFIRMED` and immutable.
5. Do not, under any condition, evaluate the forming candle, use wicks/high/low, mutate swing data, or emit a break against the prevailing structure.

(Process description only — no algorithm, pseudo-code, or flowchart is specified.)

## Computational Complexity

- Per closed H1 bar: **O(1)** — one structure-label check and one strict comparison against a single known swing price.
- Initialisation: **O(N)** over a bounded lookback of N H1 bars (replaying closed history to reconstruct the BOS event sequence), with each bar O(1).
- Complexity analysis only; no algorithm specified.

## Memory Requirement

- One immutable record per confirmed BOS event.
- Bounded by retention pruning: keep the most recent M BOS records (a fixed constant); older records are archived/dropped. M must be large enough to serve downstream consumers (e.g., Order Block qualification, future doc) — the exact M is set in the future Order Block document; within this engine, BOS records are retained per the project retention policy and pruned only from the oldest end.
- Constant per-bar working memory (a few price/time values).

## Update Frequency

- Evaluated **once per closed H1 bar**, within the bar-scoped analysis pipeline (DOC01).
- **Never** on ticks. BOS is a structural, bar-close event.

---

# Bullish BOS — Detailed

### Required swing sequence
- The prevailing DOC02A structure label must be **BULLISH** at the breaking candle's close, i.e., the latest confirmed swing high is **HH** and the latest confirmed swing low is **HL** (DOC02A).
- The break reference is the **most recent confirmed Swing High** (the latest HH).

### Required candle close
- A **closed** H1 candle whose **`close` price** is **strictly greater than** the break-reference swing high price.
- Body close only; wicks ignored; strict inequality (equality is not a break).

### Required break level
- The price of the most recent confirmed Swing High (an HH), as published by DOC02A at the candle close.

### Invalid bullish BOS
A would-be bullish BOS is **not** created (no record) when any of these hold:
- Structure label is not BULLISH (INITIAL/UNKNOWN/BEARISH).
- The candle is not closed.
- `close ≤ swingHighPrice` (tie or below).
- Only the wick exceeded the level.
- The candle opened beyond but closed back inside (close not beyond).
- No confirmed swing high exists.

There are no "created-then-invalidated" bullish BOS records; invalid candidates are simply never created.

### Equal High handling
- Equal Highs (EQH) are a **liquidity** concept (DOC00 §11, future document) and are **irrelevant** to BOS mechanics.
- The BOS reference is the **most recent confirmed Swing High price**, regardless of whether that swing participates in an EQH with a prior swing.
- A close strictly above the most recent confirmed swing high is a Bullish BOS even if that swing is equal (within ELT) to a previous swing high. BOS does not consume ELT and does not group swings.
- Note: a tie *within the fractal window* would have prevented the swing from existing at all (DOC02A); that is distinct from EQH (two separately-confirmed swings close in price) and does not affect BOS.

### Multiple break handling
- If one closed candle's body close exceeds several historical swing highs simultaneously (e.g., a strong thrust or gap), **exactly one** Bullish BOS is emitted, referencing the **most recent** confirmed swing high. Exceeding older swings does not generate additional BOS events for that candle.

### Retest handling
- After a Bullish BOS, price may return toward the broken swing-high level. **Retests do not affect the BOS record.** BOS is a one-time event fixed at the breaking candle's close.
- A retest does not invalidate, modify, or "confirm again" the BOS. Whether a retest is used for entries is an **Entry Logic** concern (out of scope).
- If, during a retest, price closes back **below** the most recent confirmed swing low while structure is still labelled BULLISH, that is a break **against** the structure — **not** a BOS (CHoCH territory, out of scope). It does not alter the existing Bullish BOS record.

### Gap handling
- **Gap up beyond the swing high and closes beyond** → valid Bullish BOS (body close beyond).
- **Gap up beyond but closes back below the swing high** → not a Bullish BOS (close not beyond).
- A gap that *skips* the breaking candle entirely (missing bar) → no BOS for the missing candle; the next clean closed candle is evaluated on its own merits against the then-current reference.

---

# Bearish BOS — Detailed

### Required swing sequence
- The prevailing DOC02A structure label must be **BEARISH** at the breaking candle's close, i.e., the latest confirmed swing high is **LH** and the latest confirmed swing low is **LL** (DOC02A).
- The break reference is the **most recent confirmed Swing Low** (the latest LL).

### Required candle close
- A **closed** H1 candle whose **`close` price** is **strictly less than** the break-reference swing low price.
- Body close only; wicks ignored; strict inequality.

### Required break level
- The price of the most recent confirmed Swing Low (an LL), as published by DOC02A at the candle close.

### Invalid bearish BOS
A would-be bearish BOS is **not** created when any of these hold:
- Structure label is not BEARISH.
- The candle is not closed.
- `close ≥ swingLowPrice` (tie or above).
- Only the wick went below the level.
- The candle opened below but closed back above (close not beyond).
- No confirmed swing low exists.

No created-then-invalidated bearish BOS records exist.

### Equal Low handling
- Equal Lows (EQL) are a **liquidity** concept (DOC00 §12, future document) and are **irrelevant** to BOS.
- The BOS reference is the **most recent confirmed Swing Low price**, regardless of EQL participation.
- A close strictly below the most recent confirmed swing low is a Bearish BOS even if that swing is equal (within ELT) to a previous swing low. BOS does not consume ELT.
- A tie within the fractal window would have prevented the swing from existing (DOC02A); distinct from EQL; does not affect BOS.

### Multiple break handling
- If one closed candle's body close falls below several historical swing lows simultaneously, **exactly one** Bearish BOS is emitted, referencing the **most recent** confirmed swing low.

### Retest handling
- After a Bearish BOS, price may return up toward the broken swing-low level. Retests do not affect the BOS record.
- A retest does not invalidate, modify, or re-confirm the BOS. Entry usage of retests is out of scope.
- If price closes back **above** the most recent confirmed swing high while structure is BEARISH, that is a break **against** the structure — not a BOS (CHoCH, out of scope) — and does not alter the existing Bearish BOS record.

### Gap handling
- **Gap down beyond the swing low and closes beyond** → valid Bearish BOS.
- **Gap down beyond but closes back above the swing low** → not a Bearish BOS.
- A gap that skips the breaking candle → no BOS for the missing candle; the next clean closed candle is evaluated independently.

---

# Validation — BOS Lifecycle

### When BOS becomes valid
- A BOS becomes valid **instantly at the close** of the breaking H1 candle, provided the structure label is directional and the strict body-close test holds in the continuation direction. There is no pending state and no second confirmation stage.

### When BOS becomes invalid
- **Never.** A confirmed BOS is an immutable historical fact. Later price action (reversal, retest, CHoCH) does **not** invalidate it. The only "invalid BOS" is a candidate that never met the confirmation criteria — and such candidates are never created as records.

### When BOS expires
- A BOS has **no expiry** within this engine. It is a permanent historical record, subject only to **retention pruning** of the oldest records (a fixed-capacity, FIFO eviction of the most ancient BOS events). Pruning removes a record from active memory; it does not "invalidate" the event.

### Whether BOS can be replaced
- **No.** A BOS record, once created, is never overwritten or replaced. Each distinct breaking candle that satisfies the rules produces a **new, additional** BOS record.

### Whether BOS can overlap
- BOS records are **distinct events**, each tied to a specific breaking candle and a specific reference swing. Two BOS records are never "the same event." They may reference the same break-reference swing only if that swing was the most-recent confirmed swing at two different candle closes — but each is still a separate, immutable event keyed by its breaking candle.
- Temporally, BOS events are naturally ordered by their breaking-candle close times; they do not "overlap" as simultaneous events because at most one BOS is emitted per closed candle.

### Whether multiple BOS can exist simultaneously
- **Yes.** Multiple BOS records coexist as an ordered historical sequence (a series of continuation breaks over time). This is the normal case in a sustained trend. The engine maintains all of them (up to the retention cap). "Simultaneously" here means coexisting in memory/history, not occurring on the same bar (at most one per bar).

---

# Automation Requirements (conformance)

| Requirement | How DOC02B satisfies it |
|---|---|
| **Deterministic** | Every BOS is a strict body-close comparison against a single known swing on a closed H1 bar; identical data ⇒ identical BOS events. |
| **Programmable** | All inputs are finite, typed values (prices, times, labels); no unbounded or fuzzy inputs. |
| **Measurable** | Each BOS has exact price, time, reference, and direction — fully auditable. |
| **Non-repainting** | BOS is emitted once, at a closed bar, and is immutable; failed candidates are never published. |
| **Independent** | Depends only on DOC02A swing/structure data and closed H1 candles; no dependency on other detection engines. |
| **Stateless whenever possible** | Per-candle evaluation is a pure function of the frozen snapshot; the only persistent state is the immutable BOS history. |
| **No subjective interpretation** | No magnitude/strength/volume filters; strict inequality only; no "significant" or "clear" language in the rules. |

---

# Dependencies (conformance — consumer only)

The BOS Engine consumes **only** the following from DOC02A:
- Confirmed Swing High (price, times)
- Confirmed Swing Low (price, times)
- HH, HL, LH, LL labels
- The derived structure label (BULLISH / BEARISH / UNKNOWN / INITIAL)

Plus, from DOC01 Market Data Access: the closed H1 candle under evaluation.

The BOS Engine **must not**:
- Create, modify, relabel, or delete any swing.
- Create, modify, or delete any HH/HL/LH/LL label.
- Change the DOC02A structure state.
- Create or modify Liquidity, Order Block, FVG, CHoCH, Entry, or Risk data.
- Read forming bars or any timeframe other than H1 for BOS purposes.

It is a **consumer only** with respect to swing/structure data, and a **sole writer** only of BOS records.

---

# Cross-Document Consistency

| Concern | How DOC02B respects it |
|---|---|
| DOC00 §8 BOS definition | Reproduced verbatim in semantics: continuation, body-close, strict, wick-not-counted, gap rules. No change. |
| DOC00 Ambiguous Rule A2 (body-close) | Enforced as the only confirmation method. |
| PATCH_001 timeframes | BOS on H1 only; none on H4 or M15. |
| DOC01 module ownership | BOS records written solely by the Market Structure Engine into the *Structure* section; closed-bar discipline via Market Data Access; immutable records; frozen per-bar snapshot consumed. |
| DOC02A swing/structure primacy | DOC02A remains the sole owner of swings and structure labels; BOS only reads them. BOS never redefines Swing High/Low or HH/HL/LH/LL. |
| DOC02A confirmation-time discipline | BOS uses only confirmed swings (DOC02A) and only closed candles, so the centre-vs-confirmation-time separation in DOC02A is respected. |

---

# Self Review Result

Before finalising, the document was checked against the required checklist. Findings and resolutions:

- **Logical contradictions:** None. Bullish and Bearish BOS are strict mirrors; the continuation-only rule (R-1) is applied symmetrically; immutability and "never invalid" are consistent (an event fixed at a closed bar cannot later change). *(Pass)*
- **Conflict with DOC00:** None. Definition, body-close decision, strict inequality, gap rules, and continuation nature all match DOC00 §8 and Ambiguous Rule A2. *(Pass)*
- **Conflict with DOC01:** None. BOS is produced by the Market Structure Engine, written to the Structure section, reads only closed bars via Market Data Access, and emits immutable records — all per DOC01. *(Pass)*
- **Conflict with DOC02A:** None. BOS consumes only DOC02A outputs and never mutates them; the BULLISH/BEARISH gate uses DOC02A's labels exactly. *(Pass)*
- **Repaint possibility:** Eliminated. BOS is published once at a closed bar and is immutable; failed candidates are never published. *(Pass)*
- **Look-ahead bias:** Eliminated. Only closed candles and already-confirmed swings (confirmation time ≤ breaking candle close) are used. No future data. *(Pass)*
- **Subjective wording:** Removed/avoided. No "significant," "strong," "clear," "usually." All rules are strict comparisons. *(Pass)*
- **Undefined terminology:** BOS, continuation, body close, break reference, breaking candle, break price, confirmation time, retention pruning, immutability — all defined. *(Pass)*
- **Missing edge cases:** Covered — gaps (both directions), opens-beyond/closes-inside, wick-only, exact tie, multiple-level breach, breaking candle later becoming a swing, BOS and swing confirmation on related bars, history gaps. *(Pass)*
- **Automation problems:** Addressed — closed-bar chokepoint, frozen snapshot consistency, immutability by structure, refusal to emit anti-structure breaks (decision table), always-well-defined reference. *(Pass)*

**Scope boundaries respected:** CHoCH, Liquidity, Order Block, Fair Value Gap, Entry Logic, and Risk Management are **not** defined or implemented. Breaks *against* the prevailing structure are explicitly **not** classified by this engine and deferred to the future CHoCH document (R-1). The BOS Engine does not qualify Order Blocks (R-4) — it only records the BOS event and the breaking/impulse candles for later consumption.

**Outcome:** No blocking issues. DOC02B is internally consistent, deterministic, measurable, programmable, non-repainting, independent, and fully conforms to DOC00, PATCH_001, DOC01, and DOC02A.

---

# Final Notes

1. **BOS only.** This document specifies the Break of Structure Engine and nothing else. No CHoCH, Liquidity, OB, FVG, entry, or risk logic.
2. **Consumer discipline.** The BOS Engine consumes DOC02A swing/structure data read-only and never mutates it. It is the sole writer of BOS records.
3. **Continuation only.** BOS confirms trend continuation in the prevailing direction. Breaks against the structure are out of scope (future CHoCH document).
4. **Body-close, strict, closed-bar, immutable.** These four properties jointly guarantee determinism and non-repainting.
5. **No quality filters added.** BOS validity is purely the body-close test. Magnitude/strength/volume filters are excluded as subjective and absent from DOC00.
6. **Downstream consumers** (Order Block, future doc) may read BOS records from the Structure section; they must not redefine BOS or mutate its records.

This document is now the official specification for the Break of Structure Engine.
