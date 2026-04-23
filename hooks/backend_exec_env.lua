--- Sets environment variables for a tool installed via the dnf backend
--- RPMs extract to usr/bin, usr/lib64, etc. under install_path
--- @param ctx BackendExecEnvCtx
--- @return BackendExecEnvResult
function PLUGIN:BackendExecEnv(ctx)
    local p = ctx.install_path
    return {
        env_vars = {
            { key = "PATH", value = p .. "/usr/bin:" .. p .. "/usr/local/bin:" .. p .. "/bin" },
            { key = "LD_LIBRARY_PATH", value = p .. "/usr/lib64:" .. p .. "/usr/lib:" .. p .. "/usr/lib/x86_64-linux-gnu" },
            { key = "MANPATH", value = p .. "/usr/share/man" },
        },
    }
end
