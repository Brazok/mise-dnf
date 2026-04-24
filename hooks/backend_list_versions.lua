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

--- Lists available versions for an RPM package via dnf repoquery.
--- @param ctx BackendListVersionsCtx
--- @return BackendListVersionsResult
function PLUGIN:BackendListVersions(ctx)
    local cmd = require("cmd")
    local strings = require("strings")

    local tool = ctx.tool
    if not tool or tool == "" then
        error("Tool name cannot be empty")
    end

    local arch = rpm_arch()

    -- Resolve the actual RPM package name (handles Provides and file provides).
    local resolved = strings.trim_space(cmd.exec(resolve_pkg_name(tool, arch)) or "")
    if resolved == "" then
        error(
            "No RPM package found for '" .. tool .. "'.\n"
            .. "Tip: run 'dnf search " .. tool .. "' to find the exact package name."
        )
    end

    local result = cmd.exec(
        "dnf repoquery --quiet --qf '%{version}-%{release}\\n'"
        .. " --arch '" .. arch .. "'"
        .. " '" .. resolved .. "' 2>/dev/null | sort -V -u"
    )

    if not result or strings.trim_space(result) == "" then
        error("No versions found for package: " .. resolved)
    end

    local versions = {}
    for line in result:gmatch("[^\r\n]+") do
        local v = strings.trim_space(line)
        if v ~= "" then
            table.insert(versions, v)
        end
    end

    return { versions = versions }
end
