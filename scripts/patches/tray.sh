#===============================================================================
# Tray-related patches: menu handler mutex/DBus delay, icon theme selection,
# and menuBarEnabled default.
#
# Sourced by: build.sh
# Sourced globals: project_root, electron_var, electron_var_re
# Modifies globals: (none)
#===============================================================================

patch_tray_menu_handler() {
	echo 'Patching tray menu handler...'
	local index_js='app.asar.contents/.vite/build/index.js'

	local tray_func tray_var first_const
	tray_func=$(grep -oP \
		'on\("menuBarEnabled",\(\)=>\{\K\w+(?=\(\)\})' "$index_js")
	if [[ -z $tray_func ]]; then
		echo 'Failed to extract tray menu function name' >&2
		cd "$project_root" || exit 1
		exit 1
	fi
	echo "  Found tray function: $tray_func"

	tray_var=$(grep -oP \
		"\}\);let \K\w+(?==null;(?:async )?function ${tray_func})" \
		"$index_js")
	if [[ -z $tray_var ]]; then
		echo 'Failed to extract tray variable name' >&2
		cd "$project_root" || exit 1
		exit 1
	fi
	echo "  Found tray variable: $tray_var"

	sed -i "s/function ${tray_func}(){/async function ${tray_func}(){/g" \
		"$index_js"

	first_const=$(grep -oP \
		"async function ${tray_func}\(\)\{.*?const \K\w+(?==)" \
		"$index_js" | head -1)
	if [[ -z $first_const ]]; then
		echo 'Failed to extract first const in function' >&2
		cd "$project_root" || exit 1
		exit 1
	fi
	echo "  Found first const variable: $first_const"

	# Add mutex guard to prevent concurrent tray rebuilds
	if ! grep -q "${tray_func}._running" "$index_js"; then
		sed -i "s/async function ${tray_func}(){/async function ${tray_func}(){if(${tray_func}._running)return;${tray_func}._running=true;setTimeout(()=>${tray_func}._running=false,1500);/g" \
			"$index_js"
		echo "  Added mutex guard to ${tray_func}()"
	fi

	# Add DBus cleanup delay after tray destroy
	if ! grep -q "await new Promise.*setTimeout" "$index_js" \
		| grep -q "$tray_var"; then
		sed -i "s/${tray_var}\&\&(${tray_var}\.destroy(),${tray_var}=null)/${tray_var}\&\&(${tray_var}.destroy(),${tray_var}=null,await new Promise(r=>setTimeout(r,250)))/g" \
			"$index_js"
		echo "  Added DBus cleanup delay after $tray_var.destroy()"
	fi

	echo 'Tray menu handler patched'
	echo '##############################################################'

	# Skip tray updates during startup (3 second window)
	echo 'Patching nativeTheme handler for startup delay...'
	if ! grep -q '_trayStartTime' "$index_js"; then
		sed -i -E \
			"s/(${electron_var_re}\.nativeTheme\.on\(\s*\"updated\"\s*,\s*\(\)\s*=>\s*\{)/let _trayStartTime=Date.now();\1/g" \
			"$index_js"
		sed -i -E \
			"s/\((\w+\([^)]*\))\s*,\s*${tray_func}\(\)\s*,/(\1,Date.now()-_trayStartTime>3e3\&\&${tray_func}(),/g" \
			"$index_js"
		echo '  Added startup delay check (3 second window)'
	fi
	echo '##############################################################'
}

patch_tray_icon_selection() {
	echo 'Patching tray icon selection for Linux visibility...'
	local index_js='app.asar.contents/.vite/build/index.js'
	local dark_check="${electron_var_re}.nativeTheme.shouldUseDarkColors"

	if grep -qP ':\$?\w+="TrayIconTemplate\.png"' "$index_js"; then
		sed -i -E \
			"s/:(\\\$?\w+)=\"TrayIconTemplate\.png\"/:\1=${dark_check}?\"TrayIconTemplate-Dark.png\":\"TrayIconTemplate.png\"/g" \
			"$index_js"
		echo 'Patched tray icon selection for Linux theme support'
	else
		echo 'Tray icon selection pattern not found or already patched'
	fi
	echo '##############################################################'
}

patch_menu_bar_default() {
	echo 'Patching menuBarEnabled to default to true when unset...'
	local index_js='app.asar.contents/.vite/build/index.js'

	local menu_bar_var
	menu_bar_var=$(grep -oP \
		'const \K\w+(?=\s*=\s*\w+\("menuBarEnabled"\))' \
		"$index_js" | head -1)
	if [[ -z $menu_bar_var ]]; then
		echo '  Could not extract menuBarEnabled variable name'
		echo '##############################################################'
		return
	fi
	echo "  Found menuBarEnabled variable: $menu_bar_var"

	# Change !!var to var!==false so undefined defaults to true
	if grep -qP ",\s*!!${menu_bar_var}\s*\)" "$index_js"; then
		sed -i -E \
			"s/,\s*!!${menu_bar_var}\s*\)/,${menu_bar_var}!==false)/g" \
			"$index_js"
		echo '  Patched menuBarEnabled to default to true'
	else
		echo '  menuBarEnabled pattern not found or already patched'
	fi
	echo '##############################################################'
}
