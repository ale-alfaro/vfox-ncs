---@class NcsTool
local M = {}

local path = Utils.fs
local sh = Utils.sh

local ARTIFACTORY_BASE_URL = "https://files.nordicsemi.com/artifactory"
local NRFUTIL_BASE_URL = ARTIFACTORY_BASE_URL .. "/swtools/external/nrfutil"
local NRFUTIL_URLS = {
    ["darwin"] = NRFUTIL_BASE_URL .. "/executables/universal-apple-darwin/nrfutil",
    ["linux-amd64"] = NRFUTIL_BASE_URL .. "/executables/x86_64-unknown-linux-gnu/nrfutil",
    ["linux-arm64"] = NRFUTIL_BASE_URL .. "/executables/aarch64-unknown-linux-gnu/nrfutil",
    ["windows-amd64"] = NRFUTIL_BASE_URL .. "/executables/x86_64-pc-windows-msvc/nrfutil.exe",
}
--- Returns the nrfutil launcher download URL for the current
---@return string
local function get_nrfutil_url()
    local os_name = sh.get_os()
    local arch = RUNTIME.archType

    -- macOS uses a universal binary
    if os_name == "darwin" then
        return NRFUTIL_URLS["darwin"]
    end

    local key = os_name .. "-" .. arch
    local url = NRFUTIL_URLS[key]
    if not url then
        Utils.fatal("Unsupported platform for nrfutil", { platform = key })
    end
    return url
end
--- Installs a specific version of nrfutil (launcher + pinned core module).
--- Layout: install_path/bin/nrfutil, install_path/home/, install_path/download/
---@param version string The mise-provided install path
---@param install_path string The mise-provided install path
---@param _download_path string The mise-provided install path
function M.install(version, install_path, _download_path)
    -- 1. Download the launcher executable
    local launcher_url = get_nrfutil_url()
    Utils.inf("Downloading nrfutil launcher", { url = launcher_url })
    local nrfutil_bin = Utils.net.executable_asset_download(launcher_url, install_path)
    if nrfutil_bin == nil then
        Utils.fatal("Failed to download nrfutil launcher")
    end

    if sh.get_os() ~= "windows" then
        sh.safe_exec("chmod +x " .. nrfutil_bin, { fail = true })
    end

    Utils.inf("Installing nrfutil toolchain-manager")
    sh.safe_exec({ nrfutil_bin, "install ", "toolchain-manager" }, { fail = true })
    Utils.inf("Configuring the NCS toolchain installation directory ")
    sh.safe_exec(
        { nrfutil_bin, "toolchain-manager", "config", "--set", "install-dir=" .. install_path },
        { fail = true }
    )

    Utils.inf("Installing NCS toolchain", { version = version })
    sh.safe_exec({
        nrfutil_bin,
        " toolchain-manager",
        "install",
        "--ncs-version",
        "v" .. version,
        "--install-dir",
        install_path,
    }, { fail = true })

    Utils.inf("nrfutil installed successfully", { version = version })
end

---@param version string The mise-provided install path
---@param install_path string The mise-provided install path
---@return EnvKey[] env_vars Array of {key, value} tables
function M.envs(version, install_path) -- luacheck: no unused args
    local nrfutil_bin = Utils.fs.Path({ install_path, "bin" })
    local nrfutil = Utils.fs.Path({ nrfutil_bin, "nrfutil" })

    local env_vars = {
        { key = "PATH", value = nrfutil_bin },
        { key = "NRFUTIL_HOME", value = install_path },
    }
    local output = sh.safe_exec({
        nrfutil,
        " toolchain-manager",
        "env",
        "--ncs-version",
        "v" .. version,
        "--install-dir",
        install_path,
        " --as-script",
    }, { fail = true })

    local lines = Utils.strings.split(output, "\n")
    for _, line in ipairs(lines) do
        local key, value = line:match('^export%s+([%w_]+)="?(.-)"?$')
        if key and value then
            if Utils.strings.has_prefix(key, "PYTHON") or Utils.strings.has_suffix(key, "PATH") then
                Utils.inf("Ignoring env var", { key = key, value = value })
            else
                table.insert(env_vars, { key = key, value = value })
            end
        end
    end

    Utils.inf("Built env vars for NCS toolchain", { env = env_vars })
    return env_vars
end

return M
