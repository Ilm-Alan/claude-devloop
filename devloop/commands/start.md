---
description: "Start a devloop for iterative development"
argument-hint: "PROMPT [-m N] [-c 'TEXT']"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh)"]
hide-from-slash-command-tool: "true"
---

# Devloop

```!
DEVLOOP_ARGS="${ARGUMENTS}" "${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh"
```

Work on the task above. This is an iterative development loop that will repeat until max iterations or completion.

## HOW THIS LOOP WORKS

After each response, the Stop hook will:
1. Check if you output `<promise>TEXT</promise>` matching the completion promise
2. If matched, allow exit (task complete!)
3. Otherwise, block exit and feed the same prompt back
4. Increment the iteration counter

## COMPLETION PROMISE (EARLY EXIT)

If `-c` / `--completion-promise` was set, you can exit early by outputting:
```
<promise>EXACT PROMISE TEXT HERE</promise>
```

**CRITICAL RULES FOR PROMISES:**
- The promise statement MUST be genuinely TRUE
- Do NOT output a false promise to escape the loop
- Do NOT lie even if you think you're stuck or should exit
- The loop is designed to continue until the promise is ACTUALLY true
- If genuinely complete, output the promise tag with confidence

## MANDATORY WORKFLOW (EVERY ITERATION)

1. **READ FILES** - Always start by reading the relevant source files to see current state
2. **ANALYZE** - Identify specific issues, missing features, or improvements needed
3. **CHANGE CODE** - Use Edit or Write tools to make at least one meaningful change
4. **VERIFY** - Run builds/tests if applicable to confirm changes work
5. **EXPLAIN** - Describe what you changed and what's left to do

## RULES

- Short responses (summaries, status updates, "complete") are NOT valid work
- Each iteration must include actual file modifications via Edit/Write tools
- If you genuinely can't find improvements, add tests, documentation, or refactor
- Use git diff or file reads to understand previous iteration's changes
- Only output `<promise>` tag when the completion criteria is genuinely met

## ANTI-PATTERNS TO AVOID

- Saying "The implementation is complete" without making changes
- Outputting only summaries of what was already done
- Trying to escape with minimal responses like "Done.", "Complete"
- Outputting a FALSE promise statement to escape
- Skipping file reads and assuming you know the current state

## EXAMPLES

Start a loop that runs for 5 iterations max:
```
/devloop:start Refactor the auth module -m 5
```

Start a loop with early exit condition:
```
/devloop:start Fix all type errors -c 'Zero TypeScript errors in build'
```

Full example with both options:
```
/devloop:start Build user registration --max-iterations 10 --completion-promise 'Registration flow complete with tests'
```
