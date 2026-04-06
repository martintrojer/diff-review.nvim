if vim.g.loaded_diff_review == 1 then
  return
end
vim.g.loaded_diff_review = 1

vim.api.nvim_create_user_command("DiffReviewComment", function()
  require("diff-review").comment_current()
end, { nargs = 0 })

vim.api.nvim_create_user_command("DiffReviewOpen", function()
  require("diff-review").open_packet()
end, { nargs = 0 })

require("diff-review").setup()
