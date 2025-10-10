# maw issue

Create a GitHub issue from the Codex CLI using the shared `maw issue` helper.

```
maw issue --title "Implement /maw-issue command" \
  --body "1. Add CLI helper\n2. Wire up slash command\n3. Document usage" \
  --labels automation,agents --dry-run
```

The command checks `gh auth status` first, targets the current repository by
default, and accepts additional flags:

- `--body-file path/to/plan.md` (or pipe STDIN) for longer bodies
- `--label/--labels` to tag the issue
- `--assignee/--assignees` to hand it to teammates
- `--web` to open the created issue in a browser

Use it after completing the `nnn` planning ritual to publish the plan upstream.
