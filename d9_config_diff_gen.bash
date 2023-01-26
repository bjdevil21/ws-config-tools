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
while getopts "cghmprRvVzZ" option; do
  case "${option}" in
  c) # Skip Drush check to see if project is enabled?
    PROJECT_CHECK=0;;
  g) # Interactive Git branch verification
    VERIFY_GIT_STATUS=1;;
  h) # Outputs help content
    Help;;
  m) # Keep generated files for manual review
    MANUAL_DIFF_REVIEW=1;;
  p) # Generate diff that can be applied with 'patch < ${DIFFS}' (or ALL_DIFFS)
    PATCH_MODE=1;;
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
declare -a PATCH_COMMANDS=()
declare -a PATCHES_GENERATED=()

KEY=0
MISSED_KEY=0
for i in "${ABS_PROJECTS_DIR}"/* ; do
  if [[ -d "$i" ]]; then
    PROJECT_DIR=$(basename "${i}")
    if [[ $(ProjectVerify "${PROJECT_DIR}") == 1 ]]; then
      KEY=$((KEY+1))
      if [[ $KEY == 1 ]]; then
        BarrierMajor
        printf "Eligible project(s) found in %s: \n" "${ABS_PROJECTS_DIR}"
        BarrierMajor
      fi
      PROJECTS_AVAILABLE[$KEY]="${PROJECT_DIR}"
      printf "%s) %s\n" ${KEY} "${PROJECT_DIR}"
    else
      MISSED_KEY=$((MISSED_KEY+1))
    fi
  fi
done
# No projects? Die now.
[[ $KEY == 0 ]] && Issue "No projects found in ${ABS_PROJECTS_DIR}. Exiting" "${WCT_ERROR}"

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
  [[ ${PATCH_MODE} == 1 ]] && > "${ALL_DIFFS}"_APPLY.patch
else # Single project
  FIRST_PROJECT=${which_project}
  LAST_PROJECT="${FIRST_PROJECT}"
fi

PrepConfigDirs

# Drush rerun active configs export
if [[ ${RERUN_EXPORT} == 1 ]]; then
  Verbose "Drush exporting the local dev site\'s config files into %s...\n" "${ABS_CONF_EXPORT_DIR}"
  cd "${ABS_WEB_ROOT}" || exit 1
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
    if [[ -d "${COPY_EXPORT_START_DIR}" && $(GetYMLCount "${COPY_EXPORT_START_DIR}") != 0 ]]; then
      BarrierMajor
      printf "WARNING: %s already exists, and presumably has your configurations from before you started this task.\n" "${COPY_EXPORT_START_DIR}"
      printf "Are you sure you want to overwrite it? (Enter Y to continue): "
      read -r overwrite_start
      if [[ "${overwrite_start}" == "Y" ]]; then
        BarrierMajor
        printf "\nOverwriting %s directory in 3 seconds " "${COPY_EXPORT_START_DIR}"
        ConsoleTimer 3 " "
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
      Verbose "WARNING: No %s with YML files detected.\n" "${COPY_EXPORT_START_DIR}"
      Verbose "Make sure to create this directory before work on a YML-altering\n"
      Verbose "task was started. If that didn't happen, then be sure to double\n"
      Verbose "check for new YML files created in the active_config directory\n"
      Verbose "and review the conf sync output in the Drupal UI.\n\n"
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
    Verbose "\nINFO: %s YML files found in %s directory, so skipping drush export and cleanup (by default).\n" "${YML_COUNT}" "${CONF_EXPORT_DIR}"
    # shellcheck disable=SC2046
    Verbose " - YMLs last update: $(date -d @$(stat -c '%Y' .))\n"
  fi
fi

cd "${ABS_CONF_EXPORT_DIR}" || exit 1

# Process each project
for ((i=FIRST_PROJECT; i <= LAST_PROJECT; i++)); do
  UpdateConfDirs "${i}" 1
  BarrierMajor
  # ALL option logging
  [[ $FIRST_PROJECT != "${LAST_PROJECT}" ]] && echo "##NO-PATCH## - Project ${i} of ${LAST_PROJECT}: ${SRC_DIR}" >> "${ALL_DIFFS}"

  # Drush: Check if project is enabled
  if [[ "${PROJECT_CHECK}" == 1 ]]; then
    # Get project name from *.info.yml file
    cd "${ABS_WEB_ROOT}" || exit 1
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

  cd "${ABS_SRC_CONF_DIR}" || exit 1
  # Project's Git branch information for review
  BarrierMajor 1
  GIT_BRANCH="$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')"
  GIT_CURRENT_BRANCH=$(git branch --show-current) || exit 1 # Not a Git project
  printf "%s\nCurrent Git branch: %s\n" "${SRC_DIR}" "${GIT_CURRENT_BRANCH}"

  BarrierMinor

  git fetch origin "${GIT_BRANCH}" --dry-run -v # Check default project branch for updates
  # Optional Git confirmation step
  if [[ $VERIFY_GIT_STATUS == 1 ]]; then
    Verbose "\n* NOTICE: If the Git output above doesn't say \"[up to date]\", consider stopping to pull down and integrate the latest upstream commits. "
    if [[ ${GIT_CURRENT_BRANCH} != "${GIT_BRANCH}" ]]; then
      printf "\n* NOTICE: %s is not on the project's %s branch.\n" "${SRC_DIR}" "${GIT_BRANCH}"
    fi
    printf "\n-- Hit Enter/Return to continue (or Ctrl-C to Cancel if you want to stop... ** "
    read -r
    BarrierMinor
  fi
  # Spawn per-project DIFFS file in ${SRC_DIR}/config/ directory
  > "${DIFFS}"
  echo ""
  printf "Checking configration files...\n"
  FILES_GENERATED+=("${ABS_SRC_CONF_DIR}/${DIFFS}")

  for TYPE in "${!CONF_DIR_TYPES[@]}"; do
    cd "${ABS_SRC_CONF_DIR}" || exit 1
    if [[ -d ./${TYPE} ]]; then
      if [[ $(GetYMLCount "./${TYPE}" gt 0) ]]; then
        cd "${TYPE}" || exit 1
        # Clear and rebuild COMMANDS_FILE for each subdirectory (TYPE)
        > "${COMMANDS_FILE}"
        FILES_GENERATED+=("${ABS_SRC_CONF_DIR}/${TYPE}/${COMMANDS_FILE}")
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
        perl -pi -e "s!^(.+?)\$!diff -${DIFF_FLAGS} ${ABS_SRC_CONF_DIR}/${TYPE}/\$1 ${ABS_CONF_EXPORT_DIR}/\$1 >> ../${DIFFS}!g" "${COMMANDS_FILE}"
        Verbose "DONE\n"
        Verbose " - 2 of 2) Appending new diffs to %s/config/%s..." "${SRC_DIR}" "${DIFFS}"
        bash "${COMMANDS_FILE}"
        Verbose "DONE\n"
      else
        Verbose "The ${SRC_DIR}/config/${TYPE}} folder doesn't have any YML files. Skipping...\n"
      fi
    else # Config subdirectory doesn't exist - skip
      Verbose "INFO: The ${SRC_DIR}/config/${TYPE} folder does not exist. Skipping...\n"
      continue
    fi
  done
  cd "${ABS_SRC_CONF_DIR}" || exit 1

  # TODO check DIFFS to see if empty here (instead of below) and delete now from directory and output list?
  # Would mean associative array vs index array used here

  if [[ -s "${DIFFS}" ]]; then
    # ALL option logging
    if [[ $FIRST_PROJECT != "${LAST_PROJECT}" ]]; then
      Verbose " - Adding all project diff contents to %s..." "${ALL_DIFFS}"
      cat "${DIFFS}" >> "${ALL_DIFFS}"
      Verbose "DONE\n\n"
    fi

    ## PATCH MODE
    if [[ "${PATCH_MODE}" == 1 ]]; then

      Verbose "** PATCH_MODE **\n\n(Experimental) patch file for ${SRC_DIR} being made..."
      cp "${OUTPUT_TOTAL}" "${OUTPUT_TOTAL}_APPLY.patch"
      # Swap files in diff for patching (patch -R reversal option not working, possibly due to different -pN levels)
      perl -0pi -e "s|(\-\-\-\s)(${USER_DIR_ROOT}\N+?)(\n)(\+\+\+\s)(${USER_DIR_ROOT}\N+?)(\n)|"'$1$5$3$4$2$6'"|g" "${OUTPUT_TOTAL}_APPLY.patch"
      Verbose "DONE\n"

      # Generate and store patch command
      IFS='/' read -r -a Nth <<< "${ABS_SRC_CONF_DIR}/"
      PATCHES_GENERATED+=("${ABS_SRC_CONF_DIR}/${DIFFS}")
      PATCH_COMMANDS+=("$(printf "patch -d %s -p%d -Er ./ < %s_APPLY.patch\n" "${ABS_SRC_CONF_DIR}" "${#Nth[@]}" "${OUTPUT_TOTAL}")")

      # ALL option logging TODO remove after other patch work is done
      if [[ $FIRST_PROJECT != "${LAST_PROJECT}" ]]; then
        cat "${OUTPUT_TOTAL}_APPLY.patch" >> "${ALL_DIFFS}_APPLY.patch"
      fi
    fi

  else
    # TODO Single project "is empty" response?
   [[ $FIRST_PROJECT != "${LAST_PROJECT}" ]] && echo "##NO-PATCH## - $(Issue "${DIFFS} is empty - Nothing to add..." "${WCT_OK}" 1 )" >> "${ALL_DIFFS}"
  fi
done

# Settings INIT for output
# ALL option logging
if [[ $FIRST_PROJECT != "${LAST_PROJECT}" ]]; then
  FILES_GENERATED+=("${ALL_DIFFS}")
  OUTPUT="${ALL_DIFFS}"
  OUTPUT_TOTAL="${OUTPUT}"
else
  OUTPUT="${DIFFS}"
  OUTPUT_TOTAL="${ABS_SRC_CONF_DIR}/${DIFFS}"
fi

# Open diff (individual or ALL) file in TEXT_EDITOR for review
if [[ -s "${OUTPUT_TOTAL}" ]]; then
  Verbose "\nOpening %s in %s...\n"  "${OUTPUT}" "${TEXT_EDITOR}"
  "${TEXT_EDITOR}" "${OUTPUT_TOTAL}"
  Verbose "Review complete.\n"
else
  Issue "No changes in ${OUTPUT} to review. Skipping... and deleting all generated diff and command files." "${WCT_OK}"
  [[ "${PATCH_MODE}" == 1 ]] && Verbose "No patch to be made. Skipping...\n" && PATCH_MODE=0
  MANUAL_DIFF_REVIEW=0
fi

# Final _ALL patch cleanup
if [[ "${PATCH_MODE}" == 1 ]]; then
  BarrierMajor 3
# TODO output all patch commands at the end
# Create for loop instead of single printf from PATCH_COMMANDS
  for ((i=0; i <= ${#PATCH_COMMANDS[@]}; i++)); do
    [[ $i == 0 ]] && echo "The following patch command(s) can apply per-project changes:" && echo ""
    if [[ -f "${PATCHES_GENERATED[$i]}" ]]; then
      printf " * %s\n" "${PATCH_COMMANDS[$i]}"
    fi
  done

  if [[ $FIRST_PROJECT != "${LAST_PROJECT}" && -f "${OUTPUT_TOTAL}_APPLY.patch" ]]; then
    # Clean out junk comments from _ALL .patch file
    sed -i -e 's|^##NO-PATCH##.*$||g' "${OUTPUT_TOTAL}_APPLY.patch" && sed -i '/^[[:space:]]*$/d' "${OUTPUT_TOTAL}_APPLY.patch" && sed -i '/^[[:blank:]]*$/ d' "${OUTPUT_TOTAL}_APPLY.patch"
  fi
  Verbose "\nWARNING: REVIEW ANY PATCHES BEFORE APPLYING! * Don't play around and find out. * \n"
  BarrierMajor 3
fi

## Post-diff review - cleanup
###############################
echo ""
if [[ ${#FILES_GENERATED[@]} -ge 1 ]]; then
  if [[ ${MANUAL_DIFF_REVIEW} == 1 ]]; then
    MESSAGE="The following files were kept for review (until the next time this script is run):"
    CLEANUP='echo'
    [[ "${PATCH_MODE}" == 1 && -f "${OUTPUT_TOTAL}" ]] && FILES_GENERATED+=("${OUTPUT_TOTAL}_APPLY.patch")
  else
    MESSAGE=$(printf "Deleting generated files")
    [[ "${PATCH_MODE}" == 1 && -f "${OUTPUT_TOTAL}" ]] && MESSAGE="${MESSAGE} (except for ${OUTPUT}_APPLY.patch)"
    MESSAGE="${MESSAGE}..."
    CLEANUP='rm -v'
  fi
  for ((i=0; i <= ${#FILES_GENERATED[@]}; i++)); do
    [[ $i == 0 ]] && echo "${MESSAGE}"
    if [[ -f "${FILES_GENERATED[$i]}" && ( ${MANUAL_DIFF_REVIEW} == 1 || $_V == 1 ) ]]; then
      $(echo "${CLEANUP}") "${FILES_GENERATED[$i]}"
    fi
  done
fi


echo "DONE."
exit 0
