---@class NcsTool
local M = {}

local path = Utils.fs
local sh = Utils.sh
--- Finds nrfutil on PATH. Errors with install instructions if not found.
---@return string nrfutil_path Absolute path to the nrfutil binary
function M.find_nrfutil()
    local nrfutil_home = NRFUTIL_HOME
    if Utils.fs.path_exists(nrfutil_home, { type = "directory" }) then
        return Utils.fs.Path({ nrfutil_home, "bin", "nrfutil" }, { type = "file", fail = true })
    end
    local find_cmd = sh.get_os() == "windows" and "where nrfutil" or "which nrfutil"
    local result = sh.safe_exec(find_cmd)
    if result and result ~= "" then
        return result
    end

    Utils.fatal(
        "nrfutil not found on PATH. "
            .. "Install it first with: mise use ncs:nrfutil@<version>\n"
            .. "Example: mise use ncs:nrfutil@8.1.1"
    )
    return "" -- unreachable; Utils.fatal calls error()
end

--- Builds the toolchain index URL for the current platform.
---@return string
function M.get_toolchain_index_url()
    local os_name = sh.get_os()
    local arch = RUNTIME.archType

    local os_map = { linux = "linux", darwin = "macos" }
    local arch_map = { amd64 = "x86_64", arm64 = "aarch64", x86_64 = "x86_64", aarch64 = "aarch64" }

    local mapped_os = os_map[os_name] or os_name
    local mapped_arch = arch_map[arch] or arch

    return "https://files.nordicsemi.com/NCS/external/bundles/v3/index-" .. mapped_os .. "-" .. mapped_arch .. ".json"
end

--- Returns the effective toolchain base directory for the current platform.
--- Always uses the mise install_path via --install-dir.
---@param install_path string The mise-provided install path
---@return string
function M.get_toolchain_dir(install_path)
    return install_path
end

--- Searches available NCS toolchain versions via nrfutil toolchain-manager.
--- Parses version strings from the search output and filters by MIN_VERSION.
---@return string[] versions Sorted list of version strings (without "v" prefix)
function M.list_versions()
    local strings = require("strings")
    local semver = require("semver")

    local nrfutil = M.find_nrfutil()

    -- Ensure toolchain-manager is installed
    Utils.inf("Ensuring nrfutil toolchain-manager is installed...")
    sh.safe_exec(nrfutil .. " install toolchain-manager", { fail = true })

    -- Point toolchain-manager at the platform-specific NCS bundle index
    -- local tc_index = M.get_toolchain_index_url()
    -- Utils.inf("Setting toolchain index", { index = tc_index })
    -- sh.safe_exec(nrfutil .. " toolchain-manager config --set toolchain-index=" .. tc_index, { fail = true })

    local output = sh.safe_exec(nrfutil .. " toolchain-manager search", { fail = true })

    local versions = {}
    local lines = strings.split(output, "\n")
    for _, line in ipairs(lines) do
        local ver = line:match("(v?%d+%.%d+%.%d+[%w%-%.]*)")
        if ver then
            local clean = ver:gsub("^v", "")
            if semver.compare(clean, NCS_MIN_VERSION) >= 0 then
                table.insert(versions, clean)
            end
        end
    end

    return semver.sort(versions)
end

--- Installs an NCS toolchain version into install_path via --install-dir.
---@param ctx BackendInstallCtx
function M.install(ctx)
    local version, install_path = ctx.version, ctx.install_path
    local nrfutil = M.find_nrfutil()
    local version_arg = "v" .. version:gsub("^v", "")

    local install_cmd = nrfutil
        .. " toolchain-manager install --ncs-version "
        .. version_arg
        .. " --install-dir "
        .. install_path

    Utils.inf("Installing NCS toolchain", { version = version_arg, install_path = install_path })
    sh.safe_exec(install_cmd, { fail = true })
end

--- Fallback: construct env vars from known NCS toolchain directory layout.
---@param ctx BackendExecEnvCtx Installation directory
---@return table[] env_vars Array of {key, value} tables
function M.envs(ctx) -- luacheck: no unused args
    local install_path = ctx.install_path
    local env_vars = {}
    local usr_bin = path.Path({ install_path, "usr", "local", "bin" }, { check_exists = true })
    local usr_lib = path.Path({ install_path, "usr", "local", "lib" }, { check_exists = true })
    local sdk_dir = path.Path({ install_path, "opt", "zephyr-sdk" }, { check_exists = true })
    local sdk_bin = path.Path({ install_path, "opt", "zephyr-sdk", "arm-zephyr-eabi", "bin" }, { check_exists = true })

    if usr_bin ~= "" then
        table.insert(env_vars, { key = "PATH", value = usr_bin })
    end
    if sdk_bin ~= "" then
        table.insert(env_vars, { key = "PATH", value = sdk_bin })
    end
    if usr_lib ~= "" then
        table.insert(env_vars, { key = "LD_LIBRARY_PATH", value = usr_lib })
    end
    if sdk_dir ~= "" then
        table.insert(env_vars, { key = "ZEPHYR_TOOLCHAIN_VARIANT", value = "zephyr" })
        table.insert(env_vars, { key = "ZEPHYR_SDK_INSTALL_DIR", value = sdk_dir })
    end

    Utils.dbg("Built manual env vars for NCS toolchain", { install_path = install_path })
    return env_vars
end

return M
