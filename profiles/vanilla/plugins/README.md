# profiles/vanilla/plugins/

Empty by design. Vanilla runs only the shared plugins from `core/plugins/` — `fort` and `fort-tools`.

## Why empty

Vanilla is the public-safe baseline. Bundling extra plugins here would mean every fort-starter user inherits project-specific tooling on first install. Instead, vanilla ships with the two core plugins and leaves this directory as an extension point.

## How to add a plugin

Drop a Claude Code plugin directory in here (must contain a manifest at `.claude-plugin/plugin.json`). `fort-bootstrap --refresh` will copy it into `./plugins/` alongside the core plugins on next assembly. Profile plugins are additive — they install on top of `core/plugins/`, not in place of it.

```
profiles/vanilla/plugins/
└── my-plugin/
    ├── .claude-plugin/
    │   └── plugin.json
    ├── skills/
    └── ...
```

## Reference: `core/plugins/`

For examples of the plugin layout that fort-starter ships, see `core/plugins/fort/` (16 workflow skills) and `core/plugins/fort-tools/` (utility skills with `.claude-plugin/plugin.json`, `skills/`, and a `README.md`). The same structural conventions apply to plugins you add here.
