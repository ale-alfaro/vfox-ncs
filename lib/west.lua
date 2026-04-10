local M = {}

require("utils")
local path = require("pathlib")
local sh = require("shell_exec")

--- Installs the west shim script into the mise install path.
---@param _version string NCS version (for API consistency)
---@param install_path string Mise-provided installation directory
function M.install(_version, install_path)
    local plugin_path = sh.safe_exec(string.format("realpath %q", RUNTIME.pluginDirPath), {}, true)
    local local_west_shim = path.Path({ plugin_path, "bin", "west_shim.py" }, { check_exists = true, fail = true })
    local installed_west_shim = path.Path({ install_path, "west_shim.py" }, { check_exists = true })
    if installed_west_shim == "" then
        sh.safe_exec(string.format("cp %q %q", local_west_shim, install_path), {}, true)
        Utils.inf("Copied west shim", { west_shim = local_west_shim, install_path = install_path })
        local fs = require("file")
        local ok, msg = os.rename(fs.join_path(install_path, "west_shim.py"), fs.join_path(install_path, "west"))
        if not ok then
            Utils.fatal("Failed to rename shim to west command", { err_msg = msg })
        end
    end
end

--- Python env vars that must be cleared to avoid NCS toolchain Python conflicts.
local PYTHON_ENV_VARS_TO_CLEAR = { "VIRTUAL_ENV", "PYTHONPATH", "PYTHONHOME" }

--- Returns environment variables for the west shim.
--- Clears Python env vars that may leak from NCS toolchain activation.
---@param _version string NCS version (unused)
---@param install_path string Installation directory
---@return table[] env_vars Array of {key, value} tables
function M.exec_env(_version, install_path) -- luacheck: no unused args
    local env_vars = {
        { key = "PATH", value = install_path },
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
