local M = {}

M.MIN_VERSION = "2.7.0"

local ARTIFACTORY_BASE_URL = "https://files.nordicsemi.com/artifactory"
local NRFUTIL_BASE_URL = ARTIFACTORY_BASE_URL .. "/swtools/external/nrfutil"
local PACKAGE_INDEX_URL = NRFUTIL_BASE_URL .. "/index/init.json"
local PACKAGE_INDEX_NAME = "nordic-external-production"

--- Default toolchain directories per platform.
--- macOS is fixed at /opt/nordic/ncs (Python/dyld requires deterministic path).
--- Linux/Windows defaults can be overridden with --install-dir.
local TOOLCHAIN_DIRS = {
    darwin = "/opt/nordic/ncs",
    linux = (os.getenv("HOME") or "") .. "/ncs",
    windows = "C:\\ncs",
}

--- nrfutil executable download URLs keyed by platform
---@type table<string, string>
local NRFUTIL_URLS = {
    ["darwin"] = NRFUTIL_BASE_URL .. "/executables/universal-apple-darwin/nrfutil",
    ["linux-amd64"] = NRFUTIL_BASE_URL .. "/executables/x86_64-unknown-linux-gnu/nrfutil",
    ["windows-amd64"] = NRFUTIL_BASE_URL .. "/executables/x86_64-pc-windows-msvc/nrfutil.exe",
}

--- Builds the toolchain index URL for the current platform.
--- This is the same NCS bundle index the old plugin fetched directly.
---@return string
function M.get_toolchain_index_url()
    local os_name = RUNTIME.osType:lower()
    local arch = RUNTIME.archType

    local os_map = { linux = "linux", darwin = "macos" }
    local arch_map = { amd64 = "x86_64", arm64 = "aarch64", x86_64 = "x86_64", aarch64 = "aarch64" }

    local mapped_os = os_map[os_name] or os_name
    local mapped_arch = arch_map[arch] or arch

    return "https://files.nordicsemi.com/NCS/external/bundles/v3/index-" .. mapped_os .. "-" .. mapped_arch .. ".json"
end

--- Returns the nrfutil download URL for the current platform
---@return string
function M.get_nrfutil_url()
    local os_name = RUNTIME.osType:lower()
    local arch = RUNTIME.archType

    -- macOS uses a universal binary
    if os_name == "darwin" then
        return NRFUTIL_URLS["darwin"]
    end

    local key = os_name .. "-" .. arch
    local url = NRFUTIL_URLS[key]
    if not url then
        error("Unsupported platform for nrfutil: " .. key)
    end
    return url
end

--- Returns the path where nrfutil is stored (inside the plugin directory)
---@return string
function M.get_nrfutil_path()
    local file = require("file")
    local bin_name = RUNTIME.osType:lower() == "windows" and "nrfutil.exe" or "nrfutil"
    return file.join_path(RUNTIME.pluginDirPath, bin_name)
end

--- Removes stale nrfutil-core binary so the launcher re-bootstraps.
--- Mirrors the cleanup step from Nordic's bootstrap-toolchain.sh.
local function cleanup_stale_nrfutil_core()
    local os_name = RUNTIME.osType:lower()
    local home = os_name == "windows" and os.getenv("USERPROFILE") or os.getenv("HOME")
    if home then
        os.remove(home .. "/.nrfutil/bin/nrfutil")
    end
end

--- Downloads nrfutil if not present, configures the package index,
--- and installs the toolchain-manager subcommand.
---@return string nrfutil_path Absolute path to the nrfutil binary
function M.ensure_nrfutil()
    local file = require("file")
    local http = require("http")
    local cmd = require("cmd")
    local log = require("log")

    local nrfutil = M.get_nrfutil_path()

    if not file.exists(nrfutil) then
        local url = M.get_nrfutil_url()
        log.info("Downloading nrfutil from " .. url)
        local err = http.download_file({ url = url }, nrfutil)
        if err ~= nil then
            error("Failed to download nrfutil: " .. err)
        end

        if RUNTIME.osType:lower() ~= "windows" then
            cmd.exec("chmod +x " .. nrfutil)
        end

        cleanup_stale_nrfutil_core()
    end

    -- Configure the package index (idempotent: remove then re-add)
    pcall(cmd.exec, nrfutil .. " config package-index remove " .. PACKAGE_INDEX_NAME)
    cmd.exec(nrfutil .. " config package-index add " .. PACKAGE_INDEX_NAME .. " " .. PACKAGE_INDEX_URL)

    -- Install toolchain-manager via the configured index
    log.info("Ensuring nrfutil toolchain-manager is installed...")
    cmd.exec(nrfutil .. " install --force --package-index-name " .. PACKAGE_INDEX_NAME .. " toolchain-manager")

    -- Point toolchain-manager at the platform-specific NCS bundle index
    local tc_index = M.get_toolchain_index_url()
    log.info("Setting toolchain index: " .. tc_index)
    cmd.exec(nrfutil .. " toolchain-manager config --set toolchain-index=" .. tc_index)

    return nrfutil
end

--- Searches available NCS toolchain versions via nrfutil toolchain-manager.
--- Parses version strings from the search output and filters by MIN_VERSION.
---@return string[] versions Sorted list of version strings (without "v" prefix)
function M.search_versions()
    local cmd = require("cmd")
    local strings = require("strings")
    local semver = require("semver")

    local nrfutil = M.ensure_nrfutil()
    local output = cmd.exec(nrfutil .. " toolchain-manager search")

    local versions = {}
    local lines = strings.split(output, "\n")
    for _, line in ipairs(lines) do
        local ver = line:match("(v?%d+%.%d+%.%d+[%w%-%.]*)")
        if ver then
            local clean = ver:gsub("^v", "")
            if semver.compare(clean, M.MIN_VERSION) >= 0 then
                table.insert(versions, clean)
            end
        end
    end

    return versions
end

--- Returns the effective toolchain base directory for the current platform.
--- On macOS this is the fixed /opt/nordic/ncs path.
--- On Linux/Windows it is the mise install_path (via --install-dir).
---@param install_path string The mise-provided install path
---@return string
function M.get_toolchain_dir(install_path)
    if RUNTIME.osType:lower() == "darwin" then
        return TOOLCHAIN_DIRS["darwin"]
    end
    return install_path
end

--- Installs an NCS toolchain version.
--- On Linux/Windows, installs directly into install_path via --install-dir.
--- On macOS, --install-dir is not supported; toolchains go to /opt/nordic/ncs.
---@param version string NCS version (e.g. "2.7.0")
---@param install_path string Directory to install into (used on Linux/Windows)
function M.install_toolchain(version, install_path)
    local cmd = require("cmd")
    local log = require("log")

    local nrfutil = M.ensure_nrfutil()
    local version_arg = "v" .. version:gsub("^v", "")

    local install_cmd = nrfutil .. " toolchain-manager install --ncs-version " .. version_arg

    -- --install-dir is not supported on macOS (fixed at /opt/nordic/ncs)
    if RUNTIME.osType:lower() ~= "darwin" then
        install_cmd = install_cmd .. " --install-dir " .. install_path
    end

    log.info("Installing NCS toolchain " .. version_arg)
    cmd.exec(install_cmd)
end

--- Retrieves environment variables for an installed NCS toolchain.
--- Parses the output of `nrfutil toolchain-manager env` for export lines.
---@param version string NCS version
---@param install_path string Installation directory (used on Linux/Windows)
---@return table[] env_vars Array of {key, value} tables
function M.get_env_vars(version, install_path)
    local cmd = require("cmd")
    local strings = require("strings")
    local log = require("log")

    local nrfutil = M.get_nrfutil_path()
    local version_arg = "v" .. version:gsub("^v", "")
    local tc_dir = M.get_toolchain_dir(install_path)

    local env_cmd = nrfutil .. " toolchain-manager env --ncs-version " .. version_arg .. " --as-script"

    -- --install-dir is not supported on macOS (fixed at /opt/nordic/ncs)
    if RUNTIME.osType:lower() ~= "darwin" then
        env_cmd = env_cmd:gsub(" --as%-script$", "") -- rebuild with --install-dir
        env_cmd = nrfutil
            .. " toolchain-manager env"
            .. " --ncs-version "
            .. version_arg
            .. " --install-dir "
            .. tc_dir
            .. " --as-script"
    end

    local ok, output = pcall(cmd.exec, env_cmd)
    if not ok then
        log.warn("nrfutil toolchain-manager env failed, falling back to manual env construction")
        return M.build_env_vars_manual(tc_dir)
    end

    local env_vars = {}
    local lines = strings.split(output, "\n")
    for _, line in ipairs(lines) do
        -- Parse "export KEY=VALUE" or "export KEY=\"VALUE\""
        local key, value = line:match('^export%s+([%w_]+)="?(.-)"?$')
        if key and value then
            -- For PATH, split on ":" and add each entry separately
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
