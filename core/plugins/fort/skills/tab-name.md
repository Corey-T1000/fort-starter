---
name: tab-name
description: |
  Set the tab title. Use when the user says "tab", "set tab", "rename tab",
  "tab title", "tab-name", or wants to label the current session.
user_invocable: true
argument-hint: "<title>"
arguments:
  - name: title
    description: "Tab title to set (auto-prefixed with 'fort:' if not already)"
    required: true
---

# Tab Name

Set the Ghostty tab title for the current session.

## Usage

```
/tab-name reviews
/tab-name fort:dashboard
/tab-name my-project
```

## Behavior

1. If the title doesn't start with `fort:`, prefix it automatically
2. Run `tab-title "{title}"`
3. Confirm with a one-liner: "Tab → {title}"

```bash
tab-title "$ARGUMENTS"
```
