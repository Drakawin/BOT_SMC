# DOC02EA — Order Block Reference Validation
## Comparative Study of Institutional SMC Order Block Methodology

> **Document status:** AUTHORITATIVE — **Reference validation only.**
> **Phase:** Pre-Design Validation (Phase 2, Part E-A).
> **This is NOT an Order Block Engine specification.** No Order Block Engine is designed here. No algorithms, pseudo-code, flowcharts, or MQL5 code are produced.
> **Purpose of this document:** Study and compare the Order Block methodology across the project's approved institutional SMC references, identify every material difference between sources, evaluate each for automation feasibility and determinism, and recommend **one** methodology to become the official Order Block definition for this project.
> **Relationship to prior documents:** This document does **not** modify DOC00–DOC02D. Where a comparison surfaces a difference between the references and an already-approved DOC00 decision, the DOC00 decision is reported as prevailing and is **not** changed.
> **Priority rule:** DOC00_Strategy_Validation.md §14 (Order Block) and §15 (Mitigation) are **already approved and locked**. Any recommendation here must be **consistent** with them; this document explains *why* that locked choice is the correct one and confirms it as the official definition.

---

# References Studied

The same three institutional references approved in DOC00, re-examined specifically for Order Block methodology.

| Tag | Reference | Role |
|---|---|---|
| **TW** | TradingWyckoff — *Smart Money Concepts (Complete Guide)* `https://tradingwyckoff.com/en/smart-money-concepts/` | Most detailed OB treatment: three mandatory conditions, three zone-marking variants, proximal/distal/50% thresholds, Breaker vs Mitigation Block distinction. Primary definitional source in DOC00. |
| **QNE** | QuantNeuralEdge — *ICT Smart Money Concepts* `https://quantneuraledge.com/learn/ict-smart-money-concepts` | Concise OB definition, open-to-low zone, impulsive+BOS validation, Breaker polarity flip. |
| **BINUS** | BINUS SIS — *ICT Strategi Trading Berbasis Smart Money Concept* `https://sis.binus.ac.id/2025/07/15/inner-circle-trader-ict-strategi-trading-berbasis-smart-money-concept/` | High-level OB description (consolidation area before a sharp move). Used to confirm mainstream consensus, not to introduce new detail. |

No Reddit, no YouTube-as-primary, no unverified blogs. Trustworthiness rationale is the same as DOC00: the three are structured, internally consistent, and publicly verifiable.

---

# Reference Comparison — Executive Matrix

The references agree on the OB *essence* and diverge on *strictness*, *zone marking*, and *lifecycle detail*. The matrix below summarises every comparison point; each is then expanded in its own subsection with the required evaluation fields.

| Comparison Point | TW | QNE | BINUS | Conflict? |
|---|---|---|---|---|
| Bullish OB definition | Last bearish candle before impulsive up-move with BOS | Last bearish candle before strong up-move (open-to-low range) | Consolidation/area before sharp move | Strictness |
| Bearish OB definition | Mirror (last bullish before down-move + BOS) | Mirror (open-to-high) | Mirror (loose) | Strictness |
| BOS relationship | **Mandatory** condition #3 (no BOS = no OB) | Required (move must "create a BOS") | Implied, not explicit | Strictness |
| CHoCH relationship | OB validates the impulse behind a CHoCH too (reversal origin) | Not detailed | Not detailed | Granularity |
| Liquidity relationship | OB quality rises after a liquidity sweep; Breaker requires a prior sweep | Mentions sweep as quality factor | Sweep mentioned generically | Granularity |
| Candle selection rule | "Last opposing candle"; multi-candle → the set or most prominent | "Last candle (or group)" | "Consolidation area" | Strictness |
| Mitigation rules | Price returns into zone; 50% (Mean Threshold) as partial-invalidation reference | Price retraces into zone = buy/sell zone | Price returns → reaction = entry | Detail |
| Invalidation rules | Body closes beyond **distal** line = invalid; SL placed beyond distal | Not explicit | Not detailed | Detail |
| Multi-candle OBs | Explicit: consecutive opposing candles → the set (or most prominent) | "Group of candles" allowed | Not detailed | Strictness |
| Nested OBs | Not explicitly defined (implied via multi-TF) | "Higher TF OBs more significant" | Not detailed | Granularity |
| Internal vs External OBs | Covered via PD Arrays / IRL-ERL (OB inside vs outside dealing range) | Not detailed | Not detailed | Granularity |
| Timeframe considerations | HTF OBs more significant; OB on analysis TF, entry on lower TF | HTF OBs more significant | H1/H4 structure, M5/M15 entry | Consensus |
| Automation feasibility | High if "most prominent" and "displacement" are pinned to fixed rules | High if "impulsive" pinned | Low as stated (too loose) | Variance |

The dominant pattern: **TW is the most automation-ready because it states explicit conditions; QNE is a close, simpler mirror; BINUS is too loose to automate as-is.**

---

# Detailed Comparison — Per Point

For each comparison point: reference definition, advantages, disadvantages, automation difficulty (1–10), determinism, possible ambiguity, and suitability for algorithmic trading.

## 1. Definition of Bullish Order Block

- **Reference definition:**
  - **TW:** "The last bearish candle before a strong upward move," valid only if the move shows displacement and breaks structure (BOS). Three simultaneous conditions.
  - **QNE:** "The last bearish candle before a strong up-move. Mark the candle's range (open to low)."
  - **BINUS:** An area where institutions place large orders before a significant price move (consolidation before sharp move).
- **Advantages:** TW's three-condition form is falsifiable and testable; QNE is simple to mark; BINUS communicates the intuition.
- **Disadvantages:** QNE omits the structural requirement (BOS) in its terse definition; BINUS is too vague to operationalise ("area," "significant").
- **Automation difficulty:** TW 4/10 (conditions are checkable once "displacement" is pinned); QNE 5/10 (must re-add BOS); BINUS 9/10 (undefined terms).
- **Determinism:** TW high; QNE medium; BINUS low.
- **Possible ambiguity:** "last bearish candle" (which window?), "strong/impulsive" (subjective unless pinned), "significant move" (undefined).
- **Suitability for algorithmic trading:** TW best; QNE acceptable if augmented with BOS; BINUS unsuitable as-is.

## 2. Definition of Bearish Order Block

- **Reference definition:** Mirror of bullish in all three sources (last bullish candle before a down-move).
- **Advantages/Disadvantages/Automation/Determinism/Ambiguity/Suitability:** Identical to bullish, mirrored. No new issues. (TW remains the strictest and most automatable.)

## 3. BOS Relationship

- **Reference definition:** TW makes BOS **mandatory** (condition #3); QNE requires the move "create a break of structure"; BINUS implies structure but does not state it.
- **Advantages:** Requiring a confirmed BOS ties the OB to a real structural event (DOC02B), which is already a deterministic, closed-bar, body-close event in this project.
- **Disadvantages:** None material; the only cost is fewer OBs (stricter filter).
- **Automation difficulty:** 2/10 — DOC02B already emits confirmed BOS events; an OB engine simply consumes them.
- **Determinism:** High — BOS is already deterministic (DOC02B).
- **Possible ambiguity:** None, given DOC02B's strict definition. (DOC00 §14 also accepts a CHoCH as the qualifying impulse, which is equally deterministic per DOC02C.)
- **Suitability for algorithmic trading:** Excellent — BOS/CHoCH are first-class deterministic events in DOC02B/DOC02C.

## 4. CHoCH Relationship

- **Reference definition:** TW treats the OB as the origin candle of the impulse behind **either** a BOS (continuation) **or** a CHoCH (reversal); QNE/BINUS do not detail this.
- **Advantages:** Accepting CHoCH as a qualifying impulse captures reversal OBs, not just continuation OBs — broader coverage with no loss of determinism (DOC02C CHoCH is as deterministic as DOC02B BOS).
- **Disadvantages:** Slightly more OBs to lifecycle-manage; manageable.
- **Automation difficulty:** 2/10 — DOC02C emits confirmed CHoCH events.
- **Determinism:** High.
- **Possible ambiguity:** None, given DOC02C.
- **Suitability for algorithmic trading:** Excellent. **Note:** DOC00 §14 already locks "a bullish BOS **or** CHoCH" as the qualifying impulse. This validation confirms that choice is sound and well-supported by TW.

## 5. Liquidity Relationship

- **Reference definition:** TW ties OB quality to a preceding liquidity sweep (higher-quality OBs come after sweeps) and makes a prior sweep the **defining** characteristic of a Breaker Block. QNE mentions sweeps as a quality factor; BINUS mentions sweeps generically.
- **Advantages:** Sweeps (DOC02D) are already deterministic labelled events; they can serve as an optional quality filter without changing OB definition.
- **Disadvantages:** Making a sweep *mandatory* for every OB would discard many valid continuation OBs; TW does not require it for OBs (only for Breakers).
- **Automation difficulty:** 2/10 to consume DOC02D sweep events.
- **Determinism:** High.
- **Possible ambiguity:** "Quality" is subjective; the project must treat sweep proximity as an **optional confluence**, never a definitional requirement for an OB (consistent with DOC00, which does not require a sweep for an OB).
- **Suitability for algorithmic trading:** Good as an optional filter; not suitable as a hard definitional gate for OBs.

## 6. Candle Selection Rules

- **Reference definition:** TW = "last opposing candle" before the impulse; on multiple consecutive opposing candles, "the OB is the set (or the most prominent one)." QNE = "last candle (or group)." BINUS = "consolidation area."
- **Advantages:** "Last opposite-body candle" is unambiguous and O(1) to find by scanning backwards from the impulse.
- **Disadvantages:** "Most prominent" (TW) is subjective; "group" (QNE) needs a bounding rule; "area" (BINUS) is unbounded.
- **Automation difficulty:** "Last opposite-body candle" = 2/10; "most prominent"/"group"/"area" = 7–9/10 (require subjective choices).
- **Determinism:** "Last opposite-body candle" is fully deterministic; the others are not, unless pinned.
- **Possible ambiguity:** Which candle when several qualify; how to bound a group.
- **Suitability for algorithmic trading:** Only "last opposite-body candle" is suitable without introducing subjectivity. **This is exactly what DOC00 §14 locks** ("the last candle of opposite body direction").

## 7. Mitigation Rules

- **Reference definition:** TW = price returns into the zone; introduces a 50% "Mean Threshold" as a partial-invalidation reference some traders use. QNE = price retraces into the zone (buy/sell zone). BINUS = price returns → reaction = entry.
- **Advantages:** A body-based mitigation rule is deterministic and closed-bar safe.
- **Disadvantages:** The 50% Mean Threshold is a *trader preference*, not a definitional requirement; adopting it as a hard rule would add a subjective threshold.
- **Automation difficulty:** Body-reaches-zone = 2/10; 50% threshold = 3/10 but introduces an unjustified constant.
- **Determinism:** Body-based mitigation is deterministic; the 50% rule is deterministic but arbitrary.
- **Possible ambiguity:** "Touched" (wick) vs "reached" (body); DOC00 §15 resolves this: **body** reaches the zone = mitigation.
- **Suitability for algorithmic trading:** Body-based mitigation (DOC00 §15) is ideal. The 50% threshold is **not** adopted (it is a discretionary trader tool, absent from DOC00).

## 8. Invalidation Rules

- **Reference definition:** TW = a candle body closing beyond the **distal** line (the far edge) invalidates the OB; SL is placed beyond the distal. QNE/BINUS do not specify invalidation precisely.
- **Advantages:** Body-close-beyond-far-edge is deterministic and mirrors the body-close philosophy of DOC02B/DOC02C/DOC02D.
- **Disadvantages:** None, provided "far edge" is precisely the zone edge opposite to the entry direction.
- **Automation difficulty:** 2/10.
- **Determinism:** High.
- **Possible ambiguity:** "Beyond the far edge" — must be pinned to the zone's far edge. **DOC00 §15 locks this exactly:** "body closes beyond the far edge of the zone (the edge opposite to entry)."
- **Suitability for algorithmic trading:** Excellent.

## 9. Multi-candle Order Blocks

- **Reference definition:** TW allows consecutive opposing candles to form "the set (or the most prominent one)"; QNE allows "a group of candles"; BINUS is silent.
- **Advantages of allowing multi-candle OBs:** Captures consolidation-before-impulse zones.
- **Disadvantages:** Introduces bounding ambiguity (where does the group start?) and a "most prominent" subjective choice. Significantly harder to make deterministic and non-repainting.
- **Automation difficulty:** 6–8/10 (bounding rule needed).
- **Determinism:** Low unless a strict bounding rule is defined.
- **Possible ambiguity:** High (group boundaries, prominence metric).
- **Suitability for algorithmic trading:** Poor as stated. **The deterministic alternative** (and the one DOC00 §14 locks) is: the OB is **exactly one candle** — the last opposite-body candle before the impulse. This preserves the "re-entry zone" intuition without bounding ambiguity. (If a future phase proves multi-candle zones add value, they can be introduced as a documented extension with a fixed bounding rule — not now.)

## 10. Nested Order Blocks

- **Reference definition:** No reference explicitly defines "nested OBs." TW and QNE note that higher-timeframe OBs are more significant and that an HTF OB may contain lower-timeframe OBs (implicitly nested). BINUS is silent.
- **Advantages:** The multi-timeframe model (H4 → H1 → M15, PATCH_001) naturally produces "nested" zones (an H1 OB inside the bounds of an H4 leg).
- **Disadvantages:** None, *provided nesting is treated as a read-only observation across timeframes*, not a new object type. An OB is defined on exactly one timeframe (H1, per PATCH_001); "nesting" is just alignment, not a separate definition.
- **Automation difficulty:** 2/10 (alignment check only).
- **Determinism:** High.
- **Possible ambiguity:** Only if "nested OB" is misread as a new definitional category. It is not.
- **Suitability for algorithmic trading:** Good, as a cross-timeframe **alignment filter** (e.g., an H1 OB that lies inside a qualifying H4 Discount). Not a separate OB type.

## 11. Internal vs External Order Blocks

- **Reference definition:** TW frames this via PD Arrays / IRL vs ERL: OBs (and FVGs) **inside** the dealing range are "internal range liquidity" (IRL); the range-bounding extremes are "external." QNE/BINUS do not detail this.
- **Advantages:** The dealing range is already a DOC00/DOC02A deterministic construct; classifying an OB as internal/external is a pure derivation (mirror of DOC02D's Internal/External Liquidity classification).
- **Disadvantages:** None, as long as it is a **derived tag**, not a new OB definition.
- **Automation difficulty:** 2/10.
- **Determinism:** High.
- **Possible ambiguity:** Only if the dealing range is undefined (DOC02A UNKNOWN/INITIAL); safe default = treat as external (as DOC02D does for liquidity).
- **Suitability for algorithmic trading:** Good, as a derived classification tag on the OB (consistent with DOC02D's pattern).

## 12. Timeframe Considerations

- **Reference definition:** All three agree higher-timeframe OBs are more significant; TW and BINUS prescribe a top-down workflow (HTF bias → HTF structure → LTF entry).
- **Advantages:** PATCH_001 already fixes the timeframe architecture: structure/OB on **H1**, execution on **M15**, bias on **H4**. This matches the consensus exactly.
- **Disadvantages:** None.
- **Automation difficulty:** 1/10 (timeframes are fixed constants).
- **Determinism:** High.
- **Possible ambiguity:** None, given PATCH_001.
- **Suitability for algorithmic trading:** Excellent — the multi-TF ambiguity is removed by fixing the timeframes.

## 13. Automation Feasibility (overall)

- **Reference definition (synthesis):** The feasibility of automating OBs is determined by how many subjective terms each source leaves open. TW leaves "displacement" and "most prominent"; QNE leaves "strong/impulsive"; BINUS leaves "area/significant."
- **Advantages of the DOC00 approach:** DOC00 §14 closes every subjective gap — "last opposite-body candle," qualifying impulse = confirmed BOS/CHoCH (already deterministic), zone = high-to-low, validation on body close.
- **Disadvantages:** Stricter rules yield fewer OBs (accepted trade-off for determinism).
- **Automation difficulty:** 4/10 for the DOC00 methodology (the only residual work is scanning backwards from a confirmed BOS/CHoCH to the last opposite-body candle — O(1) amortised).
- **Determinism:** High.
- **Possible ambiguity:** None remaining under DOC00.
- **Suitability for algorithmic trading:** Excellent — this is the core finding of the validation.

---

# Key Differences Requiring a Decision (and how DOC00 already resolves them)

| # | Difference | Options | DOC00 decision (locked) | Assessment |
|---|---|---|---|---|
| D-1 | Qualifying impulse | BOS-only vs BOS-or-CHoCH | **BOS or CHoCH** (DOC00 §14) | Sound — both are deterministic (DOC02B/DOC02C); captures continuation + reversal OBs. |
| D-2 | Candle selection | Last opposite-body vs "group"/"most prominent"/"area" | **Last opposite-body candle** (DOC00 §14) | Sound — the only fully deterministic choice; avoids bounding/prominence subjectivity. |
| D-3 | Zone marking | (a) open-to-low [TW recommended], (b) body-only, (c) full range high-to-low | **Full range high-to-low** (DOC00 §14: "high-to-low") | See *Reported Difference D-3* below. DOC00 prevails. |
| D-4 | Mitigation trigger | Wick-touch vs body-reach vs 50% threshold | **Body reaches zone** (DOC00 §15) | Sound — closed-bar safe, deterministic. 50% threshold not adopted (discretionary). |
| D-5 | Invalidation | Wick beyond vs body-close-beyond-far-edge | **Body closes beyond far edge** (DOC00 §15) | Sound — mirrors the body-close philosophy of DOC02B/C/D. |
| D-6 | Multi-candle OBs | Allowed (TW/QNE) vs single-candle | **Single candle** (implied by DOC00 §14 "the last candle of opposite body direction") | Sound — avoids bounding ambiguity; deterministic. |
| D-7 | Displacement/impulse quality | Required as a quality gate (TW) vs not required | **Not a definitional gate** in DOC00 (DOC00 has no displacement constant) | Sound — "displacement" is subjective; the BOS/CHoCH body-close already ensures a meaningful move. Sweep/FVG/Premium-Discount act as quality filters downstream. |
| D-8 | Internal/External OB | PD Array classification (TW) vs none | **Not in DOC00 as an OB concept** | Can be added later as a *derived tag* (like DOC02D's liquidity classification) without redefining OB. |
| D-9 | Nested OBs | Implicit in multi-TF vs undefined | **Not a separate concept** | Handled as cross-TF alignment, not a new OB type. |

---

# Reported Difference D-3 (reported, not changed)

This is the **one** point where DOC00's locked choice differs from a reference's *recommendation* (not its definition). It is reported per the standing instruction; **DOC00 is not changed.**

- **TW's recommendation:** mark the OB zone as **open-to-low** for a bullish OB (open of the bearish candle to its low), i.e., "body plus the impulse-side wick, excluding the opposite-side wick." TW calls this "the ICT standard, most widespread" and argues the impulse-side wick is meaningful (pre-entry manipulation) while the body-only variant produces "too many false negatives."
- **DOC00's locked choice:** the zone is the candle's **high-to-low** (full range), and the far edge is the low (bullish) / high (bearish). DOC00 §14: "The OB zone spans that candle's high-to-low." DOC00 §15: invalidation on "body closes beyond the far edge."
- **Analysis:** The full-range zone is **wider** (includes both wicks). Consequences:
  - **Pro (full range):** simpler to compute (just candle high/low — no open/close logic for the zone); more conservative stop placement (stop is placed beyond the full low/high, which DOC00 §23 Stop Loss Logic already specifies as "OB far edge minus SL Buffer"); deterministic and unambiguous.
  - **Con (full range):** wider zones can overlap more often; mitigation triggers slightly earlier (the near edge is the candle's high for a bullish OB, reached sooner than the open would be); slightly more conservative (fewer trades qualify if a tight Premium/Discount or risk-cap filter is applied, since the zone consumes more of the range).
- **Resolution status:** DOC00's full-range choice is **consistent and deterministic**. It is a legitimate, defensible variant (TW lists it as variant 3, "the most permissive, gives wider zones"). It is **not** re-litigated here. DOC00 §14/§15 prevail. The only downstream implication is that the future OB Engine must use **high/low** (not open/close) for the zone edges — which is trivially deterministic.

---

# Automation Feasibility Summary

| Source | Overall automation feasibility | Why |
|---|---|---|
| TW | High (best) | Explicit conditions; only "displacement" and "most prominent" need pinning — and DOC00 already removes both by using BOS/CHoCH + single-candle selection. |
| QNE | Medium-high | Simple and mostly aligned, but omits explicit BOS in the terse definition and uses open-to-low (differs from DOC00). |
| BINUS | Low | "Area"/"significant"/"consolidation" are undefined; usable only as intuition, not as a spec. |

The DOC00 methodology is effectively **TW's strict definition with every subjective gap closed** — making it the most automation-ready of all options examined.

---

# Non-Repainting and Look-Ahead Analysis (validation)

A core requirement is that the chosen OB methodology be **non-repainting** and free of **look-ahead bias**. Validation:

- **Non-repainting:** The OB is **locked at the moment the confirming BOS/CHoCH body-close occurs** (DOC00 §14) and is **never edited afterwards** (DOC00 §14; DOC01 immutability rule). Before that close, "the last opposite candle" can shift — but the rule does not publish an OB until the confirming close. Therefore no published OB ever changes. ✅
- **Look-ahead bias:** The OB is defined using a **future event** (the BOS/CHoCH close that happens *after* the OB candle). This is legitimate as a **historical annotation** but would become look-ahead bias if the EA *acted* on the OB before the confirming close occurred. DOC00 §14 explicitly states: "the EA must not assume the OB existed before the BOS occurred. For entries, the EA only uses OBs whose confirming BOS/CHoCH has already printed." The future OB Engine must enforce: **an OB is consumable only after its confirming BOS/CHoCH close timestamp.** ✅ (This is a constraint for the future OB Engine spec, recorded here.)

---

# Recommendation

### Recommended methodology: **The DOC00 Order Block definition (TW-strict, single-candle, full-range, body-based lifecycle)** — confirmed as the official Order Block definition for this project.

No new methodology is invented. The validation concludes that DOC00 §14/§15 **already embody** the most deterministic, automation-ready synthesis of the institutional references. The recommendation is to **adopt DOC00's locked definition unchanged as the official OB definition** and to carry the following operational pins into the future OB Engine specification (DOC02EB and beyond):

1. **Qualifying impulse:** a confirmed **BOS or CHoCH** (DOC02B/DOC02C) — deterministic, closed-bar, body-close. (D-1)
2. **Candle selection:** exactly **one candle** — the **last opposite-body candle** before the impulse. No groups, no "most prominent." (D-2, D-6)
3. **Zone:** the candle's **high-to-low** (full range). Near edge = the edge the impulse departed from; far edge = the opposite edge. (D-3, reported)
4. **Validation instant:** the OB is created and locked at the **confirming BOS/CHoCH body-close**, and is immutable thereafter. (Non-repainting.)
5. **Mitigation:** a later closed candle's **body reaches into the zone** → mitigated. (D-4)
6. **Invalidation:** a later closed candle's **body closes beyond the far edge** → invalidated/failed. (D-5)
7. **Consumability:** an OB may be used by downstream modules **only after** its confirming close timestamp (look-ahead guard). (Look-ahead analysis.)
8. **No displacement/quality gate** in the definition; quality is provided by downstream confluence (Premium/Discount, FVG, sweep, session) per DOC00's entry logic. (D-7)
9. **Internal/External** and **nested** are **not** OB definition elements; they may appear later as derived tags / cross-TF alignment, never redefining the OB. (D-8, D-9)

### Why this methodology should become the official Order Block definition

- **Deterministic:** every element is a closed-bar, body-close, or single-candle fact. Identical data ⇒ identical OBs. No "displacement," "prominent," or "significant" judgement.
- **Consistent with DOC00–DOC02D:** it *is* DOC00 §14/§15, and it consumes only DOC02A (swings), DOC02B (BOS), DOC02C (CHoCH), and DOC02D (sweeps, optional) — all already deterministic and consumer-only.
- **Suitable for MetaTrader 5:** all inputs (closed H1 OHLC, confirmed structure events) are available via the DOC01 Market Data Access chokepoint and the Structural Context.
- **Non-repainting:** by the lock-at-confirming-close + immutability rule (validated above).
- **Computationally efficient:** creating an OB is a backward scan from the confirming event to the last opposite-body candle — O(1) amortised, O(k) worst case for a small impulse length k; lifecycle checks are O(1) per closed candle per active OB.
- **Easy to automate:** no subjective thresholds; the only constants are inherited (ELT, buffers) and are not part of the OB definition itself.
- **Easy to debug:** each OB carries the confirming BOS/CHoCH reference, the source candle, and the zone edges — fully auditable and bar-by-bar reconstructable (supports DOC01's logging philosophy).
- **Easy to backtest:** because OBs are pure functions of closed-bar data and confirmed structure events, the MT5 strategy tester can reproduce them exactly from historical bars.

### Methodologies explicitly rejected (and why)

| Rejected option | Reason |
|---|---|
| QNE open-to-low zone | Differs from DOC00's locked full-range zone (D-3); offers no determinism advantage. |
| BINUS "consolidation area" | Undefined terms; not automatable without inventing rules DOC00 does not contain. |
| TW "most prominent" multi-candle OB | Subjective prominence metric; bounding ambiguity; repaint risk. |
| Mandatory displacement/impulse-size gate | "Displacement" is subjective; DOC00 deliberately omits it (D-7); BOS/CHoCH body-close already ensures a meaningful move. |
| 50% Mean Threshold as a hard mitigation/invalidation rule | Discretionary trader tool; arbitrary constant absent from DOC00; not adopted (D-4). |
| Making a liquidity sweep mandatory for every OB | Would discard valid continuation OBs; TW requires sweeps only for Breakers, not OBs (D-7). |

---

# Self Review

Before finalising, this validation was checked for:

- **Consistency with DOC00:** The recommendation is DOC00 §14/§15 itself, unchanged. The one difference from a reference (D-3, full-range vs open-to-low) is reported, and DOC00 prevails. ✅
- **Consistency with DOC01:** The recommended OB consumes only closed-bar data via Market Data Access and writes only to its own Structural Context section (sole-writer rule). ✅
- **Consistency with DOC02A:** Uses DOC02A confirmed swings for the dealing range (future Internal/External tag) without mutating them. ✅
- **Consistency with DOC02B/DOC02C:** Uses confirmed BOS/CHoCH as the qualifying impulse; both are deterministic. ✅
- **Consistency with DOC02D:** May consume sweeps as an optional quality filter; does not redefine liquidity. ✅
- **Logical contradictions:** None. Bullish/bearish are mirrors; creation/mitigation/invalidation are disjoint and ordered; single-candle selection removes multi-candle ambiguity. ✅
- **Undefined terminology:** All terms used (last opposite-body candle, far edge, near edge, confirming close, mitigated, invalidated, qualifying impulse) are defined or inherited from DOC00. ✅
- **Subjective language:** Avoided. No "strong," "significant," "prominent" as definitional terms (only when quoting/reference-reporting the sources' wording). ✅
- **Repaint possibility:** Eliminated by lock-at-confirming-close + immutability (validated). ✅
- **Look-ahead bias:** Eliminated by the consumability-after-confirming-close guard (validated; recorded as a constraint for the future OB Engine). ✅
- **Future compatibility:** The definition supports later derived tags (Internal/External) and cross-TF alignment (nested) without redefinition. ✅

**Outcome:** No blocking issues. The reference validation is complete, internally consistent, and confirms that DOC00's locked Order Block definition is the correct official methodology.

---

# Final Notes

1. **This document is a validation, not a specification.** No Order Block Engine is designed here. The future OB Engine specification (DOC02EB and beyond) will operationalise the recommendation above.
2. **DOC00 §14/§15 are confirmed as the official Order Block definition.** No change is proposed or needed.
3. **One reported difference (D-3)** exists between DOC00's full-range zone and TW's recommended open-to-low zone. DOC00 prevails; the future OB Engine must use candle high/low for the zone edges.
4. **Two constraints for the future OB Engine** are recorded here: (a) OBs are immutable after the confirming BOS/CHoCH close; (b) OBs are consumable only after that confirming close (look-ahead guard).
5. **Subjective OB notions** (displacement gates, prominence, multi-candle groups, 50% threshold) are explicitly rejected for this project, preserving the deterministic philosophy established in DOC00–DOC02D.

This document is now the official Order Block reference validation for the project.
