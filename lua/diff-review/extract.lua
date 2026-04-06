local detect = require("diff-review.detect")
local providers = require("diff-review.providers")
local session = require("diff-review.session")

local M = {}

local function safe_buf_name(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return nil
  end
  return vim.fn.fnamemodify(name, ":p")
end

local function qf_user_data(entry)
  if not entry or type(entry) ~= "table" then
    return nil
  end
  if type(entry.user_data) ~= "table" or not entry.user_data.diff then
    return nil
  end
  return entry.user_data
end

local function clean_line(line)
  if not line then
    return ""
  end
  return line:gsub("%s+$", "")
end

local function is_filler(line)
  return line ~= nil and line:match("^%s*~+$") ~= nil
end

local function context_lines(bufnr, center, radius)
  local start_line = math.max(1, center - radius)
  local end_line = math.min(vim.api.nvim_buf_line_count(bufnr), center + radius)
  local raw = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local lines = {}

  for idx, line in ipairs(raw) do
    if not is_filler(line) then
      table.insert(lines, string.format("%d: %s", start_line + idx - 1, clean_line(line)))
    end
  end

  return lines
end

local function format_context(title, lines)
  local out = { title, "```text" }
  if #lines == 0 then
    table.insert(out, "(no local context available)")
  else
    vim.list_extend(out, lines)
  end
  table.insert(out, "```")
  return out
end

local function context_title(side)
  if side == "left" then
    return "Current side context (left/original)"
  end
  return "Current side context (right/changed)"
end

function M.current()
  local current, err = session.current()
  if not current then
    return nil, err
  end

  local qf_data = qf_user_data(current.qf_entry)
  local path = safe_buf_name(current.bufnr)
  local peer_path = safe_buf_name(current.peer_bufnr)
  if qf_data then
    if current.side == "right" then
      path = qf_data.right or path
      peer_path = qf_data.left or peer_path
    else
      path = qf_data.left or path
      peer_path = qf_data.right or peer_path
    end
  end

  local detection = detect.detect(path, peer_path, vim.fn.getcwd())
  local cursor = vim.api.nvim_win_get_cursor(current.winid)
  local selected =
    clean_line(vim.api.nvim_buf_get_lines(current.bufnr, cursor[1] - 1, cursor[1], false)[1] or "")
  local peer_cursor = vim.api.nvim_win_get_cursor(current.peer_win)
  local right_rel = qf_data and qf_data.rel
    or detect.relative_path(current.side == "right" and path or peer_path, detection.repo_root)
  local left_rel = qf_data and qf_data.rel
    or detect.relative_path(current.side == "left" and path or peer_path, detection.repo_root)
  local provider = providers.for_detection(detection)
  local meta = provider.resolve_session({
    detection = detection,
    side = current.side,
    current_path = path,
    peer_path = peer_path,
    left_path = current.side == "left" and path or peer_path,
    right_path = current.side == "right" and path or peer_path,
    left_rel = left_rel,
    right_rel = right_rel,
    qf_entry = current.qf_entry,
    qf_data = qf_data,
  })

  local entry = {
    vcs = meta.vcs,
    repo_root = meta.repo_root,
    packet_key = meta.packet_key,
    path = meta.current.relpath or meta.current.path,
    rev = meta.current.display or meta.current.rev,
    side = current.side,
    peer_path = meta.peer.relpath or meta.peer.path,
    peer_rev = meta.peer.display or meta.peer.rev,
    confidence = meta.confidence,
    selected_line = selected ~= "" and selected or "(blank line)",
    line_number = cursor[1],
    qf_text = current.qf_entry and current.qf_entry.text or nil,
    qf_lnum = current.qf_entry and current.qf_entry.lnum or nil,
  }

  local context = {}
  vim.list_extend(
    context,
    format_context(context_title(current.side), context_lines(current.bufnr, cursor[1], 3))
  )
  vim.list_extend(context, { "" })
  vim.list_extend(
    context,
    format_context("Peer side context", context_lines(current.peer_bufnr, peer_cursor[1], 3))
  )
  entry.context = context

  return entry
end

return M
