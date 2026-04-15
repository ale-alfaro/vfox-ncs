--- Lists available versions for a tool (nrfutil or toolchain).
--- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendlistversions

local cache = {} ---@type {releases: ToolchainBundle[], timestamp:number}
local cache_ttl = 12 * 60 * 60 -- 12 hours in seconds
local default_version = { "3.2.1", "3.0.0", "2.7.0" }
---@param fetch_fn? fun():string[]
---@return string[]
local function get_releases(fetch_fn)
    local now = os.time()

    if cache.releases and cache.timestamp and (now - cache.timestamp) < cache_ttl then
        return cache.releases
    end

    local releases = (fetch_fn or function()
        return default_version
    end)()
    cache.releases = Utils.semver.sort(releases)
    cache.timestamp = now

    return releases
end

--- @param ctx BackendListVersionsCtx
--- @return BackendListVersionsResult
function PLUGIN:BackendListVersions(ctx)
    require("ncs")
    if not NCS[ctx.tool] then
        return {}
    end
    return { versions = get_releases(NCS[ctx.tool].list_versions) }
end
