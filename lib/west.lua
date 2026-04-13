---@class NcsTool
local M = {}

--- Installs the west shim script into the mise install path.
---@param ctx BackendInstallCtx
function M.install(ctx)
    local plugin_path = Utils.sh.safe_exec(string.format("realpath %q", RUNTIME.pluginDirPath), { fail = true })
    local local_west = Utils.fs.join_path(plugin_path, "bin", "west")
    local mise_install_path = Utils.fs.Path({ ctx.install_path, "west" })
    if not Utils.fs.exists(mise_install_path) then
        Utils.sh.safe_exec(string.format("cp %q %q", local_west, ctx.install_path), { fail = true })
        Utils.inf("Copied west shim", { west_shim = local_west, mise_west = mise_install_path })
    end
end

--- Python env vars that must be cleared to avoid NCS toolchain Python conflicts.
local PYTHON_ENV_VARS_TO_CLEAR = { "VIRTUAL_ENV", "PYTHONPATH", "PYTHONHOME" }

--- Returns environment variables for the west shim.
--- Clears Python env vars that may leak from NCS toolchain activation.
---@param ctx BackendExecEnvCtx Installation directory
---@return table[] env_vars Array of {key, value} tables
function M.envs(ctx) -- luacheck: no unused args
    local env_vars = {
        { key = "PATH", value = ctx.install_path },
    }
    for _, var in ipairs(PYTHON_ENV_VARS_TO_CLEAR) do
        table.insert(env_vars, { key = var, value = "" })
    end
    return env_vars
end

--- Lists available versions (delegates to toolchain versions for NCS alignment).
---@return string[] versions
function M.list_versions()
    local toolchain = require("toolchain")
    return toolchain.list_versions()
end

return M
