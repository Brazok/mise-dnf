--- Downloads and installs an RPM package into install_path without sudo
--- Uses dnf download + rpm2cpio + cpio to extract files into user-space
--- @param ctx BackendInstallCtx
--- @return BackendInstallResult
function PLUGIN:BackendInstall(ctx)
    local cmd = require("cmd")

    local tool = ctx.tool
    local version = ctx.version
    local install_path = ctx.install_path

    local pkg_spec = (version == "latest") and tool or (tool .. "-" .. version)
    local tmp_dir = install_path .. "/.tmp_rpm"

    cmd.exec("mkdir -p " .. tmp_dir)
    cmd.exec("mkdir -p " .. install_path)

    -- Download the RPM(s). --resolve pulls in direct dependencies.
    local dl_out = cmd.exec("dnf download --resolve --destdir=" .. tmp_dir .. " " .. pkg_spec .. " 2>&1")
    if not dl_out then
        error("dnf download failed for package: " .. pkg_spec)
    end

    -- Extract every downloaded RPM into install_path, preserving directory layout.
    -- RPMs typically extract to ./usr/bin, ./usr/lib64, etc.
    local extract_cmd = string.format(
        "cd %s && for rpm in %s/*.rpm; do rpm2cpio \"$rpm\" | cpio -idmu 2>/dev/null; done",
        install_path,
        tmp_dir
    )
    cmd.exec(extract_cmd)

    cmd.exec("rm -rf " .. tmp_dir)

    return {}
end
