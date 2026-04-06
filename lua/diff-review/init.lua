local M = {}

M.config = {
  prompt_lines = nil,
  keymaps = true,
}

local initialized = false

local function notify_capture(side, number)
  if side == "left" then
    vim.notify("Review added (" .. number .. ", left/original side)", vim.log.levels.INFO)
    return
  end
  vim.notify("Review added (" .. number .. ")", vim.log.levels.INFO)
end

local function set_buffer_keymaps(bufnr)
  if vim.b[bufnr].diff_review_keymaps_set then
    return
  end
  vim.b[bufnr].diff_review_keymaps_set = true

  local opts = { buffer = bufnr, silent = true }
  vim.keymap.set("n", "cR", function()
    require("diff-review").comment_current()
  end, opts)
  vim.keymap.set("n", "gR", function()
    require("diff-review").open_packet()
  end, opts)
end

local function maybe_attach(bufnr)
  if not M.config.keymaps then
    return
  end
  if vim.bo[bufnr].buftype ~= "" then
    return
  end

  local wins = vim.fn.win_findbuf(bufnr)
  for _, winid in ipairs(wins) do
    if vim.api.nvim_win_is_valid(winid) and vim.wo[winid].diff then
      set_buffer_keymaps(bufnr)
      return
    end
  end
end

function M.setup(opts)
  M.config = vim.tbl_extend("force", M.config, opts or {})
  if initialized then
    return
  end
  initialized = true

  local group = vim.api.nvim_create_augroup("DiffReview", { clear = true })
  vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
    group = group,
    callback = function(args)
      maybe_attach(args.buf)
    end,
  })
end

function M.open_packet()
  local entry, err = require("diff-review.extract").current()
  if not entry then
    vim.notify(err, vim.log.levels.WARN)
    return
  end
  require("diff-review.packet").open(entry, M.config)
end

function M.comment_current()
  local entry, err = require("diff-review.extract").current()
  if not entry then
    vim.notify(err, vim.log.levels.WARN)
    return
  end

  vim.ui.input({ prompt = "Review comment: " }, function(comment)
    if not comment or comment:match("^%s*$") then
      return
    end
    local number = require("diff-review.packet").append(entry, comment, M.config)
    notify_capture(entry.side, number)
  end)
end

return M
