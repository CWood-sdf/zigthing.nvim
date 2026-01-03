local ct = require("zigthing.cmdTree")

ct.createCmd({
    Zigthing = {
        stopthis = {
            _callback = function()
                require("zigthing.tracker").cancelForFile(vim.fn.expand("%:p"))
            end,
        },
        stop = {
            _callback = function(args)
                require("zigthing.tracker").cancelForFile(args.params[1][1])
            end,
            ct.requiredParams(function()
                return require("zigthing.tracker").getActiveProjects()
            end),
        },
    },
})
