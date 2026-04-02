--- Returns a list of available NCS toolchain versions via nrfutil toolchain-manager
--- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendlistversions

local cache = {} ---@type {versions: string[], timestamp: number}
local cache_ttl = 12 * 60 * 60 -- 12 hours in seconds

local function get_versions()
    local ncs = require("ncs")
    local now = os.time()

    if cache.versions and cache.timestamp and (now - cache.timestamp) < cache_ttl then
        return cache.versions
    end

    local versions = ncs.search_versions()
    cache.versions = versions
    cache.timestamp = now

    return versions
end

--- @param ctx BackendListVersionsCtx
--- @return BackendListVersionsResult
function PLUGIN:BackendListVersions(ctx)
    local versions = get_versions()
    local semver = require("semver")

    return { versions = semver.sort(versions) }
end
