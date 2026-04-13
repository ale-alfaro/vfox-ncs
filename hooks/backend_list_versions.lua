--- Lists available versions for a tool (nrfutil or toolchain).
--- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendlistversions

--- @param ctx BackendListVersionsCtx
--- @return BackendListVersionsResult
function PLUGIN:BackendListVersions(ctx)
    require("ncs")
    local tool = NCS[ctx.tool]
    if not tool then
        Utils.err("Could not find tool : ", { tool = ctx.tool })
        return {}
    end
    if not tool.list_versions then
        Utils.wrn("tool versioning not supported: ", { tool = tool, ctx = ctx })
        return { versions = { "3.2.1", "3.0.0", "2.7.0" } }
    end
    local versions = tool.list_versions(ctx)
    Utils.inf("Tool Versions: ", { tool = tool, versions = versions })
    return { versions = versions }
end
