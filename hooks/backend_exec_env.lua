--- Configures environment variables for an installed NCS toolchain.
--- Delegates to nrfutil toolchain-manager env with a manual fallback.
--- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendexecenv

--- @param ctx BackendExecEnvCtx
--- @return BackendExecEnvResult
function PLUGIN:BackendExecEnv(ctx)
    local log = require("log")
    local ncs = require("ncs")

    local install_path = ctx.install_path
    local version = ctx.version

    log.debug("Setting up NCS environment for " .. version .. " at " .. install_path)
    local env_vars = ncs.get_env_vars(version, install_path)

    return { env_vars = env_vars }
end
