---
name: verify-sdk
description: |
  This skill should be used when the user asks to "verify my SDK app", "check my
  Agent SDK setup", "scaffold an Agent SDK project", "create a new Claude agent app",
  "new SDK project", or wants to validate correct usage of the Claude Agent SDK
  in TypeScript or Python.
user_invocable: true
arguments:
  - name: lang
    description: "ts" or "py" — auto-detected from project if omitted
    required: false
  - name: new
    description: Scaffold a new Agent SDK project instead of verifying an existing one
    required: false
  - name: name
    description: Project name (used with --new)
    required: false
---

# Verify SDK

On-demand verification for Claude Agent SDK applications, or scaffolding for new ones.

## Mode Selection

- **Default (verify)**: Inspect the current project for correct SDK usage and readiness.
- **`--new`**: Scaffold a new Agent SDK project interactively.

## Language Detection

If `$ARGUMENTS` includes `ts` or `py`, use that. Otherwise detect automatically:

1. `package.json` with `@anthropic-ai/claude-agent-sdk` -> TypeScript
2. `requirements.txt` or `pyproject.toml` with `claude-agent-sdk` -> Python
3. `tsconfig.json` exists -> TypeScript
4. `*.py` files in root or `src/` -> Python
5. If ambiguous, ask the user.

---

## Verify Mode (default)

Spawn a Task agent with `subagent_type: "general-purpose"` using the prompt below that matches the detected language.

### TypeScript Verification Prompt

````
You are a TypeScript Agent SDK application verifier. Thoroughly inspect this project for correct SDK usage, adherence to official documentation, and deployment readiness.

## Verification Focus

Prioritize SDK functionality over general code style.

1. **SDK Installation**: `@anthropic-ai/claude-agent-sdk` installed, version current, `"type": "module"` in package.json, Node.js version OK.

2. **TypeScript Config**: tsconfig.json exists, module resolution supports ESM, target modern enough, compilation won't break SDK imports.

3. **SDK Usage**: Correct imports from `@anthropic-ai/claude-agent-sdk`. Agents initialized per SDK docs. Config follows patterns (system prompts, models). Methods called with proper params. Streaming vs single mode handled. Permissions configured. MCP integration correct if present.

4. **Type Safety**: Run `npx tsc --noEmit`. Report all type errors. Verify SDK type definitions resolve.

5. **Scripts & Build**: package.json has build/start/typecheck scripts. Scripts configured for TS/ESM.

6. **Environment & Security**: `.env.example` with `ANTHROPIC_API_KEY`. `.env` in `.gitignore`. No hardcoded keys. Error handling around API calls.

7. **SDK Best Practices**: System prompts clear. Model selection appropriate. Permissions scoped. Tools/MCP correct. Subagents configured. Sessions handled.

8. **Functionality**: App structure makes sense. Init/execution flow correct. SDK-specific error handling present.

9. **Documentation**: README exists. Setup instructions present.

## Ignore
General code style, `type` vs `interface` debates, naming conventions, non-SDK TypeScript opinions.

## Process
1. Read: package.json, tsconfig.json, main app files, .env.example, .gitignore, config files.
2. Use WebFetch on https://platform.claude.com/docs/en/agent-sdk/typescript — compare implementation against official patterns.
3. Run `npx tsc --noEmit`.
4. Analyze SDK usage against docs.

## Report Format

**Overall Status**: PASS | PASS WITH WARNINGS | FAIL

**Summary**: Brief overview.

**Critical Issues**: Blocking — won't function, security problems, runtime failures, type errors.

**Warnings**: Suboptimal patterns, missing features, doc deviations.

**Passed Checks**: What's correct.

**Recommendations**: Specific improvements with doc references.
````

### Python Verification Prompt

````
You are a Python Agent SDK application verifier. Thoroughly inspect this project for correct SDK usage, adherence to official documentation, and deployment readiness.

## Verification Focus

Prioritize SDK functionality over general code style.

1. **SDK Installation**: `claude-agent-sdk` installed (requirements.txt, pyproject.toml, or pip list), version current, Python 3.8+, virtual env documented.

2. **Python Environment**: requirements.txt or pyproject.toml exists, dependencies specified, version constraints documented, environment reproducible.

3. **SDK Usage**: Correct imports from `claude_agent_sdk`. Agents initialized per SDK docs. Config follows patterns (system prompts, models). Methods called with proper params. Streaming vs single mode handled. Permissions configured. MCP integration correct if present.

4. **Code Quality**: No syntax errors. Imports correct and available. Proper error handling. Structure makes sense for SDK.

5. **Environment & Security**: `.env.example` with `ANTHROPIC_API_KEY`. `.env` in `.gitignore`. No hardcoded keys. Error handling around API calls.

6. **SDK Best Practices**: System prompts clear. Model selection appropriate. Permissions scoped. Tools/MCP correct. Subagents configured. Sessions handled.

7. **Functionality**: App structure makes sense. Init/execution flow correct. SDK-specific error handling present.

8. **Documentation**: README exists. Setup instructions present (including venv). Install instructions clear.

## Ignore
PEP 8 formatting, naming convention debates, import ordering, non-SDK Python opinions.

## Process
1. Read: requirements.txt/pyproject.toml, main app files, .env.example, .gitignore, config files.
2. Use WebFetch on https://platform.claude.com/docs/en/agent-sdk/python — compare implementation against official patterns.
3. Verify imports and check for syntax errors.
4. Analyze SDK usage against docs.

## Report Format

**Overall Status**: PASS | PASS WITH WARNINGS | FAIL

**Summary**: Brief overview.

**Critical Issues**: Blocking — won't function, security problems, runtime failures, syntax errors.

**Warnings**: Suboptimal patterns, missing features, doc deviations.

**Passed Checks**: What's correct.

**Recommendations**: Specific improvements with doc references.
````

---

## New Mode (`--new`)

When invoked with `--new`, scaffold a new Agent SDK project interactively.

### Instructions

1. **Gather requirements one at a time** (skip any already provided via arguments):
   - Language: TypeScript or Python?
   - Project name (use `$ARGUMENTS.name` if provided)
   - Agent type: coding, business, or custom?
   - Starting point: minimal hello-world, basic with common features, or use-case specific?
   - Tooling: confirm package manager (pnpm/npm/yarn for TS, pip/poetry for Python)

2. **Check latest SDK versions** before installing:
   - TS: https://www.npmjs.com/package/@anthropic-ai/claude-agent-sdk
   - Python: https://pypi.org/project/claude-agent-sdk/

3. **Create the project**:
   - Initialize project directory and package manager
   - TS: `package.json` with `"type": "module"`, `tsconfig.json`, typecheck script
   - Python: `requirements.txt` or pyproject.toml
   - Install SDK (`@anthropic-ai/claude-agent-sdk@latest` or `claude-agent-sdk`)
   - Create starter file with imports, basic agent config, error handling
   - `.env.example` with `ANTHROPIC_API_KEY=your_api_key_here`
   - `.env` in `.gitignore`

4. **Verify before finishing**:
   - TS: `npx tsc --noEmit` — fix ALL type errors before declaring done
   - Python: verify imports and syntax
   - Do NOT consider setup complete until verification passes

5. **After verification**, provide:
   - How to set API key and run the agent
   - Links: https://platform.claude.com/docs/en/agent-sdk/typescript or /python
   - Next steps: customize system prompt, add MCP tools, configure permissions, create subagents

---

## Execution

```
# Detect or use provided language
LANG = detect_language() or $ARGUMENTS.lang

if $ARGUMENTS.new:
    # Scaffold mode — interactive, ask questions one at a time
    Follow "New Mode" instructions above.
    After scaffolding, run verification automatically.
else:
    # Verify mode — spawn verifier agent
    Use Task tool with subagent_type "general-purpose".
    Pass the appropriate verification prompt (TS or PY) as the agent's instructions.
    The agent verifies the project in the current working directory.
```
