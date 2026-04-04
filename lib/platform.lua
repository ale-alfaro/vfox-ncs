local M = {}

M.ARTIFACTORY_BASE_URL = "https://files.nordicsemi.com/artifactory"
M.NRFUTIL_BASE_URL = M.ARTIFACTORY_BASE_URL .. "/swtools/external/nrfutil"
M.PACKAGE_INDEX_URL = M.NRFUTIL_BASE_URL .. "/index/init.json"
M.PACKAGE_INDEX_NAME = "nordic-external-production"
M.PACKAGES_API_URL = M.ARTIFACTORY_BASE_URL .. "/api/storage/swtools/external/nrfutil/packages/nrfutil"

M.MIN_VERSION = "2.7.0"

M.ARCH_MAP = { amd64 = "x86_64", arm64 = "aarch64", x86_64 = "x86_64", aarch64 = "aarch64" }
M.OS_MAP = {
    darwin = "apple-darwin",
    linux = "unknown-linux-gnu",
    windows = "pc-windows-msvc",
}

--- nrfutil launcher download URLs keyed by platform
M.NRFUTIL_URLS = {
    ["darwin"] = M.NRFUTIL_BASE_URL .. "/executables/universal-apple-darwin/nrfutil",
    ["linux-amd64"] = M.NRFUTIL_BASE_URL .. "/executables/x86_64-unknown-linux-gnu/nrfutil",
    ["linux-arm64"] = M.NRFUTIL_BASE_URL .. "/executables/aarch64-unknown-linux-gnu/nrfutil",
    ["windows-amd64"] = M.NRFUTIL_BASE_URL .. "/executables/x86_64-pc-windows-msvc/nrfutil.exe",
}

--- Returns the Artifactory platform triple for the current machine.
--- e.g. "x86_64-unknown-linux-gnu" or "aarch64-apple-darwin"
---@return string
function M.get_platform_triple()
    local os_name = RUNTIME.osType:lower()
    local arch = RUNTIME.archType
    local mapped_arch = M.ARCH_MAP[arch] or arch
    local mapped_os = M.OS_MAP[os_name]
    if not mapped_os then
        error("Unsupported OS: " .. os_name)
    end
    return mapped_arch .. "-" .. mapped_os
end

--- Returns the executable suffix for the current OS.
---@return string
function M.get_exe_suffix()
    return RUNTIME.osType:lower() == "windows" and ".exe" or ""
end

--- Returns the current OS name lowercased.
---@return string
function M.get_os()
    return RUNTIME.osType:lower()
end

return M
