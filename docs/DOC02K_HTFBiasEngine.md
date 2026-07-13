# DOC02K — Primary Trend Bias Engine (HTF)
## Official Specification for H4 Trend Identification and MTF Synchronization

> **Document status:** AUTHORITATIVE — Official specification for the **HTF Bias Engine and MTF Synchronization**.
> **Phase:** Module Specification (Phase 2, Part K).
> **Scope of this document:** H4 Primary Trend determination, MTF Alignment rules, Constants.
> **Explicitly out of scope:** Entry Logic (M15), Trade Execution.
> **Relationship to prior documents:**
> - Implements the **Primary Trend Timeframe (H4)** rules mandated by **DOC00_PATCH_001.md**.
> - Consumes outputs from an independent `CMarketStructureEngine` instantiated on **PERIOD_H4**.
> - Produces the final synchronized Directional Bias consumed downstream by the Confluence and Entry Decision engines.

---

# Reported Items (reported, not changed)

| # | Item | Status |
|---|---|---|
| R-1 | **H4 Structure Engine Independence** — To comply with DOC00_PATCH_001 (which forbids BOS/OB/FVG logic on H4), the HTF Bias Engine relies strictly on an isolated instance of `CMarketStructureEngine` running on `PERIOD_H4`. It reads only the raw swing structure states (BULLISH/BEARISH/UNKNOWN). | Reported — operationalization of PATCH_001. |
| R-2 | **H4 Swing Fractal Strength (SFS)** — For H4 trend detection, the SFS is set to **2** (2 bars left, 2 bars right). This represents an 8-hour window on each side, which is standard for major swing identification on H4 without introducing excessive lag. | Reported — explicit constant definition. |
| R-3 | **MTF Alignment Rule (Strict)** — A trade bias is valid **only** if the H4 Primary Trend and the H1 Market Structure states match exactly. Mismatches result in a `NEUTRAL` or `NO_TRADE` bias. | Reported — standard MTF synchronization. |

---

# Concept 1 — HTF Bias Engine

- **Definition:** The module responsible for tracking the prevailing market trend on the Primary Trend Timeframe (H4).
- **Mechanism:** It wraps an instance of `CMarketStructureEngine` initialized to `PERIOD_H4` with `SFS = 2`.
- **Output:** Returns an `ENUM_STRUCTURE_STATE` (BULLISH, BEARISH, UNKNOWN).
- **Update Frequency:** Evaluates structural swings exclusively on the close of H4 bars.
- **Constraints:** Must not instantiate BOS, CHoCH, OB, or FVG engines for the H4 timeframe.

---

# Concept 2 — MTF Synchronization

- **Definition:** The logic that gates trade opportunities by ensuring higher-timeframe and structure-timeframe alignment.
- **Rule:**
  - `IF (H4_State == BULLISH) AND (H1_State == BULLISH) THEN Bias = BULLISH`
  - `IF (H4_State == BEARISH) AND (H1_State == BEARISH) THEN Bias = BEARISH`
  - `ELSE Bias = NEUTRAL` (Trade gated/blocked)
- **Application:** The synchronized bias dictates which side of the market is permissible for Confluence Engine scoring. (e.g., if Bias is BULLISH, the engine will only look for Pullbacks into Discount Bullish OBs/FVGs).

---

# Edge Cases & Recovery

- **Insufficient H4 History:** If the H4 structure engine has not yet formed enough swings to establish a state (returns `STRUCTURE_STATE_UNKNOWN`), the synchronized bias defaults to `NEUTRAL` (no trading).
- **Mid-Trade Bias Shift:** If the H4 bias flips while an H1/M15 trade is currently active, the MTF Synchronization Engine updates the bias, but it does **not** forcefully close the active trade. Active trade lifecycles are governed solely by Trade Management (Layer 5). The MTF Sync only gates *new* entries.
