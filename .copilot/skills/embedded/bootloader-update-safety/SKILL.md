---
name: bootloader-update-safety
description: Validates bootloader update safety: signature, version check, rollback strategy. Use when designing or reviewing ECU software update flows.
---

# Bootloader Update Safety

Guides safety review of bootloader and software update processes.

## Minimum Inputs

- **Update package or config**: Path to SW package, manifest, or update procedure
- **Scope** (optional): Signature, versioning, rollback, recovery

## Evidence Discipline

Output must include:
- Safety checklist (signature verification, version check, integrity)
- Rollback strategy and conditions
- Recovery path if update fails
- Gaps or recommendations

## Constraints

- Do not modify packages; review only
- Assume secure boot / HSM if OEM standard; note if absent
- Mark OEM-specific requirements when referenced

## Workflow

1. **Integrity**: Signature algorithm, key storage, verification point
2. **Versioning**: Compatibility matrix, downgrade policy
3. **Rollback**: Trigger conditions, stored golden image
4. **Recovery**: Safe mode, recovery boot, re-flash path

## Reference Standards

- ISO 14229 (UDS, 0x31, 0x36, 0x37)
- ISO/SAE 21434 (software update security)
- Common OEM SW update specs (e.g., VW TP, BMW)
