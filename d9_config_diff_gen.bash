#!/usr/bin/env bash
#############################
# Webspark 2 configuration file diff checker
# See README.md for help with settings.
# See Help() on script usage.
##############################

# SETUP
# shellcheck disable=SC2188
source ./lib/global.bash || exit 1
BashVersionCheck 4 3
UserRootDirCheck
source ./lib/d9_config_diff_gen.settings || exit 1
source ./lib/d9_config_diff_gen.functions || exit 1
. "${USER_DIR_ROOT}"/.bashrc  # Bash FYI - . is the same as source

# OPTIONS
while getopts "cghmrRvVzZ" option; do
  case "${option}" in
  c) # Skip Drush check to see if project is enabled?
    PROJECT_CHECK=0;;
  g) # Interactive Git branch verification
    VERIFY_GIT_STATUS=1;;
  h) # Outputs help content
    Help;;
  m) # Keep generated files for manual review
    MANUAL_DIFF_REVIEW=1;;
  r) # Re-run Drush export
    RERUN_EXPORT=1;;
  R) # Re-run Drush export AND create alt copy for YML file comparison/contrast. (Run this before every task/ticket is started.)
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

# EXEC
# Get and select project directories
declare -a PROJECTS_AVAILABLE=()
declare -a FILES_GENERATED=()
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
      PROJECTS_AVAILABLE[$KEY]=$PROJECT_DIR
      printf "%s) %s\n" ${KEY} "${PROJECT_DIR}"
    else
      MISSED_KEY=$((MISSED_KEY+1))
    fi
  fi
done
KEY=$((KEY+1)) ## Manually add ALL option
PROJECTS_AVAILABLE[$KEY]="ALL"
printf "%s) %s\n" ${KEY} "${PROJECTS_AVAILABLE[$KEY]}"

[[ ${MISSED_KEY} -gt 0 ]] && Verbose "\n( Ignored %s incompatible directories )\n\n" ${MISSED_KEY}
printf "Project's configs to compare (Enter 1-%d)? " "${KEY}"
read -r which_project
if [[ ${PROJECTS_AVAILABLE[$which_project]} == '' ]]; then
  Issue "Invalid project selection. Closing..." "${WCT_ERROR}"
  exit 1
elif [[ $which_project == "${KEY}" ]]; then # ALL option
  FIRST_PROJECT=1
  LAST_PROJECT=$((KEY-1)) # Get 'em all
  # shellcheck disable=SC2153
  > "${ALL_DIFFS}"
else # Single project
  FIRST_PROJECT=${which_project}
  LAST_PROJECT="${FIRST_PROJECT}"
fi

PrepConfigDir

# Drush rerun active configs export
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
        BarrierMajor
        printf "\nOk - Overwriting %s directory in 3 seconds..." "${COPY_EXPORT_START_DIR}"
        sleep 3
        rm -rf "${COPY_EXPORT_START_DIR}" || exit 1
        cp -pr "${ABS_CONF_EXPORT_DIR}" "${COPY_EXPORT_START_DIR}" || exit 1
        printf "DONE.\n\n"
        BarrierMajor
      else
        BarrierMinor
        printf "NOTICE: Keeping older version of %s.\n" "${COPY_EXPORT_START_DIR}"
        BarrierMinor
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

cd "${ABS_CONF_EXPORT_DIR}" || exit 1

#################################### BEGIN FOR LOOP
# Process each project
for ((i=FIRST_PROJECT; i <= LAST_PROJECT; i++)); do
  UpdateConfDirs "${i}" 1
  BarrierMajor
  # ALL option logging
  [[ $FIRST_PROJECT != "${LAST_PROJECT}" ]] && echo "##NO-PATCH## - Project ${i} of ${LAST_PROJECT}: ${SRC_DIR}" >> "${ALL_DIFFS}"

  # Drush: Check if project is enabled
  if [[ "${PROJECT_CHECK}" == 1 ]]; then
    # Get project name from *.info.yml file
    cd "${WEB_ROOT}" || exit 1
    PROJECT_YML_INFO=$(find "${ABS_SRC_DIR}"/ -maxdepth 1 -type f -printf "%f\n" | grep ".info.yml" | sed -r 's/.info.yml//')
    if [[ "${PROJECT_YML_INFO}" != '' ]]; then
      if [[ $(drush pm-list --pipe --status=enabled --type=module --no-core | grep "\(${PROJECT_YML_INFO}\)" | cut -f 3) ]]; then
        Verbose "Drush check: %s is enabled.\n" "${PROJECT_YML_INFO}"
      else
        Issue "${PROJECT_YML_INFO} is disabled. " "${WCT_WARNING}"
        # ALL option logging
        if [[ $FIRST_PROJECT != "$LAST_PROJECT" ]]; then
          echo "##NO-PATCH## - " "$(Issue "${PROJECT_YML_INFO} is disabled. Skipping gratuitous diff output..." "${WCT_WARNING}" 1)" >> "${ALL_DIFFS}"
          printf "Skipping...\n" && continue
        else
          printf "Closing.\n" && exit 1
        fi
      fi
    fi
  fi

  if [[ -d ${ABS_SRC_DIR}/config/ ]]; then
    cd "${ABS_SRC_DIR}/config" || exit 1
    # Project's Git branch information for review
    printf "%s\nGit branch: $(git branch --show-current)\n" "${SRC_DIR}"
    GIT_BRANCH="$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')"
    git fetch origin "${GIT_BRANCH}" --dry-run -v # Check default project branch for updates
    # Optional Git confirmation step
    if [[ $VERIFY_GIT_STATUS == 1 ]]; then
      Verbose "\n* IMPORTANT: If the Git output above doesn't say \"[up to date]\", you need to consider pulling and integrating the latest upstream changes "
      Verbose "from %s before continuing...\n" "${GIT_BRANCH}"
      printf "\n-- Hit Enter/Return to continue (or Ctrl-C to Cancel if you want to change branches, pull remote updates, etc.) ** "
      read -r
    fi
    # Spawn per-project DIFFS file in ${SRC_DIR}/config/ directory
    > "${DIFFS}"
    echo ""
    FILES_GENERATED+=("${ABS_SRC_DIR}/config/${DIFFS}")

    for TYPE in "${!CONF_DIR_TYPES[@]}"; do
      cd "${ABS_SRC_DIR}/config" || exit 1
      if [[ -d ./${TYPE} ]]; then
        if [[ $(ls -A ./"${TYPE}" | grep -E "^.+\.yml$") ]]; then
          cd "${TYPE}" || exit 1
          # Clear and rebuild COMMANDS_FILE for each subdirectory (TYPE)
          > "${COMMANDS_FILE}"
          FILES_GENERATED+=("${ABS_SRC_DIR}/config/${TYPE}/${COMMANDS_FILE}")
          Verbose "\n"
          Verbose "Comparing %s/config/%s and %s configs by:\n" "${SRC_DIR}" "${TYPE}" "${CONF_EXPORT_DIR}"
          Verbose " - 1 of 2) Generating %s in %s/config/%s..." "${COMMANDS_FILE}" "${SRC_DIR}" "${TYPE}"
          # Add newly generated YML files as diffs -- ONCE ONLY
          if [[ $NEW_YMLS_INSERTED == 0 ]]; then
            NEW_YML_FILES=$(LC_ALL=C diff -qr "${COPY_EXPORT_START_DIR}" "${ABS_CONF_EXPORT_DIR}" | grep -E "^Only in ${ABS_CONF_EXPORT_DIR}: .+\.yml$" | sed -e 's/^Only in .*:[[:space:]]*//g')
            if [[ $NEW_YML_FILES != "" ]]; then
              echo "${NEW_YML_FILES}" >> "${COMMANDS_FILE}"
              NEW_YMLS_INSERTED=$((NEW_YMLS_INSERTED+1))
              NEW_YML_FILES=''
              # ALL option logging
              [[ $FIRST_PROJECT != "${LAST_PROJECT}" ]] && echo "##NO-PATCH## - " "$(Issue "Added $(echo "${NEW_YML_FILES}" | wc -l) new YML files for review first." "${WCT_OK}" 1)" >> "${ALL_DIFFS}"
            fi
          fi
          # Adding original, existing YML files
          ls -a >> "${COMMANDS_FILE}"
          # Generates new diffs between the module (<) and the current config output (>)
          perl -pi -e 's/^.*(?<!\.yml)$//g' "${COMMANDS_FILE}" && sed -i '/^[[:space:]]*$/d' "${COMMANDS_FILE}" && sed -i '/^[[:blank:]]*$/ d' "${COMMANDS_FILE}"
          perl -pi -e "s!^(.+?)\$!diff -${DIFF_FLAGS} ${ABS_SRC_DIR}/config/${TYPE}/\$1 ${ABS_CONF_EXPORT_DIR}/\$1 >> ../${DIFFS}!g" "${COMMANDS_FILE}"
          Verbose "DONE\n"
          Verbose " - 2 of 2) Appending new diffs to %s/config/%s..." "${SRC_DIR}" "${DIFFS}"
          bash "${COMMANDS_FILE}"
          Verbose "DONE\n"
        else
          Verbose "The ${SRC_DIR}/config/${TYPE}} folder doesn't have any YML files. Skipping...\n"
        fi
      else # Config subdirectory doesn't exist - skip
        Verbose "The ${SRC_DIR}/config/${TYPE} folderrrr does not exist. Skipping...\n"
        continue
      fi
    done
    cd "${ABS_SRC_DIR}/config" || exit 1
    # ALL option logging
    if [[ $FIRST_PROJECT != "${LAST_PROJECT}" ]]; then
      if [[ -s "${DIFFS}" ]]; then # Are there diffs to add in any of the project?
        Verbose " - Adding all project diff contents to %s..." "${ALL_DIFFS}"
        cat "${DIFFS}" >> "${ALL_DIFFS}"
        Verbose "DONE\n\n"
      else
        echo "##NO-PATCH## - $(Issue "${DIFFS} is empty - Nothing to add..." "${WCT_OK}" 1 )" >> "${ALL_DIFFS}"
      fi
    fi
  else # Config directory doesn't exist - Skip project
    Issue "The ${SRC_DIR}/config folder does not exist. " "${WCT_WARNING}"
    if [[ $FIRST_PROJECT == "$LAST_PROJECT" ]]; then
      printf "Closing.\n" && exit 1
    else
      # ALL option logging
      echo "##NO-PATCH## - " "$(Issue "${SRC_DIR}/config folder does not exist. Skipping..." "${WCT_WARNING}" 1)" >> "${ALL_DIFFS}"
      printf "Skipping...\n" && continue
    fi
  fi
done
# ALL option logging
[[ $FIRST_PROJECT != "${LAST_PROJECT}" ]] && FILES_GENERATED+=("${ALL_DIFFS}")

# Open diff (individual or ALL) file in TEXT_EDITOR for review
[[ $FIRST_PROJECT != "${LAST_PROJECT}" ]] && OUTPUT="${ALL_DIFFS}" || OUTPUT="${DIFFS}"
if [[ -s "${OUTPUT}" ]]; then
  Verbose "\nOpening %s in %s...\n"  "${OUTPUT}" "${TEXT_EDITOR}"
  "${TEXT_EDITOR}" "${OUTPUT}"
  Verbose "Review complete.\n"
else
  Issue "No changes in ${OUTPUT} to review. Skipping and deleting all generated diff and command files." "${WCT_OK}"
  MANUAL_DIFF_REVIEW=0
fi

## Post-diff review - cleanup
###############################
BarrierMajor 3
if [[ ${#FILES_GENERATED[@]} -ge 1 ]]; then
  if [[ ${MANUAL_DIFF_REVIEW} == 1 ]]; then
    MESSAGE="The following files were kept for review:"
    CLEANUP='echo'
  else
    MESSAGE=$(printf "Deleting generated files...\n")
    CLEANUP='rm -v'
  fi
  for ((i=0; i <= ${#FILES_GENERATED[@]}; i++)); do
    [[ $i == 0 ]] && echo "${MESSAGE}"
    if [[ -f "${FILES_GENERATED[$i]}" ]]; then
      $(echo "${CLEANUP}") "${FILES_GENERATED[$i]}"
    fi
  done
fi

# DONE
BarrierMajor 3
echo "DONE."
exit
