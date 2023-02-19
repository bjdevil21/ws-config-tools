#!/usr/bin/env bash

# CONSTANTS
## Issue types for Issue() calls.
WCT_ERROR=1
WCT_WARNING=2
WCT_OK=3
WCT_DEBUG=4

export WCT_DEBUG WCT_OK WCT_WARNING WCT_ERROR

# BarrierMajor() - Outputs a simple, think barrier
# $1 (int) - Extra row(s) of padding (1 = above, 2 = below, 3 = both); Defaults to none
# $2 (int) - If 1, only show in verbose mode (defaults to '' == always display)
function BarrierMajor() {
  local Margins=$1
  local OnlyVerbose=$2
  if [[ -z $OnlyVerbose || ($_V == 1 && $OnlyVerbose == 1) ]]; then
    [[ $1 == 1 || $1 == 3 ]] && echo ""
    echo '==================================='
    [[ $1 == 2 || $1 == 3 ]] && echo ""
  fi
}

# BarrierMinor() - Outputs a simple, thin barrier
# $1 (int) - Padding (1 = above, 2 = below, 3 = both); Defaults to none
# $2 (int) - If 1, only show in verbose mode (defaults to '' == always display)
function BarrierMinor() {
  local Margins=$1
  local OnlyVerbose=$2
  if [[ -z $OnlyVerbose || ($_V == 1 && $OnlyVerbose == 1) ]]; then
    [[ $Margins == 1 || $Margins == 3 ]] && echo ""
    echo '----------------------------'
    [[ $Margins == 2 || $Margins == 3 ]] && echo ""
  fi
}

# Check bash version for compatibility
# $1 (int) - bash major version
# $2 (int) - bash minor version
function BashVersionCheck() {
  if ! [[ BASH_VERSINFO[0] -gt $1 || BASH_VERSINFO[0] -eq $1 && BASH_VERSINFO[1] -ge $2 ]]; then
    echo "ERROR: You need at least v4.3 to run this script. Check with 'bash --version'"
    exit 1
  fi
}

# Global pause/continue with Enter key
function ConfirmToContinue() {
  printf "\n-- Hit Enter/Return to continue (or Ctrl-C to Cancel and stop)... ** "
  read -r
  BarrierMinor
}

# Timer for console to output a period per second
# $1 (int) - N of seconds
# $2 (str) - timer expired message. (Pass in " " for an empty message.)
function ConsoleTimer() {
  local time=${1}
  local end=$(( SECONDS + time ))
  if [[ -n $2 ]]; then # not empty or null?
    local message="$2"
  else
    local message=" Time's up."
  fi
  while [ $SECONDS -lt $end ]; do
    printf '.'
    sleep 1
  done
  printf "%s\n" "${message}"
}
#export -f ConsoleTimer

# Git reset to master branch + pull
# Must be run in
# $1 (str) - Sanitized, absolute path to directory
function GitMasterRemoteSync() {
  cd "${1}" || exit 1
  if [[ -d .git ]]; then
    git checkout "$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')" && git pull || exit 1
  else
    echo "ERROR: Directory doesn't contain a Git repo. Exiting."
    exit 1
  fi
}

# Issue() - Output for various issues - info, debug, errors, etc
# Try to use only for when things are "broken" or an unexpected event occurs.
# $1 - (str) Message string to be output.
#    To get the right "parameters" below, don't use printf parameters when calling this function;
#    Include the variables directly in this string instead.
# $2 - (str) input level (use the constants above) (defaults to IssueLevel case default - MSG)
# $3 - (int) (optional) If == 1, hides the top and bottom barriers (defaults to showing them)
function Issue() {
  [[ $3 != 1 ]] && BarrierMinor 0
  local IssueLevel=$2
  printf "%s" "$(IssueLevels "${IssueLevel}")"
  #printf "%s" "$@"
  printf "%s" "$1"
  [[ $3 != 1 ]] && echo "" && BarrierMinor 0
}

# IssueLevels() - Defines text output when
# $1 (int) - Type of message (see Issue()).
# Note: Internal function for Issue(). Do not use.
function IssueLevels() {
  case $1 in
  4) echo "DEBUG: ";;
  3) echo "INFO: ";;
  2) echo "WARNING: ";;
  1) echo "ERROR: ";;
  *) echo "MSG: ";;
  esac
}

# Converts UNIX timestamps to relative time with two time unit levels (X days Y hours ago, Y hours Z mins ago, etc.)
# $1 (int) - UNIX timestamp to compare to now
# returns (str) - "X mins/hours/days ago"
function TimeToAgo() {
  local SEC_PER_MINUTE=$((60))
  local   SEC_PER_HOUR=$((60*60))
  local    SEC_PER_DAY=$((60*60*24))
  local  SEC_PER_MONTH=$((60*60*24*30))
  local   SEC_PER_YEAR=$((60*60*24*365))

  local last_unix="$1"
  local now_unix
  now_unix="$(date +'%s')"
  local delta_s=$(( now_unix - last_unix ))

  if (( delta_s < SEC_PER_MINUTE )); then
    echo $((delta_s))" seconds ago"
    return
  elif (( delta_s < SEC_PER_HOUR )); then
    local calc_s=$(((delta_s) % SEC_PER_MINUTE))
    echo $((delta_s / SEC_PER_MINUTE))" minutes "$((calc_s))" seconds ago"
    return
  elif (( delta_s < SEC_PER_DAY)); then
    local calc_m=$(((delta_s) % SEC_PER_HOUR))
    echo $((delta_s / SEC_PER_HOUR))" hours "$((calc_m / SEC_PER_MINUTE))" minutes ago"
    return
  elif (( delta_s < SEC_PER_MONTH)); then
    local calc_h=$((delta_s % SEC_PER_DAY))
    echo $((delta_s / SEC_PER_DAY))" days "$((calc_h / SEC_PER_HOUR))" hours ago"
    return
  elif (( delta_s < SEC_PER_YEAR)); then
    local calc_d=$((delta_s % SEC_PER_MONTH))
    echo $((delta_s / SEC_PER_MONTH))" months "$((calc_d / SEC_PER_DAY))" days ago"
    return
  else
    local calc_mon=$((delta_s % SEC_PER_YEAR))
    echo $((delta_s / SEC_PER_YEAR))" years "$((calc_mon / SEC_PER_MONTH))" ago"
    return
  fi
  return 1
}

# UserRootDirCheck() - Returns the script executing user's home directory, based on their OS
# (Linux or Mac - no Windows support).
# No input params
function UserRootDirCheck() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS_ROOT="/home"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS_ROOT="/Users"
  else
    echo "Unknown or unsupported OS (only Linux or MacOS). Closing..."
    exit 1
  fi
  USER_DIR_ROOT="${OS_ROOT}/$(whoami)/"
  export OS_ROOT USER_DIR_ROOT
}

# Verbose() - Prints passed in text when a global "verbose" variable ($_V) has been set to 1.
# $_V is usually linked to a setopts argument like -v.
# Functions as a shell of printf().
# $1 (str) - Message to be displayed
# NOTE: Include line breaks (\n) in any string you pass in.
function Verbose() {
  if [[ $_V -eq 1 ]]; then
    # shellcheck disable=SC2059
    printf "$@"
  fi
}
