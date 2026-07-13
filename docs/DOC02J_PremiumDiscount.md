# DOC02J — Premium and Discount Engine
## Official Specification for Dealing Range & Spatial Zones (H1)

> **Document status:** AUTHORITATIVE — Official specification for the **Premium Discount Engine**.
> **Phase:** Module Specification (Phase 2, Part J).
> **Scope of this document:** Dealing Range, Equilibrium, Premium Zone, Discount Zone.
> **Explicitly out of scope:** Multi-timeframe bias (DOC02K), Confluence (DOC03B).
> **Relationship to prior documents:**
> - Implements **DOC00_Strategy_Validation.md §17 (Premium) and §18 (Discount)** exactly.
> - Consumes **only** the outputs of **DOC02A** (Confirmed Swing High, Confirmed Swing Low).
> - Writes into the *SpatialContext* section of the Structural Context (**DOC01**, Layer 2).

---

# Reported Items (reported, not changed)

| # | Item | Status |
|---|---|---|
| R-1 | **Dealing Range Definition** — DOC00 references "the recent swing high to swing low". DOC02J explicitly determinises this as the range between the **Last Confirmed Swing High** and **Last Confirmed Swing Low** from DOC02A. | Reported — operationalisation of DOC00. |
| R-2 | **Continuous Evaluation** — DOC02J clarifies that Premium, Discount, and Equilibrium zones are dynamic and update *immediately* upon the confirmation of any new Swing High or Swing Low. | Reported — clarification of update frequency. |
| R-3 | **Zone Strictness** — Equilibrium is a singular price point. Premium is strictly `> Equilibrium`. Discount is strictly `< Equilibrium`. If price exactly equals Equilibrium, it is in neither Premium nor Discount. | Reported — strict mathematical bounding. |

---

# Concept 1 — Dealing Range

- **Definition:** The spatial vertical distance between the most recent Confirmed Swing High and the most recent Confirmed Swing Low.
- **Upper Bound (`Range High`):** `CMarketStructureEngine::GetLastSwingHighPrice()`.
- **Lower Bound (`Range Low`):** `CMarketStructureEngine::GetLastSwingLowPrice()`.
- **Invalid Condition:** If either Swing High or Swing Low is `0.0` (uninitialized), the Dealing Range is undefined.

---

# Concept 2 — Equilibrium

- **Definition:** The exact mathematical midpoint of the current Dealing Range.
- **Formula:** `(Range High + Range Low) / 2.0`.
- **Purpose:** Acts as the dividing line separating expensive prices from cheap prices within the current market leg.

---

# Concept 3 — Premium Zone

- **Definition:** The upper half of the Dealing Range. Prices considered "expensive" and optimal for selling (shorting).
- **Boundaries:** `[Equilibrium < Price <= Range High]`. (Note: prices above Range High are also technically Premium, but structurally they indicate a breakout/BOS. For context mapping, any price strictly `> Equilibrium` is Premium).
- **Rule:** A Bearish Order Block or Bearish FVG is highly qualified only if it resides within the Premium zone (DOC00 §17).

---

# Concept 4 — Discount Zone

- **Definition:** The lower half of the Dealing Range. Prices considered "cheap" and optimal for buying (going long).
- **Boundaries:** `[Range Low <= Price < Equilibrium]`.
- **Rule:** A Bullish Order Block or Bullish FVG is highly qualified only if it resides within the Discount zone (DOC00 §18).

---

# Implementation Strategy
1. The **Premium Discount Engine** acts as a lightweight calculator and state-holder.
2. It listens to closed H1 bars (or directly to `CMarketStructureEngine` swing updates).
3. It exposes query methods: `IsPremium(price)`, `IsDiscount(price)`, `GetEquilibrium()`.
4. It consumes `O(1)` memory and computing power.
