---
name: uds-diagnostic-flow
description: Guides UDS diagnostic sequence design and execution per ISO 14229. Use when defining diagnostic flows, DTC handling, or service sequences for vehicle ECUs.
---

# UDS Diagnostic Flow

Provides structured guidance for UDS (Unified Diagnostic Services) diagnostic sequences per ISO 14229.

## Minimum Inputs

- **Service IDs**: List of UDS services (e.g., 0x22, 0x2E, 0x19)
- **DTC list** (optional): DTC codes to read/clear
- **Target**: ECU address, optional sub-function parameters

## Evidence Discipline

Output must include:
- Service sequence with request/response format (hex)
- Expected positive/negative response codes
- Timing constraints (P2, P2* where applicable)
- DTC read/clear flow if DTCs provided

## Constraints

- Follow ISO 14229 service definitions; do not invent non-standard services
- Mark OEM-specific extensions clearly when used
- Session/security transitions must be explicit (e.g., 0x10 0x03 before 0x2E)

## Workflow

1. **Session**: 0x10 0x03 (extended) if write access needed
2. **Security**: 0x27 if required by OEM
3. **Service sequence**: Per user request (read DID, write DID, DTC, etc.)
4. **Response check**: NRC handling, retry logic

## Reference Standards

- ISO 14229 (UDS)
- ISO 15765-2 (transport, timing)
