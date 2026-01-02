-- lua/zig_err.lua  (quickfix-compatible version)
local M = {}

local PAT = "^([%w_/%.%-]+):(%d+):(%d+): ([^:]+): (.+)$"

-- Helper: ensure buffer exists and return its handle
local function get_bufnr(fname)
    local buf = vim.fn.bufadd(fname)
    -- make sure it’s loaded so bufnr is valid
    if vim.fn.bufloaded(buf) == 0 then
        vim.fn.bufload(buf)
    end
    return buf
end

---Parse one line of Zig build/compiler output.
---@param line string
---@return table|nil  -- quickfix-style dictionary
function M.parse(line)
    local file, lnum, cnum, sev, txt = line:match(PAT)
    if not file then
        return nil
    end

    local bufnr = get_bufnr(vim.fn.fnamemodify(file, ":p"))
    return {
        bufnr = bufnr,
        lnum = tonumber(lnum),
        end_lnum = 0,
        end_col = 0,
        nr = -1,
        col = tonumber(cnum) - 1, -- 0-based
        text = txt,
        type = (sev:lower() == "error") and "E" or "W",
        valid = 1,
        pattern = "",
    }
end

---Parse entire stderr string.
---@param raw string
---@return table[]  -- array of quickfix-style dictionaries
function M.parse_all(raw)
    local t = {}
    for line in vim.gsplit(raw, "\n", { plain = true, trimempty = true }) do
        local entry = M.parse(line)
        if entry then
            table.insert(t, entry)
        end
    end
    return t
end

return M
