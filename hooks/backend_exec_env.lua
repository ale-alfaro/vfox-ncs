--- Configures environment variables for an installed tool (nrfutil or toolchain).
--- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendexecenv

--- @param ctx BackendExecEnvCtx
--- @return BackendExecEnvResult
function PLUGIN:BackendExecEnv(ctx)
    require("ncs")
    local tool = NCS[ctx.tool]
    if not tool then
        Utils.err("Could not find tool : ", { tool = ctx.tool, version = ctx.version, install = ctx.install_path })
        return {}
    end
    Utils.inf("Preparing envs for tool: ", { tool = tool, ctx = ctx })
    local vars = { env_vars = tool.envs(ctx) }
    Utils.inf("Envs: ", { envs = vars })
    return vars
end
