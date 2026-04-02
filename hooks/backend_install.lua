--- Installs an NCS toolchain version using nrfutil toolchain-manager.
--- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendinstall

--- @param ctx BackendInstallCtx
--- @return BackendInstallResult
function PLUGIN:BackendInstall(ctx)
    local log = require("log")
    local ncs = require("ncs")

    local version = ctx.version
    local install_path = ctx.install_path

    log.info("Installing NCS toolchain " .. version .. " via nrfutil toolchain-manager")
    ncs.install_toolchain(version, install_path)
    log.info("NCS toolchain " .. version .. " installed successfully")

    return {}
end
