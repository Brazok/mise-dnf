--- Resolves the actual RPM package name for a given tool spec.
--- Cascade: exact name → virtual provides → file provides in common bin dirs.
local function resolve_pkg_name(tool, arch)
    return string.format([[
        arch=%q
        name=%q
        # 1. Exact package name
        pkg=$(dnf repoquery --quiet --qf '%%{name}\n' --arch "$arch" "$name" 2>/dev/null | sort -u | head -1)
        # 2. Virtual provides (e.g. Provides: ykman-gui → yubikey-manager-qt)
        [ -z "$pkg" ] && pkg=$(dnf repoquery --quiet --qf '%%{name}\n' --arch "$arch" --whatprovides "$name" 2>/dev/null | grep -v '^$\|No matches' | sort -u | head -1)
        # 3. File provides — loop over common bin directories
        #    --whatprovides /path is more robust; --file /path as fallback
        if [ -z "$pkg" ]; then
            for bindir in /usr/bin /usr/sbin /bin /sbin /usr/local/bin; do
                pkg=$(dnf repoquery --quiet --qf '%%{name}\n' --arch "$arch" --whatprovides "$bindir/$name" 2>/dev/null | grep -v '^$' | sort -u | head -1)
                [ -z "$pkg" ] && pkg=$(dnf repoquery --quiet --qf '%%{name}\n' --arch "$arch" --file "$bindir/$name" 2>/dev/null | sort -u | head -1)
                [ -n "$pkg" ] && break
            done
        fi
        printf '%%s' "$pkg"
    ]], arch, tool)
end

--- Maps mise arch to RPM arch string.
local function rpm_arch()
    local map = { amd64 = "x86_64", arm64 = "aarch64", ["386"] = "i686" }
    return map[RUNTIME.archType] or "x86_64"
end

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
    local strings = require("strings")

    local tool = ctx.tool
    local version = ctx.version
    local install_path = ctx.install_path

    -- Resolve the actual RPM package name so aliases like ykman-gui → yubikey-manager-qt work.
    local arch = rpm_arch()
    local resolved = strings.trim_space(cmd.exec(resolve_pkg_name(tool, arch)) or "")
    if resolved == "" then
        error(
            "No RPM package found for '" .. tool .. "'.\n"
            .. "Tip: run 'dnf search " .. tool .. "' to find the exact package name."
        )
    end

    local pkg_spec = (version == "latest") and resolved or (resolved .. "-" .. version)
    local tmp_dir = install_path .. "/.tmp_rpm"

    cmd.exec("mkdir -p '" .. tmp_dir .. "'")
    cmd.exec("mkdir -p '" .. install_path .. "'")

    -- Download the RPM(s). --resolve pulls in direct dependencies.
    local dl_out = cmd.exec("dnf download --resolve --destdir='" .. tmp_dir .. "' '" .. pkg_spec .. "' 2>&1")
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
    local home = os.getenv("HOME")
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
