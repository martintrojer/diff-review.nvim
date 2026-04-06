local M = {}

local PACKETS = {}

local DEFAULT_PROMPT = {
  "# AI Review Packet",
  "",
  "You are reviewing a DiffTool comparison.",
  "Treat each review item as a separate code review concern.",
  "Prioritize correctness bugs, regressions, missing edge cases, risky behavior changes, and unclear intent.",
  "Be concrete and skeptical. Do not assume the code is correct.",
  "Respond item-by-item and reference the review item number in your answer.",
  "",
}

local function prompt_lines(config)
  if config.prompt_lines == false then
    return {}
  end
  if type(config.prompt_lines) == "table" then
    return vim.deepcopy(config.prompt_lines)
  end
  return vim.deepcopy(DEFAULT_PROMPT)
end

local function next_number(bufnr)
  local count = 0
  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    if line:match("^### Review Item %d+$") then
      count = count + 1
    end
  end
  return count + 1
end

local function make_name(entry)
  local leaf = vim.fn.fnamemodify(entry.packet_key, ":t")
  if leaf == "" then
    leaf = "review"
  end
  return "diff-review://" .. leaf
end

local function header_lines(entry, config)
  local lines = prompt_lines(config)
  vim.list_extend(lines, {
    "## Repository Context",
    "- VCS: " .. (entry.vcs or "unknown"),
    "- Repository root: " .. (entry.repo_root or "unknown"),
    "- Source: DiffTool",
    "- Metadata: best effort",
    "",
    "## Review Items",
    "",
  })
  return lines
end

local function ensure_packet(entry, config)
  local existing = PACKETS[entry.packet_key]
  if existing and vim.api.nvim_buf_is_valid(existing) then
    return existing
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, make_name(entry))
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "hide"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].filetype = "markdown"
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, header_lines(entry, config))
  vim.bo[bufnr].modified = false

  PACKETS[entry.packet_key] = bufnr
  return bufnr
end

function M.open(entry, config)
  local bufnr = ensure_packet(entry, config)
  vim.cmd("sbuffer " .. bufnr)
  return bufnr
end

function M.append(entry, comment, config)
  local bufnr = ensure_packet(entry, config)
  local number = next_number(bufnr)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local lines = {
    "### Review Item " .. number,
    "- Path: " .. (entry.path or "unknown"),
    "- Revision: " .. (entry.rev or "unknown"),
    "- Side: " .. (entry.side or "unknown"),
    "- Peer path: " .. (entry.peer_path or "unknown"),
    "- Peer revision: " .. (entry.peer_rev or "unknown"),
    "- Line: " .. tostring(entry.line_number or "?"),
  }

  if entry.qf_text and entry.qf_text ~= "" then
    table.insert(lines, "- Quickfix entry: " .. entry.qf_text)
  end
  if entry.qf_lnum and entry.qf_lnum > 0 then
    table.insert(lines, "- Quickfix line: " .. tostring(entry.qf_lnum))
  end
  if entry.hunk and entry.hunk ~= "" then
    table.insert(lines, "- Hunk: " .. entry.hunk)
  end

  table.insert(lines, "- Selected line:")
  table.insert(lines, "```text")
  table.insert(lines, entry.selected_line or "(blank line)")
  table.insert(lines, "```")
  if entry.hunk_lines and #entry.hunk_lines > 0 then
    table.insert(lines, "- Hunk snippet:")
    table.insert(lines, "```diff")
    vim.list_extend(lines, entry.hunk_lines)
    table.insert(lines, "```")
  end
  table.insert(lines, "- Context:")
  vim.list_extend(lines, entry.context or { "```text", "(no context available)", "```" })
  table.insert(lines, "- Reviewer comment:")
  for _, line in ipairs(vim.split(comment, "\n", { plain = true })) do
    table.insert(lines, "  " .. line)
  end
  table.insert(lines, "")

  vim.api.nvim_buf_set_lines(bufnr, line_count, line_count, false, lines)
  vim.bo[bufnr].modified = false
  return number, bufnr
end

return M
