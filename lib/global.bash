#!/usr/bin/env bash

# CONSTANTS
WCT_ERROR=1
WCT_WARNING=2
WCT_OK=3
WCT_DEBUG=4

export WCT_DEBUG WCT_OK WCT_WARNING WCT_ERROR

# Check bash version for compatibility
# param 1 (int) - bash major version
# param 2 (int) - bash minor version
BashVersionCheck() {
  if ! [[ BASH_VERSINFO[0] -gt $1 || BASH_VERSINFO[0] -eq $1 && BASH_VERSINFO[1] -ge $2 ]]; then
    echo "Sorry, you need at least v4.3 to run this script. Check 'bash --version'"
    exit 1
  fi
}

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

Verbose() { # Passes in _V
  if [[ $_V -eq 1 ]]; then
    # shellcheck disable=SC2059
    printf "$@"
  fi
}

IssueLevels() {
  case $1 in
  4) echo "DEBUG: ";;
  3) echo "INFO: ";;
  2) echo "WARNING: ";;
  1) echo "ERROR: ";;
  *) echo "MSG: ";;
  esac
}

Issue() {
  BarrierMinor
  local IssueLevel=$2
  printf "%s" "$(IssueLevels "${IssueLevel}")"
  #printf "%s" "$@"
  printf "%s" "$1"
  echo ""
  BarrierMinor
}

BarrierMajor() {
  echo '============================'
}

BarrierMinor() {
  echo '----------------------------'
}