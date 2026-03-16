---
name: autosar-bsw-review
description: Reviews AUTOSAR BSW configuration and code for common MCAL/BSW issues. Use when reviewing BSW configs, MCAL settings, or AUTOSAR-compliant code.
---

# AUTOSAR BSW Review

Performs structured review of AUTOSAR Basic Software (BSW) configuration and code.

## Minimum Inputs

- **Config/code path**: Path to BSW config (ARXML, DaVinci/Eb tresos export) or BSW source
- **Scope** (optional): MCAL, Com, Mem, Diag, etc.

## Evidence Discipline

Output must include:
- Checklist of reviewed items (config params, init order, error handling)
- Issue list with severity (Critical/Suggestion/Info)
- Reference to AUTOSAR spec section where applicable
- Recommendations with concrete fix steps

## Constraints

- Do not modify source; output review report only
- Distinguish config vs. code issues
- For ARXML: validate schema compliance where possible

## Review Checklist (MCAL/BSW)

- **MCAL**: Clock config, GPIO init order, ADC calibration, CAN/LIN baud
- **Com**: PDU routing, signal layout, timeout handling
- **Mem**: NVM block layout, CRC, default values
- **Diag**: DCM/DEM config, DTC mapping, UDS routing

## Reference Standards

- AUTOSAR BSW SWS (Software Specification)
- AUTOSAR MCAL SRS
