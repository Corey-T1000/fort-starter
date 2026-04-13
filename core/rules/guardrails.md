# Guardrails

Hooks enforce security and git rules automatically — you'll be blocked or prompted. No need to memorize the inventory.

## Sandbox Model
- **Seatbelt** (macOS): Host filesystem restrictions via `/sandbox`
- **Orbstack VM** (`fort-sandbox`): Full isolation for untrusted code

## Permissions
Broad Bash allowances. SSH to remote servers affects shared infrastructure — be deliberate. Use sandbox for untrusted execution.
