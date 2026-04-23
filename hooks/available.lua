--- Not used by the dnf backend. Use 'mise use dnf:<package>' instead.
function PLUGIN:Available(_)
    error("Use 'mise use dnf:<package-name>' to install RPM packages. Example: mise use dnf:curl")
end
