#!/usr/bin/env bash

# Check bash version for compatibility
# param 1 (int) - bash major version
# param 2 (int) - bash minor version
BashVersionCheck() {
  if ! [[ BASH_VERSINFO[0] -gt $1 || BASH_VERSINFO[0] -eq $1 && BASH_VERSINFO[1] -ge $2 ]]; then
    echo "Sorry, you need at least v5.0 to run this script. Check 'bash --version'"
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

Log() { # Passes in _V
  if [[ $_V -eq 1 ]]; then
    printf "$@"
  fi
}