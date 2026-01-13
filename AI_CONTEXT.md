# AI_CONTEXT.md

## Workflow
- Keep TODO.md synchronized (mark complete, add new tasks)
- Avoid absolute paths in code and configuration files
- Do not add AI attribution to commit messages (no "Generated with Claude Code" or "Co-Authored-By: Claude" footers)
- Keep commit messages concise - use bullet points for changes, avoid verbose explanations
- Never push commits to git without explicit user confirmation
- Remove debug log lines (fprintf, println, etc.) before committing
- Avoid merge commits - use `git rebase` to integrate changes and keep a linear history
- Check for dead code after architectural changes and remove it
- Global/static state is strictly forbidden in JUCE plugin code (use instance members instead). This is because multiple plugin instances share the same process. CMP UI code runs in separate child processes, so globals are acceptable there.
