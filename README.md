# diff-review.nvim

Capture AI-oriented code review notes from Neovim `:DiffTool` sessions into a per-repo scratch buffer.

This plugin is for Neovim `0.12+` only. It is designed around `:DiffTool` side-by-side diffs, not generic diff mode.

## Features

- Capture review notes directly from active `:DiffTool` windows
- Keep one markdown review packet per repo root
- Support `git`, `jj`, and `hg`
- Extract real SCM-derived identifiers where possible
- Recover the active hunk and include a diff snippet in the review packet
- Use quickfix metadata for directory diffs
- Allow right-side and left-side capture, with explicit left-side labeling
- Bundle an AI-oriented default review preamble, overridable via `setup()`

## Requirements

- Neovim `0.12+`
- `nvim.difftool`
- `git`, `jj`, or `hg` in `PATH` for provider-backed revision metadata

## Commands

- `:DiffReviewComment` prompts for a comment and appends a review item from the current diff cursor location
- `:DiffReviewOpen` opens the current repo's review packet

## Setup

```lua
require("diff-review").setup({
  prompt_lines = nil, -- nil = bundled prompt, false = no prompt, { ... } = custom prompt
  keymaps = true,     -- install cR and gR in diff windows
})
```

Default mappings in active diff windows:

- `cR` capture a review comment
- `gR` open the review packet

## How It Works

The plugin reads the active `:DiffTool` session, figures out the current side,
captures the selected line plus nearby context, and appends that to a
per-repository scratch buffer.

Metadata comes from three layers:

1. `:DiffTool` window state
2. quickfix metadata for directory diffs
3. SCM providers under `lua/diff-review/providers/`

The providers are responsible for repo-specific revision logic:

- `git`: uses real `HEAD` commit IDs, base blob IDs, and worktree content hashes
- `jj`: uses real `@` / `@-` change and commit IDs
- `hg`: uses real committed revision identifiers, tracked file hashes, and worktree content hashes

When the SCM provider can recover a unified diff for the current file, the
plugin also extracts the matching hunk header and includes a diff snippet in
the review packet.

## Review Packet

Each packet is a markdown scratch buffer keyed by repo root. When no repo root can be detected, the current file directory is used as the packet key and the header is marked with `vcs: unknown`.

Entries are best effort and can include:

- `path`
- `rev`
- `side`
- `peer_path`
- `peer_rev`
- `hunk`
- `hunk_lines`
- `context`
- `selected_line`
- `comment`

The default header is opinionated toward AI review and can be overridden with `prompt_lines`.

## Behavior Notes

- Right-side capture is the normal changed-side workflow.
- Left-side capture is supported and explicitly tagged as left/original-side context.
- Directory diffs are best when `:DiffTool` quickfix entries carry `user_data.rel`, `user_data.left`, and `user_data.right`, which Neovim `0.12` does.
- For `git` and `hg`, uncommitted worktree content does not have a commit revision; the plugin uses a real content hash for that side instead.
- Hunk capture is provider-backed. It is strongest when the DiffTool pair matches the SCM provider's view of the file comparison.

## Tests

Run the integration suite with:

```bash
tests/run_integration.sh
```

The suite creates temporary `git`, `jj`, and `hg` repositories, opens real headless `:DiffTool` sessions, and asserts on extracted metadata plus review-packet output.

It also covers:

- file-mode and directory-mode integration
- left-side and right-side capture paths
- one public command/mapping path through `:DiffReviewComment`, `:DiffReviewOpen`, `cR`, and `gR`

## Help

Vim help is available in `doc/diff-review.txt`.
