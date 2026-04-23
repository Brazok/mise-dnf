--- Lists available versions for an RPM package via dnf repoquery
--- @param ctx BackendListVersionsCtx
--- @return BackendListVersionsResult
function PLUGIN:BackendListVersions(ctx)
    local cmd = require("cmd")
    local strings = require("strings")

    local tool = ctx.tool
    if not tool or tool == "" then
        error("Tool name cannot be empty")
    end

    local result = cmd.exec(
        "dnf repoquery --quiet --qf '%{version}-%{release}\\n' " .. tool .. " 2>/dev/null | sort -V -u"
    )

    if not result or strings.trim_space(result) == "" then
        error("No versions found for package: " .. tool)
    end

    local versions = {}
    for line in result:gmatch("[^\r\n]+") do
        local v = strings.trim_space(line)
        if v ~= "" then
            table.insert(versions, v)
        end
    end

    if #versions == 0 then
        error("No versions parsed for package: " .. tool)
    end

    return { versions = versions }
end
