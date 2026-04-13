---@class NcsTool
local M = {}

local path = Utils.fs
local sh = Utils.sh

--- Fetches available nrfutil core module versions for the current
--- Queries the Artifactory storage API, filters to current platform and stable releases.
---@return string[] versions Sorted list of version strings
function M.list_versions()
    local http = require("http")
    local json = require("json")
    local semver = require("semver")

    local resp, err = http.get({
        url = PACKAGES_API_URL,
        headers = { ["User-Agent"] = "mise-plugin" },
    })

    if err ~= nil then
        Utils.fatal("Failed to fetch nrfutil package listing", { err = err })
    end
    if resp.status_code ~= 200 then
        Utils.fatal("Artifactory returned HTTP error", { status_code = resp.status_code })
    end

    local data = json.decode(resp.body)
    local triple = sh.get_platform_triple()
    local versions = {}

    for _, child in ipairs(data.children) do
        if not child.folder then
            local name = child.uri:gsub("^/", "")
            -- Pattern: nrfutil-{triple}-{version}.tar.gz
            local file_triple, version = name:match("^nrfutil%-(.+)-(%d+%.%d+%.%d+[%w%-%.]*).tar.gz$")
            if file_triple and version and file_triple == triple then
                -- Exclude pre-release versions (alpha, beta, rc, dev)
                if not version:match("%-") then
                    table.insert(versions, version)
                end
            end
        end
    end

    return semver.sort(versions)
end

--- Returns the nrfutil launcher download URL for the current
---@return string
function M.get_nrfutil_url()
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

--- Returns the download URL for a specific nrfutil core module tarball.
---@param version string Core module version (e.g. "8.1.1")
---@return string
function M.get_tarball_url(version)
    local triple = sh.get_platform_triple()
    return NRFUTIL_BASE_URL .. "/packages/nrfutil/nrfutil-" .. triple .. "-" .. version .. ".tar.gz"
end

--- Installs a specific version of nrfutil (launcher + pinned core module).
--- Layout: install_path/bin/nrfutil, install_path/home/, install_path/download/
---@param ctx BackendInstallCtx
function M.install(ctx)
    local version, install_path = ctx.version, ctx.install_path
    local http = require("http")

    local bin_dir = path.join_path(install_path, "bin")
    local home_dir = path.join_path(install_path, "home")
    local download_dir = path.join_path(install_path, "download")

    sh.safe_exec("mkdir -p " .. bin_dir .. " " .. home_dir .. " " .. download_dir, { fail = true })

    -- 1. Download the launcher executable
    local exe_suffix = sh.get_exe_suffix()
    local launcher_dest = path.join_path(bin_dir, "nrfutil" .. exe_suffix)
    local launcher_url = M.get_nrfutil_url()
    Utils.inf("Downloading nrfutil launcher", { url = launcher_url })
    local err = http.download_file({
        url = launcher_url,
        headers = { ["User-Agent"] = "mise-plugin" },
    }, launcher_dest)
    if err ~= nil then
        Utils.fatal("Failed to download nrfutil launcher", { err = err })
    end

    if sh.get_os() ~= "windows" then
        sh.safe_exec("chmod +x " .. launcher_dest, { fail = true })
    end

    -- 2. Download the versioned core module tarball
    local tarball_url = M.get_tarball_url(version)
    local triple = sh.get_platform_triple()
    local tarball_name = "nrfutil-" .. triple .. "-" .. version .. ".tar.gz"
    local tarball_path = path.join_path(download_dir, tarball_name)
    Utils.inf("Downloading nrfutil core", { version = version, url = tarball_url })
    err = http.download_file({
        url = tarball_url,
        headers = { ["User-Agent"] = "mise-plugin" },
    }, tarball_path)
    if err ~= nil then
        Utils.fatal("Failed to download nrfutil core tarball", { err = err })
    end

    -- 3. Bootstrap: pin core version via tarball path, run nrfutil to trigger install
    Utils.inf("Bootstrapping nrfutil core", { version = version })
    sh.safe_exec(launcher_dest .. " --version", {
        env = {
            NRFUTIL_HOME = home_dir,
            NRFUTIL_BOOTSTRAP_TARBALL_PATH = tarball_path,
        },
        fail = true,
    })

    -- 4. Configure the package index (needed for toolchain-manager later)
    -- local idx_name = PACKAGE_INDEX_NAME
    -- local idx_url = PACKAGE_INDEX_URL
    -- pcall(cmd.exec, launcher_dest .. " config package-index remove " .. idx_name, { env = { NRFUTIL_HOME = home_dir } })
    -- sh.safe_exec(
    --     launcher_dest .. " config package-index add " .. idx_name .. " " .. idx_url,
    --     { env = { NRFUTIL_HOME = home_dir } },
    --     true
    -- )

    Utils.inf("nrfutil installed successfully", { version = version })
end

--- Returns environment variables for an installed nrfutil version.
---@param ctx BackendExecEnvCtx Installation directory
---@return table[] env_vars Array of {key, value} tables
function M.envs(ctx) -- luacheck: no unused args
    local install_path = ctx.install_path
    return {
        { key = "PATH", value = path.join_path(install_path, "bin") },
        { key = "NRFUTIL_HOME", value = path.join_path(install_path, "home") },
    }
end

return M
