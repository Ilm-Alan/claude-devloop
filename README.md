# Claude Devloop

An iterative development loop plugin for Claude Code. Evolved from ralph-looph with significant improvements for reliability, multi-session support, and anti-cheat enforcement.

## Why Devloop?

Ralph-loop pioneered the concept of self-referential Claude loops, but had limitations. Devloop improves on it with:

- **Multi-session support** - Unique state files per session instead of global state
- **Session isolation** - Transcript path matching prevents cross-session interference
- **Race condition prevention** - Claim hook on prompt submit
- **Comprehensive workflow** - Enforces READ/ANALYZE/CHANGE/VERIFY each iteration
- **Stronger anti-cheat** - Detailed anti-patterns and warnings, no escape hatch exposed
- **Better argument syntax** - Short flags (`-m`, `-c`) alongside long forms
- **Robust YAML escaping** - Handles quotes, backslashes, and multiline content

## Installation

```bash
/plugin install devloop@ilm-alan
```

## Usage

```bash
# Basic loop with iteration limit
/devloop:start Build a REST API for todos -m 10

# Loop with completion promise (exits when genuinely true)
/devloop:start Fix all type errors -c 'Zero TypeScript errors in build'

# Both options
/devloop:start Implement auth -m 20 -c 'Login and logout working with tests'
```

### Options

| Flag | Long form | Description |
|------|-----------|-------------|
| `-m N` | `--max-iterations N` | Stop after N iterations (default: unlimited) |
| `-c 'text'` | `--completion-promise 'text'` | Exit early when statement is true |

### Commands

- `/devloop:start <prompt> [options]` - Start a devloop
- `/devloop:stop` - Stop the active loop (user-only, not exposed to Claude)

## How It Works

1. You provide a task prompt with optional iteration limit or completion promise
2. Claude works on the task following the mandatory workflow
3. When Claude tries to exit, the stop hook intercepts
4. The **same prompt** feeds back with iteration context
5. Claude sees previous work in files/git and continues improving
6. Loop ends when: max iterations reached OR completion promise fulfilled

### Mandatory Workflow

Each iteration, Claude must:

1. **READ** - Read relevant files to see current state
2. **ANALYZE** - Identify specific issues or improvements needed
3. **CHANGE** - Make actual code changes via Edit/Write tools
4. **VERIFY** - Run builds/tests to confirm changes work

Short responses, summaries, or "complete" without changes are explicitly prohibited.

## Completion Promise

Set a completion promise for goal-oriented loops:

```bash
/devloop:start Implement user registration -c 'Registration flow complete with validation'
```

Claude exits by outputting: `<promise>Registration flow complete with validation</promise>`

### Anti-Cheat Enforcement

Claude is explicitly instructed:
- The promise must be **genuinely true** - no lying to escape
- Even if stuck or frustrated, false promises are prohibited
- The loop continues until the promise becomes naturally true

The stop hook reminds Claude each iteration:
```
Devloop iteration 3 | To exit: output <promise>TEXT</promise> (ONLY when statement is TRUE - do not lie to exit!)
```

## Multi-Session Support

Unlike ralph-loop's global state file, devloop creates unique state files per session:

```
.claude/devloop-1704067200-12345-9876.local.md
.claude/devloop-1704067300-12346-5432.local.md
```

Each session is isolated via transcript path matching, so multiple Claude instances can run devloops in the same directory without conflicts.

### How Session Isolation Works

1. **Setup**: Creates state file with unique session ID
2. **Claim hook**: On prompt submit, claims unclaimed state files by writing transcript path
3. **Stop hook**: Only processes state files matching current session's transcript path

This prevents the race conditions and cross-session interference that plague global state approaches.

## Files

```
claude-devloop/
├── .claude-plugin/
│   └── plugin.json       # Plugin manifest
├── commands/
│   ├── start.md          # /devloop:start - comprehensive workflow instructions
│   └── stop.md           # /devloop:stop - user-initiated stop
├── hooks/
│   ├── hooks.json        # Hook configuration (claim + stop)
│   ├── claim-hook.sh     # Claims state files on UserPromptSubmit
│   └── stop-hook.sh      # Intercepts exit, feeds prompt back
└── scripts/
    ├── setup-loop.sh     # Argument parsing, state file creation
    └── stop-loop.sh      # Removes state file for current session
```

## State File Format

```yaml
---
active: true
iteration: 3
max_iterations: 10
completion_promise: "All tests passing"
transcript_path: "/path/to/session/transcript.jsonl"
term_session_id: "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
started_at: "2024-01-01T12:00:00Z"
---

Your task prompt here
```
