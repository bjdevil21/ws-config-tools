#!/usr/bin/env bash

# CONSTANTS
## Issue types for Issue() calls.
WCT_ERROR=1
WCT_WARNING=2
WCT_OK=3
WCT_DEBUG=4

export WCT_DEBUG WCT_OK WCT_WARNING WCT_ERROR

# Check bash version for compatibility
# $1 (int) - bash major version
# $2 (int) - bash minor version
BashVersionCheck() {
  if ! [[ BASH_VERSINFO[0] -gt $1 || BASH_VERSINFO[0] -eq $1 && BASH_VERSINFO[1] -ge $2 ]]; then
    echo "ERROR: You need at least v4.3 to run this script. Check with 'bash --version'"
    exit 1
  fi
}

# UserRootDirCheck() - Returns the script executing user's home directory, based on their OS (Linux or Mac - no Windows support).
# No input params
UserRootDirCheck() {
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

# Verbose() - If -V is passed into the main script, this outputs text that isn't displayed by default. Functions as a shell of printf().
# $1 (str) - Message to be displayed
# NOTE: Include line breaks (\n) in any string you pass in.
Verbose() {
  if [[ $_V -eq 1 ]]; then
    # shellcheck disable=SC2059
    printf "$@"
  fi
}

# IssueLevels() - Defines text output when
# $1 (int) - Type of message (see Issue()).
# Note: Internal function for Issue(). Do not use.
IssueLevels() {
  case $1 in
  4) echo "DEBUG: ";;
  3) echo "INFO: ";;
  2) echo "WARNING: ";;
  1) echo "ERROR: ";;
  *) echo "MSG: ";;
  esac
}

# Issue() - Output for various issues - info, debug, errors, etc
# Try to use only for when things are "broken" or an unexpected event occurs.
# $1 - (str) Message string to be output.
#    To get the right "parameters" below, don't use printf parameters when calling this function;
#    Include the variables directly in this string instead.
# $2 - (str) input level (use the constants above) (defaults to IssueLevel case default - MSG)
# $3 - (int) (optional) If == 1, hides the top and bottom barriers (defaults to showing them)
Issue() {
  [[ $3 != 1 ]] && BarrierMinor 0
  local IssueLevel=$2
  printf "%s" "$(IssueLevels "${IssueLevel}")"
  #printf "%s" "$@"
  printf "%s" "$1"
  [[ $3 != 1 ]] && echo "" && BarrierMinor 0
}

# BarrierMajor() - Outputs a simple, think barrier
# No input params
BarrierMajor() {
  [[ $1 == 1 || $1 == 3 ]] && echo ""
  echo '==================================='
  [[ $1 == 2 || $1 == 3 ]] && echo ""
}

# BarrierMajor() - Outputs a simple, thin barrier
# No input params
BarrierMinor() {
  [[ $1 == 2 || $1 == 3 ]] && echo ""
  echo '----------------------------'
  [[ $1 == 2 || $1 == 3 ]] && echo ""
}

# Timer for console to output a period per second
# $1 (int) - N of seconds
# $2 (str) - timer expired message. (Pass in " " for an empty message.)
ConsoleTimer() {
  local time=${1}
  local end=$(( SECONDS + time ))
  [[ $2 != "" ]] && local message="$2" || local message=" Time's up."
  while [ $SECONDS -lt $end ]; do
    printf '.'
    sleep 1
  done
  printf "%s\n" "${message}"
}
#export -f ConsoleTimer
