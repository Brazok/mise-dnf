--- Sets environment variables for a tool installed via the dnf backend.
--- RPMs extract to usr/bin, usr/lib64, usr/share, etc. under install_path.
--- @param ctx BackendExecEnvCtx
--- @return BackendExecEnvResult
function PLUGIN:BackendExecEnv(ctx)
    local p = ctx.install_path
    return {
        env_vars = {
            -- Binaries extracted from the RPM
            { key = "PATH", value = p .. "/usr/bin:" .. p .. "/usr/local/bin:" .. p .. "/bin" },
            -- Shared libraries
            { key = "LD_LIBRARY_PATH", value = p .. "/usr/lib64:" .. p .. "/usr/lib:" .. p .. "/usr/lib/x86_64-linux-gnu" },
            -- Man pages
            { key = "MANPATH", value = p .. "/usr/share/man" },
            -- Runtime data (icons, locale, schemas…) for apps that look up XDG_DATA_DIRS at runtime
            { key = "XDG_DATA_DIRS", value = p .. "/usr/share" },
            -- Zsh completions fpath (only active when the tool is exec'd via mise, not globally)
            { key = "FPATH", value = p .. "/usr/share/zsh/site-functions" },
        },
    }
end
