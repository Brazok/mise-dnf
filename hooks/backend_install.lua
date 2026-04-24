--- Symlinks files matching `pattern` from src/ directly into dst/ (flat, no recursion).
local function link_flat(cmd, src, dst, pattern)
    cmd.exec(string.format(
        "[ -d '%s' ] && mkdir -p '%s' && find '%s' -maxdepth 1 -name '%s' -type f -exec ln -sf '{}' '%s/' \\; || true",
        src, dst, src, pattern, dst
    ))
end

--- Symlinks every file from src/ into dst/, recreating subdirectory structure.
local function link_tree(cmd, src, dst)
    cmd.exec(string.format([[
        [ -d '%s' ] && find '%s' -type f | while IFS= read -r f; do
            rel="${f#'%s'/}"
            dest_dir='%s/'"$(dirname "$rel")"
            mkdir -p "$dest_dir"
            ln -sf "$f" "$dest_dir/"
        done || true
    ]], src, src, src, dst))
end

--- Downloads and installs an RPM package into install_path without sudo.
--- Uses dnf download + rpm2cpio + cpio, then symlinks XDG resources into ~/.local/share.
--- @param ctx BackendInstallCtx
--- @return BackendInstallResult
function PLUGIN:BackendInstall(ctx)
    local cmd = require("cmd")
    local env = require("env")

    local tool = ctx.tool
    local version = ctx.version
    local install_path = ctx.install_path

    local pkg_spec = (version == "latest") and tool or (tool .. "-" .. version)
    local tmp_dir = install_path .. "/.tmp_rpm"

    cmd.exec("mkdir -p '" .. tmp_dir .. "'")
    cmd.exec("mkdir -p '" .. install_path .. "'")

    -- Download the RPM(s). --resolve pulls in direct dependencies.
    local dl_out = cmd.exec("dnf download --resolve --destdir='" .. tmp_dir .. "' " .. pkg_spec .. " 2>&1")
    if not dl_out then
        error("dnf download failed for package: " .. pkg_spec)
    end

    -- Extract every downloaded RPM into install_path, preserving directory layout.
    -- RPMs extract to ./usr/bin, ./usr/lib64, ./usr/share, etc.
    cmd.exec(string.format(
        "cd '%s' && for rpm in '%s'/*.rpm; do rpm2cpio \"$rpm\" | cpio -idmu 2>/dev/null; done",
        install_path,
        tmp_dir
    ))

    cmd.exec("rm -rf '" .. tmp_dir .. "'")

    -- Symlink XDG resources into ~/.local/share so the desktop environment
    -- and shells can discover them without manual configuration.
    local home = env.getenv("HOME")
    if home then
        local share_src = install_path .. "/usr/share"
        local share_dst = home .. "/.local/share"
        link_flat(cmd, share_src .. "/applications",               share_dst .. "/applications",               "*.desktop")
        link_flat(cmd, share_src .. "/bash-completion/completions", share_dst .. "/bash-completion/completions", "*")
        link_flat(cmd, share_src .. "/zsh/site-functions",         share_dst .. "/zsh/site-functions",         "*")
        link_flat(cmd, share_src .. "/fish/vendor_completions.d",  share_dst .. "/fish/vendor_completions.d",  "*.fish")
        link_tree(cmd, share_src .. "/icons",                      share_dst .. "/icons")
        link_tree(cmd, share_src .. "/pixmaps",                    share_dst .. "/pixmaps")
    end

    return {}
end
