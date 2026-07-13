# DOC02I — Breaker Block Engine
## Official Specification for Breaker Block Promotion, Lifecycle, and Mitigation (H1)

> **Document status:** AUTHORITATIVE — Official specification for the **Breaker Block Engine only**.
> **Phase:** Module Specification (Phase 2, Part I).
> **Scope of this document:** Bullish Breaker Block, Bearish Breaker Block, Breaker Promotion (from invalidated OB), Breaker Lifecycle, Mitigation, Active/Historical Breakers, and Breaker States.
> **Explicitly out of scope (future documents):** Entry Strategy, Risk Management, Trade Management, Order Block Selection (DOC02EB), and Mitigation Block (future document).
> **Relationship to prior documents:**
> - Implements **DOC00_Strategy_Validation.md §19 (Breaker Block)** without modification to its definition.
> - Consumes **only** the outputs of **DOC02EB** (Order Block records and their state transitions, specifically INVALIDATED OBs).
> - Consumes **only** the outputs of **DOC02B** (Confirmed BOS) and **DOC02C** (Confirmed CHoCH) for the qualifying opposite-direction break.
> - Writes into the *BreakerBlocks* section of the Structural Context (**DOC01**, Layer 2). It is the sole writer of that section.
> - Conforms to **DOC00_PATCH_001.md**: Breaker Blocks are promoted and lifecycle-managed on the **Market Structure Timeframe (H1)**.
> **Priority rule:** If anything here appears to conflict with DOC00–DOC02EB, those documents prevail. DOC02I governs only the Breaker Block Engine details.

---

# Reported Items (reported, not changed)

Per the standing instruction to *report* rather than silently change, the following are flagged. Each defines a **new operational construct** required by this document's scope that is **not present in DOC00**, defined deterministically and consistently with DOC00. **No approved document was modified.**

| # | Item | Status |
|---|---|---|
| R-1 | **Breaker Block States / Lifecycle machine** (Candidate/Confirmed/Active/Mitigated/Archived) — DOC00 §19 specifies only *promotion* (failed OB + opposite BOS/CHoCH → Breaker) and *mitigation* (price returns to zone). DOC00 does not name a state machine, nor the Candidate/Active/Archived states. DOC02I designs the requested lifecycle as the operational realisation of DOC00's promotion/mitigation semantics. It is a DOC02I design element, not a DOC00 redefinition. | Reported — extension, consistent with DOC00 §19. |
| R-2 | **Breaker Block Priority (lower than OB)** — DOC00 §19 states Breakers are "lower-priority zones, used only when no valid OB exists in the correct Premium/Discount half." DOC02I encodes this as a hard rule: a Breaker is **not consumable** if any ACTIVE or MITIGATED Order Block of the same direction exists in the correct Premium/Discount zone. This is a downstream consumption rule, not a Breaker lifecycle rule. | Reported — operationalisation of DOC00 §19 priority. |
| R-3 | **Single Breaker per failed OB** — DOC00 §19 edge case: "Multiple failed OBs before the opposite BOS → only the most recently failed one becomes the Breaker." DOC02I enforces this deterministically: when an opposite BOS/CHoCH occurs, the engine scans invalidated OBs of the opposite direction and promotes **only the most recently invalidated** one. All other invalidated OBs remain archived (no Breaker). | Reported — operationalisation of DOC00 §19 edge case. |
| R-4 | **Zone = original OB's High-Low (immutable)** — DOC00 §19: "The Breaker zone equals the original failed OB's high–low." DOC02I uses the invalidated OB's zone boundaries verbatim. The zone is never edited after promotion. | Reported — consistent with DOC00 §19. |
| R-5 | **Direction reversal** — A failed Bearish OB (which was a resistance zone) becomes a **Bullish Breaker** (support). A failed Bullish OB becomes a **Bearish Breaker** (resistance). The direction is reversed from the original OB. | Reported — consistent with DOC00 §19 polarity flip. |
| R-6 | **No Breaker invalidation** — DOC00 §19 does not define an "invalidation" event for Breakers (only mitigation). DOC02I therefore does **not** introduce Breaker invalidation. A Breaker transitions ACTIVE → MITIGATED → ARCHIVED. It does not have an INVALIDATED state. (This differs from OB, which can be invalidated.) | Reported — extension, consistent with DOC00 §19 (which is silent on Breaker invalidation). |
| R-7 | **Active vs Historical Breakers** — DOC00 does not distinguish "active" vs "historical" Breakers. DOC02I defines **Active Breakers** (the current, consumable Breakers) and **Historical Breakers** (mitigated/archived records retained for audit). Organisational distinction, not a new SMC rule. | Reported — extension, no contradiction. |
| R-8 | **Consumability / look-ahead guard** — DOC00 §19 states the Breaker is finalised "when the opposite BOS/CHoCH closes." DOC02I encodes this as a hard rule: a Breaker is consumable by downstream modules **only after** its confirming BOS/CHoCH close timestamp; before that it is a Candidate (not exposed for entries). | Reported — operationalisation of DOC00 §19. |

No approved document was modified.

---

# Concept 1 — Bullish Breaker Block

- **Definition:** A **Bullish Breaker Block** is promoted when a previously **Bearish Order Block** is **invalidated** (body closes beyond its far edge = High, per DOC02EB) and price then **breaks structure to the upside** (confirmed **Bullish BOS or Bullish CHoCH**). The zone of that failed Bearish OB becomes a **support zone** (Bullish Breaker).
- **Purpose:** A secondary re-entry zone used when no fresh Order Block is available in the correct Premium/Discount half (DOC00 §19).
- **Relationship with previous documents:** Extends DOC02EB lifecycle. The zone is the same as the failed OB; the direction and consumption semantics are reversed. Written into the *BreakerBlocks* section of the Structural Context (DOC01); this engine is the sole writer.
- **Inputs:** An invalidated Bearish OB record (from DOC02EB, state = INVALIDATED); a confirmed Bullish BOS or Bullish CHoCH (from DOC02B/DOC02C).
- **Outputs:** A Bullish Breaker Block record (direction = BULLISH, zone = original Bearish OB's High-Low, promotion timestamp = BOS/CHoCH close time, state = ACTIVE).
- **Dependencies:** DOC02EB (invalidated OB records); DOC02B/DOC02C (confirmed BOS/CHoCH events).
- **Failure Conditions:** No invalidated Bearish OB exists; no opposite Bullish BOS/CHoCH occurs; the invalidated OB was already promoted (defensive).
- **Edge Cases / Lifecycle:** See respective sections below.

---

# Concept 2 — Bearish Breaker Block

- **Definition:** A **Bearish Breaker Block** is promoted when a previously **Bullish Order Block** is **invalidated** (body closes beyond its far edge = Low, per DOC02EB) and price then **breaks structure to the downside** (confirmed **Bearish BOS or Bearish CHoCH**). The zone of that failed Bullish OB becomes a **resistance zone** (Bearish Breaker).
- **Purpose:** Mirror of Concept 1. A secondary re-entry zone used when no fresh Order Block is available.
- **Relationship with previous documents:** Mirror of Concept 1. Extends DOC02EB lifecycle.
- **Inputs/Outputs/Dependencies/Rules:** Mirror of Concept 1.

---

# Breaker Block Promotion — Detailed

### Trigger Sequence (Two-Step)
A Breaker is promoted **only** when **both** conditions occur in sequence:
1. **Step 1 — OB Invalidation:** An Order Block is invalidated (body closes beyond far edge, per DOC02EB). The OB transitions to INVALIDATED → ARCHIVED.
2. **Step 2 — Opposite BOS/CHoCH:** After the OB invalidation, a **confirmed BOS or CHoCH in the opposite direction** occurs.
   - Failed Bearish OB → requires subsequent **Bullish BOS or Bullish CHoCH**
   - Failed Bullish OB → requires subsequent **Bearish BOS or Bearish CHoCH**

Both steps must occur. A failed OB without a subsequent opposite BOS/CHoCH is **just a failed OB**, not a Breaker (DOC00 §19).

### Non-Triggers (Breaker is NOT promoted)
- OB reaches INVALIDATED, but no opposite BOS/CHoCH occurs → no Breaker.
- OB reaches INVALIDATED, and an opposite BOS/CHoCH occurs, but the OB was already promoted (defensive) → no new Breaker.
- OB reaches MITIGATED or EXPIRED (not INVALIDATED) → no Breaker. Only invalidated OBs are eligible.

### Zone Boundaries
- The Breaker's upper and lower boundaries are **numerically identical** to the original invalidated OB's boundaries (High-Low, per DOC02EB R-6).
- The zone is **immutable** after promotion. It is never edited.

### Direction Assignment
- Original Bearish OB (resistance) → Breaker direction = **BULLISH** (support)
- Original Bullish OB (support) → Breaker direction = **BEARISH** (resistance)

### Promotion Timestamp
- The **promotion timestamp** = the close time of the H1 bar that confirmed the opposite BOS/CHoCH. This is the moment the Breaker becomes active.

### Lock Timestamp
- The **lock timestamp** = the promotion timestamp (same bar). The Breaker becomes consumable on the **next** closed H1 bar after its promotion (look-ahead guard, per R-8).

### Single Breaker per Failed OB
- Each invalidated OB can produce **at most one** Breaker. Once promoted, the OB is flagged (defensive: no re-promotion).

### Most Recently Invalidated OB Wins
- When an opposite BOS/CHoCH occurs, the engine scans all invalidated OBs of the opposite direction that have **not yet been promoted**.
- If multiple exist, **only the most recently invalidated** one is promoted to a Breaker (DOC00 §19 edge case).
- All other invalidated OBs remain archived (no Breaker).

### Immutable Rules
1. Once promoted, the Breaker zone boundaries are **never edited**. (Mirrors DOC02EB immutability.)
2. Only the **state** may change (ACTIVE → MITIGATED → ARCHIVED), via defined lifecycle transitions on closed bars.
3. The original OB record is **never modified** by the promotion process (it remains INVALIDATED/ARCHIVED in DOC02EB). The Breaker is a new record that references the original.

---

# Breaker Block — Mitigation Rules

### Definition
A Breaker is **mitigated** when a closed candle's **body returns to the Breaker zone**. (DOC00 §19, mirroring DOC02EB mitigation.)

### Body Close Requirement
- Uses the candle **close** price vs. the zone boundaries (not the wick).
- **Bullish Breaker (support):** Mitigation occurs when a closed candle's body closes **within or below** the Breaker zone (i.e., `Close <= upper_boundary`). The zone is considered "touched."
- **Bearish Breaker (resistance):** Mitigation occurs when a closed candle's body closes **within or above** the Breaker zone (i.e., `Close >= lower_boundary`).

### Mitigation Timestamp
- The close time of the closed candle whose body returned to the zone.

### Mitigation State
- The Breaker transitions ACTIVE → MITIGATED at the mitigation timestamp. It remains consumable downstream (a mitigated Breaker is the entry-reference event per DOC00 §19), but its lifecycle state is MITIGATED.

### No Partial Mitigation Tracking
- Unlike FVG (DOC02F), Breakers do **not** track partial mitigation. A body return = full mitigation. The state transitions directly ACTIVE → MITIGATED.

### Repeated Mitigation
- Once a Breaker is MITIGATED, it stays MITIGATED. Repeated body returns do not change the state. The Breaker is archived (→ ARCHIVED) after mitigation.

---

# Breaker Block — No Invalidation

### Design Decision
DOC00 §19 does not define an "invalidation" event for Breakers. DOC02I therefore does **not** introduce Breaker invalidation. A Breaker transitions ACTIVE → MITIGATED → ARCHIVED. It does not have an INVALIDATED state.

### Rationale
- A Breaker is already a "failed" zone (the original OB failed). It is a secondary, lower-priority re-entry zone.
- If price blows through a Breaker zone, it simply means the Breaker did not hold. The Breaker is mitigated (touched) and archived. There is no need for a separate "invalidation" state.
- This simplifies the lifecycle and avoids ambiguity (is a Breaker that was blown through "invalidated" or "mitigated"?).

### Contrast with Order Block
- **Order Block (DOC02EB):** Can be INVALIDATED (body closes beyond far edge). OB invalidation is the **trigger** for Breaker promotion.
- **Breaker Block (DOC02I):** Cannot be INVALIDATED. Only MITIGATED (body returns to zone). No further promotion or inversion.

---

# Breaker Block — Priority Rule (Lower than OB)

### Definition
A Breaker is **not consumable** if any ACTIVE or MITIGATED Order Block of the same direction exists in the correct Premium/Discount zone (DOC00 §19).

### Implementation
- Downstream modules (Entry Decision Engine, Confluence Engine) check for the presence of a valid OB before consuming a Breaker.
- If an OB exists, the Breaker is **ignored** (not used for entry).
- If no OB exists, the Breaker is **consumable** (used for entry).

### Priority Check (Pseudocode)
```
if (Breaker.direction == BULLISH) {
    if (no ACTIVE/MITIGATED Bullish OB in Discount zone) {
        // Breaker is consumable
    } else {
        // Breaker is ignored (OB takes priority)
    }
}
```

### Rationale
- Breakers are "weaker than OBs" (DOC00 §19). They are a fallback, not a primary entry zone.
- This rule ensures the EA always prefers a fresh OB over a Breaker when both are available.

---

# Breaker Block Lifecycle — Complete State Machine

Each Breaker Block has exactly one state at any time. Transitions occur only on closed H1 bars.

### States

#### CANDIDATE
- **Purpose:** An invalidated OB has been identified, and an opposite BOS/CHoCH is being evaluated. Pre-promotion.
- **Entry Conditions:** An OB transitions to INVALIDATED (DOC02EB). The engine flags it as a Breaker candidate.
- **Exit Conditions:** Opposite BOS/CHoCH confirmed → CONFIRMED; no opposite BOS/CHoCH → remains CANDIDATE indefinitely (or until superseded by a newer invalidated OB).
- **Allowed Transitions:** → CONFIRMED; → (remains CANDIDATE).
- **Forbidden Transitions:** → ACTIVE, MITIGATED, ARCHIVED (cannot be consumed before promotion).
- **Recovery:** Transient; resolved when opposite BOS/CHoCH occurs or newer invalidated OB supersedes.

#### CONFIRMED
- **Purpose:** The Breaker has been promoted (opposite BOS/CHoCH confirmed). Immutable record now exists.
- **Entry Conditions:** From CANDIDATE when opposite BOS/CHoCH is confirmed.
- **Exit Conditions:** Finalisation → ACTIVE.
- **Allowed Transitions:** → ACTIVE.
- **Forbidden Transitions:** → MITIGATED, ARCHIVED (require ACTIVE first).
- **Recovery:** Automatic finalisation.

#### ACTIVE
- **Purpose:** The Breaker is a live, consumable zone; eligible for mitigation checks and downstream consumption (subject to priority rule).
- **Entry Conditions:** From CONFIRMED.
- **Exit Conditions:** Mitigation (body returns to zone) → MITIGATED.
- **Allowed Transitions:** → MITIGATED, ARCHIVED (retention).
- **Forbidden Transitions:** → CANDIDATE, CONFIRMED, INVALIDATED (no invalidation for Breakers).
- **Recovery:** Rebuild from immutable histories on inconsistency.

#### MITIGATED
- **Purpose:** A closed candle's body returned to the Breaker zone. The Breaker has been "used" as an entry reference.
- **Entry Conditions:** From ACTIVE on body return to zone.
- **Exit Conditions:** → ARCHIVED.
- **Allowed Transitions:** → ARCHIVED.
- **Forbidden Transitions:** → ACTIVE (mitigation is terminal; a Breaker does not become "un-mitigated").
- **Recovery:** None; terminal.

#### ARCHIVED
- **Purpose:** Terminal retention. Read-only historical record.
- **Entry Conditions:** From MITIGATED.
- **Exit Conditions:** None (pruned only by retention cap, FIFO).
- **Allowed Transitions:** None.
- **Recovery:** Immutable.

### State Machine Diagram (textual)

```
CANDIDATE → CONFIRMED → ACTIVE → MITIGATED → ARCHIVED
```

### State Machine Guarantees
- A Breaker is consumable **only** in ACTIVE or MITIGATED, and only **after** its lock timestamp.
- Mitigation is monotonic (ACTIVE → MITIGATED → ARCHIVED); Breakers never reopen.
- All transitions on closed H1 bars; the zone is immutable after the lock timestamp.
- **No invalidation:** Breakers do not have an INVALIDATED state.
- **No inversion:** Breakers do not invert (unlike FVG → IFVG).

---

# Active vs Historical Breaker Blocks

- **Active Breakers:** Breakers in ACTIVE or MITIGATED states. The consumable set. Subject to priority rule (lower than OB).
- **Historical Breakers:** Breakers in ARCHIVED state. Retained for audit/backtest. Read-only to all consumers.
- **Design intent:** Keep the Active set small (typically 0–2 Breakers at a time); Historical set grows to the retention cap, then prunes oldest-first.

---

# Breaker Block Record Structure

Each Breaker Block record contains:

| Field | Type | Description |
|---|---|---|
| `id` | string | Unique identifier (from CIdentifierGeneration, DOC01) |
| `direction` | enum | BULLISH or BEARISH (reversed from original OB) |
| `upper_boundary` | double | Identical to original OB's High (immutable) |
| `lower_boundary` | double | Identical to original OB's Low (immutable) |
| `original_ob_id` | string | Reference to the original OB record that was invalidated |
| `original_direction` | enum | The original OB's direction (opposite of `direction`) |
| `ob_creation_timestamp` | datetime | Original OB's creation timestamp (from DOC02EB) |
| `ob_invalidation_timestamp` | datetime | Original OB's invalidation timestamp (from DOC02EB) |
| `promotion_timestamp` | datetime | The bar at which opposite BOS/CHoCH occurred |
| `lock_timestamp` | datetime | Same as `promotion_timestamp` (look-ahead guard) |
| `state` | enum | CANDIDATE, CONFIRMED, ACTIVE, MITIGATED, ARCHIVED |
| `mitigation_timestamp` | datetime | Timestamp of mitigation (0 if not yet mitigated) |
| `archive_timestamp` | datetime | Timestamp of archival (0 if not yet archived) |
| `optional_context` | struct | Optional: BOS/CHoCH/sweep alignment at time of promotion (audit only) |

---

# Dependencies (consumer only)

The Breaker Block Engine consumes **only** the following, read-only:

| Consumed from | Used for |
|---|---|
| DOC02EB: Invalidated Order Block records | Trigger for Breaker promotion (INVALIDATED state) |
| DOC02EB: OB zone boundaries | Breaker zone boundaries (immutable copy) |
| DOC02B: Confirmed BOS events | Qualifying opposite-direction break |
| DOC02C: Confirmed CHoCH events | Qualifying opposite-direction break |
| DOC01: Market Data Access | Closed H1 OHLC for mitigation tests |

The Breaker Block Engine **must not**:
- Create, modify, or delete any swing, BOS, CHoCH, liquidity, FVG, or Order Block record.
- Modify the original OB record (it is immutable after invalidation).
- Create or modify Entry, Risk, or Trade Management data.
- Read forming bars or any timeframe other than H1.

It is a **consumer** of DOC02EB's output and the **sole writer** of the *BreakerBlocks* section of the Structural Context.

---

# Implementation Constraints (MetaTrader 5)

### Detection window
- Breaker promotion is triggered at the same bar where the opposite BOS/CHoCH is confirmed (closed H1 bar). No lookback beyond the current bar is needed for the trigger.
- Mitigation checks are evaluated on each subsequent closed H1 bar — O(1) per Breaker per bar.

### Memory
- Each Breaker record is a fixed-size struct (~200 bytes). The active set is typically small (0–2 Breakers). The historical set is bounded by the retention cap.
- Total memory overhead: negligible.

### Performance
- Breaker promotion: O(1) per BOS/CHoCH event (scan invalidated OBs, pick most recent).
- Mitigation check: O(B) per bar, where B = number of ACTIVE Breakers (typically 0–2).
- Total per-bar cost: O(B) — near-constant.

### Logging
- Every Breaker state transition must be logged with: Breaker ID, direction, zone boundaries, original OB ID, bar index, timestamp, and transition reason.
- Log prefixes: `[Breaker]` for all Breaker Block events.

---

# Edge Cases

### Edge Case 1: Immediate mitigation
- **Scenario:** A Breaker is promoted (ACTIVE) and the very next closed bar mitigates it.
- **Resolution:** Valid. The Breaker transitions ACTIVE → MITIGATED → ARCHIVED. The Breaker's active life was exactly one bar.

### Edge Case 2: Multiple invalidated OBs before opposite BOS/CHoCH
- **Scenario:** Two Bearish OBs are invalidated within 3 bars. Then a Bullish BOS occurs.
- **Resolution:** Only the **most recently invalidated** Bearish OB is promoted to a Bullish Breaker. The older invalidated OB remains archived (no Breaker).

### Edge Case 3: Opposite BOS/CHoCH occurs before OB invalidation
- **Scenario:** A Bullish BOS occurs, but no Bearish OB has been invalidated yet.
- **Resolution:** No Breaker is promoted. The BOS is recorded (DOC02B), but without a prior invalidated OB, there is no Breaker candidate.

### Edge Case 4: Breaker zone overlaps with an active OB
- **Scenario:** A Bullish Breaker zone overlaps with an active Bullish OB.
- **Resolution:** The OB takes priority (per priority rule). The Breaker is ignored for entry purposes. Both records coexist in the Structural Context.

### Edge Case 5: No mitigation, price moves away
- **Scenario:** A Breaker is ACTIVE. Price moves away without returning to the zone.
- **Resolution:** The Breaker remains ACTIVE indefinitely. It may eventually be superseded by a newer Breaker (if another OB is invalidated and opposite BOS/CHoCH occurs), but DOC02I does not define explicit expiration for Breakers (unlike FVG). The Breaker stays ACTIVE until mitigated or pruned by retention cap.

### Edge Case 6: Breaker promoted, but OB was already mitigated before invalidation
- **Scenario:** An OB is MITIGATED, then later invalidated (price blows through after mitigation).
- **Resolution:** Per DOC02EB, an OB that is MITIGATED can still be INVALIDATED if price closes beyond the far edge. The invalidated OB is eligible for Breaker promotion. The Breaker is promoted as usual.

---

# Validation Checklist

- **Consistency with DOC00 §19:** DOC00 Breaker definition (failed OB + opposite BOS/CHoCH) is unchanged. DOC02I operationalises the lifecycle. *(Pass)*
- **Consistency with DOC02EB:** DOC02EB OB lifecycle (ACTIVE → MITIGATED → INVALIDATED → ARCHIVED) is unchanged. DOC02I consumes invalidated OBs only. *(Pass)*
- **Consistency with DOC01:** Breaker writes into the BreakerBlocks section of the Structural Context. This engine is the sole writer. *(Pass)*
- **No subjective language:** Avoided. No "significant," "strong," "likely" as judgement. All rules are fixed comparisons. *(Pass)*
- **No repaint possibility:** Eliminated. Breaker promoted only on closed bar (opposite BOS/CHoCH confirmation). Mitigation checks only on closed bars. *(Pass)*
- **No look-ahead bias:** Eliminated. Only closed candles. Breaker consumable only after lock timestamp. *(Pass)*
- **No circular dependency:** Breaker Engine depends only on DOC02EB output and DOC02B/DOC02C events. No feedback into structure/liquidity/OB. *(Pass)*
- **Implementation feasibility:** All inputs via DOC01 Market Data Access + Structural Context; O(1)/O(B) cost; bounded memory. *(Pass)*
- **Performance feasibility:** Near-constant per bar; tiny active set; FIFO-bounded archives. *(Pass)*
- **Maintainability:** Single concern (post-invalidation promotion); clean consumer of DOC02EB; full audit trail. *(Pass)*

**Scope boundaries respected:** Entry Strategy, Risk Management, Trade Management, Order Block Selection, and Mitigation Block are **not** designed here. The Breaker Block Engine promotes and lifecycle-manages Breaker zones only.

**Reported items (R-1…R-8)** are operational extensions consistent with DOC00; none redefines an approved concept.

**Outcome:** No blocking issues. DOC02I is internally consistent, deterministic, and implementable on MT5 without modification to DOC00–DOC02EB.
