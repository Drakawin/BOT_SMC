# DOC02A — Market Structure Engine: Foundation
## Swing Detection and Structure Labelling (H1 + H4)

> **Document status:** AUTHORITATIVE — Official specification for the Market Structure Engine **foundation only**.
> **Phase:** Module Specification (Phase 2, Part A).
> **Scope of this document:** Swing High, Swing Low, Swing Detection, Swing Confirmation, Higher High (HH), Higher Low (HL), Lower High (LH), Lower Low (LL), and the swing-sequence structure labelling state machine.
> **Explicitly out of scope (future documents):** BOS, CHoCH, Order Block, Liquidity, Fair Value Gap, and the live trading-bias flip mechanism. Those are not defined, referenced for behaviour, or implemented here.
> **Relationship to prior documents:**
> - Implements the swing/structure rules approved in **DOC00_Strategy_Validation.md** (§1 Market Structure, §2 Swing High, §3 Swing Low, §4–§7 HH/HL/LH/LL) **without modification**.
> - Conforms to **DOC00_PATCH_001.md**: swings are detected on the **Market Structure Timeframe (H1)**; the swing-sequence classification is also the basis of the **Primary Trend Timeframe (H4)** bias (H4 permits swing-based classification but no BOS/CHoCH/OB/FVG).
> - Realises the **Market Structure Engine** module defined in **DOC01_System_Architecture.md** (Layer 2), respecting its write-ownership of the *Structure* section of the Structural Context.
> **Priority rule:** If anything in this document appears to conflict with DOC00 or PATCH_001, those documents prevail. DOC02A governs only the foundation details of swing detection and structure labelling.

---

# Reported Items (reported, not changed)

Per the standing instruction to *report* rather than silently change, the following scoping notes are flagged. None contradicts an approved document; they are clarifications required to keep DOC02A internally consistent with DOC00.

| # | Item | Status |
|---|---|---|
| R-1 | DOC00 defines the trading **bias** as flipping only on a **CHoCH** body-close, while DOC00 §1 *Market Structure* defines bullish/bearish **structure** as the HH/HL or LH/LL swing sequence. These are two distinct concepts. DOC02A specifies **only the swing-sequence structure labelling**. How that labelling becomes the live trading bias, and how CHoCH reversals reconcile with it, is owned by the future BOS/CHoCH document and DOC00. DOC02A does **not** define bias flips. | Reported — no change to DOC00. |
| R-2 | PATCH_001 assigns **H4 = bias only** (no BOS/CHoCH/OB/FVG) and **H1 = structure detection**. Swing-sequence classification (HH/HL/LH/LL) is permitted on **both** H4 (as the bias basis) and H1 (as the structure basis), because it uses only swings — which is consistent with PATCH_001's "H4: determine Bullish/Bearish only." DOC02A specifies swing detection once and notes it runs on both timeframes per PATCH_001 roles. | Reported — consistent with PATCH_001. |
| R-3 | DOC00 specifies the comparison for HH/HL/LH/LL as "previous confirmed swing." DOC02A defines "previous confirmed swing high/low" precisely as **the most recent confirmed swing of the same type** (a swing high is compared only to the previous swing high; a swing low only to the previous swing low). This is the only interpretation consistent with DOC00 §4 (HH) and §6 (HL). | Reported — clarification, no contradiction. |

No DOC00, PATCH_001, or DOC01 content was modified.

---

# Conformance Summary

This document reproduces **no new SMC definition**. Every definition below is the DOC00 definition stated with full operational detail. The DOC00 constants in force are:

| Constant | Value | Source |
|---|---|---|
| Swing Fractal Strength (SFS) | **2** candles on each side | DOC00 §2, §3 |
| Market Structure Timeframe | **H1** | PATCH_001 |
| Primary Trend Timeframe | **H4** | PATCH_001 |
| Comparison operator for HH/HL/LH/LL | **strict** (`>` / `<`); ties are never HH/HL/LH/LL | DOC00 §4–§7 |
| Closed-bar requirement | swings confirmed only after SFS right-side candles have **closed** | DOC00 §2, §3 |

---

# Topic 1 — Swing High

- **Definition:** A **confirmed Swing High** is a closed candle whose **high** is **strictly greater than** the highs of the **SFS = 2** candles immediately to its left **and** the SFS = 2 candles immediately to its right. The candle is labelled a Swing High **only after** the right-side SFS candles have closed. (DOC00 §2, unchanged.)
- **Purpose:** Provide a confirmed, immutable pivot that anchors structure labelling (this document), and downstream (future docs) liquidity, Order Block ranges, and Premium/Discount range tops.
- **Why it exists:** Structure cannot be measured without objective turning points. The fractal rule turns "a top" into a precise, repeatable, falsifiable event rather than a visual judgement.
- **Relation with DOC00:** This is DOC00 §2 reproduced with operational detail. No semantic change.
- **Relation with DOC01:** Produced by the **Market Structure Engine** (DOC01 Layer 2), written into the *Structure* section of the **Structural Context**. It is the sole writer of swing-high records. Other modules read swing highs only from the context.
- **Inputs:** Closed candles of the structure timeframe (H1 for structure; H4 for the trend classification per R-2), specifically the high prices of a candidate candle and its SFS left/right neighbours.
- **Outputs:** A **Swing High record**: timestamp (bar open or close time of the centre candle, fixed choice — bar **close** time), the high price, the timeframe, and a confirmation time (the close time of the SFS-th right-side candle).
- **Dependencies:** Market Data Access (DOC01) for closed candles; Utility for time/precision. No dependency on any other detection engine.
- **Deterministic Rules:**
  1. Only **closed** candles may participate.
  2. SFS = 2 candles must exist on **both** sides of the candidate.
  3. The candidate's high must be **strictly greater than** each of the SFS left highs and each of the SFS right highs (strict inequality; no `≥`).
  4. A tie (equal high) disqualifies the candidate (see Equal High handling below and in the Swing Detection section).
  5. A candidate becomes a confirmed Swing High exactly when the SFS-th right-side candle **closes**.
  6. Once confirmed, the Swing High record is **immutable**.
- **Validation Rules:**
  - The centre candle and all SFS×2 = 4 neighbour candles must be present and closed; otherwise no confirmation.
  - The recorded price must equal the centre candle's actual high (no rounding).
  - The confirmation timestamp must be ≥ the centre candle's close time + SFS bars.
- **Edge Cases:**
  - Fewer than SFS right-side candles available yet → not confirmed (pending).
  - Equal highs within the window → no Swing High (strict inequality).
  - A very long candle that exceeds neighbours by a wide margin → still a valid Swing High (magnitude is irrelevant).
  - Two adjacent candidate centres both satisfy the rule → each is evaluated independently; both can be confirmed if each independently satisfies strict dominance over its own window.
- **Failure Cases:**
  - History gap removes a neighbour → candidate cannot be confirmed; left pending until history is continuous, then re-evaluated.
  - Market Data Access returns a non-closed candle → must be rejected by the closed-bar guard; no confirmation occurs.
- **False Detection Cases:**
  - Minor fractal tops in choppy, low-volatility ranges produce many low-significance Swing Highs. This is **inherent** to SFS = 2; mitigated by the H1 timeframe (PATCH_001) and downstream filters, **not** by changing the swing rule.
  - Acting on a still-forming candidate (treating an unconfirmed pivot as a swing) → strictly forbidden by the closed-bar confirmation rule.
- **Automation Challenges:**
  - Enforcing closed-bar discipline at a single chokepoint (DOC01 Market Data Access) so no path can read a forming bar.
  - Guaranteeing immutability after confirmation so later code cannot rewrite a swing.
  - Handling the "pending candidate" lifecycle without ever exposing an unconfirmed swing to consumers.
- **Recommended Solution:** Maintain a **pending candidate** for the most recent SFS bars; promote to a confirmed, immutable Swing High record the instant the SFS-th right-side candle closes; publish only confirmed records to the Structural Context. Consumers never see pending candidates.
- **Computational Complexity:** Per new closed bar: **O(SFS) = O(1)** comparisons to test the candidate centred SFS bars ago. Initialisation (cold start): **O(N·SFS) = O(N)** over a lookback of N bars. (Complexity analysis only; no algorithm is specified.)
- **Data Required:** Closed high prices for the structure timeframe, with a bounded lookback sufficient to confirm the most recent candidate (≥ SFS closed bars beyond the latest candidate) plus an initialisation window.
- **Memory Requirement:** Bounded: one record per confirmed Swing High, pruned to a fixed retention depth (e.g., the most recent M confirmed swings). Pending-candidate state is at most SFS entries. Constant per-bar working memory.
- **Update Frequency:** Evaluated **once per closed bar** of the structure timeframe (H1) — and, for trend classification, once per closed H4 bar. Never on ticks.

---

# Topic 2 — Swing Low

- **Definition:** A **confirmed Swing Low** is a closed candle whose **low** is **strictly lower than** the lows of the SFS = 2 candles immediately to its left and to its right, confirmed only after the right-side SFS candles have closed. (DOC00 §3, unchanged; mirror of Swing High.)
- **Purpose:** Provide a confirmed, immutable pivot that anchors structure labelling (this document) and, downstream (future docs), liquidity, Order Block ranges, and Premium/Discount range bottoms.
- **Why it exists:** Symmetric counterpart to Swing High. Lows cannot be inferred from highs; an independent, objective rule is required for bottoms.
- **Relation with DOC00:** DOC00 §3 reproduced with operational detail. No semantic change.
- **Relation with DOC01:** Produced by the **Market Structure Engine**, written to the *Structure* section of the Structural Context. Sole writer of swing-low records.
- **Inputs:** Closed candles of the structure timeframe (H1; H4 for trend), specifically the low prices of a candidate candle and its SFS left/right neighbours.
- **Outputs:** A **Swing Low record**: bar close time of the centre candle, the low price, the timeframe, and a confirmation time (close time of the SFS-th right-side candle).
- **Dependencies:** Market Data Access; Utility. No other engine dependency.
- **Deterministic Rules:**
  1. Only closed candles participate.
  2. SFS = 2 candles must exist on both sides.
  3. The candidate's low must be **strictly lower than** each of the SFS left lows and each of the SFS right lows (strict inequality; no `≤`).
  4. A tie (equal low) disqualifies the candidate.
  5. Confirmation occurs exactly when the SFS-th right-side candle closes.
  6. Once confirmed, the Swing Low record is immutable.
- **Validation Rules:** Mirror of Swing High: neighbour presence/closure, exact recorded price, confirmation-timestamp sanity.
- **Edge Cases:** Insufficient right-side bars (pending); equal lows within the window (no swing); a very long down-candle (still valid); adjacent candidates each evaluated independently.
- **Failure Cases:** History gap; non-closed candle supplied — both block confirmation.
- **False Detection Cases:** Minor fractal bottoms in choppy ranges (inherent to SFS = 2; mitigated by timeframe and downstream filters); acting on a pending candidate (forbidden).
- **Automation Challenges:** Identical to Swing High: closed-bar discipline, immutability, pending-candidate lifecycle.
- **Recommended Solution:** Mirror of Swing High: pending candidate → immutable confirmed Swing Low record on the SFS-th right-side candle close; publish only confirmed records.
- **Computational Complexity:** O(1) per new closed bar; O(N) initialisation (complexity analysis only).
- **Data Required:** Closed low prices for the structure timeframe, bounded lookback.
- **Memory Requirement:** One record per confirmed Swing Low, pruned to a fixed retention depth; at most SFS pending entries.
- **Update Frequency:** Once per closed bar of the structure timeframe (H1; H4 for trend). Never on ticks.

---

# Topic 3 — Swing Detection

This section defines the **detection process** that produces Swing Highs and Swing Lows. It specifies the exact conditions and the reasons for each. (Process specification only — no algorithm, pseudo-code, or flowchart.)

- **Definition:** Swing Detection is the process of identifying candidate fractal centres on the structure timeframe and confirming them as Swing Highs or Swing Lows once the closed-bar and SFS conditions are met.
- **Purpose:** Convert raw closed candles into a labelled, immutable sequence of confirmed swings that all downstream logic consumes.
- **Why it exists:** A single, reproducible detection process is the only way to guarantee that identical data yields identical swings.
- **Relation with DOC00:** Operationalises DOC00 §2 and §3. No change to the definitions.
- **Relation with DOC01:** Implemented inside the Market Structure Engine; reads only from Market Data Access (the closed-bar chokepoint); writes only to the *Structure* section.
- **Inputs:** Closed OHLC candles of the structure timeframe (high and low series) with a bounded lookback.
- **Outputs:** The confirmed Swing High and Swing Low sequences for the timeframe.
- **Dependencies:** Market Data Access (closed candles); Utility (time/precision).
- **Deterministic Rules:**
  1. **Closed-candle requirement:** Only candles whose bar has fully closed may participate in detection, as a centre or as a neighbour. The forming (current) candle is never used.
  2. **Fractal confirmation:** A candidate centre is a Swing High iff its high strictly exceeds all four neighbour highs (SFS = 2 left + 2 right); a Swing Low iff its low is strictly below all four neighbour lows.
  3. **Asymmetry of centre vs. confirmation:** The centre candle is *identified* once it has closed, but it is only *confirmed* SFS bars later, when its right-side neighbours have also closed.
  4. **Immutability:** A confirmed swing is never relabelled, moved, or deleted by detection (deletion only via retention pruning of the oldest records, never of recent ones).
- **Validation Rules:** A swing is valid only if (a) centre and all neighbours are closed, (b) strict inequality holds against every neighbour, (c) confirmation time is consistent with SFS.
- **Edge Cases:** Pending candidates whose confirmation is delayed by a history gap; two centres within SFS bars of each other (each evaluated against its own window); identical neighbour values creating a tie.
- **Failure Cases:** Missing neighbour candle; non-closed candle supplied; lookback shorter than SFS beyond the latest candidate.
- **False Detection Cases:** Treating a visual top as a swing before confirmation; using `≥`/`≤` instead of strict `>`/`<` (would create false swings on ties); reading the forming candle's high/low (would create repaint-prone, non-deterministic swings.
- **Automation Challenges:** Guaranteeing the closed-bar guard is the *only* entry point for candle data; preventing any consumer from reading pending candidates; keeping the pending set bounded.
- **Recommended Solution:** Detection runs once per closed bar; it inspects exactly the candidate whose centre closed SFS bars ago (now confirmable) and either promotes it to a confirmed swing or discards it. Only confirmed swings are published.
- **Computational Complexity:** O(1) per closed bar; O(N) at initialisation.
- **Data Required:** Closed high and low series of the structure timeframe; bounded lookback ≥ SFS beyond the latest candidate plus an initialisation window.
- **Memory Requirement:** Bounded confirmed-swing lists + at most SFS pending candidates.
- **Update Frequency:** Once per closed bar of the structure timeframe.

### Swing Detection — Detailed Explanations

- **Closed candle requirement.** A candle is "closed" only after its timeframe period has elapsed and MT5 reports it as a historical (non-forming) bar. Detection uses closed bars exclusively. This is the single rule that eliminates repaint and look-ahead at the source. The forming bar's high/low can change tick-to-tick; a closed bar's OHLC is final.

- **Fractal confirmation.** "Fractal" here means a local extreme over a fixed symmetric window of SFS candles on each side. The centre is confirmed as a swing only if it **strictly dominates** (high) or **is strictly dominated by** (low) every one of the SFS×2 neighbours. Symmetry (equal count left and right) is mandatory; an asymmetric window would make the rule timeframe- and direction-dependent and break determinism.

- **Why SFS = 2.** SFS = 2 is the value locked by DOC00. Rationale it satisfies: (a) it is the smallest symmetric window that filters single-bar noise (a 1-bar spike is absorbed), (b) it is large enough to be meaningful on H1/H4 for XAUUSD yet small enough to detect the swings that matter intraday, (c) it is a fixed constant — not adaptive — so results never depend on volatility or any runtime parameter. SFS is **not** a tunable in this document; changing it requires a formal DOC00 revision.

- **Why future candles are required.** A swing is, by definition, a point that is *higher/lower than what came after it*. Therefore the SFS candles to the right are part of the definition, not an optimisation. Without them, every local tick-high would momentarily qualify. The right-side requirement is what makes a swing a swing.

- **Why repaint does NOT occur (by construction).** Repaint means a signal changes after it first appears. Under these rules a swing is **published only once**, at the exact close of the SFS-th right-side candle, using only closed (final) data. Before that moment, no swing exists for consumers. After that moment, the record is immutable. Therefore there is no prior "appearance" to change. The only apparent "change" a naive observer might see — a candidate that looks like a swing but later fails — is **never published** in the first place, so it is not a repaint.

- **How to avoid look-ahead bias.** Look-ahead would mean using information not yet available at the decision time. The rule avoids it by two invariants: (1) detection and all consumers operate strictly on **closed** bars, and (2) a swing is dated at its **centre candle's close time** but only **acted upon** at or after its **confirmation time** (centre close + SFS bars). Any downstream consumer must reference swings by their confirmation time, not their centre time, when deciding what was "known." This separation is what prevents the canonical SMC error of treating a swing as if it were known the moment its centre formed.

- **Equal High handling.** If the candidate's high equals any neighbour's high (a tie), the strict-inequality test fails and **no Swing High** is produced for that centre. Equal highs are not discarded — they are relevant to liquidity (Equal Highs / EQH, future document) — but they are **not swings**. DOC00 §4 confirms: equal consecutive swing highs are classified as Equal Highs, not HH. Within detection, a tie simply yields no swing at that centre.

- **Equal Low handling.** Mirror of Equal High: a tie at the low disqualifies the centre as a Swing Low. Equal lows are not swings; they belong to liquidity (Equal Lows / EQL, future document). Detection records no swing on a tie.

---

# Topic 4 — Swing Confirmation

- **Definition:** Swing Confirmation is the single event that converts a pending swing candidate into an immutable, published Swing High/Low. It occurs at the **close of the SFS-th candle to the right** of the candidate centre.
- **Purpose:** Define the exact, unambiguous instant at which a swing becomes real for all consumers, and guarantee it cannot change afterwards.
- **Why it exists:** Without a precise confirmation instant, "when is a swing valid?" becomes a judgement call. Pinning it to a specific closed bar removes all ambiguity.
- **Relation with DOC00:** DOC00 §2/§3 state swings are "evaluated only after the right-hand candles have closed" and "confirmed only after the right-hand candles close." DOC02A names that event **Swing Confirmation** and fixes its instant. No semantic change.
- **Relation with DOC01:** Confirmation is the event that makes a swing eligible to be written to the Structural Context. Before confirmation, nothing is written to the context for that candidate.
- **Inputs:** The pending candidate and the close status of its SFS right-side candles.
- **Outputs:** A confirmed Swing High/Low record (immutable) with a confirmation timestamp.
- **Dependencies:** Market Data Access (closed-bar status); Utility (timestamps).
- **Deterministic Rules:**
  1. Confirmation happens **exactly once** per candidate.
  2. Confirmation happens **only** when all SFS right-side candles are closed.
  3. Confirmation requires the strict-inequality fractal test to hold at the moment of confirmation (re-validated against final neighbour values).
  4. After confirmation, the record is immutable; no later bar can un-confirm it.
  5. A candidate that fails the test at confirmation is discarded silently (it was never published).
- **Validation Rules:** Confirmation timestamp = close time of the SFS-th right-side candle; the record's centre timestamp precedes it by exactly SFS bars; the strict test holds against the finalised neighbours.
- **Edge Cases:** A candidate whose right-side candles include a history gap — confirmation is deferred until the gap is filled and all SFS right-side candles are present and closed; if history cannot be made continuous, the candidate is never confirmed.
- **Failure Cases:** Confirmation attempted on a non-closed candle (must be blocked); strict test fails at the confirmation instant (candidate discarded).
- **False Detection Cases:** Publishing a candidate before the SFS-th right-side candle closes (forbidden); re-evaluating an already-confirmed swing and changing it (forbidden by immutability).
- **Automation Challenges:** Ensuring the "publish" step is atomic relative to consumers (consumers must never observe a half-published swing); ensuring immutability is enforced by data structure, not by convention.
- **Recommended Solution:** On each closed bar, identify the candidate (if any) whose SFS-th right-side candle just closed; apply the strict test against finalised neighbours; on success, publish one immutable record; on failure, drop the candidate. No partial states are ever exposed.
- **Computational Complexity:** O(1) per closed bar (one candidate, SFS comparisons).
- **Data Required:** Closed high/low of the candidate centre and its SFS right-side candles.
- **Memory Requirement:** One immutable record per confirmed swing (bounded by retention); at most SFS pending candidates.
- **Update Frequency:** Once per closed bar of the structure timeframe.

---

# Topic 5 — Higher High (HH)

- **Definition:** A confirmed Swing High whose price is **strictly greater than** the price of the **previous confirmed Swing High**. (DOC00 §4, unchanged.) "Previous confirmed Swing High" = the most recent confirmed Swing High recorded **before** this one, regardless of any intervening Swing Lows (R-3).
- **Purpose:** Building block of bullish structure; one of the two signals (with HL) required to classify structure as bullish.
- **Why it exists:** Objectively encodes "tops are rising," which is the definition of bullish structure in DOC00 §1.
- **Relation with DOC00:** DOC00 §4 reproduced. Strict inequality; equal highs are **not** HH (they are Equal Highs, future doc).
- **Relation with DOC01:** Computed by the Market Structure Engine and stored as a label on the Swing High record within the *Structure* section.
- **Inputs:** The newly confirmed Swing High price; the previous confirmed Swing High price.
- **Outputs:** A boolean HH label attached to the new Swing High.
- **Dependencies:** Swing Detection/Confirmation (this document).
- **Deterministic Rules:**
  1. Only **confirmed** swing highs are compared.
  2. Comparison is **strict** `>`; ties produce no HH label.
  3. The comparison uses the most recent prior confirmed Swing High.
  4. The HH label is assigned at the Swing High's confirmation instant and is immutable.
- **Validation Rules:** Both swings confirmed; prices taken from the respective centre highs without rounding; strict inequality satisfied.
- **Edge Cases:** First confirmed Swing High has no predecessor → no HH/LH label (structure still "unknown," see Market Structure). Equal to predecessor → no HH (Equal High territory). A new high that equals a much older (non-adjacent) swing high → irrelevant; only the immediately preceding confirmed Swing High is compared.
- **Failure Cases:** Missing previous swing record (data retention pruned it) → no HH label can be computed; structure labelling must handle "previous unknown."
- **False Detection Cases:** Using `≥` (would mislabel equals as HH); comparing to a non-adjacent older high (would misclassify the trend).
- **Automation Challenges:** Ensuring the "previous" pointer always refers to the immediately preceding confirmed swing of the same type; handling the first-swing (no predecessor) case deterministically.
- **Recommended Solution:** Maintain an ordered list of confirmed Swing Highs; on each new confirmation, compare to the last entry with strict `>`; assign and freeze the label.
- **Computational Complexity:** O(1) per swing confirmation (one comparison).
- **Data Required:** The new and the previous confirmed Swing High prices.
- **Memory Requirement:** The confirmed Swing High list (bounded retention; must retain at least the previous entry).
- **Update Frequency:** Evaluated at each Swing High confirmation.

---

# Topic 6 — Higher Low (HL)

- **Definition:** A confirmed Swing Low whose price is **strictly greater than** the price of the previous confirmed Swing Low. (DOC00 §6, unchanged.) "Previous confirmed Swing Low" = the most recent confirmed Swing Low before this one.
- **Purpose:** Building block of bullish structure; the second signal (with HH) required to classify structure as bullish. "Lows are rising."
- **Why it exists:** DOC00 §1 defines bullish structure as HH **and** HL; HL is the lows-rising half.
- **Relation with DOC00:** DOC00 §6 reproduced. Strict inequality; equal lows are not HL.
- **Relation with DOC01:** Computed by the Market Structure Engine; stored as a label on the Swing Low record in *Structure*.
- **Inputs:** The newly confirmed Swing Low price; the previous confirmed Swing Low price.
- **Outputs:** A boolean HL label attached to the new Swing Low.
- **Dependencies:** Swing Detection/Confirmation.
- **Deterministic Rules:** Mirror of HH with strict `>` against the immediately preceding confirmed Swing Low; immutable at confirmation; ties produce no HL.
- **Validation Rules:** Both swings confirmed; exact prices; strict inequality.
- **Edge Cases:** First confirmed Swing Low (no predecessor) → no HL/LL label; equal to predecessor → no HL (Equal Low territory, future doc).
- **Failure Cases:** Previous swing record pruned → label "previous unknown."
- **False Detection Cases:** Using `≥`; comparing to a non-adjacent low.
- **Automation Challenges:** Same as HH for the "previous" pointer and first-swing handling.
- **Recommended Solution:** Maintain an ordered list of confirmed Swing Lows; compare new vs last with strict `>`; freeze the label.
- **Computational Complexity:** O(1) per swing confirmation.
- **Data Required:** New and previous confirmed Swing Low prices.
- **Memory Requirement:** Confirmed Swing Low list (bounded; retain at least previous).
- **Update Frequency:** At each Swing Low confirmation.

---

# Topic 7 — Lower High (LH)

- **Definition:** A confirmed Swing High whose price is **strictly less than** the price of the previous confirmed Swing High. (DOC00 §6/§7 pattern, unchanged.) "Previous confirmed Swing High" = the most recent confirmed Swing High before this one.
- **Purpose:** Building block of bearish structure; one of the two signals (with LL) to classify structure as bearish. "Tops are falling."
- **Why it exists:** DOC00 §1 defines bearish structure as LH **and** LL; LH is the tops-falling half.
- **Relation with DOC00:** DOC00 §6/§7 reproduced. Strict inequality; equal highs are not LH.
- **Relation with DOC01:** Computed by the Market Structure Engine; label on the Swing High record.
- **Inputs:** Newly confirmed Swing High price; previous confirmed Swing High price.
- **Outputs:** A boolean LH label attached to the new Swing High.
- **Dependencies:** Swing Detection/Confirmation.
- **Deterministic Rules:** Strict `<` against the immediately preceding confirmed Swing High; immutable at confirmation; ties produce no LH.
- **Validation Rules:** Both swings confirmed; exact prices; strict inequality.
- **Edge Cases:** First confirmed Swing High → no label; equal to predecessor → no LH (Equal High territory).
- **Failure Cases:** Previous swing record pruned → "previous unknown."
- **False Detection Cases:** Using `≤`; comparing to a non-adjacent high.
- **Automation Challenges:** Same as HH.
- **Recommended Solution:** Ordered list of confirmed Swing Highs; compare new vs last with strict `<`; freeze.
- **Computational Complexity:** O(1) per confirmation.
- **Data Required:** New and previous confirmed Swing High prices.
- **Memory Requirement:** Confirmed Swing High list (bounded).
- **Update Frequency:** At each Swing High confirmation.

---

# Topic 8 — Lower Low (LL)

- **Definition:** A confirmed Swing Low whose price is **strictly less than** the price of the previous confirmed Swing Low. (DOC00 §7 pattern, unchanged.)
- **Purpose:** Building block of bearish structure; the second signal (with LH) to classify structure as bearish. "Lows are falling."
- **Why it exists:** DOC00 §1 defines bearish structure as LH **and** LL; LL is the lows-falling half.
- **Relation with DOC00:** DOC00 §7 pattern reproduced. Strict inequality; equal lows are not LL.
- **Relation with DOC01:** Computed by the Market Structure Engine; label on the Swing Low record.
- **Inputs:** Newly confirmed Swing Low price; previous confirmed Swing Low price.
- **Outputs:** A boolean LL label attached to the new Swing Low.
- **Dependencies:** Swing Detection/Confirmation.
- **Deterministic Rules:** Strict `<` against the immediately preceding confirmed Swing Low; immutable; ties produce no LL.
- **Validation Rules:** Both swings confirmed; exact prices; strict inequality.
- **Edge Cases:** First confirmed Swing Low → no label; equal to predecessor → no LL (Equal Low territory).
- **Failure Cases:** Previous swing record pruned → "previous unknown."
- **False Detection Cases:** Using `≤`; comparing to a non-adjacent low.
- **Automation Challenges:** Same as HL.
- **Recommended Solution:** Ordered list of confirmed Swing Lows; compare new vs last with strict `<`; freeze.
- **Computational Complexity:** O(1) per confirmation.
- **Data Required:** New and previous confirmed Swing Low prices.
- **Memory Requirement:** Confirmed Swing Low list (bounded).
- **Update Frequency:** At each Swing Low confirmation.

---

# Market Structure — Consistent Maintenance of HH / HL / LH / LL

This section defines how the four labels are maintained **consistently** and how the **structure labelling state machine** behaves. It defines **swing-sequence structure classification only**. It does **not** define the live trading bias or its CHoCH-based flip (R-1).

### The two independent sequences
Swing Highs and Swing Lows are maintained as **two independent ordered sequences**. Each new swing is compared **only** to the immediately preceding swing of the **same type**. This independence is essential: in strong trends, several swing highs can occur with swing lows interleaved or (rarely) two same-type swings close together; the comparison must not cross types.

| New swing | Compared to | Possible labels |
|---|---|---|
| Swing High (new) | Previous confirmed Swing High | **HH** (strict `>`) or **LH** (strict `<`) or **none** (tie / no predecessor) |
| Swing Low (new) | Previous confirmed Swing Low | **HL** (strict `>`) or **LL** (strict `<`) or **none** (tie / no predecessor) |

A swing always receives **exactly one** of {HH, LH, none} or {HL, LL, none}; never both, never ambiguous. Ties and first-of-type cases receive "none."

### Structure Labelling State Machine

The structure label is derived from the **most recent confirmed swing of each type**. It is recomputed only when a new swing is confirmed (DOC00 §1: "only re-evaluated when a new swing point is confirmed").

**States:**

| State | Meaning |
|---|---|
| **INITIAL** | The engine has just started; no confirmed swings exist yet. |
| **UNKNOWN** | At least one confirmed swing exists, but the structure cannot yet be classified (see transition conditions). |
| **BULLISH** | The latest swing high is **HH** **and** the latest swing low is **HL**. |
| **BEARISH** | The latest swing high is **LH** **and** the latest swing low is **LL**. |
| **INVALID** | An internal inconsistency was detected (see below); analysis continues but the label is not trusted until recovered. |

**State transition conditions (swing-sequence classification):**

- **INITIAL → UNKNOWN:** the first confirmed swing (of either type) appears. A single swing cannot classify structure.
- **→ BULLISH:** when both a latest swing high and a latest swing low exist **and** the latest high is HH **and** the latest low is HL.
- **→ BEARISH:** when both exist **and** the latest high is LH **and** the latest low is LL.
- **→ UNKNOWN:** when both exist but the pair is mixed (e.g., HH with LL, or LH with HL) — i.e., the two sequences disagree — or when a tie/first-of-type leaves one side without a usable label.
- **→ UNKNOWN:** if only one type has a confirmed swing so far (the other has none).
- **Stays in current state:** if no new swing has been confirmed since the last evaluation (the label is unchanged between swing events).

**Notes on the mixed case:** A mixed pair (e.g., HH + LL) is genuinely inconclusive at the swing-sequence level. Per R-1, DOC02A does **not** resolve this into a trading bias; it labels it UNKNOWN and leaves resolution to the future BOS/CHoCH document and DOC00. This avoids inventing a rule DOC00 does not contain.

**Initial state:** INITIAL. No structure label is produced until at least one swing of each type is confirmed and both yield a comparable (HH/LH and HL/LL) result.

**Unknown state:** A normal, non-error state meaning "the swing sequence does not currently express a clear bullish or bearish classification." It is **not** a failure. Consumers must treat UNKNOWN as "no structure classification available."

**Bullish state:** Requires the conjunction HH **and** HL on the latest swings. Both conditions are required (DOC00 §1). Either alone is insufficient.

**Bearish state:** Requires the conjunction LH **and** LL on the latest swings. Both required.

**Invalid state:** Reached only by a detected internal inconsistency, never by normal market data. Examples: two swings with identical centre timestamps; a swing high recorded below a contemporaneous swing low beyond symbol precision; a confirmation timestamp preceding the centre timestamp; a label computed against a non-adjacent predecessor due to a corrupted list. INVALID is a **defensive** state.

**Recovery strategy (from INVALID):**
1. Freeze the current published structure label at its last valid value (do not propagate an untrusted label).
2. Rebuild the two ordered swing sequences from the immutable confirmed-swing records (which are never corrupted because they are immutable and timestamped).
3. Re-derive all HH/HL/LH/LL labels from scratch using strict inequality against the correct predecessors.
4. Recompute the structure label from the rebuilt sequences.
5. If the rebuilt state is consistent, exit INVALID to the recomputed state (BULLISH / BEARISH / UNKNOWN).
6. If inconsistency persists, remain INVALID, log at ERROR, and do not emit a structure label until the underlying data (history) is corrected.

Because confirmed swing records are immutable and timestamped, reconstruction is always deterministic and yields the same labels that were originally computed — INVALID recovery is a safety mechanism, not a source of changed results.

### Why this is consistent and deterministic
- Each label comes from exactly one comparison with strict inequality → no ties, no ambiguity.
- The structure label is a pure function of the two most recent confirmed swings → reproducible.
- Labels and the structure state change **only** on swing confirmations, which occur only on closed bars at a fixed cadence → no tick-driven churn.
- All records are immutable after confirmation → no repaint, no retroactive changes.

---

# Cross-Document Consistency

| Concern | How DOC02A respects it |
|---|---|
| DOC00 swing definitions | Reproduced verbatim in semantics; SFS = 2, strict inequality, closed-bar confirmation all unchanged. |
| DOC00 §1 structure | Bullish = HH+HL, bearish = LH+LL; "only re-evaluated when a new swing is confirmed." Implemented exactly. |
| DOC00 equal-high/low rule | Ties never produce swings or HH/HL/LH/LL labels; equal highs/lows are deferred to the future Liquidity/EQH-EQL document. |
| PATCH_001 timeframes | Swings detected on H1 (structure) and the same detection basis used on H4 (trend classification). No BOS/CHoCH/OB/FVG on H4. |
| DOC01 module ownership | All swings and structure labels are produced and written solely by the Market Structure Engine into the *Structure* section. Other modules read only. |
| DOC01 closed-bar discipline | Enforced via Market Data Access as the only candle source; this document mandates closed-only participation. |
| DOC01 immutability | Swing records and labels are immutable after confirmation. |

---

# Self Review Result

Before finalising, the document was checked against the required checklist. Findings and resolutions:

- **Logical contradictions:** None. Swing High/Low are strict mirrors; HH/HL and LH/LL use strict inequality consistently; the structure state machine requires conjunction (HH+HL / LH+LL) per DOC00 §1. *(Pass)*
- **Missing definitions:** All eight required topics are fully defined. "Previous confirmed swing" is pinned (R-3). "Closed candle," "confirmation instant," "strict inequality," "tie," "pending candidate" are all defined. *(Pass)*
- **Subjective language:** Removed/avoided. No "significant," "clear," "usually," "feel." Every classification is a strict comparison. *(Pass)*
- **Repaint possibility:** Eliminated by construction — swings are published once, at a fixed closed bar, and are immutable. The only apparent repaint (a failed candidate) is never published. *(Pass)*
- **Look-ahead bias:** Eliminated — closed-bar-only participation, and the centre-time vs. confirmation-time separation prevents acting on a swing before it was knowable. *(Pass)*
- **Ambiguous wording:** "Previous swing" disambiguated to "immediately preceding confirmed swing of the same type"; "structure" disambiguated from "trading bias" (R-1). *(Pass)*
- **Undefined terminology:** SFS, fractal, centre, neighbour, confirmation, pending candidate, immutability, retention, INVALID — all defined. *(Pass)*
- **Incomplete edge cases:** Covered: first-swing, ties, history gaps, non-closed candle, adjacent candidates, missing predecessor (pruned), mixed swing pairs. *(Pass)*

**Scoping boundaries respected:** BOS, CHoCH, Order Block, Liquidity, and Fair Value Gap are **not** defined, behaviourally referenced, or implemented. Where the mixed-swing case or the bias question implicitly touches CHoCH territory, DOC02A defers to the future BOS/CHoCH document and DOC00 (R-1) rather than inventing a rule.

**Outcome:** No blocking issues. DOC02A is internally consistent, deterministic, measurable, programmable, and fully conforms to DOC00, PATCH_001, and DOC01.

---

# Final Notes

1. **Foundation only.** This document specifies swing detection, swing confirmation, the HH/HL/LH/LL labels, and the swing-sequence structure labelling state machine. It does **not** specify BOS, CHoCH, or any other SMC concept.
2. **No new SMC definitions.** Every definition is DOC00, stated with operational precision. No terminology is redefined.
3. **Determinism is architectural.** Closed-bar discipline + strict inequality + immutable records + confirmation-time separation collectively guarantee identical data ⇒ identical swings ⇒ identical structure labels.
4. **Bias is out of scope.** How the structure label becomes the live trading bias, and how CHoCH reversals reconcile with it, is owned by DOC00 and the future BOS/CHoCH document (R-1).
5. **The next foundation documents** (Order Block, Liquidity, Fair Value Gap, BOS/CHoCH) will consume the *Structure* section produced here — read-only — and must not redefine swings or labels.

This document is now the official specification for the Market Structure Engine foundation.
