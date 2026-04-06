local base = require("diff-review.providers.base")
local detect = require("diff-review.detect")
local util = require("diff-review.providers.util")

local M = {
  name = "hg",
}

local function rev_spec(repo_root, revset)
  local out = util.run({
    "hg",
    "log",
    "-r",
    revset,
    "--template",
    "{rev} {node|short}\n",
  }, repo_root)
  if not out then
    return {
      rev = revset,
      kind = "unknown",
      display = revset,
    }
  end

  local revnum, node = out:match("^(%S+)%s+(%S+)$")
  if not revnum or not node then
    return {
      rev = revset,
      kind = "unknown",
      display = revset,
    }
  end

  return {
    rev = node,
    kind = "commit",
    display = string.format("%s %s", revnum, node),
  }
end

local function worktree_spec(path)
  local hash = util.file_hash(path)
  local short = util.shorten_hash(hash)
  return {
    rev = hash or "WORKTREE",
    kind = hash and "blob" or "working-copy",
    display = short and ("WORKTREE " .. short) or "WORKTREE",
  }
end

function M.resolve_session(ctx)
  local current_in_repo = detect.is_inside_root(ctx.current_path, ctx.detection.repo_root)
  local peer_in_repo = detect.is_inside_root(ctx.peer_path, ctx.detection.repo_root)
  local dot = rev_spec(ctx.detection.repo_root, ".")

  if current_in_repo and not peer_in_repo then
    local current = worktree_spec(ctx.current_path)
    return base.make_meta(ctx, {
      confidence = "medium",
      current_rev = current.rev,
      current_rev_kind = current.kind,
      current_display = current.display,
      peer_rev = dot.rev,
      peer_rev_kind = dot.kind,
      peer_display = dot.display,
    })
  end

  if peer_in_repo and not current_in_repo then
    local peer = worktree_spec(ctx.peer_path)
    return base.make_meta(ctx, {
      confidence = "medium",
      current_rev = dot.rev,
      current_rev_kind = dot.kind,
      current_display = dot.display,
      peer_rev = peer.rev,
      peer_rev_kind = peer.kind,
      peer_display = peer.display,
    })
  end

  if ctx.side == "right" then
    local current = worktree_spec(ctx.current_path)
    return base.make_meta(ctx, {
      confidence = "low",
      current_rev = current.rev,
      current_rev_kind = current.kind,
      current_display = current.display,
      peer_rev = dot.rev,
      peer_rev_kind = dot.kind,
      peer_display = dot.display,
    })
  end

  local peer = worktree_spec(ctx.peer_path)
  return base.make_meta(ctx, {
    confidence = "low",
    current_rev = dot.rev,
    current_rev_kind = dot.kind,
    current_display = dot.display,
    peer_rev = peer.rev,
    peer_rev_kind = peer.kind,
    peer_display = peer.display,
  })
end

return M
