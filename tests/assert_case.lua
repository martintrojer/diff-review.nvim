local function env(name)
  local value = vim.fn.getenv(name)
  if value == vim.NIL then
    return nil
  end
  if value == "" then
    return nil
  end
  return value
end

local function split(value, sep)
  if not value or value == "" then
    return {}
  end

  local out = {}
  for item in string.gmatch(value, "([^" .. sep .. "]+)") do
    table.insert(out, item)
  end
  return out
end

local function assert_eq(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s mismatch\nexpected: %s\nactual: %s", label, expected, tostring(actual)))
  end
end

local function assert_contains(lines, needle, label)
  for _, line in ipairs(lines) do
    if line == needle then
      return
    end
  end
  error(string.format("missing %s\nneedle: %s", label, needle))
end

local function wait_for_difftool(mode)
  if mode ~= "dir" then
    return
  end

  local ok = vim.wait(2000, function()
    local qf = vim.fn.getqflist({ size = 1 })
    if (qf.size or 0) == 0 then
      return false
    end
    local entry = require("diff-review.session").current()
    return entry ~= nil
  end, 20)
  if not ok then
    error("timed out waiting for DiffTool directory layout")
  end
end

local function wait_for_mapping(lhs)
  local ok = vim.wait(2000, function()
    local map = vim.fn.maparg(lhs, "n", false, true)
    return not vim.tbl_isempty(map)
  end, 20)
  if not ok then
    error("timed out waiting for mapping " .. lhs)
  end
end

local left = assert(env("DIFF_LEFT"), "missing DIFF_LEFT")
local right = assert(env("DIFF_RIGHT"), "missing DIFF_RIGHT")
local mode = env("DIFF_MODE") or "file"
local side = env("DIFF_SIDE") or "right"
local expect_vcs = assert(env("EXPECT_VCS"), "missing EXPECT_VCS")
local expect_path = assert(env("EXPECT_PATH"), "missing EXPECT_PATH")
local expect_peer_path = assert(env("EXPECT_PEER_PATH"), "missing EXPECT_PEER_PATH")
local expect_rev = assert(env("EXPECT_REV"), "missing EXPECT_REV")
local expect_peer_rev = assert(env("EXPECT_PEER_REV"), "missing EXPECT_PEER_REV")
local expect_qf_text = env("EXPECT_QF_TEXT")
local expect_hunk = env("EXPECT_HUNK")
local use_public = env("USE_PUBLIC") == "1"
local comment = env("EXPECT_COMMENT") or "integration test comment"

local opts
if mode == "dir" then
  opts = { ignore = split(env("DIFF_IGNORE"), ":") }
end

require("difftool").open(left, right, opts)
wait_for_difftool(mode)
if side == "left" then
  vim.cmd("wincmd h")
end

local entry, err = require("diff-review.extract").current()
if not entry then
  error(err)
end

assert_eq(entry.vcs, expect_vcs, "vcs")
assert_eq(entry.path, expect_path, "path")
assert_eq(entry.peer_path, expect_peer_path, "peer_path")
assert_eq(entry.rev, expect_rev, "rev")
assert_eq(entry.peer_rev, expect_peer_rev, "peer_rev")
assert_eq(entry.side, side, "side")
if expect_qf_text then
  assert_eq(entry.qf_text, expect_qf_text, "qf_text")
end
if expect_hunk then
  assert_eq(entry.hunk, expect_hunk, "hunk")
end

local packet = require("diff-review.packet")
local number
local bufnr

if use_public then
  assert_eq(vim.fn.exists(":DiffReviewComment"), 2, "DiffReviewComment command")
  assert_eq(vim.fn.exists(":DiffReviewOpen"), 2, "DiffReviewOpen command")

  vim.cmd("doautocmd BufWinEnter")
  vim.cmd("doautocmd WinEnter")
  wait_for_mapping("cR")
  wait_for_mapping("gR")

  local comment_map = vim.fn.maparg("cR", "n", false, true)
  local open_map = vim.fn.maparg("gR", "n", false, true)
  if vim.tbl_isempty(comment_map) then
    error("missing cR buffer-local mapping")
  end
  if vim.tbl_isempty(open_map) then
    error("missing gR buffer-local mapping")
  end

  vim.ui.input = function(_, cb)
    cb(comment)
  end
  vim.cmd("DiffReviewComment")
  vim.cmd("DiffReviewOpen")

  number = 1
  bufnr = vim.api.nvim_get_current_buf()
else
  number, bufnr = packet.append(entry, comment, require("diff-review").config)
end
assert_eq(number, 1, "review item number")

local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
assert_contains(lines, "- VCS: " .. expect_vcs, "packet vcs")
assert_contains(lines, "- Path: " .. expect_path, "packet path")
assert_contains(lines, "- Revision: " .. expect_rev, "packet rev")
assert_contains(lines, "- Peer path: " .. expect_peer_path, "packet peer path")
assert_contains(lines, "- Peer revision: " .. expect_peer_rev, "packet peer rev")
assert_contains(lines, "- Side: " .. side, "packet side")
if expect_hunk then
  assert_contains(lines, "- Hunk: " .. expect_hunk, "packet hunk")
end
assert_contains(lines, "  " .. comment, "packet comment")

print(string.format("ok %s %s", expect_vcs, mode .. ":" .. side))
