---
name: workbench
description: |
  Structured prototyping with liftable code. Use when the user says "workbench", "build a prototype",
  "scaffold this", or needs a structured playground that mirrors a real project's architecture.
  Different from /playground (single-file HTML explorers) — workbench code is meant to graduate
  to production. Outputs to scratch/playground/<name>/.
user_invocable: true
argument-hint: "[idea or topic]"
arguments:
  - name: topic
    description: "What to build — a feature, component, widget, or tool prototype"
    required: false
---

# Workbench

Fast, low-commitment prototyping space. Build something visible quickly, validate the idea, then decide if it graduates to a real project.

**Key convention:** Same file structure, same imports, same tokens as the target project. Playground code should be liftable to production with minimal rework.

## Step 1: Shape Selection

Before building, determine the playground shape. If the user specifies a shape or the context makes it obvious, use it. Otherwise default to **Explorer**.

| Shape | Structure | When to use |
|---|---|---|
| **Explorer** (default) | Single HTML file, inline everything | Pure visual recon, "does this idea work?" |
| **Next.js** | App Router, Tailwind, components in `/components` | Building pages, layouts, interactive features |
| **Dashboard widget** | React component matching your dashboard's widget patterns + your data-fetching layer | New dashboard cards |
| **Standalone tool** | Vite + React, same structure as `projects/` | New self-contained tools |

**When to ask:** If the topic clearly maps to a shape (e.g., "new dashboard card" = Dashboard widget, "CSS experiment" = Explorer), just use it. Only ask when ambiguous between non-Explorer shapes:

> "This could be an Explorer or a Next.js playground — which shape?"

**When NOT to ask:** If unspecified and nothing suggests a structured shape, default to Explorer silently.

---

## Step 2: Build

### Explorer Shape

Output: `scratch/playground/<name>.html` (single file)

- Inline all CSS and JS — no build step, no dependencies
- Open in a browser and it works
- Use CDN links for libraries if needed (e.g., GSAP, Three.js, D3)
- Keep it scrappy — this is recon, not production

### Next.js Shape

Output: `scratch/playground/<name>/`

```
scratch/playground/<name>/
  app/
    page.tsx
    layout.tsx
  components/
    <ComponentName>.tsx
  package.json          # Next.js + Tailwind deps
  tailwind.config.ts
  tsconfig.json
```

- Mirror the target project's Tailwind config and design tokens
- Use the same component patterns (naming, prop conventions, file structure)
- Include a minimal `package.json` — `pnpm install && pnpm dev` should work

### Dashboard Widget Shape

Output: `scratch/playground/<name>/`

```
scratch/playground/<name>/
  components/
    <WidgetName>.tsx          # The widget component
    <WidgetName>.stories.tsx  # Optional: visual test
  hooks/
    use<DataSource>.ts        # Data-fetching hook with mock data
  index.tsx                   # Preview harness
  package.json
```

- Match your target dashboard's patterns: card wrapper, your data-fetching layer (TanStack Query, SWR, or whatever you use), styling system
- Include mock data that mirrors the real API shape
- Widget should drop into the dashboard grid with no changes

### Standalone Tool Shape

Output: `scratch/playground/<name>/`

```
scratch/playground/<name>/
  src/
    App.tsx
    main.tsx
    components/
  index.html
  package.json          # Vite + React deps
  vite.config.ts
  tsconfig.json
```

- Same structure as `projects/` directory conventions
- Vite + React + Tailwind baseline
- `pnpm install && pnpm dev` should work

---

## Step 3: Present

After building, show what was created and how to use it.

**Explorer:**
> Playground ready: `scratch/playground/<name>.html`
> Open in browser to preview.

**Structured shapes:**
> Playground ready: `scratch/playground/<name>/`
> ```
> cd scratch/playground/<name> && pnpm install && pnpm dev
> ```

---

## Step 4: Iterate

Stay in the playground until the user is satisfied. Fast iteration — don't over-polish.

When the idea is validated:
- **Explorer**: Offer to graduate it into the appropriate project structure
- **Structured shapes**: Note which files can be copied directly into the target project

---

## Graduation

When playground code is ready to move to production:
1. Identify the target project directory
2. Copy files, adjusting imports and paths as needed
3. Remove the playground directory (or leave it — scratch is meant to be messy)

Don't proactively suggest graduation. Wait for the user to say "ship it" or "move this to the project."
