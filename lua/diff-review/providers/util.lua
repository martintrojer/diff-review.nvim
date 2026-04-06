local M = {}

local function trim(s)
  if not s then
    return nil
  end
  s = s:gsub("%s+$", "")
  if s == "" then
    return nil
  end
  return s
end

function M.run(cmd, cwd)
  local result = vim.system(cmd, { cwd = cwd, text = true }):wait()
  if result.code ~= 0 then
    return nil
  end
  return trim(result.stdout)
end

function M.run_first(cmds, cwd)
  for _, cmd in ipairs(cmds) do
    local out = M.run(cmd, cwd)
    if out then
      return out
    end
  end
  return nil
end

function M.shorten_hash(value, len)
  if not value or value == "" then
    return nil
  end
  len = len or 12
  if #value <= len then
    return value
  end
  return value:sub(1, len)
end

function M.file_hash(path)
  if not path or path == "" or vim.fn.filereadable(path) ~= 1 then
    return nil
  end
  local cwd = vim.fn.fnamemodify(path, ":p:h")
  local abs = vim.fn.fnamemodify(path, ":p")

  local sha = M.run_first({
    { "sha256sum", abs },
    { "shasum", "-a", "256", abs },
    { "openssl", "dgst", "-sha256", abs },
  }, cwd)
  if not sha then
    return nil
  end

  return sha:match("^([0-9a-fA-F]+)") or sha
end

return M
