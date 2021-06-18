#!/bin/bash
#github-action genshdoc

# if already sourced, return
[[ -v _MAIN__LOADED ]] && return || _MAIN__LOADED=True
declare -ga _MAIN__CLASSES=(main array hash shopt datetime list process timer)

# @file main.sh
# @brief Generic bash library functions (management of messages, traps, arrays, hashes, strings, etc.).
# @description Contains functions to manipulate different data types (strings, array and associative array) and common usage functions, such as some process
#   management functions, shopt manipulation functions, dynamic regular expression manipulation functions and so on.  
#   It contains the following classes:
#     * main
#     * array
#     * hash
#     * list
#     * datetime
#     * shopt
#     * process
#     * timer
#   
#   Use the command `module.doc <function_name>` to see the documentation for a function (see an [example](https://github.com/vargiuscuola/std-lib.bash#examples))
# @show-internal
shopt -s expand_aliases

module.import "args"

############
#
# GLOBALS
#

# @global-header Flags
# @global _MAIN__FLAGS[SOURCED] Bool Is current file sourced? This flag is automatically set when the module is loaded
# @global _MAIN__FLAGS[INTERACTIVE] Bool Is the current process running in an interactive shell? This flag is automatically set when the module is loaded
# @global _MAIN__FLAGS[CHROOTED] Bool Is current process chrooted? This flag is set when calling `main.is-chroot()`
# @global _MAIN__FLAGS[WINDOWS] Bool Is current O.S. Windows? This flag is set when calling `main.is-windows()`

# @global-header Boolean Values
# @global True 0
True=0
# @global False 1
False=1

# @global-header Others
# @global _MAIN__RAW_SCRIPTNAME String Calling script path, raw and not normalized: as seen by the shell through BASH_SOURCE variable
# @global _MAIN__SCRIPTPATH String Calling script path after any possible link resolution
# @global _MAIN__SCRIPTNAME String Calling script real name (after any possible link resolution)
# @global _MAIN__SCRIPTDIR String Absolute path where reside the calling script, after any possible link resolution
# @global _MAIN__GIT_PATH String Root path of Git for Windows environment: it's set when calling `main.is-windows()`

############
#
# SETTINGS
#

# @setting _MAIN__KILL_PROCESS_WAIT_INTERVAL Number[0.1] Seconds to wait between checks to test whether a process has been successfully killed
[[ -v _MAIN__KILL_PROCESS_WAIT_INTERVAL ]] || _MAIN__KILL_PROCESS_WAIT_INTERVAL=0.1

# @constant-header Terminal color codes
# @constant Color_Off Disable color
Color_Off='\e[0m'
# @constant Black,Red,Green,Yellow,Blue,Purple,Cyan,Orange                                   Regular Colors
Black='\e[0;30m' Red='\e[0;31m' Green='\e[0;32m' Yellow='\e[0;33m' Blue='\e[0;34m' Purple='\e[0;35m' Cyan='\e[0;36m' White='\e[0;37m' Orange=$'\e''[38;5;208m'
# @constant BBlack,BRed,BGreen,BYellow,BBlue,BPurple,BCyan,BWhite                            Bold Colors
BBlack='\e[1;30m' BRed='\e[1;31m' BGreen='\e[1;32m' BYellow='\e[1;33m' BBlue='\e[1;34m' BPurple='\e[1;35m' BCyan='\e[1;36m' BWhite='\e[1;37m'
# @constant UBlack,URed,UGreen,UYellow,UBlue,UPurple,UCyan,UWhite                            Underlined Colors
UBlack='\e[4;30m' URed='\e[4;31m' UGreen='\e[4;32m' UYellow='\e[4;33m' UBlue='\e[4;34m' UPurple='\e[4;35m' UCyan='\e[4;36m' UWhite='\e[4;37m'
# @constant On_Black,On_Red,On_Green,On_Yellow,On_Blue,On_Purple,On_Cyan,On_White            Background Colors
On_Black='\e[40m' On_Red='\e[41m' On_Green='\e[42m' On_Yellow='\e[43m' On_Blue='\e[44m' On_Purple='\e[45m' On_Cyan='\e[46m' On_White='\e[47m'
# @constant IBlack,IRed,IGreen,IYellow,IBlue,IPurple,ICyan,IWhite                            High Intensty Colors
IBlack='\e[0;90m' IRed='\e[0;91m' IGreen='\e[0;92m' IYellow='\e[0;93m' IBlue='\e[0;94m' IPurple='\e[0;95m' ICyan='\e[0;96m' IWhite='\e[0;97m'
# @constant BIBlack,BIRed,BIGreen,BIYellow,BIBlue,BIPurple,BICyan,BIWhite                    Bold High Intensity Colors
BIBlack='\e[1;90m' BIRed='\e[1;91m' BIGreen='\e[1;92m' BIYellow='\e[1;93m' BIBlue='\e[1;94m' BIPurple='\e[1;95m' BICyan='\e[1;96m' BIWhite='\e[1;97m'
# @constant On_IBlack,On_IRed,On_IGreen,On_IYellow,On_IBlue,On_IPurple,On_ICyan,On_IWhite    High Intensty Background Colors
On_IBlack='\e[0;100m' On_IRed='\e[0;101m' On_IGreen='\e[0;102m' On_IYellow='\e[0;103m' On_IBlue='\e[0;104m' On_IPurple='\e[10;95m' On_ICyan='\e[0;106m' On_IWhite='\e[0;107m'


############
#
# INITIALITAZION
#

declare -gA _MAIN__FLAGS=([SOURCED]=$False)
declare -gA _MAIN__TIMER=()

# test if file is sourced or executed
if [ "${BASH_SOURCE[1]}" != "${0}" ]; then
  _MAIN__RAW_SCRIPTNAME="${BASH_SOURCE[-1]}"
  _MAIN__FLAGS[SOURCED]=$True
else
  _MAIN__RAW_SCRIPTNAME="$0"
fi
[ -z "${-//*i*/}" ] && _MAIN__FLAGS[INTERACTIVE]=$True || _MAIN__FLAGS[INTERACTIVE]=$False

test -L "${_MAIN__RAW_SCRIPTNAME}" && _MAIN__SCRIPTPATH="$( readlink "${_MAIN__RAW_SCRIPTNAME}" )" || _MAIN__SCRIPTPATH="${_MAIN__RAW_SCRIPTNAME}"
_MAIN__SCRIPTNAME="${_MAIN__SCRIPTPATH##*/}"



############
#
# MAIN FUNCTIONS
#
############

# @description Dereference shell aliases: return the name of the function to which an alias point to, resolving it recursively if needed
# @alias main.dereference-alias_
# @arg $1 String Name of alias to dereference
# @return String Name of function to which provided alias point to
# @example
#   $ alias alias1="func1"
#   $ alias alias2="alias1"
#   $ main.dereference-alias_ alias2
#   # return __="func1"
main_dereference-alias_() {
  args.check-number 1 || return $?
  # recursively expand alias, dropping arguments
  # output == input if no alias matches
  local function_name="$1" p
  while [[ "alias" = $(type -t -- $function_name) ]] && p=$(alias -- "$function_name" 2>&-); do
    function_name=$(sed -re "s/alias "$function_name"='(\S+).*'$/\1/" <<< "$p")
  done
  declare -g __="$function_name"
}
alias main.dereference-alias_="main_dereference-alias_"

# @description Check whether the current environment is Windows, testing if `uname -a` return a string starting with `MINGW`.  
#   Store the result $True or $False in the flag _MAIN__FLAGS[WINDOWS].
# @exitcodes Standard (0 for true, 1 for false)
# @alias main.is-windows
# @example
#   $ uname -a
#   MINGW64_NT-6.1 chiller2 2.11.2(0.329/5/3) 2018-11-10 14:38 x86_64 Msys
#   $ main.is-windows
#   # statuscode = 0
main_is-windows() {
  if [[ -z "${_MAIN__FLAGS[WINDOWS]}" ]]; then
    [[ "$( uname -a  )" =~ ^MINGW ]] && _MAIN__FLAGS[WINDOWS]=$True || _MAIN__FLAGS[WINDOWS]=$False
  fi
  return "${_MAIN__FLAGS[WINDOWS]}"
}
alias main.is-windows="main_is-windows"

# @description Check whether the script is chroot'ed, and store the value $True or $False in flag $_MAIN__FLAGS[CHROOTED].
# @alias main.is-chroot
# @exitcodes Standard (0 for true, 1 for false)
# @example
#   main.is-chroot
main_is-chroot() {
  if [ -z "${_MAIN__FLAGS[CHROOTED]}" ]; then
    [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/. 2>/dev/null)" ] && _MAIN__FLAGS[CHROOTED]=$True || _MAIN__FLAGS[CHROOTED]=$False
  fi
  return "${_MAIN__FLAGS[CHROOTED]}"
}
alias main.is-chroot="main_is-chroot"

# @description Set the current script path and the current script directory to the global variables `_MAIN__SCRIPTPATH` and `_MAIN__SCRIPTDIR`.
# @alias main.set-script-path-info
# @example
#   $ main.set-script-path-info
#   $ echo _MAIN__SCRIPTPATH=$_MAIN__SCRIPTPATH
#   _MAIN__SCRIPTPATH=/usr/local/src/script.sh
#   $ echo _MAIN__SCRIPTDIR=$_MAIN__SCRIPTDIR
#   _MAIN__SCRIPTDIR=/usr/local/src
main_set-script-path-info() {
  _MAIN__SCRIPTPATH="$( realpath "$_MAIN__SCRIPTPATH" )"
  _MAIN__SCRIPTDIR="${_MAIN__SCRIPTPATH%/*}"
}
alias main.set-script-path-info="main_set-script-path-info"



############
#
# SHOPT FUNCTIONS
#
############

# @description Backup the provided shopt options.
# @alias shopt.backup
# @arg $@ String Options to be backed up
# @example
#   $ shopt -p expand_aliases
#   shopt -s expand_aliases
#   $ shopt.backup expand_aliases extdebug
#   $ shopt -u expand_aliases
#   $ shopt -p expand_aliases
#   shopt -u expand_aliases
#   $ shopt.restore expand_aliases extdebug
#   $ shopt -p expand_aliases
#   shopt -s expand_aliases
shopt_backup() {
  args.check-number 1 - || return $?
  declare -gA _MAIN__SHOPT_BACKUP
  local opt
  for opt ; do
    shopt -p $opt &>/dev/null && _MAIN__SHOPT_BACKUP["$opt"]=$True || _MAIN__SHOPT_BACKUP["$opt"]=$False
  done
}
alias shopt.backup="shopt_backup"

# @description Restore the provided shopt options backuped up by the previously called `shopt.backup` function.
# @alias shopt.restore
# @arg $@ String Options to be restored
# @example
#   $ shopt -p expand_aliases
#   shopt -s expand_aliases
#   $ shopt.backup expand_aliases extdebug
#   $ shopt -u expand_aliases
#   $ shopt -p expand_aliases
#   shopt -u expand_aliases
#   $ shopt.restore expand_aliases extdebug
#   $ shopt -p expand_aliases
#   shopt -s expand_aliases
shopt_restore() {
  args.check-number 1 - || return $?
  [[ "$#" = 0 ]] && { echo "Error arguments in function \"${FUNCNAME[0]}\"" ; return 1 ; }
  local opt is_enabled
  for opt ; do
    shopt -p $opt &>/dev/null
    is_enabled=$?
    [[ "$is_enabled" = ${_MAIN__SHOPT_BACKUP["$opt"]} ]] && continue
    if [[ "$is_enabled" = $True ]]; then
      shopt -u "$opt" &>/dev/null
    else
      shopt -s "$opt" &>/dev/null
    fi
  done
}
alias shopt.restore="shopt_restore"



############
#
# DATETIME FUNCTIONS
#
############

# @description Convert the provided time interval to a seconds interval. The format of the time interval is the following:  
#   [\<n\>d] [\<n\>h] [\<n\>m] [\<n\>s]
# @alias datetime.interval-to-sec_
# @arg $@ String Any of the following time intervals: \<n\>d (\<n\> days), \<n\>h (\<n\> hours), \<n\>m (\<n\> minutes) and \<n\>s (\<n\> seconds)
# @example
#   $ datetime.interval-to-sec_ 1d 2h 3m 45s
#   # return __=93825
datetime_interval-to-sec_() {
  args.check-number 1 - || return $?
  local args="$@"
  declare -g __=0
  [[ "$args" =~ ^([[:digit:]]*)$ ]] && { (( __+=${BASH_REMATCH[1]} )) ; return ; }
  [[ "$args" =~ ([[:digit:]]+)d ]] && (( __+=${BASH_REMATCH[1]}*60*60*24 ))
  [[ "$args" =~ ([[:digit:]]*)h ]] && (( __+=${BASH_REMATCH[1]}*60*60 ))
  [[ "$args" =~ ([[:digit:]]*)m ]] && (( __+=${BASH_REMATCH[1]}*60 ))
  [[ "$args" =~ ([[:digit:]]*)s ]] && (( __+=${BASH_REMATCH[1]} ))
}
alias datetime.interval-to-sec_="datetime_interval-to-sec_"

############
#
# TIMER FUNCTIONS
#
############

# @description Start a timer
# @alias timer.start
# @arg $1 String[_] Name of timer
timer_start() {
  args.check-number 0 1 || return $?
  local name="${1:-_}"
  _MAIN__TIMER[$name]="$SECONDS"
}
alias timer.start="timer_start"

# @description Return the seconds elapsed for the provided timer
# @alias timer.elapsed
# @arg $1 String[_] Name of timer
# @return Return the elapsed seconds for the timer
# @example
#   $ timer.start timer1
#   $ sleep 5
#   $ timer.elapsed timer1
#   # return __=5
timer_elapsed() {
  args.check-number 0 1 || return $?
  local name="${1:-_}"
  declare -g __=$(($SECONDS-${_MAIN__TIMER[$name]}))
}
alias timer.elapsed="timer_elapsed"

############
#
# ARRAY FUNCTIONS
#
############

# @description Return the list of array's indexes which have the provided value.
# @alias array.find-indexes_
# @arg $1 String Array name
# @arg $2 String Value to find
# @return An array of indexes of the array containing the provided value.
# @exitcodes 0 if at least one item in array is found, 1 otherwise
# @example
#   $ declare -a ary=(a b c "s 1" d e "s 1")
#   $ array.find-indexes_ ary "s 1"
#   # return __a=(3 6)
array_find-indexes_() {
  args.check-number 2 || return $?
  declare -n my_array=$1
  declare -ag __a=()
  local i ret=1
  for i in "${!my_array[@]}"; do
    [[ "${my_array[$i]}" = "$2" ]] && { __a+=($i) ; ret=0 ; } || true
  done
  return $ret
}
alias array.find-indexes_="array_find-indexes_"

# @description Return the index of the array containing the provided value, or -1 if not found.
# @alias array.find_
# @arg $1 String Array name
# @arg $2 String Value to find
# @return The index of the array containing the provided value, or -1 if not found.
# @exitcodes 0 if found, 1 if not found
# @example
#   $ declare -a ary=(a b c "s 1" d e "s 1")
#   $ array.find_ ary "s 1"
#   # return __=3
array_find_() {
  args.check-number 2 || return $?
  declare -n my_array=$1
  local i
  for i in "${!my_array[@]}"; do
    if [[ "${my_array[$i]}" = "$2" ]]; then
      declare -g __=$i
      return 0
    fi
  done
  declare -g __=-1
  return 1
}
alias array.find_="array_find_"
array_find() { array_find_ "$@" ; local ret="$?" ; echo "$__" ; return "$ret" ; }
alias array.find="array_find"

# @description Check whether an item is present in the provided array.
# @alias array.include
# @arg $1 String Array name
# @arg $2 String Value to find
# @exitcodes 0 if found, 1 if not found
# @example
#   $ declare -a ary=(a b c "s 1" d e "s 1")
#   $ array.include ary "s 1"
#   # exitcode=0
array_include() {
  args.check-number 2 || return $?
  declare -n my_array=$1
  local item
  for item in "${my_array[@]}"; do
    [[ "$item" = "$2" ]] && return 0
  done
  return 1
}
alias array.include="array_include"

# @description Return an array containing the intersection between two arrays.
# @alias array.intersection_
# @arg $1 String First array name
# @arg $2 String Second array name
# @return An array containing the intersection of the two provided arrays.
# @exitcodes 0 if the intersection contains at least one element, 1 otherwise
# @example
#   $ declare -a ary1=(a b c d e f)
#   $ declare -a ary2=(b d g h)
#   $ array.intersection_ ary1 ary2
#   # return __a=(b d)
array_intersection_() {
  args.check-number 2 || return $?
  declare -n ary1_ref=$1
  declare -n ary2_ref=$2
  declare -ga __a=()
  local item ret=1
  
  for item in "${ary1_ref[@]}"; do
    array_find_ ary2_ref "$item" && { __a+=("$item") ; ret=0 ; } || true
  done
  return $ret
}
alias array.intersection_="array_intersection_"

# @description Remove the item at the provided index from array.
# @alias array.remove-at
# @arg $1 String Array name
# @arg $2 String Index of the item to remove
# @example
#   $ declare -a ary=(a b c d e f)
#   $ array.remove-at ary 2
#   $ declare -p ary
#   declare -a ary=([0]="a" [1]="b" [2]="d" [3]="e" [4]="f")
array_remove-at() {
  args.check-number 2 || return $?
  local aryname="$1" idx="$2"
  declare -n ary_ref="$aryname"
  ary_ref=( "${ary_ref[@]:0:$idx}" "${ary_ref[@]:$(( $idx+1 ))}" )
}
alias array.remove-at="array_remove-at"

# @description Remove the first instance of the provided item from array.
# @alias array.remove
# @arg $1 String Array name
# @arg $2 String Item to remove
# @exitcodes 0 if item is found and removed, 1 otherwise
# @example
#   $ declare -a ary=(a b c d e a)
#   $ array.remove ary a
#   $ declare -p ary
#   declare -a ary=([0]="b" [1]="c" [2]="d" [3]="e" [4]="a")
array_remove() {
  args.check-number 2 || return $?
  local aryname="$1" val="$2"
  declare -n ary_ref="$aryname"
  array_find_ "$aryname" "$val" && ary_ref=( "${ary_ref[@]:0:$__}" "${ary_ref[@]:$(( $__+1 ))}" )
}
alias array.remove="array_remove"

# @description Remove any occurrence of the provided item from array.
# @alias array.remove-values
# @arg $1 String Array name
# @arg $2 String Item to remove
# @example
#   $ declare -a ary=(a b c d e a)
#   $ array.remove-values ary a
#   $ declare -p ary
#   declare -a ary=([0]="b" [1]="c" [2]="d" [3]="e")
array_remove-values() {
  args.check-number 2 || return $?
  local aryname="$1" val="$2" ret=1
  declare -n ary_ref="$aryname"
  array_find-indexes_ "$aryname" "$val"
  (( ${#__a[@]} > 0 )) && ret=0
  local i
  for (( i=$(( ${#__a[@]}-1 )) ; i>=0 ; i-- )); do
    ary_ref=( "${ary_ref[@]:0:${__a[$i]}}" "${ary_ref[@]:$(( ${__a[$i]}+1 ))}" )
  done
  return $ret
}
alias array.remove-values="array_remove-values"

# @description Check whether an array with the provided name exists.
# @alias array.defined
# @arg $1 String Array name
# @exitcodes Standard (0 for true, 1 for false)
array_defined() {
  args.check-number 1 || return $?
  local def="$( declare -p "$1" 2>/dev/null )" && [[ "$def" =~ "declare -a" ]]
}
alias array.defined="array_defined"

# @description Initialize an array (resetting it if already existing).
# @alias array.init
# @arg $1 String Array name
array_init() {
  args.check-number 1 || return $?
  unset "$1"
  declare -ga "$1"='()'
}
alias array.init="array_init"

# @description Return an array with duplicates removed from the provided array.
# @alias array.uniq_
# @arg $1 String Array name
# @return Array with duplicates removed
# @example
#   $ declare -a ary=(1 2 1 5 6 1 7 2)
#   $ array.uniq_ "${ary[@]}"
#   $ declare -p __a
#   declare -a __a=([0]="1" [1]="2" [2]="5" [3]="6" [4]="7")
array_uniq_() {
  local v
  declare -A h
  for v in "$@"; do
    h[$v]=1
  done
  declare -ga __a=("${!h[@]}")
}
alias array.uniq="array_uniq"

# @description Compare two arrays
# @alias array.eq
# @arg $1 String First array name
# @arg $2 String Second array name
# @exitcodes 0 if the array are equal, 1 otherwise
# @example
#   $ declare -a ary1=(1 2 3)
#   $ declare -a ary2=(1 2 3)
#   $ array.eq ary1 ary2
#   # exitcode=0
array_eq() {
  declare -n _array_eq_ary1=$1
  declare -n _array_eq_ary2=$2
  local i
  [ "${#_array_eq_ary1[@]}" != "${#_array_eq_ary2[@]}" ] && return 1
  for i in "${!_array_eq_ary1[@]}"; do
    [ "${_array_eq_ary1[$i]}" != "${_array_eq_ary2[$i]}" ] && return 1
  done
  return 0
}
alias array.eq="array_eq"

# @description Print a string with the definition of the provided array or hash (as shown in `declare -p` but without the first part declaring the variable).
# @alias array.to_s
# @alias hash.to_s
# @arg $1 String Array name
# @example
#   $ declare -a ary=(1 2 3)
#   $ array.to_s ary
#   ([0]="1" [1]="2" [2]="3")
array_to_s() {
  declare -p $1 | cut -d= -f 2-
}
alias array.to_s="array_to_s"
alias hash.to_s="array_to_s"

############
#
# SET FUNCTIONS
#
############

# @description Compare two sets (a set is an array where index associated to values are negligibles)
# @alias set.eq
# @arg $1 String First array name
# @arg $2 String Second array name
# @exitcodes 0 if the values of arrays are the same, 1 otherwise
# @example
#   $ declare -a ary1=(1 2 3 1 1)
#   $ declare -a ary2=(3 2 1 2 2)
#   $ set.eq ary1 ary2
#   # exitcode=0
set_eq() {
  declare -A _set_eq_values1
  declare -A _set_eq_values2
  local v
  # convert set n.1 to hash
  declare -n _set_eq_ary=$1
  for v in "${_set_eq_ary[@]}"; do
    _set_eq_values1[$v]=1
  done
  # convert set n.2 to hash
  declare -n _set_eq_ary=$2
  for v in "${_set_eq_ary[@]}"; do
    _set_eq_values2[$v]=1
  done
  hash_eq _set_eq_values1 _set_eq_values2
}
alias set.eq="set_eq"

############
#
# LIST FUNCTIONS
#
############

# @description Return the index inside a list in which appear the provided searched item.
# @alias list.find_
# @alias list_include
# @alias list.include
# @arg $1 String Item to find
# @arg $@ String Elements of the list
# @return The index inside the list in which appear the provided item.
# @exitcodes 0 if the item is found, 1 otherwise
list_find_() {
  args.check-number 1 - || return $?
  local what="$1" ; shift
  declare -a ary=("$@")
  
  array.find_ ary "$what"
}
alias list.find_="list_find_"

# @description Check whether an item is included in a list of values.
# @alias list.include
# @arg $1 String Item to find
# @arg $@ String Elements of the list
# @exitcodes 0 if the item is found, 1 otherwise
list_include() {
  args.check-number 1 - || return $?
  local what="$1" ; shift
  declare -a ary=("$@")
  
  array.include ary "$what"
}
alias list.include="list_include"



############
#
# REGEXP FUNCTIONS
#
############

# @description Escape a string which have to be used as a search pattern in a bash parameter expansion as ${parameter/pattern/string}.
#  The escaped characters are `%*[?/`
# @alias regexp.escape-bash-pattern_
# @arg $1 String String to be escaped
# @return Escaped string
# @example
#   $ regexp.escape-bash-pattern_ 'a * x #'
#   # return __=a \* x \#
regexp_escape-bash-pattern_() {
  declare -g __="${1//\#/\\#}"
  __="${__//\%/\\%}"
  __="${__//\*/\\*}"
  __="${__//\[/\\[}"
  __="${__//\?/\\?}"
  __="${__//\//\\/}"
}
alias regexp.escape-bash-pattern_="regexp_escape-bash-pattern_"

# @description Escape a string which have to be used as a search pattern in a extended regexp in `sed` or `grep`.
#   The escaped characters are the following: `{$.*[\^|]`.
# @alias regexp.escape-ext-regexp-pattern_
# @arg $1 String String to be escaped
# @arg $2 String[/] Separator used in the `sed` expression
# @return Escaped string
# @example
#   $ regexp.escape-ext-regexp-pattern_ "[WW]"  "W"
#   # return __=\[\W\W[]]
regexp_escape-ext-regexp-pattern_() {
  local sep="${2:-/}" ret="$1"
  # escape backslash first, so we don't escape the backslash used to escape the other special characters
  ret="${ret//\\/\\\\}"
  # escape the separator character, but only if it's not one of the characters escaped on the next steps
  if [[ ! "$sep" =~ \{|\$|\.|\*|\[|\\|\^|\||\] ]]; then
    regexp_escape-bash-pattern_ "$sep"
    ret="${ret//${__}/\\${sep}}"
  fi
  # escape * and [, which have special meaning in bash parameter expansion too
  ret="${ret//\*/\\*}"
  ret="${ret//\[/\\[}"
  # escape other characters {$.^|], which doesn't have special meaning in bash parameter expansion (so no need to use backslash in the search pattern)
  ret="${ret//{/\\{}"
  ret="${ret//$/\\$}"
  ret="${ret//./\\.}"
  ret="${ret//^/\\^}"
  ret="${ret//|/\\|}"
  ret="${ret//\]/[]]}"    # ] needs a special escaping, not only backslash but all the sequence \[]]
  declare -g __="$ret"
}
alias regexp.escape-ext-regexp-pattern_="regexp_escape-ext-regexp-pattern_"

# @description Escape a string which have to be used as a replace string on a `sed` command.
#   The escaped characters are the separator character and the following characters: `/&`.
# @alias regexp.escape-ext-regexp-pattern_
# @arg $1 String String to be escaped
# @arg $2 String[/] Separator used in the `sed` expression
# @return Escaped string
# @example
#   $ regexp.escape-regexp-replace_ "p/x"
#   # return __="p\/x"
#   $ regexp.escape-regexp-replace_ "x//" "x"
#   # return __="\x//"
regexp_escape-regexp-replace_() {
  local rpl_str="$1" sep_ch="${2:-/}"
  
  [[ "$sep_ch" != / && "$sep_ch" != \& ]] && rpl_str="${rpl_str//${sep_ch//\*/\\*}/\\$sep_ch}"
  rpl_str="${rpl_str//\//\\/}"
  rpl_str="${rpl_str//&/\\&}"
  declare -g __="$rpl_str"
}
alias regexp.escape-regexp-replace_="regexp_escape-regexp-replace_"



############
#
# STRING FUNCTIONS
#
############

# @description Append a string to the content of the provided variable, optionally prefixing it with a separator if the variable is not empty.
# @alias string.append
# @alias string.concat
# @arg $1 String Variable name
# @arg $2 String String to append
# @arg $3 String[" "] Separator
# @opt -m|--multi-line Append the string to every line of the destination variable
# @return Concatenation of the two strings, optionally separated by the provided separator
string_append() {
  [[ "$1" = -m || "$1" = --multi-line ]] && { local multi=1 ; shift ; } || local multi
  declare -n var_ref="$1"
  if [[ -n "$multi" ]]; then
    regexp.escape-bash-pattern_ "${3:- }$2" ; local esc_search="$__"
    var_ref=$'\n'"${var_ref}"$'\n'
    var_ref="${var_ref//$'\n'/${3:- }$2$'\n'}"
    var_ref="${var_ref//$'\n'${esc_search}$'\n'/$'\n'$2$'\n'}"
    var_ref="${var_ref#*$'\n'}"
    var_ref="${var_ref%$'\n'}"
  else
    [[ -z "$var_ref" ]] && var_ref="$2" || var_ref="${var_ref}${3:- }$2"
  fi
}
alias string.append="string_append"
alias string.concat="string_append"


############
#
# HASH FUNCTIONS
#
############

# @description Check whether an hash with the provided name exists.
# @alias hash.defined
# @arg $1 String Hash name
# @exitcodes Standard (0 for true, 1 for false)
hash_defined() {
  args.check-number 1 || return $?
  local def="$( declare -p "$1" 2>/dev/null )" && [[ "$def" =~ "declare -A" ]]
}
alias hash.defined="hash_defined"

# @description Initialize an hash (resetting it if already existing).
# @alias hash.init
# @arg $1 String Hash name
hash_init() {
  args.check-number 1 || return $?
  unset "$1"
  declare -gA "$1"='()'
}
alias hash.init="hash_init"

# @description Check whether a hash contains the provided key.
# @alias hash.has-key
# @arg $1 String Hash name
# @arg $2 String Key name to find
# @exitcodes Standard (0 for true, 1 for false)
hash_has-key() {
  args.check-number 2 || return $?
  declare -n ref="$1"
  [[ ${ref["$2"]+x} ]]
}
alias hash.has-key="hash_has-key"

# @description Merge two hashes.
# @alias hash.merge
# @arg $1 String Variable name of the 1st hash, in which to merge the 2nd hash
# @arg $2 String Variable name of the 2nd hash, which is merged into the 1st hash
# @example
#   $ declare -A h1=([a]=1 [b]=2 [e]=3)
#   $ declare -A h2=([a]=5 [c]=6)
#   $ hash.merge h1 h2
#   $ declare -p h1
#   declare -A h1=([a]="5" [b]="2" [c]="6" [e]="3" )
hash_merge() {
  local merge_into="$1" merge_from="$2"
  local def_h1="$( declare -p $merge_into )" def_h2="$( declare -p $merge_from )"
  shopt_backup extglob
  shopt -s extglob
  [[ "$def_h1" =~ "(" ]] && { def_h1="${def_h1#*\(}" ; def_h1="${def_h1%)*(\')}" ; } || def_h1=""
  [[ "$def_h2" =~ "(" ]] && { def_h2="${def_h2#*\(}" ; def_h2="${def_h2%)*(\')}" ; } || def_h2=""
  shopt_restore extglob
  eval "$merge_into=($def_h1 $def_h2)"
}
alias hash.merge="hash_merge"

# @description Copy an hash.
# @alias hash.copy
# @arg $1 String Variable name of the hash to copy from
# @arg $2 String Variable name of the hash to copy to: if the hash is not yet defined, it will be created as a global hash
# @example
#   $ declare -A h1=([a]=1 [b]=2 [e]=3)
#   $ hash.copy h1 h2
#   $ declare -p h2
#   declare -A h2=([a]="1" [b]="2" [e]="3")
hash_copy() {
  local from="$1" to="$2"
  local hash_def="$( declare -p $from 2>/dev/null | cut -s -d= -f2- )"
  [[ -z "$hash_def" ]] && hash_def="()"
  if declare -p "$to" &>/dev/null; then
    eval "$to=$hash_def"
  else
    declare -gA "$to=$hash_def"
  fi
}
alias hash.copy="hash_copy"

# @description Return the key of the hash which have the provided value.
# @alias hash.find-value_
# @arg $1 String Hash name
# @arg $2 String Value to find
# @example
#   $ declare -A h1=([a]=1 [b]=2 [e]=3)
#   $ hash.find-value_ h1 2
#   $ echo $__
#   b
hash_find-value_() {
  declare -n hash_ref="$1"
  declare -g __=""
  local value="$2" key
  for key in "${!hash_ref[@]}"; do
    varname="$hname[$key]"
    [[ "${hash_ref[$key]}" = "$value" ]] && { __="$key" ; return 0 ; }
  done
  return 1
}
alias hash.find-value_="hash_find-value_"

# @description Compare two hashes
# @alias hash.eq
# @arg $1 String First hash name
# @arg $2 String Second hash name
# @exitcodes 0 if the hashes are equal, 1 otherwise
# @example
#   $ declare -a h1=([key1]=val1 [key2]=val2)
#   $ declare -a h2=([key1]=val1 [key2]=val2)
#   $ hash.eq h1 h2
#   # exitcode=0
hash_eq() {
  declare -n _hash_eq_h1=$1
  declare -n _hash_eq_h2=$2
  local i
  [ "${#_hash_eq_h1[@]}" != "${#_hash_eq_h2[@]}" ] && return 1
  for i in "${!_hash_eq_h1[@]}"; do
    [ "${_hash_eq_h1[$i]}" != "${_hash_eq_h2[$i]}" ] && return 1
  done
  return 0
}

############
#
# FD FUNCTIONS
#
############

# @description Get the first file descriptor number available.
# @alias hfd.get_
# @noargs
# @return File descriptor number
fd_get_() {
  local start_fd=11
  while [[ -e /proc/$$/fd/$start_fd ]]; do
    (( start_fd+=1 ))
  done
  declare -g __="$start_fd"
}
alias fd.get_="fd_get_"

############
#
# PROCESS MANAGEMENT
#
############

# @description Check if a process with provided PID exists.
# @alias process.exists
# @arg $1 Number PID of the process
# @exitcodes 0 if process exists, 1 otherwise
alias process_exists="ps -p &>/dev/null"
alias process.exists="ps -p &>/dev/null"

# @description Test if process with provided PID is a child of the current process.
# @alias process.is-child
# @arg $1 Number PID of the process
# @exitcodes 0 if process is a child process, 1 otherwise
process_is-child() {
  local pid="$1" cur_pid=$BASHPID
  ps -o pid:1= --ppid $cur_pid 2>&- | grep -Fqx "$1"
}
alias process.is-child="process_is-child"

# @description Kill a process and wait for the process to actually terminate.
# @alias process.kill
# @arg $1 Number PID of the process to kill
# @arg $2 String[TERM] Signal to send
# @arg $2 Number[3] Seconds to wait for the process to end: if zero, kill the process and return immediately
# @exitcodes 0 if process is successfully killed, 1 otherwise (not killed or not ended before the timeout period)
process_kill() {
  local pid="$1" signal="${2:-TERM}" wait="${3:-3}"
  process_exists "$pid" || return 0

  kill "-${signal}" "$pid" &>/dev/null
  timer_start _main__process_kill
  local elapsed_time=0
  while [ -n "$wait" -a "$elapsed_time" -lt "$wait" ]; do
    process_exists "$pid" || return 0
    sleep $_MAIN__KILL_PROCESS_WAIT_INTERVAL
    timer_elapsed _main__process_kill ; elapsed_time="$__"
  done
  process_exists "$pid" && return 1 || return 0
}
alias process.kill="process_kill"

############
#
# ENV FUNCTIONS
#
############

# @description Append the provided path to the `PATH` environment variable.
# @alias env.PATH.append-item
# @arg $1 String Path to append
env_PATH_append-item() {
  [[ ":$PATH:" != *":$1:"* ]] && export PATH="${PATH}:$1"
}
alias env.PATH.append-item="env_PATH_append-item"

# @description Prepend the provided path to the `PATH` environment variable.
# @alias env.PATH.prepend-item
# @arg $1 String Path to prepend
env_PATH_prepend-item() {
  [[ ":$PATH:" != *":$1:"* ]] && export PATH="$1:${PATH}"
}
alias env.PATH.prepend-item="env_PATH_prepend-item"
