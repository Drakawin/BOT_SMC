# DOC00 — PATCH 001
## Timeframe Architecture

> **Patch type:** Targeted replacement — Timeframe Architecture only.
> **Applies to:** DOC00_Strategy_Validation.md (approved foundation).
> **Rule of scope:** No SMC definition, constant, risk rule, money-management rule, session rule, or terminology is modified by this patch. Everything not listed under *Affected Sections* remains exactly as approved.

---

# Patch Topic

Timeframe Architecture

---

# Replacement Summary

The two-timeframe model (HTF = M15, LTF = M1) is replaced by a three-timeframe model.

| Role | Old (DOC00 approved) | New (this patch) |
|---|---|---|
| Higher Timeframe (HTF) | M15 | — *removed* |
| Lower Timeframe (LTF) | M1 | — *removed* |
| Primary Trend Timeframe | — | **H4** |
| Market Structure Timeframe | — | **H1** |
| Execution Timeframe | — | **M15** |

The previous identifiers **HTF** and **LTF** are superseded by the three named timeframes above. Wherever DOC00 used **HTF**, the replacement is the **Market Structure Timeframe (H1)** unless the context is *bias only*, in which case the replacement is the **Primary Trend Timeframe (H4)**. Wherever DOC00 used **LTF**, the replacement is the **Execution Timeframe (M15)**.

---

# New Timeframe Architecture

## Primary Trend Timeframe

- **Timeframe:** H4
- **Purpose:** Determine the overall market direction only.
- **Permitted on this timeframe:**
  - Determine whether the market bias is **Bullish** or **Bearish**.
- **Explicitly NOT permitted on this timeframe:**
  - No entry logic.
  - No BOS.
  - No CHoCH.
  - No Order Block.
  - No Fair Value Gap.
- **Notes:** This timeframe produces the single directional bias that downstream timeframes consume. No execution decision originates here.

## Market Structure Timeframe

- **Timeframe:** H1
- **Purpose:** Detect and maintain all structural and zone objects.
- **Permitted on this timeframe:**
  - Market Structure
  - Swing High
  - Swing Low
  - Higher High
  - Higher Low
  - Lower High
  - Lower Low
  - Break of Structure (BOS)
  - Change of Character (CHOCH)
  - Liquidity
  - Liquidity Sweep
  - Equal High
  - Equal Low
  - Order Block
  - Mitigation
  - Breaker Block
  - Fair Value Gap
  - Premium / Discount
- **Notes:** All SMC definitions, confirmation rules, and constants defined in DOC00 remain unchanged; they now resolve on H1 instead of the former M15 HTF.

## Execution Timeframe

- **Timeframe:** M15
- **Purpose:** Act on the structural picture produced by the higher timeframes.
- **Permitted on this timeframe:**
  - Entry Confirmation
  - Trade Execution
  - Break Even
  - Trailing Stop
  - Trade Management
- **Notes:** Entry confirmation logic (including the LTF CHoCH step defined in DOC00) now resolves on M15 instead of the former M1 LTF. No SMC rule is changed.

---

# Mapping of DOC00 References

To preserve DOC00's approved rules verbatim, the following textual substitution is mandated wherever the former labels appear:

- Every occurrence of **"HTF (Higher Timeframe)"** or **"HTF"** referring to structure, swings, BOS/CHoCH, OB, FVG, Premium/Discount, mitigation, breakers, or trailing — is replaced by **"Market Structure Timeframe (H1)"**.
- Every occurrence of **"HTF"** referring to overall directional bias only — is replaced by **"Primary Trend Timeframe (H4)"**.
- Every occurrence of **"LTF (Lower Timeframe)"** or **"LTF"** — is replaced by **"Execution Timeframe (M15)"**.
- The phrase **"two-timeframe model"** in *Selected Smart Money Concept Methodology* is replaced by **"three-timeframe model"**.

No other wording is altered.

---

# Reason for This Patch

The previous M15 → M1 architecture produces too much market noise for XAUUSD.

The new H4 → H1 → M15 architecture is expected to generate approximately **3–5 high-quality trading opportunities per day** while significantly reducing:

- false BOS,
- false CHOCH,
- spread sensitivity,
- slippage sensitivity.

---

# What This Patch Does NOT Change

- No Smart Money Concept rule is modified.
- No constant is modified (SFS, ELT, FVG Min Size, SL Buffer, Break-Even Buffer, MaxRiskPerTradePoints, Lot Size, Risk:Reward, Max Open Positions, Equity Kill Threshold, session windows, BrokerUTCOffset).
- No risk rule is modified.
- No money management rule is modified.
- No session rule is modified.
- No terminology is modified (CHoCH, OB, FVG, Dealing Range, Premium/Discount, BOS, Liquidity, Mitigation, Breaker Block, EQH/EQL, Liquidity Sweep, Break Even, Trailing Stop all retain their DOC00 meanings).

---

# Patch Status

Patch Status:
READY

Affected Sections:
- References (no content change; the MQL5 implementation reference remains the feasibility source for the new timeframe set)
- Reference Comparison (the "two-timeframe" framing in the Selected Methodology row context is updated to three-timeframe)
- Selected Smart Money Concept Methodology (Point 1: "Two-timeframe model" → "Three-timeframe model"; HTF/LTF role split across H4 / H1 / M15)
- Complete Definitions — the following components resolve their timeframe references per the mapping above:
  - Market Structure
  - Swing High
  - Swing Low
  - Higher High
  - Higher Low
  - Lower High
  - Lower Low
  - Break Of Structure (BOS)
  - Change Of Character (CHOCH)
  - Liquidity
  - Equal High
  - Equal Low
  - Liquidity Sweep
  - Order Block
  - Mitigation
  - Fair Value Gap
  - Premium
  - Discount
  - Breaker Block
  - Entry Confirmation (HTF bias → H4 bias; LTF CHoCH → M15 CHoCH)
  - Trailing Stop (confirmed HTF swings → confirmed H1 swings)
- Deterministic Rules (Global constants table: replace HTF = M15 / LTF = M1 rows with Primary Trend Timeframe = H4 / Market Structure Timeframe = H1 / Execution Timeframe = M15)
- Automation Challenges (Point 3 "Two-timeframe synchronisation" → "Three-timeframe synchronisation (H4 / H1 / M15)")
- Recommended Implementations (every "HTF"/"LTF" reference resolves per the mapping above)
- Project Assumptions (Point 2 "Timeframe choice: HTF = M15, LTF = M1" → "Timeframe choice: Primary Trend = H4, Market Structure = H1, Execution = M15")

Unaffected Sections:
Every section of DOC00 not listed above — including Project Purpose, all SMC definitions' substance, all constant values, all risk/money-management/session rules, Ambiguous Rules, Edge Cases, False Signal Analysis (other than timeframe wording already covered), Limitations, Future Considerations, Self Review Result, and Final Recommendations — remains exactly as approved. No definition, rule, constant, or terminology is changed by this patch.
