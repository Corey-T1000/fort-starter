# scratch/scripts/

One-off bash, python, or node helpers — the kind of script you write once to migrate data, audit a directory, or poke an API, and might never run again.

## Conventions

- Name scripts by intent, not by language: `audit-stale-branches.sh`, not `script.sh`
- Add a 2-3 line header comment explaining what the script does and when it was used
- If a script earns recurring use, promote it to a real `bin/` location and delete the scratch copy
- Don't be precious — `rm` freely; that's what scratch is for

## Examples

```
scripts/
  migrate-old-config.py       # one-time, ran 2026-04-10
  count-files-by-ext.sh
  hit-api-with-csv.ts
```
