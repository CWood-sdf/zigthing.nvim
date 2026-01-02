local M = {}

---@class ZigThing.Config
---@field setQfList boolean?
local Config = {
    setQfList = false,
}

---@param opts ZigThing.Config
function M.setup(opts)
    Config = vim.tbl_extend("force", Config, opts)
end

---@return ZigThing.Config
function M.getConfig()
    return Config
end

return M
