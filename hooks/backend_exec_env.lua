--- Configures environment variables for an installed tool (nrfutil or toolchain).
--- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendexecenv

--- @param ctx BackendExecEnvCtx
--- @return BackendExecEnvResult
function PLUGIN:BackendExecEnv(ctx)
    require("ncs")
    Utils.inf("Preparing envs for tool: ", { ctx = ctx })
    local plugin = PLUGIN.name
    local install_root_dir
    for dir in Utils.fs.parents(ctx.install_path) do
        if Utils.fs.path_exists(Utils.fs.join_path(dir, plugin .. "-" .. ctx.tool), { type = "directory" }) then
            install_root_dir = dir
            break
        end
    end
    local envs = {}
    if not install_root_dir then
        Utils.wrn("Could not find mise installs root dir")
    else
        local nrfutil_install_path = Utils.fs.Path({ install_root_dir, plugin .. "-nrfutil", ctx.version })
        if Utils.fs.path_exists(nrfutil_install_path, { type = "directory" }) then
            local nrfutil_envs = NCS.nrfutil.envs(ctx.version, nrfutil_install_path)
            envs = Utils.tbl_extend("keep", envs, nrfutil_envs)
            --     { key = "NRFUTIL_HOME", value = nrfutil_home },
            --     { key = "PATH", value = Utils.fs.join_path(nrfutil_home, "bin") },
            -- })
        end
    end
    local tool = NCS[ctx.tool]
    if not tool then
        return { env_vars = envs }
    end
    envs = Utils.tbl_extend("keep", envs, tool.envs(ctx.version, ctx.install_path))
    Utils.inf("Envs: ", { envs = envs })
    return { env_vars = envs }
end
