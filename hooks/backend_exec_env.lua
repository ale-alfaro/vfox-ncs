--- Configures environment variables for an installed tool (nrfutil or toolchain).
--- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendexecenv

--- @param ctx BackendExecEnvCtx
--- @return BackendExecEnvResult
function PLUGIN:BackendExecEnv(ctx)
    require("utils")
    local log = require("log")

    if ctx.tool == "nrfutil" then
        local nrfutil = require("nrfutil")
        log.debug("Setting up nrfutil environment at " .. ctx.install_path)
        return { env_vars = nrfutil.exec_env(ctx.version, ctx.install_path) }
    elseif ctx.tool == "toolchain" then
        local toolchain = require("toolchain")
        log.debug("Setting up NCS toolchain environment for " .. ctx.version)
        return { env_vars = toolchain.exec_env(ctx.version, ctx.install_path) }
    elseif ctx.tool == "west" then
        local west = require("west")
        Utils.dbg("Setting up west environment at " .. ctx.install_path)
        return { env_vars = west.exec_env(ctx.version, ctx.install_path) }
    else
        error("Unknown tool: " .. tostring(ctx.tool))
    end
end
