local base = require("diff-review.providers.base")
local detect = require("diff-review.detect")
local util = require("diff-review.providers.util")

local M = {
  name = "git",
}

function M.resolve_session(ctx)
  local current_in_repo = detect.is_inside_root(ctx.current_path, ctx.detection.repo_root)
  local peer_in_repo = detect.is_inside_root(ctx.peer_path, ctx.detection.repo_root)
  local head = util.run({ "git", "rev-parse", "HEAD" }, ctx.detection.repo_root)
  local current_hash = current_in_repo and util.file_hash(ctx.current_path) or nil
  local peer_hash = peer_in_repo and util.file_hash(ctx.peer_path) or nil

  local function worktree_spec(hash)
    local short = util.shorten_hash(hash)
    return {
      rev = hash or "WORKTREE",
      kind = hash and "blob" or "working-copy",
      display = short and ("WORKTREE " .. short) or "WORKTREE",
    }
  end

  local function head_spec()
    local short = util.shorten_hash(head)
    return {
      rev = head or "HEAD",
      kind = "commit",
      display = short and ("HEAD " .. short) or "HEAD",
    }
  end

  if current_in_repo and not peer_in_repo then
    local current = worktree_spec(current_hash)
    local peer = head_spec()
    return base.make_meta(ctx, {
      confidence = "medium",
      current_rev = current.rev,
      current_rev_kind = current.kind,
      current_display = current.display,
      peer_rev = peer.rev,
      peer_rev_kind = peer.kind,
      peer_display = peer.display,
    })
  end

  if peer_in_repo and not current_in_repo then
    local current = head_spec()
    local peer = worktree_spec(peer_hash)
    return base.make_meta(ctx, {
      confidence = "medium",
      current_rev = current.rev,
      current_rev_kind = current.kind,
      current_display = current.display,
      peer_rev = peer.rev,
      peer_rev_kind = peer.kind,
      peer_display = peer.display,
    })
  end

  if ctx.side == "right" then
    local current = worktree_spec(current_hash)
    local peer = head_spec()
    return base.make_meta(ctx, {
      confidence = "low",
      current_rev = current.rev,
      current_rev_kind = current.kind,
      current_display = current.display,
      peer_rev = peer.rev,
      peer_rev_kind = peer.kind,
      peer_display = peer.display,
    })
  end

  local current = head_spec()
  local peer = worktree_spec(peer_hash)
  return base.make_meta(ctx, {
    confidence = "low",
    current_rev = current.rev,
    current_rev_kind = current.kind,
    current_display = current.display,
    peer_rev = peer.rev,
    peer_rev_kind = peer.kind,
    peer_display = peer.display,
  })
end

return M
