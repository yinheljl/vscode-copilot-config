---
name: doip-diagnostic-gateway
description: Designs and validates DoIP diagnostic gateway routing and test cases per ISO 13400. Use when configuring DoIP gateways or routing UDS over Ethernet.
---

# DoIP Diagnostic Gateway

Guides DoIP (Diagnostics over IP) gateway configuration and test case design per ISO 13400.

## Minimum Inputs

- **Gateway config**: Routing table or config file (source/target addresses, logical addresses)
- **Scope** (optional): Routing validation, test cases, conformance

## Evidence Discipline

Output must include:
- Routing table summary (source → target, protocol)
- Test cases: vehicle discovery, routing, alive check, diagnostic message
- Conformance notes (ISO 13400-2) where applicable

## Constraints

- Follow ISO 13400; do not invent non-standard DoIP messages
- Distinguish IPv4 vs. IPv6 if both used
- Mark OEM-specific routing rules clearly

## Workflow

1. **Parse config**: Extract logical/physical address mapping
2. **Routing table**: Source ECU, target ECU, DoIP entity
3. **Test cases**: Vehicle discovery (0x0001), routing activation, UDS over DoIP
4. **Conformance**: Check required DoIP entities and messages

## Reference Standards

- ISO 13400-1 (DoIP overview)
- ISO 13400-2 (transport protocol, network layer)
