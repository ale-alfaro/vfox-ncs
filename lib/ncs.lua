---@nodoc
require("utils.core")

_G.ARTIFACTORY_BASE_URL = "https://files.nordicsemi.com/artifactory"
_G.NRFUTIL_BASE_URL = _G.ARTIFACTORY_BASE_URL .. "/swtools/external/nrfutil"
_G.PACKAGE_INDEX_URL = _G.NRFUTIL_BASE_URL .. "/index/init.json"
_G.PACKAGE_INDEX_NA_GE = "nordic-external-production"
_G.PACKAGES_API_URL = _G.ARTIFACTORY_BASE_URL .. "/api/storage/swtools/external/nrfutil/packages/nrfutil"

_G.NCS_MIN_VERSION = "2.7.0"

--- nrfutil launcher download URLs keyed by platform
_G.NRFUTIL_URLS = {
    ["darwin"] = _G.NRFUTIL_BASE_URL .. "/executables/universal-apple-darwin/nrfutil",
    ["linux-amd64"] = _G.NRFUTIL_BASE_URL .. "/executables/x86_64-unknown-linux-gnu/nrfutil",
    ["linux-arm64"] = _G.NRFUTIL_BASE_URL .. "/executables/aarch64-unknown-linux-gnu/nrfutil",
    ["windows-amd64"] = _G.NRFUTIL_BASE_URL .. "/executables/x86_64-pc-windows-msvc/nrfutil.exe",
}

Utils._submodules = {
    inspect = true,
    fs = true,
    sh = true,
}

Utils._mise_submods = {
    strings = true,
    semver = true,
    file = true,
    cmd = true,
}
-- These are for loading runtime modules in the vim namespace lazily.
setmetatable(Utils, {
    --- @param t table<any,any>
    __index = function(t, key)
        if Utils._submodules[key] then
            t[key] = require("utils." .. key)
            return t[key]
        elseif Utils._mise_submods[key] then
            t[key] = require(key)
            return t[key]
        end
    end,
})
_G.NRFUTIL_HOME = os.getenv("NRFUTIL_HOME") or Utils.fs.Path({ os.getenv("HOME"), ".nrfutil" })

---@class NcsTool
---@field list_versions? fun(): string[]
---@field install fun(ctx: BackendInstallCtx): nil
---@field envs fun(ctx: BackendExecEnvCtx):table<string,string>

_G.NCS = _G.NCS or {}
NCS._tools = {
    nrfutil = true,
    west = true,
    toolchain = true,
}
NCS._tools_alias = {
    ["toolchain-manager"] = "toolchain",
}

-- These are for loading runtime modules in the vim namespace lazily.
setmetatable(NCS, {
    --- @param t table<string,NcsTool>
    __index = function(t, key)
        if NCS._tools_alias[key] then
            key = NCS._tools_alias[key]
        end
        if NCS._tools[key] then
            t[key] = require(key)
            return t[key]
        end
    end,
})
