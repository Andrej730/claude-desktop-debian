#===============================================================================
# Cowork runtime resources: plugin shim script and architecture-specific
# smol-bin VHDX for KVM guest SDK access.
#
# Sourced by: build.sh
# Sourced globals:
#   claude_extract_dir, electron_resources_dest, architecture
# Modifies globals: (none)
#===============================================================================

copy_cowork_resources() {
	section_header 'Cowork Resources'

	local resources_src="$claude_extract_dir/lib/net45/resources"

	# Copy cowork-plugin-shim.sh (used by app for MCP plugin sandboxing)
	local shim_src="$resources_src/cowork-plugin-shim.sh"
	if [[ -f $shim_src ]]; then
		cp "$shim_src" "$electron_resources_dest/cowork-plugin-shim.sh"
		chmod +x "$electron_resources_dest/cowork-plugin-shim.sh"
		echo "Copied cowork-plugin-shim.sh"
	else
		echo "Warning: cowork-plugin-shim.sh not found at $shim_src"
	fi

	# Copy smol-bin VHDX (contains SDK binaries for KVM guest VM).
	# The app copies this from resources to the bundle dir at startup
	# (win32-gated; our index.js patch extends this to Linux).
	# App looks for smol-bin.{arch}.vhdx where arch is x64 or arm64.
	local smol_arch='x64'
	if [[ $architecture == 'arm64' ]]; then
		smol_arch='arm64'
	fi
	local smol_vhdx="$resources_src/smol-bin.${smol_arch}.vhdx"
	if [[ -f $smol_vhdx ]]; then
		cp "$smol_vhdx" \
			"$electron_resources_dest/smol-bin.${smol_arch}.vhdx"
		echo "Copied smol-bin.${smol_arch}.vhdx"
	else
		echo "Warning: smol-bin VHDX not found at $smol_vhdx"
		echo "KVM Cowork will rely on virtiofs for SDK access"
	fi

	section_footer 'Cowork Resources'
}
