--- Installs a specific version of a tool (nrfutil or toolchain).
--- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendinstall

--- @param ctx BackendInstallCtx
--- @return BackendInstallResult
function PLUGIN:BackendInstall(ctx)
    local log = require("log")

    if ctx.tool == "nrfutil" then
        local nrfutil = require("nrfutil")
        log.info("Installing nrfutil " .. ctx.version)
        nrfutil.install(ctx.version, ctx.install_path)
    elseif ctx.tool == "toolchain" then
        local toolchain = require("toolchain")
        log.info("Installing NCS toolchain " .. ctx.version)
        toolchain.install(ctx.version, ctx.install_path)
    else
        error("Unknown tool: " .. tostring(ctx.tool))
    end

    return {}
end
