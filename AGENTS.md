# diff-review.nvim

Guidance for agents working in this repository.

## Scope

- This is a Neovim `0.12+` plugin built around `:DiffTool`.
- Keep the main logic generic to DiffTool sessions.
- Keep SCM-specific logic isolated under `lua/diff-review/providers/`.

## Core Principles

- The plugin captures AI-oriented review notes from side-by-side `:DiffTool` sessions into a scratch packet.
- Review packets are keyed per repo root. If no repo root can be detected, fall back to the current file directory and mark the metadata accordingly.
- Favor extracting metadata from active diff windows and quickfix context before using SCM-specific queries.
- Preserve ambiguity instead of inventing false precision. If the source data is incomplete, record the best identifier available and let the consumer reason from it.
- Use repo-root-relative paths whenever that can be done reliably.
- Treat the right side as the normal changed side, but keep left-side capture working and explicit.

## Architecture Rules

- Do not leak `git`, `jj`, or `hg` command logic into general modules like:
  - `lua/diff-review/init.lua`
  - `lua/diff-review/extract.lua`
  - `lua/diff-review/packet.lua`
  - `lua/diff-review/session.lua`
- SCM queries belong in provider modules only.
- `lua/diff-review/detect.lua` should only detect repo root, VCS, and provider selection.
- Prefer extracting file/session context from actual `:DiffTool` state before falling back to SCM-specific inference.
- `lua/diff-review/packet.lua` should remain presentation-focused. Do not move SCM or session-detection logic into packet formatting.
- Keep the setup surface small unless there is a clear user-facing need to expand it.

## Testing Rules

- Prefer real integration tests over mocks for provider behavior.
- Use temporary repos and real headless `:DiffTool` sessions for `git`, `jj`, and `hg`.
- Keep integration coverage in `tests/`.
- After changing extraction or provider logic, run:

```bash
tests/run_integration.sh
```

## Formatting And Linting

- Keep Lua code formatted with `stylua`.
- Keep Lua code clean under `luacheck`.
- Before finishing substantive changes, run:

```bash
stylua lua plugin tests
luacheck lua plugin tests
```

- If either tool is unavailable in the environment, say so explicitly in the final handoff.
- Do not reformat unrelated files just to satisfy style preferences.

## Editing Rules

- Preserve the provider boundary.
- Prefer small focused modules over adding condition-heavy logic to one file.
- Keep review-packet output AI-oriented and best-effort; do not hide ambiguity when the source data is incomplete.
- Use repo-root-relative paths when possible.
- Keep the plugin targeted to `:DiffTool`, not generic Vim diff mode, unless the design is intentionally expanded.

## Notes

- For `git` and `hg`, uncommitted content does not have a real commit revision; using a real content hash for the worktree side is acceptable.
- For `jj`, prefer real change ID and commit ID when available.
