---@class ZigThing.Project.ClosureData
---@field cancelling boolean

---@class ZigThing.Project
---@field cmd vim.SystemObj
---@field ev uv.uv_fs_event_t
---@field data ZigThing.Project.ClosureData

---@type { [string]: ZigThing.Project }
local trackingProjects = {}

local uv = vim.uv
local M = {}

local _runner = ""
local function getRunner()
    if _runner == "" then
        local runnerName = "build_runner-0.15.zig"
        local script_path = debug.getinfo(1).source
        script_path = script_path:sub(2, #script_path)
        local script_root = vim.fn.fnamemodify(script_path, ":h:h:h")
        _runner = script_root .. "/" .. runnerName
    end
    return _runner
end

local cacheDir = vim.fn.stdpath("cache") .. "/zigthing"

---gets the location directory of the build.zig for this file's project
---@param file string a zig file
---@return string?
local function getRootFor(file)
    if not require("zigthing").getConfig().multiworkspace then
        return vim.fn.getcwd()
    end
    local root = vim.fn.fnamemodify(file, ":h")
    if vim.fn.filereadable(root .. "/" .. "build.zig") == 1 then
        return root
    end
    if root == file then
        return nil
    end
    -- idk this seems pretty close to fsroot, just assume there isnt a build.zig there
    if #root <= 3 then
        return nil
    end
    return getRootFor(root)
end

function M.cancelForFile(file)
    local root = getRootFor(file)

    if root == nil then
        return
    end

    if trackingProjects[root] ~= nil then
        local proj = trackingProjects[root]
        proj.data.cancelling = true
        local code = 15
        local children = vim.api.nvim_get_proc_children(proj.cmd.pid)
        for _, c in ipairs(children) do
            vim.uv.kill(c, code)
        end
        proj.cmd:kill(code)
        -- vim.uv.kill(proj.cmd.pid, 9)
        -- vim.uv.kill(proj.cmd.pid, 2)
    end
end

---@return string[]
function M.getActiveProjects()
    local ret = {}
    for k, _ in pairs(trackingProjects) do
        table.insert(ret, k)
    end
    return ret
end

---@param file string
---@return boolean
function M.isActive(file)
    local r = getRootFor(file)
    if r == nil then
        return false
    end

    return trackingProjects[r] ~= nil
end

---@param file string
---@param root string
---@param ns number
local function trackFile(file, root, ns)
    local ev = uv.new_fs_event()
    if ev == nil then
        print("no ev created :(")
        return
    end
    local lastBufs = {}
    vim.print("Tracking: " .. file)

    uv.fs_event_start(
        ev,
        file,
        {},
        vim.schedule_wrap(function()
            local qf = require("zigthing.qf_parse")
            local qflist = {}
            -- if require("zigthing").getConfig().setQfList then
            --     vim.fn.setqflist({})
            --     vim.cmd("cgetfile " .. file)
            --     qflist = vim.fn.getqflist()
            -- else
            local f = io.open(file, "r")
            if f == nil then
                return
            end
            local raw = f:read("*a")
            for _, entry in ipairs(qf.parse_all(raw, root)) do
                table.insert(qflist, entry)
            end
            -- end

            local diags = vim.diagnostic.fromqflist(qflist)

            local levels = {
                note = vim.diagnostic.severity.HINT,
                error = vim.diagnostic.severity.ERROR,
            }

            local newDiags = {}
            for _, diag in ipairs(diags) do
                local msg = diag.message
                for zigname, level in pairs(levels) do
                    if msg:sub(2, #zigname + 1) == zigname then
                        diag.severity = level
                        diag.message = msg:sub(#zigname + 4)
                        break
                    end
                end
                newDiags[tostring(diag.bufnr)] = newDiags[tostring(diag.bufnr)] or {}
                table.insert(newDiags[tostring(diag.bufnr)], diag)
            end

            vim.diagnostic.reset(ns)
            for _, buf in ipairs(lastBufs) do
                vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
            end
            lastBufs = {}

            for buf, diag in pairs(newDiags) do
                buf = buf * 1
                -- print(buf)
                -- vim.print(diag)
                table.insert(lastBufs, buf)
                vim.diagnostic.set(ns, buf, diag, {})
            end
        end)
    )
    return ev
end

function M.addFile(filePath)
    local root = getRootFor(filePath)

    if root == nil then
        return false
    end
    if trackingProjects[root] ~= nil then
        return true
    end

    vim.fn.mkdir(cacheDir, "p")

    local errorsTxt = vim.fs.normalize(root .. "/zig_errors.txt")

    local ns = vim.api.nvim_create_namespace("zigthing-" .. root)

    errorsTxt = errorsTxt
        :gsub("[^%w._-]", "_") -- keep only A-Z a-z 0-9 . _ -
        :gsub("_+", "_") -- collapse runs
        :gsub("^_", "")  -- drop leading _
    errorsTxt = cacheDir .. "/" .. errorsTxt

    local f = io.open(errorsTxt, "w")
    if f ~= nil then
        f:write(" ")
        f:close()
    else
        print("Could not create " .. errorsTxt)
    end
    local ev = trackFile(errorsTxt, root, ns)
    if ev == nil then
        print("Could not track " .. errorsTxt)
        return false
    end
    local procInfo = {
        "zig",
        "build",
        "check",
        "--watch",
        "-fincremental",
        "--build-runner",
        getRunner(),
    }
    -- vim.print(procInfo)
    -- vim.print("@ " .. root)
    -- vim.print("E path: " .. errorsTxt)
    ---@type ZigThing.Project.ClosureData
    local data = {
        cancelling = false,
    }
    ---@type ZigThing.Project
    local proj = {
        data = data,
        cmd = vim.system(
            procInfo,
            {
                env = {
                    ERRORFILE_PATH = errorsTxt,
                },
                cwd = root,
            },
            vim.schedule_wrap(function()
                vim.diagnostic.reset(ns)
                uv.fs_event_stop(ev)
                trackingProjects[root] = nil
            end)
        ),
        ev = ev,
    }
    trackingProjects[root] = proj
end

return M
