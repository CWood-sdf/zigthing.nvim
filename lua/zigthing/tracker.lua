---@class ZigThing.Project
---@field cmd vim.SystemObj
---@field ev uv.uv_fs_event_t

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

local function trackFile(file)
    local ev = uv.new_fs_event()
    if ev == nil then
        print("no ev created :(")
        return
    end
    local lastDiags = {}

    uv.fs_event_start(
        ev,
        file,
        {},
        vim.schedule_wrap(function()
            vim.fn.setqflist({})
            vim.cmd("cgetfile " .. file)

            local qflist = vim.fn.getqflist()
            local ns = vim.api.nvim_create_namespace("zigthing")

            -- for _, v in ipairs(qflist) do
            --     v.bufnr = vim.api.nvim_buf_from
            -- end

            local diags = vim.diagnostic.fromqflist(qflist)

            local levels = {
                note = vim.diagnostic.severity.HINT,
                error = vim.diagnostic.severity.ERROR,
            }

            for buf, _ in pairs(lastDiags) do
                lastDiags[buf] = {}
            end

            for _, diag in ipairs(diags) do
                local msg = diag.message
                for zigname, level in pairs(levels) do
                    if msg:sub(2, #zigname + 1) == zigname then
                        diag.severity = level
                        diag.message = msg:sub(#zigname + 4)
                        break
                    end
                end
                lastDiags[diag.bufnr] = lastDiags[diag.bufnr] or {}

                table.insert(lastDiags[diag.bufnr], diag)
            end

            for buf, diag in pairs(lastDiags) do
                vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
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
    local ev = trackFile(errorsTxt)
    if ev == nil then
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
    ---@type ZigThing.Project
    local proj = {
        cmd = vim.system(procInfo, {
            env = {
                ERRORFILE_PATH = errorsTxt,
            },
        }, function()
            print("PROCESS DIED UNEXPECTEDLY!")
            uv.fs_event_stop(ev)
            trackingProjects[root] = nil
        end),
        ev = ev,
    }
    trackingProjects[root] = proj
end

return M
