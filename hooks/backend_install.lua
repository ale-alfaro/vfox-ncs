--- Installs a specific version of a tool (nrfutil or toolchain).
--- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendinstall

--- @param ctx BackendInstallCtx
--- @return BackendInstallResult
function PLUGIN:BackendInstall(ctx)
    require("ncs")
    local tool = NCS[ctx.tool]
    if not tool then
        Utils.err("Could not find tool : ", { tool = ctx.tool, version = ctx.version, install = ctx.install_path })
        return {}
    end
    Utils.inf("Preparing to install  tool: ", { tool = tool, ctx = ctx })
    tool.install(ctx)
    return {}
end
