# scratch/playground/

Structured prototypes meant to graduate to production. Unlike `design-lab/` (single-file visual studies), playground entries are scaffolded mini-projects — package.json, source files, the works.

## Conventions

- One subdir per prototype: `playground/<name>/`
- Mirror the architecture of the real project it might graduate into (same framework, similar layout)
- When code is ready to promote, move it into the real project tree and delete or archive the playground entry
- Don't treat playground entries as long-lived — they're disposable by design

## Examples

```
playground/
  new-auth-flow/
    package.json
    src/
    README.md
  websocket-spike/
    server.ts
```
