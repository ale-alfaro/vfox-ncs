local M = {}

local platform = require("platform")

--- Default toolchain directories per platform.
--- macOS is fixed at /opt/nordic/ncs (Python/dyld requires deterministic path).
--- Linux/Windows defaults can be overridden with --install-dir.
local TOOLCHAIN_DIRS = {
    darwin = "/opt/nordic/ncs",
    linux = (os.getenv("HOME") or "") .. "/ncs",
    windows = "C:\\ncs",
}

--- Finds nrfutil on PATH. Errors with install instructions if not found.
---@return string nrfutil_path Absolute path to the nrfutil binary
function M.find_nrfutil()
    local cmd = require("cmd")
    local strings = require("strings")

    local find_cmd = platform.get_os() == "windows" and "where nrfutil" or "which nrfutil"
    local ok, path = pcall(cmd.exec, find_cmd)
    if ok and path and path ~= "" then
        return strings.trim_space(path)
    end

    error(
        "nrfutil not found on PATH. "
            .. "Install it first with: mise use ncs:nrfutil@<version>\n"
            .. "Example: mise use ncs:nrfutil@8.1.1"
    )
end

--- Builds the toolchain index URL for the current platform.
---@return string
function M.get_toolchain_index_url()
    local os_name = platform.get_os()
    local arch = RUNTIME.archType

    local os_map = { linux = "linux", darwin = "macos" }
    local arch_map = { amd64 = "x86_64", arm64 = "aarch64", x86_64 = "x86_64", aarch64 = "aarch64" }

    local mapped_os = os_map[os_name] or os_name
    local mapped_arch = arch_map[arch] or arch

    return "https://files.nordicsemi.com/NCS/external/bundles/v3/index-" .. mapped_os .. "-" .. mapped_arch .. ".json"
end

--- Returns the effective toolchain base directory for the current platform.
--- On macOS this is the fixed /opt/nordic/ncs path.
--- On Linux/Windows it is the mise install_path (via --install-dir).
---@param install_path string The mise-provided install path
---@return string
function M.get_toolchain_dir(install_path)
    if platform.get_os() == "darwin" then
        return TOOLCHAIN_DIRS["darwin"]
    end
    return install_path
end

--- Searches available NCS toolchain versions via nrfutil toolchain-manager.
--- Parses version strings from the search output and filters by MIN_VERSION.
---@return string[] versions Sorted list of version strings (without "v" prefix)
function M.list_versions()
    local cmd = require("cmd")
    local strings = require("strings")
    local semver = require("semver")
    local log = require("log")

    local nrfutil = M.find_nrfutil()

    -- Ensure toolchain-manager is installed
    log.info("Ensuring nrfutil toolchain-manager is installed...")
    cmd.exec(nrfutil .. " install --force --package-index-name " .. platform.PACKAGE_INDEX_NAME .. " toolchain-manager")

    -- Point toolchain-manager at the platform-specific NCS bundle index
    local tc_index = M.get_toolchain_index_url()
    log.info("Setting toolchain index: " .. tc_index)
    cmd.exec(nrfutil .. " toolchain-manager config --set toolchain-index=" .. tc_index)

    local output = cmd.exec(nrfutil .. " toolchain-manager search")

    local versions = {}
    local lines = strings.split(output, "\n")
    for _, line in ipairs(lines) do
        local ver = line:match("(v?%d+%.%d+%.%d+[%w%-%.]*)")
        if ver then
            local clean = ver:gsub("^v", "")
            if semver.compare(clean, platform.MIN_VERSION) >= 0 then
                table.insert(versions, clean)
            end
        end
    end

    return semver.sort(versions)
end

--- Installs an NCS toolchain version.
--- On Linux/Windows, installs directly into install_path via --install-dir.
--- On macOS, --install-dir is not supported; toolchains go to /opt/nordic/ncs.
---@param version string NCS version (e.g. "2.7.0")
---@param install_path string Directory to install into (used on Linux/Windows)
function M.install(version, install_path)
    local cmd = require("cmd")
    local log = require("log")

    local nrfutil = M.find_nrfutil()
    local version_arg = "v" .. version:gsub("^v", "")

    local install_cmd = nrfutil .. " toolchain-manager install --ncs-version " .. version_arg

    -- --install-dir is not supported on macOS (fixed at /opt/nordic/ncs)
    if platform.get_os() ~= "darwin" then
        install_cmd = install_cmd .. " --install-dir " .. install_path
    end

    log.info("Installing NCS toolchain " .. version_arg)
    cmd.exec(install_cmd)
end

--- Retrieves environment variables for an installed NCS toolchain.
--- Parses the output of `nrfutil toolchain-manager env` for export lines.
--- Falls back to manual env construction if nrfutil is unavailable or fails.
---@param version string NCS version
---@param install_path string Installation directory (used on Linux/Windows)
---@return table[] env_vars Array of {key, value} tables
function M.exec_env(version, install_path)
    local strings = require("strings")
    local log = require("log")

    local tc_dir = M.get_toolchain_dir(install_path)

    -- Try to find nrfutil; fall back to manual env if not available
    local ok_find, nrfutil = pcall(M.find_nrfutil)
    if not ok_find then
        log.warn("nrfutil not on PATH, using manual env construction")
        return M.build_env_vars_manual(tc_dir)
    end

    local version_arg = "v" .. version:gsub("^v", "")

    local env_cmd = nrfutil .. " toolchain-manager env --ncs-version " .. version_arg .. " --as-script"

    if platform.get_os() ~= "darwin" then
        env_cmd = nrfutil
            .. " toolchain-manager env"
            .. " --ncs-version "
            .. version_arg
            .. " --install-dir "
            .. tc_dir
            .. " --as-script"
    end

    local cmd = require("cmd")
    local ok_exec, output = pcall(cmd.exec, env_cmd)
    if not ok_exec then
        log.warn("nrfutil toolchain-manager env failed, falling back to manual env construction")
        return M.build_env_vars_manual(tc_dir)
    end

    local env_vars = {}
    local lines = strings.split(output, "\n")
    for _, line in ipairs(lines) do
        local key, value = line:match('^export%s+([%w_]+)="?(.-)"?$')
        if key and value then
            if key == "PATH" then
                local parts = strings.split(value, ":")
                for _, p in ipairs(parts) do
                    local trimmed = strings.trim_space(p)
                    if trimmed ~= "" and trimmed ~= "$PATH" then
                        table.insert(env_vars, { key = "PATH", value = trimmed })
                    end
                end
            else
                table.insert(env_vars, { key = key, value = value })
            end
        end
    end

    if #env_vars == 0 then
        log.warn("No env vars parsed from nrfutil output, using manual fallback")
        return M.build_env_vars_manual(tc_dir)
    end

    return env_vars
end

--- Fallback: construct env vars from known NCS toolchain directory layout.
---@param install_path string Installation directory
---@return table[] env_vars Array of {key, value} tables
function M.build_env_vars_manual(install_path)
    local file = require("file")
    local log = require("log")

    local env_vars = {}
    local usr_bin = file.join_path(install_path, "usr", "local", "bin")
    local usr_lib = file.join_path(install_path, "usr", "local", "lib")
    local sdk_dir = file.join_path(install_path, "opt", "zephyr-sdk")
    local sdk_bin = file.join_path(sdk_dir, "arm-zephyr-eabi", "bin")

    if file.exists(usr_bin) then
        table.insert(env_vars, { key = "PATH", value = usr_bin })
    end
    if file.exists(sdk_bin) then
        table.insert(env_vars, { key = "PATH", value = sdk_bin })
    end
    if file.exists(usr_lib) then
        table.insert(env_vars, { key = "LD_LIBRARY_PATH", value = usr_lib })
    end
    if file.exists(sdk_dir) then
        table.insert(env_vars, { key = "ZEPHYR_TOOLCHAIN_VARIANT", value = "zephyr" })
        table.insert(env_vars, { key = "ZEPHYR_SDK_INSTALL_DIR", value = sdk_dir })
    end

    log.debug("Built manual env vars for NCS toolchain at " .. install_path)
    return env_vars
end

return M
