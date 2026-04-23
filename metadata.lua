-- metadata.lua
-- Plugin metadata and configuration
-- Documentation: https://mise.jdx.dev/tool-plugin-development.html#metadata-lua

PLUGIN = { -- luacheck: ignore
    -- Required: Tool name (lowercase, no spaces)
    name = "mise-dnf",

    -- Required: Plugin version (not the tool version)
    version = "1.0.0",

    -- Required: Brief description of the tool
    description = "Install RPM packages into user-space via dnf download + rpm2cpio",

    -- Required: Plugin author/maintainer
    author = "brazok",

    -- Optional: Repository URL for plugin updates
    updateUrl = "https://github.com/brazok/mise-dnf",

    -- Optional: Minimum mise runtime version required
    minRuntimeVersion = "0.2.0",

    -- Optional: Legacy version files this plugin can parse
    -- legacyFilenames = {
    --     ".mise-dnf-version",
    --     ".mise-dnfrc"
    -- }
}
