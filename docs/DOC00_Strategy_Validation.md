# DOC00 — Strategy Validation & Specification
## Deterministic Smart Money Concept (SMC) for XAUUSD on MetaTrader 5

> **Document status:** AUTHORITATIVE — Source of truth for all future phases.
> **Phase:** Research & Validation (Phase 0). No code, no Expert Advisor design.
> **Priority rule:** If any future requirement conflicts with this document, this document prevails unless the project owner explicitly revises it in writing.

---

# Project Purpose

This project exists to discover, validate, and define the **most deterministic** version of Smart Money Concept (SMC) that can be implemented **consistently** inside a MetaTrader 5 (MT5) Expert Advisor (EA) on **XAUUSD** with **Exness Standard**.

The objective is explicitly **NOT**:
- to find the highest win-rate strategy,
- to assume or guarantee profitability,
- to replicate a discretionary trader's judgement,
- to maximise trade frequency or sophistication.

The objective **IS**:
- to produce a set of trading rules where **every rule is programmable, deterministic, and measurable**,
- to ensure that **identical market data always produces an identical result**, with **zero human discretion**,
- to lock down one unambiguous definition for every SMC concept so that future design, coding, back-testing, and forward-testing phases all reference a single source of truth.

**Automation consistency is ranked higher than trading complexity.** Where a more "accurate" SMC interpretation requires human judgement, the simpler, fully-deterministic interpretation is chosen instead. The reasons for every such choice are recorded in this document.

### Locked project parameters (do not change without owner approval)

| Parameter | Locked value |
|---|---|
| Platform | MetaTrader 5 |
| Language | MQL5 |
| Broker | Exness Standard |
| Symbol | XAUUSD |
| Strategy | Smart Money Concept (SMC) |
| Lot size | Fixed 0.01 |
| Take profit | Risk : Reward = 1 : 2 |
| Max simultaneous open positions | 1 |
| Money management | No Martingale, No Grid, No Hedging, No Averaging, No Recovery System |
| Kill switch | Stop opening new trades **permanently** when Equity ≤ 50% of Initial Balance; resume only after manual reset |

---

# References

The following references were studied in full. They were chosen because they are structured, internally consistent, and publicly verifiable. No Reddit, no YouTube-as-primary, and no unexplained blogs were used.

### Primary references (used for definitions)

1. **TradingWyckoff — Smart Money Concepts (Complete Guide)**
   `https://tradingwyckoff.com/en/smart-money-concepts/`
   *Why selected:* The most structured and internally consistent of the three. It provides explicit, numbered conditions for BOS, CHoCH/MSS, Order Blocks, Breaker Blocks, Mitigation Blocks, Fair Value Gaps, Liquidity, and the ICT Premium/Discount/Equilibrium model, plus the ICT Killzones and Power of Three (PO3). It is treated as the **default tie-breaker** when the other references disagree.

2. **QuantNeuralEdge — ICT Smart Money Concepts (Learn)**
   `https://quantneuraledge.com/learn/ict-smart-money-concepts`
   *Why selected:* Frames SMC from an "institutional footprint" angle and gives concise, automatable definitions of FVG, Order Blocks, Liquidity Sweeps, and Breaker Blocks. Used to corroborate TradingWyckoff and to surface ICT-specific terminology (OTE, PD Arrays).

### Validation reference (used for cross-checking terminology and process)

3. **BINUS Student Information System — "Inner Circle Trader (ICT): Strategi Trading Berbasis Smart Money Concept" (2025)**
   `https://sis.binus.ac.id/2025/07/15/inner-circle-trader-ict-strategi-trading-berbasis-smart-money-concept/`
   *Why selected:* An academic-style synthesis of ICT methodology that restates the core principles (market structure, liquidity, OB, FVG, premium/discount, killzones) in a neutral, verifiable way. Used to validate that the selected definitions are consistent with mainstream ICT teaching, not to introduce new definitions.

### Implementation reference (not used for SMC definitions)

4. **MQL5 Documentation**
   `https://www.mql5.com/en/docs`
   *Why selected:* The official language reference. Used only to confirm that the chosen deterministic rules are expressible in MT5 (e.g., time-series access, bar indexing, server-time functions). It defines **no** SMC concepts and is referenced here only for feasibility, which is examined in the Automation Challenges section.

### Trustworthiness statement
All three SMC references agree on the core vocabulary and differ only in naming and strictness. Where they differ, this document picks **one** definition and records the justification (see *Reference Comparison* and *Ambiguous Rules*). No unverified blog, forum, or video was used as a definitional source.

---

# Reference Comparison

The three references share the same backbone — **price-action footprint of institutional order flow** — and disagree mainly on (a) naming, (b) confirmation strictness, and (c) how much discretion is expected. The matrix below summarises the points that affect automation.

| Concept | TradingWyckoff (TW) | QuantNeuralEdge (QNE) | BINUS (ICT) | Conflict? | Resolution adopted |
|---|---|---|---|---|---|
| Swing point | Local pivot / fractal | Pivot high/low | Pivot high/low | Naming only | Fractal with fixed N=2 each side |
| Trend structure | HH/HL (bull), LH/LL (bear) | Same | Same | None | Adopted as-is |
| Break of structure (BOS) | Close beyond prior swing in trend direction = continuation | Break of last swing | Break confirming trend | Confirmation strictness | **Body-close** confirmation only |
| Reversal signal | "MSS" (Market Structure Shift) = break against trend | "CHoCH" = first reversal break | "CHoCH" = reversal signal | **Naming conflict** | Standardise on **CHoCH**; treat MSS as synonym |
| BOS vs CHoCH trigger | Close-based | Not explicit | Not explicit | Implicit | Close-based; wicks ignored |
| Order Block | Last opposite-colour candle before impulse that breaks structure | Last opposite candle before strong move | Last opposite candle before impulse | Strictness | **TW strict** definition adopted |
| Mitigation Block | Distinct concept (last reference candle after no OB) | Sometimes merged with OB | Not detailed | Conflict | Keep **distinct** from OB (TW) |
| Breaker Block | Failed OB reclaimed after structure break opposite way | Same idea | Not detailed | None | Adopted (TW) |
| Fair Value Gap | 3-candle imbalance (gap between candle 1 high and candle 3 low, bullish) | Same | Same | None | Adopted as-is |
| Liquidity | Resting orders above highs / below lows | Same | Same | None | Adopted |
| Equal Highs/Lows | Wick-level pools | Wick-level | Wick-level | None | Wick-level + tolerance |
| Liquidity Sweep | Wick beyond pool then close back inside | Same | Same | Tolerance undefined | Fixed-point tolerance |
| Premium/Discount | Equilibrium = 50% of dealing range | Same | Same | None | Adopted |
| Session timing | ICT Killzones (London, NY) | Mentioned | London/NY sessions | Granularity | Fixed UTC windows (configurable) |
| Entry | OB + FVG in discount/premium + lower-TF CHoCH | OB + FVG + sweep | OB + FVG + CHoCH | Granularity | Fixed multi-step trigger |

### Key naming decision (CHoCH vs MSS)
TW calls the reversal break an **MSS (Market Structure Shift)**; QNE and BINUS call it a **CHoCH (Change of Character)**. They describe the **same event**. To avoid ever mixing two names for one event, this project uses **CHoCH** exclusively and treats "MSS" as a non-preferred synonym that must **not** appear in any later document or code symbol.

### Key strictness decision (body-close vs wick)
All three references describe structure breaks loosely as "price breaks the level." For a deterministic EA, "price breaks" is too loose because a wick spike and a closing break are different events. This project adopts **body-close confirmation** for every structure break (BOS and CHoCH): the break is valid only when a candle's **body** (open-to-close) closes beyond the reference swing price, never on a wick that retracts. This is a deliberate trade-off: fewer signals, fewer false breaks, fully unambiguous.

---

# Selected Smart Money Concept Methodology

The project adopts a **single, consolidated SMC methodology** built on the TradingWyckoff definitions, validated against QuantNeuralEdge and BINUS, and reduced to deterministic rules. The methodology has these properties:

1. **Two-timeframe model.** Structure, liquidity, Order Blocks, Fair Value Gaps, Premium/Discount are mapped on a **higher timeframe (HTF)**; entry confirmation happens on a **lower timeframe (LTF)**. Both timeframes are fixed constants (set in *Project Assumptions*), never chosen by the EA at runtime.
2. **Close-based structure.** BOS and CHoCH are confirmed only by body closes.
3. **Fractal-based swings.** Swing highs/lows are defined by a fixed fractal strength (no adaptive or "feel-based" pivots).
4. **Zone-based execution.** Trading happens only inside a qualified Order Block that lies in the correct Premium/Discount half and that contains or is aligned with a Fair Value Gap.
5. **Session-gated.** New entries are allowed only inside fixed trading-session windows.
6. **One position, fixed risk, fixed reward.** No scaling, no martingale, no grid, no recovery.
7. **Hard kill switch.** A single equity-based rule can permanently halt new entries until a manual reset.

No part of the methodology requires interpretation at runtime. Every threshold is a named constant with a fixed numeric value recorded in *Deterministic Rules*.

---

# Complete Definitions

Each component below is given a full validation block. Fields used throughout:

- **Definition** — the single, locked definition used by this project.
- **Purpose** — why the concept exists in the methodology.
- **Automatable?** — Yes / No / Conditional.
- **Automation difficulty (1–10)** — 1 = trivial, 10 = requires judgement.
- **Potential ambiguity** — what could be misread.
- **Potential repaint risk** — whether the signal can change after it first appears.
- **Potential look-ahead bias** — whether a naive implementation can peek into the future.
- **Edge cases** — inputs that break naive logic.
- **False signal scenarios** — how the concept can fire incorrectly.
- **Recommended deterministic implementation** — the exact rule this project adopts.
- **Reason** — why this rule was chosen.

Fixed global constants referenced below are listed in *Deterministic Rules*.

---

## 1. Market Structure

- **Definition:** The directional relationship between consecutive confirmed swing highs and swing lows on the HTF. A sequence of Higher Highs and Higher Lows is a **bullish structure**; a sequence of Lower Highs and Lower Lows is a **bearish structure**. The structure is only re-evaluated when a new swing point is confirmed.
- **Purpose:** Establishes the bias (long-only in bullish structure, short-only in bearish structure) and the reference levels for BOS/CHoCH.
- **Automatable?:** Yes.
- **Automation difficulty:** 3/10.
- **Potential ambiguity:** "Structure" is often used loosely to mean "the chart." Here it is strictly the swing-sequence state machine.
- **Potential repaint risk:** None once swings are confirmed (see Swing High/Low repaint rule).
- **Potential look-ahead bias:** Only if swings are confirmed using bars that are not yet closed; using closed-bar confirmation removes this.
- **Edge cases:** The first few bars before two confirmed swings exist; long consolidations with no new swings.
- **False signal scenarios:** Whipsaw between bullish/bearish on very short fractals in ranging markets.
- **Recommended deterministic implementation:** Maintain a labelled list of confirmed HTF swings. Recompute bias only when a new swing is confirmed. Until at least two confirmed swings exist, bias = "undefined" and no trade is allowed.
- **Reason:** A pure state machine on confirmed swings is fully reproducible and cannot be argued with.

## 2. Swing High

- **Definition:** A **confirmed Swing High** is a candle on the HTF whose **high** is strictly greater than the highs of the **Swing Fractal Strength (SFS = 2)** candles immediately to its left and the SFS candles immediately to its right, evaluated only after the right-hand candles have closed.
- **Purpose:** Anchors structure, liquidity pools, Order Block ranges, and Premium/Discount range tops.
- **Automatable?:** Yes.
- **Automation difficulty:** 2/10.
- **Potential ambiguity:** "Swing" vs "pivot" vs "fractal" — all treated as synonyms here, defined by SFS.
- **Potential repaint risk:** A candle looks like a swing while the right-hand bars are still forming; it is **only** confirmed SFS bars later. The rule forbids acting on an unconfirmed swing.
- **Potential look-ahead bias:** Inherent danger: a swing is only knowable SFS bars after it forms. The implementation must never label a swing until those bars have closed; this is the canonical SMC look-ahead trap and is handled by the confirmation rule.
- **Edge cases:** Equal highs within the window (a tie is treated as "not strictly greater," so no swing); very long candles that dominate the window.
- **False signal scenarios:** Small fractal swings in choppy markets produce noise; mitigated by the HTF and by SFS = 2.
- **Recommended deterministic implementation:** Confirm an HTF swing high only when SFS closed bars exist on both sides and the centre high is strictly the greatest. SFS is a fixed constant (2).
- **Reason:** Strict inequality + fixed SFS + closed-bar confirmation gives identical results every run and cannot repaint.

## 3. Swing Low

- **Definition:** Mirror of Swing High: a candle whose **low** is strictly lower than the lows of SFS candles on each side, confirmed only after the right-hand candles close.
- **Purpose:** Anchors structure, liquidity pools, OB ranges, and Premium/Discount range bottoms.
- **Automatable?:** Yes.
- **Automation difficulty:** 2/10.
- **Potential ambiguity:** Same as Swing High.
- **Potential repaint risk:** Same as Swing High — only after SFS right-side bars close.
- **Potential look-ahead bias:** Same — must wait for SFS closed bars.
- **Edge cases:** Ties at the low (not a swing).
- **False signal scenarios:** Noise in ranging markets.
- **Recommended deterministic implementation:** Strict-minimum rule with SFS = 2, closed-bar confirmation.
- **Reason:** Symmetry with Swing High; deterministic.

## 4. Higher High (HH)

- **Definition:** A confirmed Swing High whose price is strictly greater than the previous confirmed Swing High.
- **Purpose:** Building block of bullish structure.
- **Automatable?:** Yes.
- **Automation difficulty:** 1/10.
- **Potential ambiguity:** Equal highs are NOT Higher Highs (strict inequality).
- **Potential repaint risk:** None after both swings are confirmed.
- **Potential look-ahead bias:** None if swings are confirmed.
- **Edge cases:** Equal consecutive swing highs → classified as Equal Highs (liquidity), not HH.
- **False signal scenarios:** None beyond swing-detection errors.
- **Recommended deterministic implementation:** Compare consecutive confirmed swing highs with strict `>`.
- **Reason:** Strict inequality removes the "is it really higher?" debate.

## 5. Higher Low (HL)

- **Definition:** A confirmed Swing Low strictly higher than the previous confirmed Swing Low.
- **Purpose:** Building block of bullish structure.
- **Automatable?:** Yes. Difficulty 1/10. No repaint/look-ahead once swings are confirmed. Equal lows → Equal Lows, not HL. Recommended: strict `<` comparison inverted. Reason: symmetry.

## 6. Lower High (LH)

- **Definition:** A confirmed Swing High strictly lower than the previous confirmed Swing High.
- **Purpose:** Building block of bearish structure.
- **Automatable?:** Yes. Difficulty 1/10. No repaint/look-ahead once confirmed. Recommended: strict comparison. Reason: deterministic.

## 7. Lower Low (LL)

- **Definition:** A confirmed Swing Low strictly lower than the previous confirmed Swing Low.
- **Purpose:** Building block of bearish structure.
- **Automatable?:** Yes. Difficulty 1/10. Recommended: strict comparison. Reason: deterministic.

## 8. Break of Structure (BOS)

- **Definition:** A **continuation** event. In a bullish structure, a BOS occurs when an HTF candle **body closes above** the most recent confirmed Swing High. In a bearish structure, a BOS occurs when an HTF candle **body closes below** the most recent confirmed Swing Low. A wick beyond the level that does not close beyond it is **not** a BOS.
- **Purpose:** Confirms the prevailing structure is intact and extends the trend; also the impulse that qualifies an Order Block.
- **Automatable?:** Yes.
- **Automation difficulty:** 3/10.
- **Potential ambiguity:** "Break" — wick or close? This project: **body close only**.
- **Potential repaint risk:** None — a closed candle's body cannot change.
- **Potential look-ahead bias:** Only if one checks the break on the forming candle; the rule requires the candle to be closed.
- **Edge cases:** Gap opens beyond the level (the open is already beyond) — still counts as a close beyond the level since the body closes beyond it; a candle that opens beyond but closes back inside is not a BOS.
- **False signal scenarios:** Stop-hunt wicks that close beyond briefly then reverse — partially filtered by requiring a close, but a single bad close can still occur; this is why the entry logic adds Order Block + FVG + session filters.
- **Recommended deterministic implementation:** On each closed HTF candle, compare `close` (not high/low, not wick) to the reference swing. BOS valid iff close is strictly beyond in the trend direction. Mark the BOS candle; the candle(s) that formed the impulse are eligible Order Block sources.
- **Reason:** Body-close is the single most reproducible break definition and filters wick noise.

## 9. Change of Character (CHoCH)

- **Definition:** A **reversal** event (synonym of the ICT "MSS"; this project uses CHoCH only). In a bullish structure, a CHoCH occurs when an HTF candle **body closes below** the most recent confirmed Swing Low. In a bearish structure, a CHoCH occurs when an HTF candle **body closes above** the most recent confirmed Swing High. CHoCH flips the structural bias.
- **Purpose:** First objective sign that the trend may be reversing; bias is switched from bullish to bearish (or vice-versa) only by a CHoCH.
- **Automatable?:** Yes.
- **Automation difficulty:** 3/10.
- **Potential ambiguity:** Same close-vs-wick issue → resolved as body-close only.
- **Potential repaint risk:** None on closed candles.
- **Potential look-ahead bias:** None if evaluated on closed candles.
- **Edge cases:** A CHoCH immediately followed by a BOS back the other way (whipsaw); the bias simply flips each time a qualifying close occurs — there is no hysteresis beyond the definition.
- **False signal scenarios:** Stop runs that close beyond a swing then reverse; mitigated downstream by zone + session filters, not by softening the CHoCH rule.
- **Recommended deterministic implementation:** On a closed HTF candle, if the body close breaches the most recent opposing swing, set bias to the new direction and record the CHoCH candle as the start of the new structure.
- **Reason:** One unambiguous rule for bias flips; no judgement.

## 10. Liquidity

- **Definition:** Resting buy/sell interest located **above** confirmed Swing Highs / Equal Highs (buy-side liquidity, BSL) and **below** confirmed Swing Lows / Equal Lows (sell-side liquidity, SSL). Liquidity is represented as a **price level** equal to the swing wick extreme, tagged BSL or SSL.
- **Purpose:** Targets for liquidity sweeps; explains where stops cluster.
- **Automatable?:** Yes (as labelled levels).
- **Automation difficulty:** 3/10.
- **Potential ambiguity:** Liquidity is often described qualitatively ("pool of orders"). Here it is strictly a **labelled price level** derived from confirmed swings and equal highs/lows.
- **Potential repaint risk:** A level can be added or removed only when swings are confirmed — not at runtime on forming bars.
- **Potential look-ahead bias:** None if derived from confirmed swings.
- **Edge cases:** Many overlapping levels; the project keeps the **most recent** relevant BSL above price and SSL below price as the active targets.
- **False signal scenarios:** Treating every minor swing as liquidity; mitigated by using only confirmed HTF swings.
- **Recommended deterministic implementation:** Maintain two active levels: nearest confirmed BSL above current price and nearest confirmed SSL below current price, recomputed only on new confirmed swings.
- **Reason:** A finite, labelled set of levels is trivially reproducible.

## 11. Equal High (EQH)

- **Definition:** Two (or more) confirmed Swing Highs whose high prices differ by **no more than the Equal-Level Tolerance (ELT)** points. For XAUUSD, ELT is a fixed constant (see *Deterministic Rules*).
- **Purpose:** Identifies a buy-side liquidity pool that is likely to be swept.
- **Automatable?:** Yes.
- **Automation difficulty:** 4/10.
- **Potential ambiguity:** "Approximately equal" — resolved by a fixed ELT in points.
- **Potential repaint risk:** None once both swings are confirmed.
- **Potential look-ahead bias:** None.
- **Edge cases:** Three near-equal highs; the group is treated as one EQH liquidity level at the highest of the group.
- **False signal scenarios:** Tolerance too wide merges unrelated highs; ELT is fixed and documented to avoid this.
- **Recommended deterministic implementation:** After a new swing high is confirmed, compare its high to the previous confirmed swing high; if `abs(diff) ≤ ELT`, label both as an EQH pool at the higher price.
- **Reason:** Fixed tolerance removes the "close enough" judgement.

## 12. Equal Low (EQL)

- **Definition:** Two or more confirmed Swing Lows whose lows differ by ≤ ELT points.
- **Purpose:** Sell-side liquidity pool.
- **Automatable?:** Yes. Difficulty 4/10. Mirror of EQH. Recommended: same ELT logic at the lower price. Reason: deterministic.

## 13. Liquidity Sweep

- **Definition:** A liquidity sweep occurs when a candle's **wick** exceeds a BSL (by going above it) or an SSL (by going below it) by more than ELT points, but the candle **closes back inside** the level (i.e., the close is not a confirming BOS/CHoCH body close beyond the level). A sweep is confirmed only on the **close** of the sweeping candle.
- **Purpose:** Signals that liquidity has been taken and a reversal is probable; a high-value entry context.
- **Automatable?:** Yes.
- **Automation difficulty:** 5/10.
- **Potential ambiguity:** "Closes back inside" must be precisely defined: the candle close is on the pre-sweep side of the level.
- **Potential repaint risk:** Only on the forming candle; the rule acts on the closed candle, so no repaint.
- **Potential look-ahead bias:** None if the sweep is confirmed on close.
- **Edge cases:** A candle sweeps and closes beyond (that is a BOS/CHoCH, not a sweep); a candle sweeps multiple levels in one bar.
- **False signal scenarios:** A sweep followed by continuation (the "sweep fails"); this is inherent to the concept and is why sweeps are a **context filter**, not a standalone entry.
- **Recommended deterministic implementation:** On each closed candle, test: did the wick cross the nearest active BSL/SSL by > ELT while the close remained on the inside? If yes, mark a sweep at that level and invalidate that level as a future target.
- **Reason:** Close-based confirmation on a closed bar is fully deterministic.

## 14. Order Block (OB)

- **Definition (TradingWyckoff strict, adopted):** A **Bullish Order Block** is the **last down-closing (bearish) HTF candle** before an up-impulse that produces a bullish BOS or CHoCH. A **Bearish Order Block** is the **last up-closing (bullish) HTF candle** before a down-impulse that produces a bearish BOS or CHoCH. The OB **zone** spans that candle's high-to-low. The OB is only validated once the BOS/CHoCH has been confirmed by a body close.
- **Purpose:** The institutional re-entry zone where price is expected to return and react.
- **Automatable?:** Yes.
- **Automation difficulty:** 6/10.
- **Potential ambiguity:** References disagree on whether OB must be unmitigated, must contain a FVG, must be the "last opposite candle," etc. This project adopts TW's strict "last opposite-colour candle before the impulse that breaks structure."
- **Potential repaint risk:** The OB is only finalised when the BOS/CHoCH close occurs; before that, "the last opposite candle" can shift. The rule locks the OB at the moment of the confirming close and never edits it afterwards.
- **Potential look-ahead bias:** The OB is defined using a future event (the BOS close). This is legitimate as a **historical annotation** but the EA must not assume the OB existed before the BOS occurred. For entries, the EA only uses OBs whose confirming BOS/CHoCH has already printed.
- **Edge cases:** The impulse contains no opposite-colour candle (rare gap move) → no OB is recorded for that move. Two opposite candles before the impulse → only the last one is the OB.
- **False signal scenarios:** Price returns to the OB and blows through it ("OB failure"); mitigated by requiring the OB to sit in the correct Premium/Discount half and by LTF confirmation.
- **Recommended deterministic implementation:** When a BOS/CHoCH is confirmed by body close, scan backwards through the impulse candles to the last candle of opposite body direction; record its high–low as the OB zone, tagged bullish/bearish with the confirming BOS/CHoCH timestamp. An OB is invalidated (mitigated) when a later closed candle's body trades through the **far edge** of the zone (see Mitigation).
- **Reason:** TW's strict definition is the most reproducible and is consistent across QNE and BINUS.

## 15. Mitigation

- **Definition:** Mitigation is the event of price **returning to** an Order Block (or Breaker Block) zone after the OB-creating impulse. An OB is considered **mitigated** when a closed candle's body reaches into the zone. An OB is considered **invalidated/failed** when a closed candle's body closes beyond the **far edge** of the zone (the edge opposite to entry).
- **Purpose:** Marks the moment an OB has been "used." Also defines the entry reference: entries occur **on** mitigation of a qualified OB.
- **Automatable?:** Yes.
- **Automation difficulty:** 5/10.
- **Potential ambiguity:** "Mitigation" sometimes means "price touched the OB" (wick) and sometimes "price closed in the OB" (body). This project: **body** reaches the zone = mitigation; **body closes beyond the far edge** = invalidation.
- **Potential repaint risk:** None on closed candles.
- **Potential look-ahead bias:** None.
- **Edge cases:** Price gaps straight through the zone on open; both mitigation and invalidation can occur on the same candle → treat as invalidation (failure), not a usable mitigation.
- **False signal scenarios:** A wick into the zone is not mitigation; traders commonly miscount wick touches.
- **Recommended deterministic implementation:** Track each OB's near and far edge. On each closed candle, if the body enters the zone → mark mitigated. If the body closes beyond the far edge → mark invalidated.
- **Reason:** Body-based definitions are unambiguous and match the close-based structure logic.

## 16. Fair Value Gap (FVG)

- **Definition:** A **Bullish FVG** is a three-candle pattern on a timeframe where the **low of candle 3** is **greater than the high of candle 1**; the gap between them is the imbalance zone. A **Bearish FVG** is where the **high of candle 3** is **less than the low of candle 1**. The FVG zone is bounded by those two prices. Evaluated only after candle 3 closes.
- **Purpose:** Marks imbalance / inefficient price delivery that price tends to revisit; a confluence filter inside an OB and an LTF entry trigger.
- **Automatable?:** Yes.
- **Automation difficulty:** 2/10.
- **Potential ambiguity:** Whether candle order is 1-2-3 left-to-right — yes, left to right by close time.
- **Potential repaint risk:** Only while candle 3 is forming; confirmed on candle 3 close.
- **Potential look-ahead bias:** None once candle 3 has closed.
- **Edge cases:** Overlapping FVGs → merge into one zone spanning the outer bounds.
- **False signal scenarios:** Tiny FVGs that never fill; mitigated by a minimum-gap size (FVG Min Size constant) — FVGs smaller than this are ignored.
- **Recommended deterministic implementation:** Scan three consecutive closed candles; if the gap condition holds and the gap is ≥ FVG Min Size points, record the FVG zone. Mark an FVG filled when a later closed candle's body fully trades through the gap.
- **Reason:** Three-candle rule is universally consistent across references and trivially reproducible.

## 17. Premium

- **Definition:** The **upper half** of the current **Dealing Range** (the range from the most recent confirmed Swing Low to the most recent confirmed Swing High that bound the active structure leg). Any price > the 50% equilibrium line is "in Premium."
- **Purpose:** In a **bearish** bias, short entries are sought in Premium (sell high).
- **Automatable?:** Yes. Difficulty 2/10. No repaint once the range swings are confirmed. Recommended: equilibrium = (swingHigh + swingLow)/2; Premium = price > equilibrium. Reason: deterministic midpoint.

## 18. Discount

- **Definition:** The **lower half** of the current Dealing Range. Any price < the 50% equilibrium line is "in Discount."
- **Purpose:** In a **bullish** bias, long entries are sought in Discount (buy low).
- **Automatable?:** Yes. Difficulty 2/10. Mirror of Premium. Recommended: Discount = price < equilibrium. Reason: deterministic.

## 19. Breaker Block

- **Definition (TW, adopted):** A **Bullish Breaker** forms when a previously **bearish Order Block fails** (price closes beyond its far edge) and price then **breaks structure to the upside** (bullish BOS/CHoCH); the zone of that failed bearish OB becomes a support zone (Bullish Breaker). A **Bearish Breaker** is the mirror. The Breaker zone equals the original failed OB's high–low.
- **Purpose:** A secondary re-entry zone used when no fresh OB is available.
- **Automatable?:** Yes.
- **Automation difficulty:** 6/10.
- **Potential ambiguity:** The trigger sequence (fail → opposite BOS) must both occur; a failed OB without a subsequent opposite BOS is just a failed OB, not a Breaker.
- **Potential repaint risk:** Finalised only when the opposite BOS/CHoCH closes; not edited afterwards.
- **Potential look-ahead bias:** Same legitimate-historical-annotation caveat as OB.
- **Edge cases:** Multiple failed OBs before the opposite BOS → only the most recently failed one becomes the Breaker.
- **False signal scenarios:** Breakers are weaker than OBs; the project treats Breakers as **lower-priority** zones, used only when no valid OB exists in the correct Premium/Discount half.
- **Recommended deterministic implementation:** On OB invalidation, flag the zone as a candidate; if a subsequent opposite BOS/CHoCH is confirmed, promote the candidate to a Breaker tagged with the new bias.
- **Reason:** Reproducible promotion rule; keeps Breakers distinct from OBs.

## 20. Session

- **Definition:** Fixed UTC trading windows. For XAUUSD, two **active sessions** are defined (configurable, but fixed at deploy time):
  - **London session:** 07:00–10:00 UTC.
  - **New York AM session:** 12:00–15:00 UTC.
  Outside these windows, no new entries are opened (existing trades are still managed). The EA converts broker server time to UTC via a configured offset.
- **Purpose:** Restrict entries to the highest-probability, most liquid windows and avoid the low-liquidity periods where SMC patterns misfire.
- **Automatable?:** Yes.
- **Automation difficulty:** 4/10 (the only difficulty is the broker-time-to-UTC offset).
- **Potential ambiguity:** ICT Killzones shift with US DST; this project intentionally uses **fixed UTC** windows to avoid DST-driven non-determinism, accepting a small accuracy trade-off.
- **Potential repaint risk:** None.
- **Potential look-ahead bias:** None.
- **Edge cases:** Broker server time misconfiguration; bars that straddle a session boundary.
- **False signal scenarios:** Trading the dead zone between sessions; eliminated by the window rule.
- **Recommended deterministic implementation:** Maintain a configured **BrokerUTCOffset** parameter. Convert each closed-bar timestamp to UTC. New entries are allowed only when the bar close time falls inside an active session window.
- **Reason:** Fixed UTC + explicit offset is fully reproducible and immune to DST ambiguity.

## 21. Market Timing

- **Definition:** The combination of (a) being inside an active Session window **and** (b) requiring the entry signal to form on a **freshly closed** candle. Market Timing is the temporal gate that wraps the entry logic.
- **Purpose:** Ensures signals are acted on at the right time and only on confirmed (closed) data.
- **Automatable?:** Yes.
- **Automation difficulty:** 3/10.
- **Potential ambiguity:** Whether the "current" or "last closed" candle is used — always the **last closed** candle.
- **Potential repaint risk:** None (closed candle).
- **Potential look-ahead bias:** None (no future data).
- **Edge cases:** A signal that would have triggered but the session ended — it is discarded, not carried over.
- **False signal scenarios:** Acting on a still-forming candle; eliminated.
- **Recommended deterministic implementation:** Evaluate the full entry rule exactly once per LTF candle close, and only if that close time is inside an active session.
- **Reason:** Close-locked evaluation is the backbone of reproducibility.

## 22. Entry Confirmation

- **Definition:** A long entry is confirmed when **all** of the following are simultaneously true on the most recent closed LTF candle:
  1. HTF bias is **bullish** (per CHoCH/BOS state machine).
  2. A **valid, unmitigated Bullish OB** (or, failing that, a Bullish Breaker) exists in the current Dealing Range's **Discount** half.
  3. A **Bullish FVG** exists inside or overlapping that OB zone, OR the most recent liquidity event was an **SSL sweep** in Discount.
  4. The LTF has produced a **CHoCH to the upside** (body close above the most recent LTF Swing Low) **after** reaching the OB zone — i.e., LTF structure has shifted in the trade direction.
  5. The candle close time is inside an active Session.
  6. No position is currently open and the kill switch is not tripped.
  A short entry is the exact mirror in Premium with bearish conditions.
- **Purpose:** The single, all-conditions-must-be-true entry trigger.
- **Automatable?:** Yes.
- **Automation difficulty:** 7/10.
- **Potential ambiguity:** The order of checks and what "inside or overlapping" means for FVG/OB — defined as: the FVG zone and the OB zone share any price overlap.
- **Potential repaint risk:** None — every input is closed-candle based.
- **Potential look-ahead bias:** None — strictly past and current closed candles.
- **Edge cases:** Multiple OBs in the half; the **most recent unmitigated** one in the correct half is used.
- **False signal scenarios:** All confluences met but the move fails; inherent risk, managed by the 1:2 RR and the single-position rule, not by softening the rule.
- **Recommended deterministic implementation:** A pure boolean AND of the six conditions, evaluated once per LTF close. No partial scoring, no "almost" signals.
- **Reason:** A strict AND of closed-candle facts is the most deterministic possible trigger and removes all discretion.

## 23. Stop Loss Logic

- **Definition:** For a long, the stop loss is placed at the **far edge of the entry OB zone minus a fixed SL Buffer** points (i.e., below the OB low). For a short, the mirror: OB high plus SL Buffer. If the entry references a Breaker, the same logic uses the Breaker zone. The stop is set once at entry and is **not** widened afterwards.
- **Purpose:** Cap the risk per trade to a known, fixed structural distance.
- **Automatable?:** Yes.
- **Automation difficulty:** 2/10.
- **Potential ambiguity:** "Far edge" — for a long, the OB's low; for a short, the OB's high.
- **Potential repaint risk:** None at execution time.
- **Potential look-ahead bias:** None.
- **Edge cases:** OB zone so wide that the resulting risk exceeds a sanity cap — see Risk Protection; in that case the trade is **skipped** (not resized), because lot size is fixed at 0.01.
- **False signal scenarios:** Stop placed too tight (wicks out) — mitigated by SL Buffer constant.
- **Recommended deterministic implementation:** SL = OB far edge ∓ SL Buffer, computed at entry, sent as a fixed SL order.
- **Reason:** Structural stop tied to the same zone that justified entry; fully deterministic.

## 24. Take Profit Logic

- **Definition:** Take profit is set at **entry price + 2 × (entry price − stop loss)** for a long, and the mirror for a short. This enforces the locked **Risk : Reward = 1 : 2**.
- **Purpose:** Lock the fixed reward multiple.
- **Automatable?:** Yes. Difficulty 1/10. No repaint/look-ahead. Recommended: compute from the fixed SL distance at entry. Reason: enforces the project's hard 1:2 rule.

## 25. Break Even

- **Definition:** When price moves in favour by **1R** (i.e., by an amount equal to the initial risk = entry − SL distance), the stop loss is moved to the **entry price + Break-Even Buffer** points for a long (mirror for a short). This occurs at most once per trade.
- **Purpose:** Remove risk after price has travelled 1R.
- **Automatable?:** Yes.
- **Automation difficulty:** 3/10.
- **Potential ambiguity:** Whether BE uses 1R or some other distance — fixed at exactly 1R.
- **Potential repaint risk:** None.
- **Potential look-ahead bias:** None.
- **Edge cases:** Price gaps past 1R and straight to TP; BE may not have been applied — acceptable.
- **False signal scenarios:** BE then reversal to stop at no loss — by design.
- **Recommended deterministic implementation:** On each tick/closed candle after entry, if `unrealised favourable distance ≥ 1R` and BE not yet applied, modify SL to entry ∓ Break-Even Buffer. Set an internal flag so it happens once.
- **Reason:** 1R is objective and matches the RR framework.

## 26. Trailing Stop

- **Definition:** A **structural trailing stop** is used. After break-even has been applied, the stop is moved to each newly **confirmed** HTF Swing Low (for a long) / Swing High (for a short), but **never against the trade** (the new stop must be more favourable than the current stop) and never beyond the original 2R take-profit logic.
- **Purpose:** Let winners run while locking in gains structurally.
- **Automatable?:** Yes.
- **Automation difficulty:** 4/10.
- **Potential ambiguity:** Whether to trail on every swing or only major swings — every **confirmed HTF** swing.
- **Potential repaint risk:** None, because only confirmed swings are used.
- **Potential look-ahead bias:** None.
- **Edge cases:** A confirmed swing that is worse than the current stop → ignored.
- **False signal scenarios:** Premature trailing exit in strong trends — inherent, accepted.
- **Recommended deterministic implementation:** On each newly confirmed HTF swing in the trade direction, if the swing level improves on the current SL, move the SL to that swing ∓ SL Buffer.
- **Reason:** Structural trailing is deterministic and consistent with the structure engine.

## 27. Risk Protection

- **Definition:** A multi-layer protection system, all deterministic:
  1. **Fixed lot:** 0.01 always. No dynamic sizing.
  2. **One position:** maximum 1 simultaneous open trade.
  3. **No money-management tricks:** no martingale, grid, hedging, averaging, or recovery — ever.
  4. **Per-trade sanity cap:** if the OB-based stop distance implies a risk per trade greater than a configured **MaxRiskPerTradePoints** value, the trade is **skipped** (not resized).
  5. **Equity kill switch:** the EA tracks **Initial Balance** (set at EA start / on manual reset). If at any check **Equity ≤ 50% of Initial Balance**, the EA enters a **HALTED** state: no new trades are opened **permanently**, even if equity later recovers. The HALTED state is cleared **only** by an explicit manual reset by the user (which re-sets the Initial Balance reference).
- **Purpose:** Guarantee bounded, simple, recoverable-by-human-only risk.
- **Automatable?:** Yes.
- **Automation difficulty:** 3/10 (logic is simple; the discipline is in never adding exceptions).
- **Potential ambiguity:** What counts as "Equity" — the MT5 account equity at the check instant. What counts as "Initial Balance" — the account balance recorded at EA start or at the last manual reset.
- **Potential repaint risk:** None.
- **Potential look-ahead bias:** None.
- **Edge cases:** Open trade exists when the kill switch trips — the open trade is **still managed** (can be closed by SL/TP/BE/trail); only **new** entries are blocked. Gap moves that skip from >50% to <50% — the switch still trips at the first check.
- **False signal scenarios:** Equity dip caused by floating loss on the single open trade trips the switch — by design; this is the intended conservative behaviour.
- **Recommended deterministic implementation:** On every check cycle, compute equity ratio; if ≤ 0.5 and not already HALTED, set HALTED = true and persist it. Gate all new-entry logic on `HALTED == false`. Provide a manual reset input that sets HALTED = false and re-records Initial Balance.
- **Reason:** A single, persistent, human-only reset is the most robust guardrail and cannot be gamed by the strategy itself.

---

# Deterministic Rules

This section is the **operational core**: every threshold the EA will ever need, expressed as a named constant with a fixed value. No value here is chosen at runtime.

### Global constants

| Constant | Value (XAUUSD) | Meaning |
|---|---|---|
| HTF (Higher Timeframe) | M15 | Structure, OB, FVG, Premium/Discount, swings for bias and trailing |
| LTF (Lower Timeframe) | M1 | Entry CHoCH and execution |
| Swing Fractal Strength (SFS) | 2 bars each side | Swing High/Low confirmation window |
| Equal-Level Tolerance (ELT) | 20 points (~0.20 USD) | Max difference for EQH/EQL and sweep beyond-level |
| FVG Min Size | 10 points | Minimum imbalance to record an FVG |
| SL Buffer | 20 points | Extra distance beyond the OB/Breaker far edge for the stop |
| Break-Even Buffer | 5 points | Distance beyond entry for the break-even stop |
| MaxRiskPerTradePoints | 1500 points (~15.00 USD move) | Per-trade sanity cap; trades needing a wider stop are skipped |
| Lot Size | 0.01 (fixed) | Never changed |
| Risk : Reward | 1 : 2 (fixed) | Take-profit multiple |
| Max Open Positions | 1 | Hard cap |
| Equity Kill Threshold | 0.50 (50% of Initial Balance) | Kill-switch trigger |
| London Session (UTC) | 07:00–10:00 | Active entry window A |
| New York AM Session (UTC) | 12:00–15:00 | Active entry window B |
| BrokerUTCOffset | configured at deploy | Server-time → UTC offset |

### Decision rules (closed-candle, evaluated once per LTF close)

1. **Bias rule.** Bias = bullish iff the latest confirmed swing sequence is HH/HL and no CHoCH to the downside has occurred since; bias = bearish iff LH/LL with no CHoCH to the upside since; otherwise undefined → no trade.
2. **Swing rule.** Swings confirmed only with SFS = 2 strictly-greater/strictly-lower closed bars on each side.
3. **Structure-break rule.** BOS/CHoCH valid iff a closed HTF candle's **body close** is strictly beyond the referenced swing, in the relevant direction.
4. **OB rule.** On a confirmed BOS/CHoCH, the OB = last opposite-body candle before the impulse; zone = its high–low.
5. **Mitigation/invalidation rule.** Body enters zone → mitigated; body closes beyond far edge → invalidated.
6. **FVG rule.** 3 closed candles; bullish iff low3 > high1; bearish iff high3 < low1; recorded only if gap ≥ FVG Min Size.
7. **Premium/Discount rule.** Equilibrium = (rangeSwingHigh + rangeSwingLow)/2 using the active Dealing Range swings; Discount = price < equilibrium; Premium = price > equilibrium.
8. **Sweep rule.** Wick beyond active BSL/SSL by > ELT while close stays inside → sweep; the swept level is retired.
9. **Entry rule.** Strict AND of the six entry-confirmation conditions (see Entry Confirmation). Any false → no trade.
10. **Stop/TP rule.** SL = OB far edge ∓ SL Buffer; TP = entry ± 2 × risk. If risk > MaxRiskPerTradePoints → skip.
11. **Management rule.** At +1R, move SL to entry ± Break-Even Buffer (once). After BE, trail SL to each newly confirmed HTF swing in the trade direction, only if it improves the stop.
12. **Kill-switch rule.** Equity ≤ 50% of Initial Balance → HALTED = true (persisted). No new entries while HALTED. Manual reset only.

Every rule above references only **closed** candles and **fixed** constants, so identical data ⇒ identical output.

---

# Ambiguous Rules

The following points were **ambiguous or contested** in the references and have been **resolved once** here. They must **not** be re-litigated in later phases without owner approval.

| # | Ambiguity | Options considered | Decision | Justification |
|---|---|---|---|---|
| A1 | Naming of the reversal break | "MSS" (TW) vs "CHoCH" (QNE/BINUS) | **CHoCH** only | More widely recognised; one name prevents mixed terminology |
| A2 | What counts as a structure break | Wick break vs body close | **Body close** only | Filters wick noise; reproducible |
| A3 | Order Block strictness | "last opposite candle" vs TW's full conditions | **TW strict** | Most reproducible; agrees with QNE/BINUS in spirit |
| A4 | Mitigation definition | Wick touch vs body reach | **Body reach** | Consistent with close-based structure |
| A5 | "Liquidity" as concept vs level | Qualitative pool vs labelled price | **Labelled price level** | Automatable |
| A6 | Equal highs/lows tolerance | "approx equal" | **ELT = 20 points** fixed | Removes "feel" |
| A7 | Sweep beyond-level threshold | undefined | **> ELT beyond, close inside** | Deterministic |
| A8 | Session windows & DST | ICT shifting killzones | **Fixed UTC windows** | Immune to DST non-determinism |
| A9 | Breaker vs OB priority | equal vs OB-first | **OB first, Breaker fallback** | OBs are stronger per references |
| A10 | Break-even distance | various | **Exactly 1R** | Matches RR framework |
| A11 | Trailing method | ATR / fixed / structural | **Structural (confirmed swings)** | Consistent with structure engine |
| A12 | When OBs/Breakers may be edited | after creation | **Never edited after the confirming close** | Prevents repaint/look-ahead |
| A13 | Risk per trade when OB is wide | resize vs skip | **Skip** | Lot size is fixed at 0.01 |
| A14 | Kill-switch reset | auto vs manual | **Manual only** | Human-in-the-loop guardrail |
| A15 | "Almost" entries | score vs strict AND | **Strict AND** | No discretion |

---

# Edge Cases

Catalogue of inputs that would break naive logic, with the deterministic handling mandated above.

- **E1. Insufficient history.** Fewer than two confirmed HTF swings → bias undefined → no trade.
- **E2. Tie highs/lows within SFS window.** Strict inequality means no swing is recorded; no false pivot.
- **E3. Gap open beyond a structure level.** If the body closes beyond → valid BOS/CHoCH; if it gaps beyond but closes back inside → not a break.
- **E4. Impulse with no opposite-colour candle.** No OB is recorded for that move; no entry is taken from it.
- **E5. OB wider than MaxRiskPerTradePoints.** Trade skipped, not resized.
- **E6. Sweep and BOS on the same candle.** Classified by the close: if the close is beyond → BOS/CHoCH; if the close is inside → sweep. Never both.
- **E7. Overlapping FVGs.** Merged into one zone (outer bounds).
- **E8. Multiple OBs in the correct half.** The most recent unmitigated one is used.
- **E9. Session-boundary straddles.** A signal whose close time is outside the window is discarded.
- **E10. Broker-time misconfiguration.** Wrong BrokerUTCOffset shifts sessions; treated as a deployment error, surfaced by a sanity check (see Future Considerations), not auto-corrected.
- **E11. CHoCH immediately reversed by BOS.** Bias flips twice; both are recorded; the EA simply follows the latest bias.
- **E12. Kill switch trips with a trade open.** Open trade is still managed; only new entries are blocked.
- **E13. EA restart mid-trade.** HALTED state and Initial Balance must be persisted so restart cannot bypass the kill switch.
- **E14. Division/decimal on Premium/Discount.** Equilibrium is a midpoint; compare using the same price precision as quotes.

---

# False Signal Analysis

How each concept can fire wrongly, and the project's mitigation.

| Concept | False signal | Mitigation in this methodology |
|---|---|---|
| Swing | Noise pivots in chop | HTF (M15) + SFS = 2 |
| BOS | Wick-stop close that immediately reverses | Body-close + downstream filters |
| CHoCH | Stop-run close that reverses | Body-close + OB/FVG/session filters |
| OB | OB failure (price blows through) | Premium/Discount + LTF CHoCH + 1:2 RR + skip-if-wide |
| FVG | Micro-gaps that never fill | FVG Min Size |
| Liquidity sweep | Sweep then continuation | Sweep is a context filter, not an entry alone |
| Breaker | Weaker reactions than OB | Breaker is fallback only |
| Session | Trading illiquid hours | Fixed active windows |
| Entry | All-confluence-true but loss | Inherent; bounded by single position + kill switch |

The methodology deliberately accepts that **false signals will occur**; it bounds their cost (fixed 0.01, 1:2 RR, one position, 50% kill switch) rather than claiming to eliminate them.

---

# Automation Challenges

Feasibility and pitfalls of implementing the chosen rules in MQL5 on MT5 (Exness, XAUUSD). No code is produced here; only the challenges and how each is addressed deterministically.

1. **Closed-bar discipline.** MT5 allows reading the forming bar (shift 0). Every rule must read only **closed** bars (shift ≥ 1 on each timeframe). This is the single most important guard against repaint and look-ahead and is mandated across all rules.
2. **Swing confirmation latency.** A swing is only knowable SFS bars after it forms. The EA must never label or use a swing before the SFS right-side bars close. This is the canonical SMC look-ahead trap; handled by the confirmation rule.
3. **Two-timeframe synchronisation.** HTF (M15) and LTF (M1) must be read consistently. The EA evaluates on each LTF close and reads the latest **closed** HTF bar(s). Care must be taken that an HTF bar is only treated as closed once its own close has occurred.
4. **Broker server time vs UTC.** Exness MT5 server time is GMT+2/GMT+3 (shifts with DST). The EA uses a configured BrokerUTCOffset to convert to UTC for session windows. Because sessions are defined in fixed UTC, the only DST sensitivity is the offset itself, which is a deployment parameter.
5. **Point/price precision for XAUUSD.** XAUUSD quotes typically have 2 or 3 decimals on Exness; all point-based constants (ELT, FVG Min Size, buffers) are expressed in **points** relative to the symbol's `_Point`, and the sanity checks compare in the symbol's native precision.
6. **Persistence across restarts.** The HALTED flag, Initial Balance, and the open-trade state must survive an EA restart so the kill switch and one-position rules cannot be bypassed by reloading the EA.
7. **OB/Breaker immutability.** Zones must be stored as immutable records once their confirming BOS/CHoCH has closed; later code must never rewrite them (prevents repaint).
8. **Symbol/timeframe availability.** M1 and M15 history must be present and synchronised; gaps in history must not be silently interpolated (treated as "no signal" until clean history is available).
9. **Single-position enforcement under slippage/requotes.** The one-position rule must be checked at order-send time and again after fill, to avoid accidental double entries.
10. **Equity check frequency.** The kill switch must be evaluated often enough to catch a 50% drawdown promptly, but on a deterministic cadence (e.g., every tick or every closed LTF bar) so behaviour is reproducible.

---

# Recommended Implementations

This consolidates the *Recommended deterministic implementation* of every component into one place for the design phase to reference. Each item below is a plain-language rule (no code, no pseudo-code) that fully specifies behaviour.

- **Swings:** SFS = 2, strict inequality, confirmed only after right-side bars close, on HTF.
- **Structure state machine:** bullish (HH/HL) / bearish (LH/LL) / undefined; flips only on a CHoCH body close.
- **BOS/CHoCH:** closed HTF body close strictly beyond the referenced swing, in the relevant direction.
- **Liquidity:** two active levels (nearest BSL above, nearest SSL below) from confirmed swings/EQH/EQL.
- **EQH/EQL:** consecutive confirmed swings within ELT = 20 points.
- **Sweep:** wick beyond level by > ELT with close inside, on a closed candle; retire the level.
- **Order Block:** last opposite-body candle before a confirmed BOS/CHoCH impulse; zone = high–low; immutable after confirmation.
- **Mitigation/invalidation:** body enters zone → mitigated; body closes beyond far edge → invalidated.
- **FVG:** 3 closed candles, gap ≥ FVG Min Size; merge overlaps; fill on body trade-through.
- **Premium/Discount:** midpoint of the active Dealing Range; longs in Discount, shorts in Premium.
- **Breaker:** failed OB promoted on a subsequent opposite BOS/CHoCH; fallback zone only.
- **Session:** fixed UTC windows (London 07:00–10:00, NY AM 12:00–15:00) via BrokerUTCOffset.
- **Entry:** strict AND of the six conditions, evaluated once per LTF close.
- **Stop loss:** OB far edge ∓ SL Buffer; skip if distance > MaxRiskPerTradePoints.
- **Take profit:** entry ± 2 × risk.
- **Break even:** at +1R, SL → entry ± Break-Even Buffer, once.
- **Trailing:** after BE, SL → each newly confirmed HTF swing in the trade direction, if it improves the stop.
- **Risk protection:** fixed 0.01, one position, no money-management tricks, MaxRiskPerTradePoints skip, 50%-equity manual-reset kill switch with persisted HALTED state.

---

# Project Assumptions

These are the assumptions the methodology depends on. They must be confirmed or revisited before the design phase.

1. **Symbol behaviour:** XAUUSD on Exness Standard provides continuous M1 and M15 data with 2–3 decimal pricing and stable `_Point`/contract specs. Assumed stable for the project lifetime.
2. **Timeframe choice:** HTF = M15, LTF = M1 are assumed appropriate for XAUUSD intraday SMC. These are documented constants and can be revised by the owner.
3. **Broker time:** A correct BrokerUTCOffset is provided at deployment. DST handling is the deployer's responsibility; sessions are fixed in UTC.
4. **Point sizes:** All point constants assume Exness XAUUSD `_Point`. If the symbol spec changes, constants must be reviewed.
5. **Account currency:** Risk/RR are expressed in price-distance terms; P&L currency conversion is assumed linear and not part of the strategy logic.
6. **Single instrument:** Only XAUUSD is in scope. Cross-symbol correlations are out of scope.
7. **Deterministic data:** Back-testing assumes deterministic, replayable tick/bar history (MT5 tester assumption).
8. **Manual reset availability:** A human can reset the kill switch; the EA never auto-resets.
9. **No partial fills complexity:** For a 0.01 lot on XAUUSD, partial-fill edge cases are assumed negligible; the one-position rule is enforced post-fill regardless.
10. **Reference stability:** The three references' definitions are treated as fixed; this document freezes their interpretation.

---

# Limitations

Honest scope limits of this document and the methodology it defines.

1. **Not a profitability proof.** This document defines a *deterministic* strategy, not a *winning* one. Win rate and expectancy can only be established by back-/forward-testing, which is out of scope here.
2. **Simplified sessions.** Fixed UTC windows approximate ICT Killzones and ignore DST micro-shifts; some high-probability windows may be missed or slightly mistimed.
3. **Single confluence model.** Only OB + FVG (+ sweep) + LTF CHoCH + Premium/Discount are used. Other ICT tools (OTE, PD Arrays, Silver Bullet, specific killzones) are intentionally excluded for determinism.
4. **Fixed lot, fixed RR.** No compounding, no dynamic sizing, no adaptive RR — by design. This caps both upside and downside.
5. **Structural stop distance variability.** OB widths vary, so real per-trade risk varies in price terms; bounded only by the skip rule, not normalised.
6. **No regime filter.** The strategy does not detect "ranging vs trending" regimes; it follows structure mechanically.
7. **One instrument, one timeframe pair.** Generalisation to other symbols/timeframes is not validated here.
8. **Reference bias.** Definitions lean on TW as tie-breaker; alternative valid SMC schools exist and are intentionally not adopted.
9. **Kill switch is blunt.** A 50% equity halt is conservative and may stop trading after a single bad sequence; recovery requires human action.
10. **No news/economic-event handling.** The methodology is purely price-action; news-driven dislocations are unhandled except via the fixed risk controls.

---

# Future Considerations

Items deliberately deferred to later phases or owner decisions. They are recorded so they are not lost, but are **out of scope** for DOC00.

1. **Back-test and forward-test plan** to measure actual win rate, expectancy, drawdown, and to tune constants (SFS, ELT, FVG Min Size, buffers, session windows) within the deterministic framework. Tuning must preserve determinism (fixed values, no runtime adaptation).
2. **BrokerUTCOffset auto-detection** or a deployment sanity check that warns if server time is inconsistent with expected Exness time.
3. **Additional ICT concepts** (OTE, PD Arrays, Power of Three labels) as optional deterministic extensions, only if back-testing justifies them.
4. **Slippage/spread model** for realistic testing on XAUUSD during session opens.
5. **Reporting/logging schema** so every signal, zone, and management action is auditable and reproducible.
6. **Multi-symbol generalisation** review if the methodology is later applied beyond XAUUSD.
7. **Regime/seasonality study** to decide whether a deterministic regime gate is worth adding.
8. **Equity-kill refinement** — e.g., whether the 50% threshold or the manual-reset policy should be parameterised (owner decision).

---

# Self Review Result

Before finalising, the document was checked against the self-review checklist. Findings and fixes:

- **Logical contradictions:** None found. CHoCH/BOS, OB/Breaker, mitigation/invalidation are mutually exclusive and consistently ordered. *(Pass)*
- **Conflicting terminology:** The CHoCH-vs-MSS naming conflict was resolved by standardising on CHoCH and banning "MSS" (see A1). *(Fixed)*
- **Subjective decisions:** Every threshold that could be subjective (equal-level tolerance, sweep threshold, break-even distance, trailing method) is now a named constant (see A6, A7, A10, A11, Deterministic Rules). *(Fixed)*
- **Undefined concepts:** "Liquidity," "Dealing Range," "far edge," "mitigation vs invalidation," "inside or overlapping" were all given precise definitions. *(Fixed)*
- **Incomplete definitions:** Mitigation Block and Breaker Block, which QNE/BINUS left thin, were completed from TW. *(Fixed)*
- **Rules that cannot be automated:** None remain. Every rule is closed-candle and constant-based. *(Pass)*
- **Rules depending on human judgement:** The only human-in-the-loop step is the **manual kill-switch reset**, which is intentional and documented. Entry, management, and risk rules require no judgement. *(Pass)*
- **Rules producing inconsistent outputs:** The closed-candle + fixed-constant discipline guarantees identical inputs ⇒ identical outputs. The main residual risks (forming-bar evaluation, swing look-ahead, zone editing after creation) are explicitly banned (see Automation Challenges and Edge Cases). *(Pass)*

**Outcome:** No blocking issues remain. The document is internally consistent, fully deterministic, and ready to serve as the authoritative specification.

---

# Final Recommendations

1. **Adopt this document as the sole source of truth** for all subsequent phases (design, coding, testing). Any deviation must be raised as a formal change to DOC00.
2. **Freeze the constants** in *Deterministic Rules* before design begins. Tuning happens only later, via documented back-testing, and any new value becomes a new frozen constant.
3. **Enforce closed-bar discipline as the #1 engineering rule.** Every SMC bug class worth fearing (repaint, look-ahead, forming-bar acting) comes from violating it.
4. **Make the kill switch the most defensively-implemented feature** — persisted, manual-reset-only, checked on a deterministic cadence, and bypass-proof across restarts.
5. **Treat Breakers as fallback only** and never as a primary zone; back-testing should confirm whether they add value at all.
6. **Validate the session windows against Exness XAUUSD behaviour** early in testing; adjust the fixed UTC windows (not the methodology) if data justifies it.
7. **Log everything deterministically**: every swing, BOS/CHoCH, OB, FVG, sweep, entry check, and management action should be reconstructable from logs, so that any back-test result can be explained bar-by-bar.
8. **Do not add complexity without proof.** Any future ICT addition must (a) be expressible deterministically and (b) improve measured expectancy — otherwise it is rejected.
9. **Re-confirm the assumptions** in *Project Assumptions* with the owner before the design phase, especially the timeframe pair, the BrokerUTCOffset handling, and the 50% kill-switch policy.
10. **Carry this document's terminology unchanged** into every later document and into all code symbol names, so that "CHoCH," "OB," "FVG," "Dealing Range," "Premium/Discount," and the named constants mean exactly what they mean here — nothing more, nothing less.
