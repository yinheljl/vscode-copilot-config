---
name: someip-service-debug
description: Debugs SOME/IP service discovery, method calls, and event flows. Use when analyzing SOME/IP logs, service descriptions, or Ethernet-based in-vehicle communication.
---

# SOME/IP Service Debug

Guides debugging of SOME/IP services: discovery, method calls, and events.

## Minimum Inputs

- **Service description**: FIDL, ARXML, or JSON service definition; or log file path
- **Issue** (optional): e.g., "service not found", "method timeout", "event not received"

## Evidence Discipline

Output must include:
- Service/event/method mapping from description
- Expected message flow (Find, Offer, Subscribe, Notify)
- Anomaly analysis if log provided
- Suggested checks (multicast, port, instance ID)

## Constraints

- Follow SOME/IP spec; do not assume non-standard behavior
- Distinguish SD (Service Discovery) vs. payload messages
- Mark OEM-specific extensions when present

## Workflow

1. **Parse service definition**: Extract Service ID, Instance, Method/Event IDs
2. **Map flow**: Find/Offer, Subscribe/SubscribeAck, Request/Response
3. **Log analysis**: Match frames to expected flow, flag gaps
4. **Recommendations**: Wireshark filters, config checks

## Reference Standards

- SOME/IP Specification (Automotive Grade Linux / COVESA)
- AUTOSAR SOME/IP binding
