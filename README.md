# vfox-ncs

A [mise](https://mise.jdx.dev/) backend plugin for the [nRF Connect SDK (NCS)](https://developer.nordicsemi.com/nRF_Connect_SDK/doc/latest/nrf/index.html) toolchain.

## What it does

### nrfutil

**Downloads and installs the nrfutil launcher and core module from Nordic's Artifactory**

The nrfutil tool is Nordic's command-line utility for managing toolchains, flashing firmware, and more. This plugin handles:
1. Downloading the platform-specific launcher binary
2. Installing a pinned core module version
3. Configuring the Nordic package index

### NCS Toolchain

**Installs NCS toolchains via `nrfutil toolchain-manager`**

The NCS toolchain bundles everything needed to build nRF Connect SDK applications: GCC cross-compiler, CMake, Ninja, Python, and west. This plugin installs toolchains to platform-appropriate locations and exports the correct environment variables.

### West via uv script

**Creates a shim of west using uv scripts with inline metadata for dependency management**

No more `.venv` required to build with west. The uv script handles dependency management in the background. **You need `uv` installed and in your PATH.**

The west shim:
- Detects NCS workspace structure (both `nrf/` and `zephyr/` requirements)
- Clears Python env vars (`VIRTUAL_ENV`, `PYTHONPATH`, `PYTHONHOME`) to avoid conflicts with the NCS toolchain's bundled Python
- Manages its own isolated Python environment via uv

You can read more about uv scripts and [Python's inline script metadata spec](https://packaging.python.org/en/latest/specifications/inline-script-metadata/#inline-script-metadata).

## Usage

```bash
# Install the plugin
mise plugin install ncs https://github.com/ale-alfaro/vfox-ncs

# List available versions
mise ls-remote ncs:nrfutil
mise ls-remote ncs:toolchain

# Install tools
mise install ncs:nrfutil@8.1.1
mise install ncs:toolchain@3.2.1
mise install ncs:west@3.2.1

# Use on demand
mise x ncs:west@3.2.1 -- west build -p -b nrf52840dk/nrf52840 app

# Use as defaults
mise use ncs:nrfutil@8.1.1
mise use ncs:toolchain@3.2.1
mise use ncs:west@3.2.1
west build -p -b nrf52840dk/nrf52840 app
```

## Environment variables

| Variable                   | Value                                                        |
| -------------------------- | ------------------------------------------------------------ |
| `PATH` (nrfutil)           | adds `<install>/bin` (nrfutil binary)                        |
| `NRFUTIL_HOME`             | `<install>/home` (nrfutil config and cache)                  |
| `PATH` (toolchain)         | adds toolchain bin directories (from `nrfutil toolchain-manager env`) |
| `ZEPHYR_TOOLCHAIN_VARIANT` | `zephyr`                                                     |
| `ZEPHYR_SDK_INSTALL_DIR`   | Zephyr SDK directory within the NCS toolchain                |
| `LD_LIBRARY_PATH`          | `<install>/usr/local/lib` (toolchain shared libraries)       |
| `PATH` (west)              | adds west shim directory                                     |
| `VIRTUAL_ENV`              | cleared (empty) to avoid Python conflicts                    |
| `PYTHONPATH`               | cleared (empty) to avoid Python conflicts                    |
| `PYTHONHOME`               | cleared (empty) to avoid Python conflicts                    |

## Development

### Local testing

```bash
mise plugin link --force ncs-test .
mise cache clear
mise install ncs-test:nrfutil@8.1.1
mise install ncs-test:toolchain@3.2.1
mise install ncs-test:west@3.2.1
mise x ncs-test:west@3.2.1 -- west --version
```

### Code quality

```bash
mise run lint       # Run all linters
mise run format     # Format Lua code
mise run test       # Smoke tests
mise run ci         # Full CI suite (lint + smoke + integration)
```

### Debugging

```bash
mise plugin link --force ncs-test .
mise cache clear
MISE_DEBUG=1 mise install ncs-test:west@3.2.1
```

## Files

- `metadata.lua` - Plugin metadata
- `hooks/backend_list_versions.lua` - Lists available versions (nrfutil from Artifactory, toolchain/west via nrfutil toolchain-manager)
- `hooks/backend_install.lua` - Downloads and installs tools
- `hooks/backend_exec_env.lua` - Configures PATH and environment variables
- `lib/nrfutil.lua` - nrfutil launcher and core module management
- `lib/toolchain.lua` - NCS toolchain installation and environment setup
- `lib/west.lua` - West shim installation and Python env var isolation
- `lib/platform.lua` - Platform detection and Nordic Artifactory URLs
- `lib/utils.lua` - Logging and validation utilities
- `lib/pathlib.lua` - Path manipulation utilities
- `lib/shell_exec.lua` - Safe command execution wrapper
- `lib/inspect.lua` - Table pretty-printing for debug output
- `bin/west_shim.py` - uv-managed west script
- `mise-tasks/smoke-test` - Quick install and verify test
- `mise-tasks/integration-test` - Full NCS build test

## License

MIT
