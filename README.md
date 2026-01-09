# Claude Devloop

A Claude Code plugin for iterative development loops. Feeds the same prompt back to Claude repeatedly, letting it review and improve its work across multiple iterations.

## Installation

```bash
/plugin install Ilm-Alan/claude-devloop
```

## Usage

```bash
/devloop:start Build a REST API for todos -m 10
/devloop:start Fix all bugs -p 'All tests passing'
```

### Options

- `-m, --max-iterations <n>` - Maximum iterations (default: unlimited, use -m N to limit)
- `-p, --promise-complete '<text>'` - Allow early exit when statement is true

### Commands

- `/devloop:start <prompt>` - Start a devloop
- `/devloop:stop` - Stop the active loop

## How It Works

1. You provide a task prompt
2. Claude works on the task
3. When Claude tries to exit, the stop hook intercepts and feeds the **same prompt** back
4. Claude sees its previous work in files and git history
5. Loop continues until max iterations or completion promise is fulfilled

Each iteration, Claude is instructed to:
- READ relevant files to see current state
- IDENTIFY at least one specific improvement
- MAKE code changes using Edit/Write tools
- VERIFY changes work (build/test if applicable)

## Completion Promise

You can set a completion promise that allows Claude to exit early when the condition is genuinely true:

```bash
/devloop:start Implement user auth -p 'Login and registration working with tests'
```

Claude exits by outputting: `<promise>Login and registration working with tests</promise>`

**Important**: Claude must not lie to escape - the promise must be genuinely true.

## Multiple Sessions

Each loop creates a unique state file (`.claude/devloop-{session_id}.local.md`), so multiple Claude sessions can run devloops in the same directory without conflicts.

## Files

```
claude-devloop/
├── .claude-plugin/
│   └── plugin.json       # Plugin manifest
├── commands/
│   ├── start.md          # /devloop:start command
│   └── stop.md           # /devloop:stop command
├── hooks/
│   ├── hooks.json        # Stop hook config
│   ├── stop-hook.sh      # Intercepts exit, feeds prompt back
│   └── claim-hook.sh     # Claims state files for sessions
└── scripts/
    ├── setup-loop.sh     # Creates state file, shows banner
    └── stop-loop.sh      # Stops the loop
```

## State File

The loop state is stored in `.claude/devloop-{session_id}.local.md`:

```yaml
---
active: true
iteration: 1
max_iterations: 5
completion_promise: "Your promise text"
transcript_path: "/path/to/transcript"
started_at: "2024-01-01T00:00:00Z"
---

Your prompt here
```

## License

MIT
