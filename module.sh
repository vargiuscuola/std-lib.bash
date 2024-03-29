#!/usr/bin/env bash
#github-action genshdoc

# if already sourced, return
[ -v _MODULE__LOADED ] && return || _MODULE__LOADED=True

# @file module.sh
# @brief Include shell libraries modules
# @description Allow loading of libraries modules which simply are script files containing libraries of functions organized in classes.  
#   A module can contain one or more classes, where a class is a set of homogeneous functions with names prefixed with the name of the class.  
#   For example, the module [main](https://github.com/vargiuscuola/std-lib.bash/blob/master/REFERENCE-main.md) contains classes as `array`, `hash` etc.,
#   with functions of class `array` starting with the prefix `array_`.  
#   For a module containing only one class, the name of the class is the name of the module, as in the module [trap](https://github.com/vargiuscuola/std-lib.bash/blob/master/REFERENCE-trap.md)
#   where all functions start with `trap_`.
#   
#   Use the command `module.doc <function_name>` to see the documentation for a function (see an [example](https://github.com/vargiuscuola/std-lib.bash#examples))
# @show-internal

shopt -s expand_aliases
source "$(dirname "${BASH_SOURCE[0]}")/package.sh"


############
#
# GLOBALS
#

# @global _MODULE__CLASS_TO_PATH Hash Associate each class defined in modules to the script's path containing it: it is set by the `module_import` function or his alias `module.import`
declare -gA _MODULE__CLASS_TO_PATH
# @global _MODULE__SHDOC_DIR String Cache the path of the package github.com/vargiuscuola/shdoc (used by the function `module_doc` and his alias `module.doc`


############
#
# MODULE FUNCTIONS
#
############

# alias for printing an error message
alias errmsg='>&2 echo -e "\\e[1;31m[ERROR]\\e[0m \\e[0;33m${FUNCNAME[0]}()\\e[0m#"'

# @internal
# @description Return normalized absolute path.
# @alias module.abs-path_
# @arg $1 String Path
# @return Normalized absolute path
# @example
#   $ cd /var/cache
#   $ module.abs-path_ "../lib"
#   # return __="/var/lib"
:module_abs-path_() {
  (( $# != 1 )) && { errmsg "Wrong number of arguments: $# instead of 1" ; return 1 ; }      # validate the number of arguments
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
declare -ga _MODULE__IMPORTED_MODULES
:module.abs-path_ "${BASH_SOURCE[0]}" && _MODULE__IMPORTED_MODULES=("$__")
:module.abs-path_ "${BASH_SOURCE[-1]}" && _MODULE__IMPORTED_MODULES+=("$__")

# @description Import a module, i.e. a shell library path which is sourced by the current function.  
#   The provided library path can be relative or absolute. If it's relative, the library will be searched in the following paths:
#   * calling path
#   * current path (where the current script reside)
#   * default library path (/lib/sh in Linux or /c/linux-lib/sh in Windows)
#   If the requested module is correctly `source`-ed, its path is added to the list of imported modules stored in global variable `_MODULE__IMPORTED_MODULES`.
#   Also, the classes defined inside the module are linked to the path of the module through the associative array `_MODULE__CLASS_TO_PATH`: the classes contained inside a module are declared
#   inside the module itself through the array _${capitalized module name}__CLASSES. If this variable is not defined, is expected that only one class is defined with the same name of the module.  
#   For example, the module `github/vargiuscuola/std-lib.bash/args`, which doesn't declare the variable `_ARGS_CLASSES`, is supposed to define only one class named `args`.  
#   The concept of class in this context refers to an homogeneous set of functions all starting with the same prefix `<class name>_` as in `args_check-number` and `args_parse`.
# @alias module.import
# @arg $1 String Module path. Shell extension `.sh` can be omitted
# @opt -f|--force Force the import of the module also if already imported
# @exitcodes Standard
# @example
#   $ module.import github/vargiuscuola/std-lib.bash/main
#   $ module.import --force args
module_import() {
  [[ "$1" = -f || "$1" = --force ]] && { local __module__is_force=1 ; shift ; }            # check the `-f|--force` option
  (( $# != 1 )) && { errmsg "Wrong number of arguments: $# instead of 1" ; return 1 ; }    # validate the number of arguments
  local module="$1" module_name="${1##*/}"
  module_name="${module_name%.sh}"
  :module.abs-path_ "$(dirname "${BASH_SOURCE[0]}")" && local path="$__"
  :module.abs-path_ "$(dirname "${BASH_SOURCE[1]}")" && local caller_path="$__"
  local module_path
  
  [[ "$module" =~ \.sh$ ]] || module="${module}.sh"
  
  while :; do
    [[ $module == /* && -e "$module" ]] && { module_path="$module" ; break ; }            # try absolute path
    [[ -f "${caller_path}/${module}" ]] && { module_path="${caller_path}/${module}" ; break ; }    # try relative to caller
    [[ -f "${path}/${module}" ]] && { module_path="${path}/${module}" ; break ; }        # try current path
    package.get-lib-dir_
    [[ -f "$__/${module}" ]] && module_path="$__/${module}"                      # try system wide lib path
    break
  done
  [[ -z "$module_path" ]] && { errmsg "Failed to import \"$module\"" ; return 1 ; }
  # normalize module_path
  :module.abs-path_  "$module_path" && module_path="$__"
  
  # check if module already loaded
  if [ -v __module__is_force ]; then
    unset "_${module_name^^}__LOADED"
  else
    local loaded_module
    for loaded_module in "${_MODULE__IMPORTED_MODULES[@]}"; do
      [ "$loaded_module" == "$module_path" ] && return 0
    done
  fi

  _MODULE__IMPORTED_MODULES+=("$module_path")
  source "$module_path" || return 1
  declare -n aref="_${module_name^^}__CLASSES"
  local class
  for class in "${aref[@]:-${module_name}}"; do
    _MODULE__CLASS_TO_PATH[$class]="$module_path"
  done
}
alias module.import="module_import"

# @description Check whether a module has been imported.
# @alias module.is-imported
# @arg $1 String Module name
# @exitcodes 0 if module is imported, 1 otherwise.
module_is-imported() {
  [ -v _${1^^}__LOADED ]
}
alias module.is-imported="module_is-imported"

# @description Return the path of the provided class.
# @alias module.get-class-path_
# @arg $1 String Class name
# @return Path of the file where the class is defined (see the [Overview](#overview) for an explanation of the concept of class in this context).
# @example
#   $ cd /var/cache
#   $ module.abs-path_ "../lib"
#   # return __="/var/lib"
module_get-class-path_() {
  (( $# != 1 )) && { errmsg "Wrong number of arguments: $# instead of 1" ; return 1 ; }      # validate the number of arguments
  declare -g __="${_MODULE__CLASS_TO_PATH[$1]}"
}
alias module.get-class-path_="module_get-class-path_"


# @description List the functions of the provided class, which must be already loaded with `module.import` or at least `source`-ed.
# @alias module.list-class-functions
# @arg $1 String Class name
# @stdout List of functions which are part of the provided class
# @example
#   $ module.list-class-functions args
#   args.check-number
#   args.parse
#   args_check-number
#   args_parse
#   args_to_str_
module_list-class-functions() {
  (( $# != 1 )) && { errmsg "Wrong number of arguments: $# instead of 1" ; return 1 ; }      # validate the number of arguments
  echo >&2 "# Functions"
  declare -F | sed -E 's/^declare -[^[:space:]]+ //' | grep -- "^${1}_"
  echo >&2 "# Aliases"
  alias | sed -E 's/^alias // ; s/=.*//' | grep -- "^${1}\\."
}
alias module.list-class-functions="module_list-class-functions"


# @description List the classes defined inside a module.
# @alias module.list-classes
# @arg $1 String Module name.
# @stdout List of classes defined in the provided module
# @example
#   $ module.list-classes main
#   hash
#   main
#   collection
#   datetime
#   list
#   shopt
#   array
module_list-classes() {
  (( $# != 1 )) && { errmsg "Wrong number of arguments: $# instead of 1" ; return 1 ; }      # validate the number of arguments
  printf "%s\n" "${_MAIN__CLASSES[@]}"
}
alias module.list-classes="module_list-classes"

# @description Print the documentation for the provided function name.
# @alias module.doc
# @arg $1 String Function or alias name
# @stdout Print the documentation for the function
module_doc() {
  (( $# != 1 )) && { errmsg "Wrong number of arguments: $# instead of 1" ; return 1 ; }      # validate the number of arguments
  if [ -z "$_MODULE__SHDOC_DIR" ]; then
    package.load github.com/vargiuscuola/shdoc >/dev/null
    package.get-path_ github.com/vargiuscuola/shdoc
    _MODULE__SHDOC_DIR="$__"
  fi

  # get the class and function name
  local function_name="$1" p
  # if provided name is an alias, recursively expand it to get the function name
  while [[ "alias" = $(type -t -- $function_name) ]] && p=$(alias -- "$function_name" 2>&-); do
    function_name=$(sed -re "s/alias "$function_name"='(\S+).*'$/\1/" <<< "$p")
  done
  local class_name=${function_name%%_*}
  [ -z "$class_name" ] && { errmsg "Cannot find the class of the function '$function_name'" ; return 1 ; }

  # get the path of the class
  module_get-class-path_ "$class_name"
  [ -z "$__" ] && { errmsg "The class '$class_name' has not been loaded" ; return 1 ; }
  ${_MODULE__SHDOC_DIR}/shdoc < "$__" | sed -nE -e "/## ${function_name/./_}\(\)/,/^## /p" | head -n -1
}
alias module.doc="module_doc"