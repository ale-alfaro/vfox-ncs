---@nodoc
require("utils.core")

--- nrfutil launcher download URLs keyed by platform
---@class Utils
---@module 'utils.inspect'
---@module 'utils.fs'
---@module 'utils.sh'
---@module 'utils.net'
---@module 'strings'
---@module 'semver'
Utils._submodules = {
    inspect = true,
    fs = true,
    sh = true,
    net = true,
}

Utils._mise_submods = {
    strings = true,
    semver = true,
    file = true,
    http = true,
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

---@class NcsTool
---@field list_versions? fun(): string[]
---@field install fun(version: string,install_path:string, install_path:string): nil
---@field envs fun(version: string,install_path:string):EnvKey[]

_G.NCS = _G.NCS or {}
---@class NCS._tools : table<string, NcsTool>
NCS._tools = {
    nrfutil = true,
    west = true,
    toolchain = true,
}
---@class NCS._tools_alias : table<string, string>
NCS._tools_alias = {
    ["toolchain-manager"] = "toolchain",
    ["arm-zephyr-eabi"] = "toolchain",
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
