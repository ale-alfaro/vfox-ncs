--- Lists available versions for a tool (nrfutil or toolchain).
--- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendlistversions

--- @param ctx BackendListVersionsCtx
--- @return BackendListVersionsResult
function PLUGIN:BackendListVersions(ctx)
    require("utils")
    if ctx.tool == "nrfutil" then
        local nrfutil = require("nrfutil")
        return { versions = nrfutil.list_versions() }
    elseif ctx.tool == "toolchain" then
        local toolchain = require("toolchain")
        return { versions = toolchain.list_versions() }
    elseif ctx.tool == "west" then
        local west = require("west")
        return { versions = west.list_versions() }
    else
        error("Unknown tool: " .. tostring(ctx.tool))
    end
end
