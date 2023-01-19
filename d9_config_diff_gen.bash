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
function Help() {
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
  echo "  -m - Keep diff and command files for manual review in the /config/install directory of the compared project."
  echo "  -g - Interactively verify Git branch status for each project"
  printf "  -d - Re-run Drush export of active configs into ~/%s \n" "${CONF_EXPORT_DIR}"
  echo "  -b - Blab mode (verbose output)"
  echo "  -z - Extra careful mode"
  echo "  -Z - Extra careful mode (verbose)"
  echo "  -v - Script version"
  echo "  -h - Returns this help message"
  exit 0
}
# Is the project a valid project to check?
function ProjectVerify() { # $1 is passed-in SRC_DIR
  if [[ $1 =~ .*"webspark-module-".* || $1 =~ .*"webspark-theme-".* || $1 =~ .*"webspark-profile-".* ]]; then
    echo "true"
  else
    echo "false"
  fi
}
# Prepare active configs directory
function PrepConfigDir() {
  if [[ -d "${ABS_CONF_EXPORT_DIR}" ]]; then
    find "${ABS_CONF_EXPORT_DIR}" -type f -not -name "*.yml" -exec rm {} \; # Delete non-YML files from config dir
    YML_COUNT=$(find "${ABS_CONF_EXPORT_DIR}" -type f -name "*.yml" 2>/dev/null | wc -l)
    if [[ $YML_COUNT != 0 ]]; then
      if [[ ${RUN_DRUSH_EXPORT} == 1 ]]; then
        Verbose "Emptying %s directory..." "${ABS_CONF_EXPORT_DIR}"
        rm "${ABS_CONF_EXPORT_DIR}"/*
        Verbose "DONE.\n"
      fi
    else
      RUN_DRUSH_EXPORT=1 # Forcing rebuild to populate empty directory
    fi
  else
    Verbose "\nNotice: %s does not exist. Creating directory..." "${ABS_CONF_EXPORT_DIR}"
    mkdir "${ABS_CONF_EXPORT_DIR}" || exit 1
    Verbose "DONE.\n"
    if [[ "${RUN_DRUSH_EXPORT}" == 0 ]]; then
      RUN_DRUSH_EXPORT=1 # Forcing rebuild to populate directory
    fi
  fi
}
function UpdateConfDirs() {
  TMP_CURR_PROJ=$(printf "## Project %d - %s ##" "$1" "${DIR_OPTIONS[$1]}")
  if [[ $2 == 1 ]]; then
    printf "\n\n%s\n" "${TMP_CURR_PROJ}"
  fi
  SRC_DIR=${DIR_OPTIONS[$1]}
  ABS_SRC_DIR=${GH_PROJECTS_DIR}${SRC_DIR}
}

# END FUNCTIONS

# Options
while getopts "bdghmvzZ" option; do
  case "${option}" in
  b) # "Blab" Verbose mode
    _V=1;;
  d) # Re-run Drush export
    RUN_DRUSH_EXPORT=1;;
  g) # Interactive Git branch verification
    VERIFY_GIT=1;;
  h) # Outputs help content
    Help;;
  m) # Keep files for manual review
    MANUAL_DIFF_REVIEW=1;;
  v) # Return version
    echo "${VERSION}"
    exit 0
    ;;
  z) # Do everything
    MANUAL_DIFF_REVIEW=1
    RUN_DRUSH_EXPORT=1
    VERIFY_GIT=1;;
  Z) # Do everything loudly
    MANUAL_DIFF_REVIEW=1
    # shellcheck disable=SC2034
    _V=1
    RUN_DRUSH_EXPORT=1
    VERIFY_GIT=1;;
  \?) # Default: Invalid option
    Issue "Invalid option. Try -h for help." "${WCT_ERROR}"
    exit 1
    ;;
  esac
done

PrepConfigDir
if [[ ${RUN_DRUSH_EXPORT} == 1 ]]; then
  Verbose "Drush exporting the local dev site\'s config files into %s...\n" "${ABS_CONF_EXPORT_DIR}"
  cd "${WEB_ROOT}" || exit 1
  drush cex --destination="${DRUSH_EXPORT_DIR}"
  echo ""
  # Remove site-specific settings from exported active YMLs
  # https://www.drupal.org/docs/distributions/creating-distributions/how-to-write-a-drupal-installation-profile#s-configuration)
  Verbose "YML: Cleaning out default local site UUIDs, etc. from exported YMLs..."
  find "${ABS_CONF_EXPORT_DIR}"/ -type f -exec sed -i -e '/^uuid: /d' {} \;
  find "${ABS_CONF_EXPORT_DIR}"/ -type f -exec sed -i -e '/_core:/,+1d' {} \;
  Verbose "DONE\n"
  echo ""
else
  if [[ "${YML_COUNT}" == 0 ]]; then
    Issue "No YML files exist in ${DRUSH_EXPORT_DIR}.\nRe-run with the -d option to rebuild the active configs with Drush. Closing." "${WCT_ERROR}"
    exit 1
  else
    Verbose "\n%s YML files found in %s directory, so skipping drush export and cleanup (by default).\n" "${YML_COUNT}" "${CONF_EXPORT_DIR}"
    # shellcheck disable=SC2046
    Verbose " - YMLs last update: $(date -d @$(stat -c '%Y' .))\n"
  fi
fi

cd "${ABS_CONF_EXPORT_DIR}" || exit 1

# Get possible project directories from GH_PROJECTS_DIR to select
declare -a DIR_OPTIONS=()
KEY=0
MISSED_KEY=0
for i in "${GH_PROJECTS_DIR}"/* ; do
  if [[ -d "$i" ]]; then
    YML_FILE=$(basename "${i}")
    if [[ $(ProjectVerify "${YML_FILE}") != false ]]; then
      KEY=$((KEY+1))
      if [[ $KEY == 1 ]]; then
        BarrierMajor
        printf "Eligible project(s) found in %s: \n" "${GH_PROJECTS_DIR}"
        BarrierMajor
      fi
      DIR_OPTIONS[$KEY]=$YML_FILE
      printf "%s) %s\n" ${KEY} "${YML_FILE}"
    else
      MISSED_KEY=$((MISSED_KEY+1))
    fi
  fi
done
# Manually add ALL option
KEY=$((KEY+1))
DIR_OPTIONS[$KEY]="ALL"
printf "%s) %s\n" ${KEY} "${DIR_OPTIONS[$KEY]}"

[[ ${MISSED_KEY} -gt 0 ]] && Verbose "(%s incompatible directories were ignored)\n" ${MISSED_KEY}

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
############################### BEGIN for loop

for ((i=FIRST_PROJECT; i <= LAST_PROJECT; i++)); do
  UpdateConfDirs "${i}" 1
  BarrierMajor
  if [[ -d ${ABS_SRC_DIR}/config/install ]]; then
    cd "${ABS_SRC_DIR}"/config/install || exit 1
    printf "%s\nGit branch: $(git branch --show-current)\n" "${SRC_DIR}"
    git fetch origin "$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')" --dry-run -v # Check "master" branch for updates
    if [[ $VERIFY_GIT == 1 ]]; then
      Verbose "\n* IMPORTANT: If the Git output above doesn't say \"\[up to date\]\", you probably need to pull the latest upstream changes down "
      Verbose "from $(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@') before continuing...\n"
      printf "\n-- Hit Enter/Return to continue (or Ctrl-C to Cancel if you want to change branches, pull remote updates, etc.) ** "
      read -r
    else
      sleep 1
    fi
    echo ""
    Verbose "Comparing %s/config/install and %s configs by doing... \n" "${SRC_DIR}" "${CONF_EXPORT_DIR}"
  else
    Issue "The ${SRC_DIR}/config/install folder does not exist. " "${WCT_WARNING}"
    if [[ $FIRST_PROJECT == "$LAST_PROJECT" ]]; then
      printf "Closing.\n" && exit 1
    else
      printf "Skipping...\n"
      continue
    fi
  fi

  # TODO - Way to check for NEW config files in active_configs that are relevant to tested project directory?
  # 1) Maybe look for any files in THE ACTIVE_CONFIGS DIR ${ABS_CONF_EXPORT_DIR} that 1) are NOT in the EXISTING PROJECT ../config directory (assuming no
  # config import has been done on the site since work on new ticket/branch started), and 2) are newer that last Git
  # commit in ${ABS_SRC_DIR}?
  # OR (more reliably)...
  # 2) Create a separate script to dump the configs to an alt tmp directory BEFORE WORK STARTS. Then (in this script) compare
  # directory file lists and manually add the files to ${COMMANDS_FILE} as EITHER:
  #   a) full diff output for each file so it can be used as a patch file, OR
  #   b) diff commands with -q applied (returning "Only in ..." output) to let the dev know to manually copy/paste the new files?

  > "${COMMANDS_FILE}"
  ls -a > "${COMMANDS_FILE}"
  > "${DIFFS}"

  # Generates new diffs between the module (<) and the current config output (>)
  Verbose " - 1 of 2) Generating diff commands file %s to be executed in %s/config/install..." "${COMMANDS_FILE}" "${SRC_DIR}"
  perl -pi -e 's/^.*(?<!\.yml)$//g' "${COMMANDS_FILE}" && sed -i '/^[[:space:]]*$/d' "${COMMANDS_FILE}" && sed -i '/^[[:blank:]]*$/ d' "${COMMANDS_FILE}"
  perl -pi -e "s!^(.+?)\$!diff -uNwEbB ./\$1 ${ABS_CONF_EXPORT_DIR}/\$1 >> ${DIFFS}!g" "${COMMANDS_FILE}"
  Verbose "DONE\n"
  Verbose " - 2 of 2) Executing diff file %s in %s/config/install..." "${DIFFS}" "${SRC_DIR}"
  bash "${COMMANDS_FILE}"
  Verbose "DONE\n"

  # ALL option
  if [[ $FIRST_PROJECT != "${LAST_PROJECT}" ]]; then
    echo "##NO-PATCH## - Project ${i} of ${LAST_PROJECT}: ${SRC_DIR}" >> "${ALL_DIFFS}"
    cat "${DIFFS}" >> "${ALL_DIFFS}"
  fi
done

############################ END FOR LOOP

# Open diffs file for review
Verbose "$(BarrierMinor)"

OUTPUT=$([[ $FIRST_PROJECT != "${LAST_PROJECT}" ]] && echo "${ALL_DIFFS}" || echo "${DIFFS}")
if [[ -s "${OUTPUT}" ]]; then
  Verbose "Opening %s in %s...\n"  "${OUTPUT}" "${TEXT_EDITOR}"
  "${TEXT_EDITOR}" "${OUTPUT}"
  Verbose "Review complete.\n"
else
  Verbose "No changes in diff file to review. Skipping and deleting all generated diff and command files.\n"
  MANUAL_DIFF_REVIEW=0
fi
BarrierMinor

# Post-diff Cleanup
for ((i=FIRST_PROJECT; i <= LAST_PROJECT; i++)); do
  UpdateConfDirs "${i}" 0
  if [[ ${MANUAL_DIFF_REVIEW} == 1 ]]; then
    [[ $i == "${FIRST_PROJECT}" ]] && echo "The following files were kept for review:"
    echo " - ~/${PROJECTS_DIR}${SRC_DIR}""/config/install/""${DIFFS}"
    echo " - ~/${PROJECTS_DIR}${SRC_DIR}""/config/install/""${COMMANDS_FILE}"
    if [[ $FIRST_PROJECT != "${LAST_PROJECT}" && ${LAST_PROJECT} == "$i" ]]; then
      echo " - ""${ALL_DIFFS}"
      Verbose "...Remember to delete these files when done reviewing!\n" "${COMMANDS_FILE}" "${DIFFS}"
    fi
  else
    Verbose "Deleting %s, %s files in %s if they exist... " "${COMMANDS_FILE}" "${DIFFS}" ${DIR_OPTIONS[$i]}
    [[ -f "${ABS_SRC_DIR}"/config/install/"${COMMANDS_FILE}" ]] && rm "${ABS_SRC_DIR}"/config/install/"${COMMANDS_FILE}"
    [[ -f "${ABS_SRC_DIR}"/config/install/"${DIFFS}" ]] && rm "${ABS_SRC_DIR}"/config/install/"${DIFFS}"
    if [[ $FIRST_PROJECT != "${LAST_PROJECT}" ]]; then # Delete ALL projects diff
      [[ -f "${ALL_DIFFS}" ]] && rm "${ALL_DIFFS}"
    fi
    Verbose "DONE.\n"
  fi
done

printf "\nDONE.\n"
exit
