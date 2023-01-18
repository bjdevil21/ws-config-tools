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

source ./lib/global.bash || exit 1
BashVersionCheck 4 3
UserRootDirCheck
source ./etc/d9_config_diff_gen.settings || exit 1
. "${USER_DIR_ROOT}"/.bashrc  # Bash FYI - . is the same as source

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
  printf "  -d - Re-run Drush export of active configs into ~/%s \n" "${CONF_EXPORT_DIR}"
  echo "  -b - Blab mode (verbose) output"
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
    YML_COUNT=$(expr "$(find "${ABS_CONF_EXPORT_DIR}" -type f -name "*.yml" 2>/dev/null | wc -l)")
    if [[ $YML_COUNT != 0 ]]; then
      if [[ ${RUN_DRUSH_EXPORT} == 1 ]]; then
        Log "Emptying %s directory..." "${ABS_CONF_EXPORT_DIR}"
        rm "${ABS_CONF_EXPORT_DIR}"/*
        Log "DONE.\n"
      fi
    else
      RUN_DRUSH_EXPORT=1 # Forcing rebuild to populate directory
    fi
  else
    Log "Notice: %s does not exist. Creating directory..." "${ABS_CONF_EXPORT_DIR}"
    mkdir "${ABS_CONF_EXPORT_DIR}" || exit 1
    Log "DONE.\n"
    if [[ "${RUN_DRUSH_EXPORT}" == 0 ]]; then
      RUN_DRUSH_EXPORT=1 # Forcing rebuild to populate directory
    fi
  fi
}

# Options
while getopts "bdmvh" option; do
  case "${option}" in
  m) # Keep files for manual review
    MANUAL_DIFF_REVIEW=1;;
  b) # "Blab" Verbose mode
    _V=1;;
  d) # Re-run Drush export
    RUN_DRUSH_EXPORT=1;;
  v) # Return version
    echo "${VERSION}"
    exit 0
    ;;
  h)
    Help;;
  \?) # Default: Invalid option
    printf "ERROR: Invalid option. Try -h for help.\n"
    exit 1
    ;;
  esac
done

PrepConfigDir

if [[ ${RUN_DRUSH_EXPORT} == 1 ]]; then
  Log "Drush exporting the local dev site\'s config files into %s...\n" "${ABS_CONF_EXPORT_DIR}"
  cd "${WEB_ROOT}" || exit 1
  drush cex --destination="${DRUSH_EXPORT_DIR}"
  echo ""
  # Remove site-specific settings from exported active YMLs
  # https://www.drupal.org/docs/distributions/creating-distributions/how-to-write-a-drupal-installation-profile#s-configuration)
  Log "Cleaning out default local site configs from exported YMLs..."
  find "${ABS_CONF_EXPORT_DIR}"/ -type f -exec sed -i -e '/^uuid: /d' {} \;
  find "${ABS_CONF_EXPORT_DIR}"/ -type f -exec sed -i -e '/_core:/,+1d' {} \;
  Log "DONE\n"
  echo ""
else
  if [[ "${YML_COUNT}" == 0 ]]; then
    printf "ERROR: No YML files exist in %s.\nRe-run with the -d option to rebuild the active configs with Drush. Closing.\n" ${DRUSH_EXPORT_DIR} && exit 1
  else
    Log "%s YML files found in export directory, so skipping drush export and cleanup (by default).\n" ${YML_COUNT}
    Log "Note: YMLs directory last updated on $(date -d @$(stat -c '%Y' .)).\n"
  fi
fi

Log "Moving to %s..." "${ABS_CONF_EXPORT_DIR}"
cd "${ABS_CONF_EXPORT_DIR}" || exit 1
Log "DONE\n"

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
        printf "Eligible project(s) found in %s: \n" "${GH_PROJECTS_DIR}"
      fi
      DIR_OPTIONS[$KEY]=$YML_FILE
      printf "%s) %s\n" ${KEY} "${YML_FILE}"
    else
      MISSED_KEY=$((MISSED_KEY+1))
    fi
  fi
done

# @TODO - Add "look for ALL projects" option?

[[ ${MISSED_KEY} -gt 0 ]] && Log "NOTE: %s incompatible directories were ignored.\n" ${MISSED_KEY} # If/then shorthand
printf "Project's configs to compare (Enter 1-%d)? " "${KEY}"
read -r which_project
if [[ ${DIR_OPTIONS[$which_project]} == '' ]]; then
  printf "ERROR: Invalid project selection. Closing...\n"
  exit 1
fi
SRC_DIR=${DIR_OPTIONS[$which_project]}
ABS_SRC_DIR=${GH_PROJECTS_DIR}${SRC_DIR}

if [[ -d ${ABS_SRC_DIR}/config/install ]]; then
  cd "${ABS_SRC_DIR}"/config/install || exit 1
  echo "============================"
  printf "%s\nGit branch: $(git branch --show-current)\n" "${SRC_DIR}"
  printf "Hit Return/Enter to continue (or Ctrl-C to stop and change Git branches): \n"
  read -r GitStop

  Log "Comparing %s and %s configs by... \n" "${SRC_DIR}" "${CONF_EXPORT_DIR}"
else
  printf "ERROR: The %s/config/install folder does not exist. Closing...\n" "${ABS_SRC_DIR}"
  exit 1
fi

# Regenerate new diff files
# @TODO - Way to check for NEW config files in active_configs that are relevant to tested project directory?
# Maybe look for any files in THE ACTIVE_CONFIGS DIR ${ABS_CONF_EXPORT_DIR} that 1) are NOT in the EXISTING PROJECT ../config directory (assuming no
# config import has been done on the site since work on new ticket/branch started), and 2) are newer that last Git
# commit in ${ABS_SRC_DIR}?
#

> "${COMMANDS_FILE}"
ls -a > "${COMMANDS_FILE}"
> "${DIFFS}"

# Generates new diffs between the module (<) and the current config output (>)
Log "1 of 2) Generating diff commands file %s to be executed in %s/config/install..." "${COMMANDS_FILE}" "${SRC_DIR}"
perl -pi -e 's/^.*(?<!\.yml)$//g' "${COMMANDS_FILE}" && sed -i '/^[[:space:]]*$/d' "${COMMANDS_FILE}" && sed -i '/^[[:blank:]]*$/ d' "${COMMANDS_FILE}"
perl -pi -e "s!^(.+?)\$!diff -uNwEbB ./\$1 ${ABS_CONF_EXPORT_DIR}/\$1 >> ${DIFFS}!g" "${COMMANDS_FILE}"
Log "DONE\n"
Log "2 of 2) Generating diff file %s in %s/config/install..." "${DIFFS}" "${SRC_DIR}"
bash "${COMMANDS_FILE}"
printf "DONE\n"

# Open diffs file for review.
Log "Opening %s in %s...\n" "${DIFFS}" "${TEXT_EDITOR}"
"${TEXT_EDITOR}" "${DIFFS}"

echo "Review complete."
echo "----------------------------"

if [[ ${MANUAL_DIFF_REVIEW} == 1 ]]; then
  printf "** %s (and %s), and the active_configs are in ~/%s and ~/%s for manual review, respectively.\n" "${DIFFS}" "${COMMANDS_FILE}" "${PROJECTS_DIR}${SRC_DIR}" "${CONF_EXPORT_DIR}"
  Log "Remember to delete these files manually when review is done!\n" "${COMMANDS_FILE}" "${DIFFS}"
else
  printf "Deleting %s, %s files if they exist..." "${COMMANDS_FILE}" "${DIFFS}"
  [[ -f "${ABS_SRC_DIR}"/config/install/"${COMMANDS_FILE}" ]] && rm "${ABS_SRC_DIR}"/config/install/"${COMMANDS_FILE}"
  [[ -f "${ABS_SRC_DIR}"/config/install/"${DIFFS}" ]] && rm "${ABS_SRC_DIR}"/config/install/"${DIFFS}"
  printf "DONE.\n"
  Log "Use -m next time to save those files for a manual review, if desired.\n"
fi
exit
