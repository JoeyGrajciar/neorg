require("neorg.modules.base")

local module = neorg.modules.create("core.integrations.truezen")

module.load = function()
    local success, truezen = pcall(require, "true-zen.main")

    assert(success, "Unable to load truezen...")

    local success, truezen_setup = pcall(require, "true-zen")
    assert(success, "Unable to load truezen setup")

    truezen_setup.setup(module.config.public)

    module.private.truezen = truezen
end

module.private = {
    truezen = nil,
}

module.config.public = {
    -- truezen setup configs: https://github.com/Pocco81/TrueZen.nvim
    setup = {},
}

module.public = {
    toggle_ataraxis = function()
        vim.cmd(":TZAtaraxis")
    end,
}
return module
