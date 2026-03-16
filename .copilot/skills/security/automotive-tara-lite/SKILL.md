---
name: automotive-tara-lite
description: Performs lightweight TARA (Threat Analysis and Risk Assessment) for automotive systems per ISO/SAE 21434. Use when conducting threat analysis or security concept review.
---

# Automotive TARA Lite

Provides a simplified TARA workflow aligned with ISO/SAE 21434.

## Minimum Inputs

- **System boundary**: Description of assets, interfaces, trust boundaries
- **Scope** (optional): Specific assets or attack paths

## Evidence Discipline

Output must include:
- Asset list with security relevance
- Threat list with attack path and impact
- Risk rating (or qualitative: High/Medium/Low)
- Mitigation suggestions with trace to controls

## Constraints

- Follow ISO/SAE 21434 concepts; mark simplifications
- Do not claim full TARA; label as "lite" / simplified
- OEM-specific methods (e.g., EVITA) noted when used

## Workflow

1. **Asset identification**: ECUs, data, functions
2. **Threat scenario**: Attack path, attacker capability
3. **Impact**: Safety, financial, privacy
4. **Risk**: Likelihood × impact (simplified)
5. **Mitigation**: Technical/organizational controls

## Reference Standards

- ISO/SAE 21434 (Cybersecurity engineering)
- EVITA (if referenced)
- SAE J3061 (precursor)
