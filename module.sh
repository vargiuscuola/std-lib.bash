#!/usr/bin/env bash
#github-action genshdoc

# @file module.sh
# @brief Include shell libraries modules
# @show-internal
shopt -s expand_aliases
source "$(dirname "${BASH_SOURCE[0]}")/package.sh"

# @internal
# @description Return normalized absolute path
# @alias module.abs-path_
# @arg $1 String Path
# @return Normalized absolute path
# @example
#   $ module.abs-path_ "../lib"
#      return> /var/lib
:module_abs-path_() {
	local path="$1"
	if [[ -d "$path" ]]; then
		pushd "$path" &>/dev/null
		declare -g __="$PWD"
		popd &>/dev/null
	else
		pushd "${path%/*}" &>/dev/null
		declare -g __="$PWD/${path##*/}"
		popd &>/dev/null
	fi
}
alias :module.abs-path_=":module_abs-path_"

# @global _MODULE__IMPORTED_MODULES Array Imported modules
:module.abs-path_ "${BASH_SOURCE[0]}" && _MODULE__IMPORTED_MODULES=("$__")
:module.abs-path_ "${BASH_SOURCE[-1]}" && _MODULE__IMPORTED_MODULES+=("$__")

# @description Import module
# @alias module.import
# @arg $1 String Module path. Shell extension `.sh` can be omitted
# @exitcodes Standard
# @example
#   $ module.import "github/vargiuscuola/std-lib.bash/main"
module_import() {
	local module="$1"
	:module.abs-path_ "$(dirname "${BASH_SOURCE[0]}")" && local path="$__"
	:module.abs-path_ "$(dirname "${BASH_SOURCE[1]}")" && local caller_path="$__"
	local module_path
	
	[[ "$module" =~ \.sh$ ]] || module="${module}.sh"
	
	# try absolute
	if [[ $module == /* && -e "$module" ]]; then
		module_path="$module"
	# try relative to caller
	elif [[ -f "${caller_path}/${module}" ]]; then
		module_path="${caller_path}/${module}"
	# try current package path
	elif [[ -f "${path}/${module}.sh" ]]; then
		module_path="${path}/${module}.sh"
	# try system wide lib dir
	else
		package.get-lib-dir_
		[[ -f "$__/${module}" ]] && module_path="$__/${module}"
	fi
	[[ -z "$module_path" ]] && { echo "[ERROR] failed to import \"$module\"" ; return 1 ; }
	# normalize module_path
	:module.abs-path_  "$module_path" && module_path="$__"
	
	# check if module already loaded
	local loaded_module
	for loaded_module in "${_MODULE__IMPORTED_MODULES[@]}"; do
		[[ "$loaded_module" == "$module_path" ]] && return 0
	done
	
	_MODULE__IMPORTED_MODULES+=("$module_path")
	source "$module_path" || return 1
}
alias module.import="module_import"
