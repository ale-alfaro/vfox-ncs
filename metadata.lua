-- metadata.lua
-- Plugin metadata and configuration
-- Documentation: https://mise.jdx.dev/backend-plugin-development.html

PLUGIN = { -- luacheck: ignore
    name = "ncs",
    version = "0.1.0",
    description = "A mise backend plugin for Nordic Connect SDK (NCS) toolchains via nrfutil",
    author = "ale-alfaro",
    notes = {
        "Install the Nordic Connect nrfutil tool, toolchains and west shim using uv",
    },
    minRuntimeVersion = "0.3.0",
    license = "MIT",
    homepage = "https://github.com/ale-alfaro/vfox-ncs",
}
