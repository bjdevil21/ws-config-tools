#!/usr/bin/env bash
##
# Webspark 2 configuration file diff checker
# The following files are required:
# - d9_config_diff_gen.bash
# - etc
#   - d9_config_diff_gen.settings
# - lib
#   - global.bash
# See Help() on using the script
##

# IDE checks
# shellcheck disable=SC2188

source ./lib/global.bash || exit 1
BashVersionCheck 4 3
UserRootDirCheck
source ./etc/d9_config_diff_gen.settings || exit 1
. "${USER_DIR_ROOT}"/.bashrc  # Bash FYI - . is the same as source

# HELPER FUNCTIONS

# Help() - Output help docs
function Help {
  # Display Help
  echo ""
  echo "Webspark 2 configuration file diff checker"
  echo ""
  echo "Generates and opens a diff file between the module's current config files and your local D9 dev site's exported "
  echo "config files."
  echo "By default, the diff file are deleted after being opened and viewed."
  echo ""
  echo "Notes:"
  echo "* You MUST configure your options in a corresponding ./etc/d9_config_diff_gen.settings file before using this script."
  echo "* This script currently only checks a project's /config/install directories. It does not check other YML files"
  echo "  (in the root directory, other /config directories, etc.)"
  echo ""
  echo "Flags (options):"
  echo "  -k - Keep diff and command files for manual review in the /config/install directory of the compared project."
  echo "  -g - Interactively verify Git branch status for each project"
  printf "  -r - Re-run Drush export of active configs into ~/%s \n" "${CONF_EXPORT_DIR}"
  echo " -R - -r plus creates/overwrites second 'starting point' export dir (to compare later for new YML files)"
  echo "  -c - Skip Drush check if project is enabled (by default, disabled projects bloat the config diff output)"
  echo "  -V - Verbose output"
  echo "  -z - Extra careful mode"
  echo "  -Z - Extra careful mode (verbose)"
  echo "  -v - Returns version of script"
  echo "  -h - Returns this help message"
  exit 0
}
# Is the project a valid project to check?
# $1 (int) - Directory to be checked
function ProjectVerify {
  if [[ $1 =~ "webspark-module-".* || $1 =~ "webspark-theme-".* || $1 =~ "webspark-profile-".* ]]; then
    echo "true"
  else
    echo "false"
  fi
}
# Prepare active configs directory
# No input params
function PrepConfigDir {
  if [[ -d "${ABS_CONF_EXPORT_DIR}" ]]; then
    find "${ABS_CONF_EXPORT_DIR}" -type f -not -name "*.yml" -exec rm {} \; # Delete non-YML files from config dir
    YML_COUNT=$(find "${ABS_CONF_EXPORT_DIR}" -type f -name "*.yml" 2>/dev/null | wc -l)
    if [[ ${YML_COUNT} != 0 ]]; then
      if [[ ${RERUN_EXPORT} == 1 ]]; then
        Verbose "Emptying %s directory..." "${ABS_CONF_EXPORT_DIR}"
        rm "${ABS_CONF_EXPORT_DIR}"/*
        Verbose "DONE.\n"
      fi
    else
      RERUN_EXPORT=1 # Forcing rebuild to populate empty directory
    fi
  else
    Verbose "\nNotice: %s does not exist. Creating directory..." "${ABS_CONF_EXPORT_DIR}"
    mkdir "${ABS_CONF_EXPORT_DIR}" || exit 1
    Verbose "DONE.\n"
    if [[ "${RERUN_EXPORT}" == 0 ]]; then
      RERUN_EXPORT=1 # Forcing rebuild to populate directory
    fi
  fi
}
# Resets config directory names/locations
# $1 (int) - Assigned project number from assembled list
# $2 (int) - If 1, output current project messaging
function UpdateConfDirs {
  if [[ $2 == 1 ]]; then
    printf "\n\n%s\n" "$(printf "## Project %d - %s ##" "$1" "${DIR_OPTIONS[$1]}")"
  fi
  SRC_DIR=${DIR_OPTIONS[$1]}
  ABS_SRC_DIR=${GH_PROJECTS_DIR}${SRC_DIR}
}

# SCRIPT OPTIONS
while getopts "cghkrRvVzZ" option; do
  case "${option}" in
  c) # Skip Drush check to see if project is enabled?
    PROJECTS_CHECK=0;;
  g) # Interactive Git branch verification
    VERIFY_GIT_STATUS=1;;
  h) # Outputs help content
    Help;;
  k) # Keep files for manual review
    MANUAL_DIFF_REVIEW=1;;
  r) # Re-run Drush export
    RERUN_EXPORT=1;;
  R) # Re-run Drush export AND create alt copy for comparison/contrast
    RERUN_EXPORT=1
    COPY_EXPORT_START=1;;
  v) # Return script version
    echo "${VERSION}"
    exit 0;;
  V) # Verbose output
    _V=1;;
  z) # Do everything (except clear alt config dir *_start - needs -R)
    MANUAL_DIFF_REVIEW=1
    RERUN_EXPORT=1
    VERIFY_GIT_STATUS=1;;
  Z) # Do everything loudly (except clear alt config dir *_start - needs -R)
    MANUAL_DIFF_REVIEW=1
    RERUN_EXPORT=1
    VERIFY_GIT_STATUS=1
    # shellcheck disable=SC2034
    _V=1;;
  \?) # Default: Invalid option
    Issue "Invalid option. Try -h for help." "${WCT_ERROR}"
    exit 1
    ;;
  esac
done

PrepConfigDir
if [[ ${RERUN_EXPORT} == 1 ]]; then
  Verbose "Drush exporting the local dev site\'s config files into %s...\n" "${ABS_CONF_EXPORT_DIR}"
  cd "${WEB_ROOT}" || exit 1
  drush cex --destination="${RERUN_EXPORT_DIR}"
  echo ""
  # Remove site-specific settings from exported active YMLs
  # https://www.drupal.org/docs/distributions/creating-distributions/how-to-write-a-drupal-installation-profile#s-configuration)
  Verbose "Cleaning out default local site UUIDs, etc. from exported YMLs..."
  find "${ABS_CONF_EXPORT_DIR}"/ -type f -exec sed -i -e '/^uuid: /d' {} \;
  find "${ABS_CONF_EXPORT_DIR}"/ -type f -exec sed -i -e '/_core:/,+1d' {} \;
  Verbose "DONE\n"
  echo ""
  if [[ ${COPY_EXPORT_START} == 1 ]]; then
    if [[ -d "${COPY_EXPORT_START_DIR}" ]]; then
      BarrierMajor
      printf "WARNING: %s already exists with your starting configurations before you started this task.\n" "${COPY_EXPORT_START_DIR}"
      printf "Are you sure you want to overwrite it? (Enter Y to continue): "
      read -r overwrite_start
      if [[ "${overwrite_start}" == "Y" ]]; then
        printf "\nOk - Overwriting %s directory in 3 seconds..." "${COPY_EXPORT_START_DIR}"
        sleep 3
        rm -rf "${COPY_EXPORT_START_DIR}" || exit 1
        cp -pr "${ABS_CONF_EXPORT_DIR}" "${COPY_EXPORT_START_DIR}" || exit 1
        printf "DONE.\n\n"
      else
        printf "Keeping older version of %s.\n" "${COPY_EXPORT_START_DIR}"
      fi
    else
      Verbose "NOTICE: No %s was detected.\n" "${COPY_EXPORT_START_DIR}"
      Verbose "Make sure to create this directory before work on a YML-altering\n"
      Verbose "task was started. If that didn't happen, then be sure to double\n"
      Verbose "check for new YML files created in the active_config directory\n"
      Verbose "and review the Conf sync output in the Drupal UI.\n\n"
      printf "Copying %s over to %s..." "${ABS_CONF_EXPORT_DIR}" "${COPY_EXPORT_START_DIR}"
      cp -pr "${ABS_CONF_EXPORT_DIR}" "${COPY_EXPORT_START_DIR}" || exit 1
      printf "DONE.\n\n"
    fi
  fi
else # Skip all exports
  if [[ "${YML_COUNT}" == 0 ]]; then
    Issue "No YML files exist in ${RERUN_EXPORT_DIR}.\nRe-run with an option that rebuilds the active configs with Drush. Closing." "${WCT_ERROR}"
    exit 1
  else
    Verbose "\n%s YML files found in %s directory, so skipping drush export and cleanup (by default).\n" "${YML_COUNT}" "${CONF_EXPORT_DIR}"
    # shellcheck disable=SC2046
    Verbose " - YMLs last update: $(date -d @$(stat -c '%Y' .))\n"
  fi
fi

# Get and select project directories
cd "${ABS_CONF_EXPORT_DIR}" || exit 1
declare -a DIR_OPTIONS=()
KEY=0
MISSED_KEY=0
for i in "${GH_PROJECTS_DIR}"/* ; do
  if [[ -d "$i" ]]; then
    PROJECT_DIR=$(basename "${i}")
    if [[ $(ProjectVerify "${PROJECT_DIR}") != false ]]; then
      KEY=$((KEY+1))
      if [[ $KEY == 1 ]]; then
        BarrierMajor
        printf "Eligible project(s) found in %s: \n" "${GH_PROJECTS_DIR}"
        BarrierMajor
      fi
      DIR_OPTIONS[$KEY]=$PROJECT_DIR
      printf "%s) %s\n" ${KEY} "${PROJECT_DIR}"
    else
      MISSED_KEY=$((MISSED_KEY+1))
    fi
  fi
done

## Manually add ALL option
KEY=$((KEY+1))
DIR_OPTIONS[$KEY]="ALL"
printf "%s) %s\n" ${KEY} "${DIR_OPTIONS[$KEY]}"
## End Manually add ALL option

[[ ${MISSED_KEY} -gt 0 ]] && Verbose "( Ignored %s incompatible directories )\n" ${MISSED_KEY}
printf "Project's configs to compare (Enter 1-%d)? " "${KEY}"
read -r which_project
if [[ ${DIR_OPTIONS[$which_project]} == '' ]]; then
  Issue "Invalid project selection. Closing..." "${WCT_ERROR}"
  exit 1
elif [[ $which_project == "${KEY}" ]]; then # ALL option
  FIRST_PROJECT=1
  LAST_PROJECT=$((KEY-1)) # Get 'em all
  > "${ALL_DIFFS}"
else # Single project
  FIRST_PROJECT=${which_project}
  LAST_PROJECT="${FIRST_PROJECT}"
fi

# Process each project
for ((i=FIRST_PROJECT; i <= LAST_PROJECT; i++)); do
  UpdateConfDirs "${i}" 1
  BarrierMajor
  # ALL option logging
  [[ $FIRST_PROJECT != "${LAST_PROJECT}" ]] && echo "##NO-PATCH## - Project ${i} of ${LAST_PROJECT}: ${SRC_DIR}" >> "${ALL_DIFFS}"

  if [[ -d ${ABS_SRC_DIR}/config/install ]]; then
    # Check if project is enabled (skipped by default)
    if [[ "${PROJECTS_CHECK}" == 1 ]]; then
      # Get project name from *.info.yml file
      cd "${WEB_ROOT}" || exit 1
      PROJECT_YML_INFO=$(find "${ABS_SRC_DIR}"/ -maxdepth 1 -type f -printf "%f\n" | grep ".info.yml" | sed -r 's/.info.yml//')
      if [[ "${PROJECT_YML_INFO}" != '' ]]; then
        if [[ $(drush pm-list --pipe --status=enabled --type=module --no-core | grep "\(${PROJECT_YML_INFO}\)" | cut -f 3) ]]; then
          Verbose "%s is enabled and will be reviewed.\n" "${PROJECT_YML_INFO}"
        else
          Issue "${PROJECT_YML_INFO} is disabled. "
          # ALL option logging
          if [[ $FIRST_PROJECT == "$LAST_PROJECT" ]]; then
            printf " Closing.\n" && exit 1
          else
            echo "##NO-PATCH## - " "$(Issue "${PROJECT_YML_INFO} is disabled. Skipping gratuitous diff output..." "${WCT_WARNING}" 1)" >> "${ALL_DIFFS}"
            printf " Skipping...\n" && continue
          fi
        fi
      fi
      cd "${ABS_CONF_EXPORT_DIR}" || exit 1
    fi
    # Git branch output information
    cd "${ABS_SRC_DIR}"/config/install || exit 1
    printf "%s\nGit branch: $(git branch --show-current)\n" "${SRC_DIR}"
    TMP_GIT_BRANCH="$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')"
    git fetch origin "${TMP_GIT_BRANCH}" --dry-run -v # Check default project branch for updates
    # Optional Git confirmation step (disabled by default)
    if [[ $VERIFY_GIT_STATUS == 1 ]]; then
      Verbose "\n* IMPORTANT: If the Git output above doesn't say \"[up to date]\", you need to consider pulling and integrating the latest upstream changes "
      Verbose "from %s before continuing...\n" "${TMP_GIT_BRANCH}"
      printf "\n-- Hit Enter/Return to continue (or Ctrl-C to Cancel if you want to change branches, pull remote updates, etc.) ** "
      read -r
    fi
    echo ""
    Verbose "Comparing %s/config/install and %s configs by doing... \n" "${SRC_DIR}" "${CONF_EXPORT_DIR}"
  else
    Issue "The ${SRC_DIR}/config/install folder does not exist. " "${WCT_WARNING}"
    if [[ $FIRST_PROJECT == "$LAST_PROJECT" ]]; then
      printf "Closing.\n" && exit 1
    else
      echo "##NO-PATCH## - " "$(Issue "${SRC_DIR}/config/install folder does not exist. Skipping..." "${WCT_WARNING}" 1)" >> "${ALL_DIFFS}"
      printf "Skipping...\n" && continue
    fi
  fi

  > "${COMMANDS_FILE}"
  > "${DIFFS}"

  Verbose " - 1 of 2) Generating diff commands file %s to be executed in %s/config/install..." "${COMMANDS_FILE}" "${SRC_DIR}"

  # Add newly generated YML files as diffs -- ONCE ONLY
  if [[ $NEW_YMLS_INSERTED == 0 ]]; then
    NEW_YML_FILES=$(LC_ALL=C diff -qr "${COPY_EXPORT_START_DIR}" "${ABS_CONF_EXPORT_DIR}" | grep -E "^Only in ${ABS_CONF_EXPORT_DIR}: .+\.yml$" | sed -e 's/^Only in .*:[[:space:]]*//g')
    if [[ $NEW_YML_FILES != "" ]]; then
      echo "${NEW_YML_FILES}" >> "${COMMANDS_FILE}"
      NEW_YMLS_INSERTED=$((NEW_YMLS_INSERTED+1))
      echo "##NO-PATCH## - " "$(Issue "Added $(echo "${NEW_YML_FILES}" | wc -l) new YML files for review first." "${WCT_OK}" 1)" >> "${ALL_DIFFS}"
    fi
  fi


  # Adding original, existing YML files
  ls -a >> "${COMMANDS_FILE}"

  # Generates new diffs between the module (<) and the current config output (>)
  perl -pi -e 's/^.*(?<!\.yml)$//g' "${COMMANDS_FILE}" && sed -i '/^[[:space:]]*$/d' "${COMMANDS_FILE}" && sed -i '/^[[:blank:]]*$/ d' "${COMMANDS_FILE}"
  perl -pi -e "s!^(.+?)\$!diff -${DIFF_FLAGS} ./\$1 ${ABS_CONF_EXPORT_DIR}/\$1 >> ${DIFFS}!g" "${COMMANDS_FILE}"
  Verbose "DONE\n"
  Verbose " - 2 of 2) Executing diff file %s in %s/config/install..." "${DIFFS}" "${SRC_DIR}"
  bash "${COMMANDS_FILE}"
  Verbose "DONE\n"

  # ALL option logging
  if [[ $FIRST_PROJECT != "${LAST_PROJECT}" ]]; then
    if [[ -s "${DIFFS}" ]]; then # File not empty?
      Verbose " - Adding diff contents to %s" "${ALL_DIFFS}"
      cat "${DIFFS}" >> "${ALL_DIFFS}"
      Verbose "DONE\n\n"
    else
      echo "##NO-PATCH## - " "$(Issue "${DIFFS} is empty - Nothing to add..." "${WCT_OK}" 1)" >> "${ALL_DIFFS}"
    fi
  fi

done

# Open diff (individual or ALL) file for review (if not empty)
BarrierMinor
OUTPUT=$([[ $FIRST_PROJECT != "${LAST_PROJECT}" ]] && echo "${ALL_DIFFS}" || echo "${DIFFS}")
if [[ -s "${OUTPUT}" ]]; then
  Verbose "Opening %s in %s...\n"  "${OUTPUT}" "${TEXT_EDITOR}"
  "${TEXT_EDITOR}" "${OUTPUT}"
  Verbose "Review complete.\n"
else
  Issue "No changes ${OUTPUT} to review. Skipping and deleting all generated diff and command files.\n" "${WCT_OK}"
  MANUAL_DIFF_REVIEW=0
fi
BarrierMinor

## Post-diff review - cleanup
for ((i=FIRST_PROJECT; i <= LAST_PROJECT; i++)); do
  UpdateConfDirs "${i}" 0
  # Optionally keep diff(s) file(s) (disabled by default)
  if [[ ${MANUAL_DIFF_REVIEW} == 1 ]]; then
    [[ $i == "${FIRST_PROJECT}" ]] && echo "The following files were kept for review:"
    echo " - ~/${PROJECTS_DIR}${SRC_DIR}""/config/install/""${DIFFS}"
    echo " - ~/${PROJECTS_DIR}${SRC_DIR}""/config/install/""${COMMANDS_FILE}"
    if [[ $FIRST_PROJECT != "${LAST_PROJECT}" && ${LAST_PROJECT} == "$i" ]]; then
      echo " - ""${ALL_DIFFS}"
      Verbose "Remember to delete these files when done reviewing!\n" "${COMMANDS_FILE}" "${DIFFS}"
    fi
  else
    # Delete all files
    Verbose "Deleting %s, %s files in %s if they exist... " "${COMMANDS_FILE}" "${DIFFS}" ${DIR_OPTIONS[$i]}
    [[ -f "${ABS_SRC_DIR}"/config/install/"${COMMANDS_FILE}" ]] && rm "${ABS_SRC_DIR}"/config/install/"${COMMANDS_FILE}"
    [[ -f "${ABS_SRC_DIR}"/config/install/"${DIFFS}" ]] && rm "${ABS_SRC_DIR}"/config/install/"${DIFFS}"
    if [[ $FIRST_PROJECT != "${LAST_PROJECT}" ]]; then # Delete ALL projects diff
      [[ -f "${ALL_DIFFS}" ]] && rm "${ALL_DIFFS}"
    fi
    Verbose "DONE.\n"
  fi
done

# DONE
printf "\nDONE.\n"
exit
