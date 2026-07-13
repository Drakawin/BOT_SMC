# DOC02H — Balanced Price Range (BPR) Engine
## Official Specification for Balanced Price Range Detection & Lifecycle (H1)

> **Document status:** AUTHORITATIVE — Official specification for the **Balanced Price Range Engine only**.
> **Phase:** Module Specification (Phase 2, Part H).
> **Scope of this document:** Balanced Price Range Detection, BPR Minimum Size, Multiple Overlaps, BPR State Machine, Fill Lifecycle, Interaction with Original/Inverse FVGs.
> **Explicitly out of scope (future documents):** Entry Strategy, Risk Management, Trade Management.
> **Relationship to prior documents:**
> - Implements SMC's Balanced Price Range concept deterministically as an extension to **DOC02F (FVG Engine)**.
> - Conforms to **DOC00_PATCH_001.md**: Detected and lifecycle-managed on the **Market Structure Timeframe (H1)**.
> - Writes into the *FVG* section of the Structural Context (**DOC01**, Layer 2).
> **Priority rule:** If anything here appears to conflict with DOC00–DOC02G, those documents prevail.

---

# Reported Items (reported, not changed)

| # | Item | Status |
|---|---|---|
| R-1 | **Balanced Price Range (BPR) Construction** — DOC00 does not explicitly specify BPR. DOC02H defines BPR deterministically as the mathematical overlap (intersection) between an ACTIVE/PARTIALLY_FILLED Bullish FVG and an opposite Bearish FVG. | Reported — extension, SMC standard concept. |
| R-2 | **Direction determination by latest FVG** — DOC02H assigns the direction of the BPR based on the *newest* FVG that triggers the overlap (e.g., a new Bullish FVG overlapping an old Bearish FVG creates a Bullish BPR). | Reported — operational decision. |
| R-3 | **Cross-direction overlap detection** — DOC02F only handles same-direction overlap merging. DOC02H handles cross-direction overlap to generate BPRs. | Reported — extension of overlap mechanics. |
| R-4 | **BPR Minimum Size** — DOC02F defines FVG Min Size (10 points). DOC02H applies this exact same constraint to BPRs: the *overlapping area itself* must be `≥ FVG Min Size` to form a valid BPR. | Reported — consistent false-signal mitigation. |
| R-5 | **BPR State Machine & No Inversion** — BPR uses the exact same states as DOC02F (ACTIVE, PARTIALLY_FILLED, FILLED, INVALIDATED, EXPIRED, ARCHIVED). However, unlike regular FVGs (DOC02G), a FILLED BPR does **not** invert into an Inverse BPR; it transitions terminally to ARCHIVED. | Reported — lifecycle operational decision. |
| R-6 | **Restriction to Original FVGs only** — To prevent exponential permutations, BPRs are formed **only** from the overlap of two *Original* FVGs. IFVGs overlapping FVGs, or IFVGs overlapping IFVGs, do **not** form BPRs. | Reported — constraint to ensure systemic stability. |

---

# Concept 1 — Balanced Price Range (BPR)

- **Definition:** A **Balanced Price Range** is an independent price zone created when a newly confirmed Original FVG mathematically overlaps with an existing ACTIVE or PARTIALLY_FILLED Original FVG of the **opposite direction**.
- **Zone Boundaries:** The BPR is the strictly overlapping area between the two FVGs at the moment of creation, using their *remaining unfilled boundaries*:
  - `Upper Boundary = min(FVG1.remainingUpper, FVG2.remainingUpper)`
  - `Lower Boundary = max(FVG1.remainingLower, FVG2.remainingLower)`
- **Independence:** Once created, the BPR is an independent entity. If the component FVGs that formed it are later filled, expired, or invalidated, the BPR record remains unaffected and maintains its own lifecycle.

---

# Creation Rules & Edge Cases

### Multiple Overlaps
- If a single newly created FVG overlaps with **multiple** opposite-direction ACTIVE FVGs, **multiple distinct BPRs** are generated (one for each valid overlap that meets the minimum size). They are not merged together unless they share the same direction and overlap each other (handled by DOC02F overlap merge natively).

### BPR Minimum Size
- An overlap is only valid if `Upper Boundary - Lower Boundary ≥ FVG Min Size (10 points)`. 
- Overlaps that touch at a single point (Upper A = Lower B) have width 0 and are rejected. Thin overlaps < 10 points are rejected.

### Interaction with IFVG (Inversions)
- BPRs are constructed **exclusively** from Original FVGs. IFVGs do not participate in BPR creation.
- A completely FILLED BPR transitions to ARCHIVED. It does **not** undergo inversion.

---

# State Machine & Fill Lifecycle

BPRs follow the exact **body-based, closed H1 candle** tracking mechanics as DOC02F.

1. **ACTIVE**: Formed upon valid overlap.
2. **PARTIALLY_FILLED**: A closed candle body penetrates the BPR boundary but does not fully trade through it. The `remainingUpper` or `remainingLower` is adjusted.
3. **FILLED**: A closed candle body completely trades through the remaining BPR zone. Terminal state (transitions directly to ARCHIVED).
4. **INVALIDATED**: Gap collapse (remaining width ≤ 0) without a complete body fill. Terminal state.
5. **EXPIRED**: The BPR capacity cap per direction (shared pool with FVGs/IFVGs) is exceeded, superseding older BPRs. Terminal state.
6. **ARCHIVED**: Final resting state for pruned/dead BPRs.

---

# Implementation Constraints
1. **Array Injection:** Since a BPR behaves operationally identical to a standard FVG (it has an upper/lower bound, direction, and is filled by bodies), it is injected directly into the FVG Engine's main tracking array `m_fvgs` using a `bool isBPR = true` flag. This avoids writing a parallel, redundant fill-tracking engine.
2. **Detection Order:** In the FVG Engine execution flow, same-direction `MergeWithOverlaps` must execute **first**, followed immediately by `CheckBPROverlaps` using the finalized bounds.

---

# Validation Checklist
- [ ] BPR creates only when overlap `≥ FVG Min Size`.
- [ ] BPR ignores IFVGs.
- [ ] BPR completely fills on body-through.
- [ ] FILLED BPR does not invert.
- [ ] Included in the `EnforceActiveCap` limit.