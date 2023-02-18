#!/usr/bin/env bash
#############################
# Webspark 2 configuration file diff checker
# See README.md for help with settings.
# See Help() on script usage.
##############################

# SETUP
# shellcheck disable=SC2188
source ./lib/_global.bash || exit 1
BashVersionCheck 4 3
UserRootDirCheck
source ./lib/config_diffs.settings || exit 1
source ./lib/config_diffs.functions || exit 1
. "${USER_DIR_ROOT}"/.bashrc  # Bash FYI - . is the same as source

# OPTIONS
while getopts "ghmpPrRSvVzZ" option; do
  case "${option}" in
  g) # Interactive Git branch verification
    VERIFY_GIT_STATUS=1;;
  h) # Outputs help content
    Help;;
  m) # Keep generated files for manual review
    MANUAL_DIFF_REVIEW=1;;
  p) # Generate patch files from diffs (use 'patch < $<<diffs-file>>
    PATCH_MODE=1;;
  P) # Clean out all existing .patch files
    PATCH_MODE=-1;;
  r) # Re-run Drush export
    RERUN_EXPORT=1;;
  R) # Re-run Drush export AND create alt copy for YML file comparison/contrast. (Run this before every task/ticket is started.)
    RERUN_EXPORT=1
    # shellcheck disable=SC2034
    COPY_EXPORT_START=1;;
  S) # Skip Drush check to see if project is enabled?
    PROJECT_CHECK=0;;
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
    # shellcheck disable=SC2034
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

# Random tasks that don't need any project generation, etc. Usually exits script gracefully.
NonDiffsTasks

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

# No projects == exit
[[ $KEY == 0 ]] && Issue "No projects found in ${ABS_PROJECTS_DIR}. Exiting...\n" "${WCT_ERROR}" && exit 1

KEY=$((KEY+1)) ## Manually add ALL option
PROJECTS_AVAILABLE[$KEY]="ALL"
printf "%s) %s\n" ${KEY} "${PROJECTS_AVAILABLE[$KEY]}"

[[ ${MISSED_KEY} -gt 0 ]] && Verbose "\n** NOTE: ( Ignored %s incompatible directories )\n\n" ${MISSED_KEY}
printf "Project's configs to compare (Enter 1-%d)? " "${KEY}"
read -r which_project
if [[ -z ${PROJECTS_AVAILABLE[$which_project]} ]]; then # is empty?
  Issue "Invalid project selection. Closing..." "${WCT_ERROR}"
  exit 1
elif [[ $which_project == "${KEY}" ]]; then # Last (i.e. ALL) option
  FIRST_PROJECT=1
  LAST_PROJECT=$((KEY-1)) # Get 'em all
  # shellcheck disable=SC2153
  > "${ALL_DIFFS}"
  FILES_GENERATED+=("${ALL_DIFFS}")
  [[ ${PATCH_MODE} == 1 ]] && > "${ALL_DIFFS}${PATCH_SUFFIX}"
else # Single project
  FIRST_PROJECT=${which_project}
  LAST_PROJECT="${FIRST_PROJECT}"
fi

# Conf directories
PrepConfigDirs

# Initialize for modified YML file check
> "${SCRIPT_ROOT}/_covered_unsorted_ymls.tmp"
> "${SCRIPT_ROOT}/_covered_ymls.tmp"

cd "${ABS_CONF_EXPORT_DIR}" || exit 1

# Process each project
for ((i=FIRST_PROJECT; i <= LAST_PROJECT; i++)); do
  UpdateProjDirPaths "${i}" 1
  BarrierMajor
  # ALL projects logging
  [[ $FIRST_PROJECT != "${LAST_PROJECT}" ]] && echo "##NO-PATCH## - Project ${i} of ${LAST_PROJECT}: ${PROJ_DIR}" >> "${ALL_DIFFS}"

  # Drush: Check if project is enabled
  if [[ "${PROJECT_CHECK}" == 1 ]]; then
    # Get project name from *.info.yml file
    cd "${ABS_WEB_ROOT}" || exit 1
    PROJECT_YML_INFO=$(find "${ABS_PROJ_DIR}"/ -maxdepth 1 -type f -printf "%f\n" | grep ".info.yml" | sed -r 's/.info.yml//')
    if [[ -n "${PROJECT_YML_INFO}" ]]; then # Project exists; -n equivalent as != ''
      if [[ $(drush pm-list --pipe --status=enabled --type=module --no-core | grep "\(${PROJECT_YML_INFO}\)" | cut -f 3) ]]; then
        Verbose "Drush check: %s is enabled.\n" "${PROJECT_YML_INFO}"
      else
        Issue "${PROJECT_YML_INFO} is disabled. " "${WCT_WARNING}"
        # ALL projects logging
        if [[ $FIRST_PROJECT != "$LAST_PROJECT" ]]; then
          echo "##NO-PATCH## - $(Issue "${PROJECT_YML_INFO} is disabled. Skipping gratuitous diff output..." "${WCT_WARNING}" 1)" >> "${ALL_DIFFS}"
          printf "Skipping...\n" && continue
        else
          printf "Closing.\n" && exit 1
        fi
      fi
    fi
  fi
  cd "${ABS_PROJ_CONF_DIR}" || exit 1

  ## Each project's Git branch review
  BarrierMajor 1
  GIT_BRANCH="$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')"
  GIT_CURRENT_BRANCH=$(git branch --show-current) || exit 1 # Not a Git project
  printf "%s\nCurrent Git branch: %s\n" "${PROJ_DIR}" "${GIT_CURRENT_BRANCH}"
  BarrierMinor

  ### Check default project branch for updates
  if [[ ${GIT_CURRENT_BRANCH} != "${GIT_BRANCH}" ]]; then
    printf "NOTICE: %s is not on the project's %s branch for this comparison.\n" "${PROJ_DIR}" "${GIT_BRANCH}"
    [[ $VERIFY_GIT_STATUS == 1 ]] && ConfirmToContinue
  fi
  GIT_MASTER_STATUS=$(git fetch origin "${GIT_BRANCH}" --dry-run -v 2>&1)
  GIT_MATCH=$(echo "${GIT_MASTER_STATUS}" | grep -i -E "\[up.to.date\]\s+${GIT_BRANCH}\s+")
  if [[ ${GIT_MATCH} =~ "up to date" ]]; then
    printf "OK: Project's %s branch up to date with remote.\n" "${GIT_BRANCH}"
  else
    Issue "${GIT_BRANCH} isn't up to date with remote project. Pull down and merge ${GIT_BRANCH} updates ASAP." "${WCT_WARNING}"
    echo "${GIT_MASTER_STATUS}"
    [[ $VERIFY_GIT_STATUS == 1 ]] && ConfirmToContinue
  fi

  ## Spawn per-project DIFFS file in ${PROJ_DIR}/config/ directory
  > "${DIFFS}"
  echo ""
  printf "Checking configration files...\n"
  FILES_GENERATED+=("${ABS_PROJ_CONF_DIR}/${DIFFS}")

  ## Check three different possible conf directories
  for TYPE in "${!CONF_DIR_TYPES[@]}"; do
    cd "${ABS_PROJ_CONF_DIR}" || exit 1
    if [[ -d ./${TYPE} ]]; then
      if [[ $(GetYMLData "./${TYPE}" 1) != 0 ]]; then
        cd "${TYPE}" || exit 1
        ### Clear and rebuild COMMANDS_FILE for each subdirectory (TYPE)
        > "${COMMANDS_FILE}"
        # Add existing and modified project YML files for processing ...
        ls -A >> "${COMMANDS_FILE}" # in this loop run
        ls -A >> "${SCRIPT_ROOT}/_covered_unsorted_ymls.tmp" # later
        ################
        GenerateDiffs "${ABS_CONF_EXPORT_DIR}" "${ABS_PROJ_CONF_DIR}" "${COMMANDS_FILE}" "${CONF_EXPORT_DIR}" "${DIFFS}" "${PROJ_DIR}" "${TYPE}"
        ################
      else
        Verbose "The ${PROJ_DIR}/config/${TYPE}} folder doesn't have any YML files. Skipping...\n"
      fi
    else # Config subdirectory doesn't exist - skip
      Verbose "INFO: The ${PROJ_DIR}/config/${TYPE} folder does not exist. Skipping...\n"
      continue
    fi
  done
  cd "${ABS_PROJ_CONF_DIR}" || exit 1

  GenerateOptionalDiffs "${ABS_PROJ_CONF_DIR}" ''

done

# Settings for output
# ALL projects logging
if [[ $FIRST_PROJECT != "${LAST_PROJECT}" ]]; then
  OUTPUT="${ALL_DIFFS}"
  OUTPUT_TOTAL="${OUTPUT}"
else
  OUTPUT="${DIFFS}"
  OUTPUT_TOTAL="${ABS_PROJ_CONF_DIR}/${DIFFS}"
fi

# BEGIN Run only once (ROO)
> "${COMMANDS_FILE}.ROO.new.bash"
YML_FILES=$(LC_ALL=C diff -qr "${COPY_EXPORT_START_DIR}" "${ABS_CONF_EXPORT_DIR}")

# TODO combine 1 and 2 into single function?

##------------------ Catch-all 1 of 2) Pull in newly generated YML files to add them
NEW_YML_FILES=$(echo "${YML_FILES}" | \
  grep -E "^Only in ${ABS_CONF_EXPORT_DIR}: .+\.yml$" | \
  sed -e 's/^Only in .*:[[:space:]]*//g')
if [[ -n $NEW_YML_FILES ]]; then # Not empty?
  YML_COUNT=$(echo "${NEW_YML_FILES}" | wc -l)
  if [[ $_V == 1 ]]; then
    echo ""
    BarrierMajor 3
    echo "  ** NEW FILES FOUND **"
    echo "  * ${YML_COUNT} new YML files were found and will be added to ${PROJ_DIR}:"
    BarrierMinor
    echo "${NEW_YML_FILES}"
    ConfirmToContinue "Y"
    BarrierMajor 3
  else
    echo "NOTICE: ${YML_COUNT} new YML files were found and will be added to ${PROJ_DIR}."
  fi
  echo "${NEW_YML_FILES}" >> "${COMMANDS_FILE}.ROO.new.bash"
  # Add new YMLs to already covered list
  echo "${NEW_YML_FILES}" >> "${SCRIPT_ROOT}/_covered_unsorted_ymls.tmp"

  GenerateDiffs "${ABS_CONF_EXPORT_DIR}" "${ABS_PROJ_CONF_DIR}" "${COMMANDS_FILE}.ROO.new.bash" "${CONF_EXPORT_DIR}" "${DIFFS}" "${PROJ_DIR}" 'new'

  GenerateOptionalDiffs "${ABS_PROJ_CONF_DIR}" 'new'

  unset NEW_YML_FILES
else
  if [[ $_V == 1 ]]; then
    BarrierMinor 2
    Verbose "NOTE: No new, non-project YML files were detected. Skipping.\n"
    BarrierMinor
  fi
fi

##--------------- Catch-all 2 of 2) Check for modified YMLs not found in ANY project in PROJECTS_DIR

# TODO Does a non-project, modified YML file check need a flag to skip?
> "${COMMANDS_FILE}.ROO.modified.bash"
> "${SCRIPT_ROOT}/_all_ymls.tmp"
echo "${YML_FILES}" | \
  grep -E "^Files ${COPY_EXPORT_START_DIR}/(.+?\.yml) and ${ABS_CONF_EXPORT_DIR}/(.+?\.yml) differ(\n)?$" | \
  perl -p -e "s|^Files ${COPY_EXPORT_START_DIR}/(.+?\.yml) and ${ABS_CONF_EXPORT_DIR}/(.+?\.yml) differ(\n)?$|\$1_-_|g" | \
  perl -p -0 -e "s/_-_/\n/g" | \
  sort > "${SCRIPT_ROOT}/_modded_ymls.tmp"
GetYMLData "${ABS_CONF_EXPORT_DIR}" 0 >> "${SCRIPT_ROOT}/_all_ymls.tmp"
sort < "${SCRIPT_ROOT}/_covered_unsorted_ymls.tmp" > "${SCRIPT_ROOT}/_covered_ymls.tmp"
comm --check-order -23 "${SCRIPT_ROOT}/_all_ymls.tmp" "${SCRIPT_ROOT}/_covered_ymls.tmp" > "${SCRIPT_ROOT}/_eligible_ymls.tmp"
MODDED_YML_FILES=$(comm -1 "${SCRIPT_ROOT}/_eligible_ymls.tmp" "${SCRIPT_ROOT}/_modded_ymls.tmp" | sed -E "s/^\t(.+?)$/\1/g")

if [[ -n $MODDED_YML_FILES ]]; then
  YML_COUNT=$(echo "${MODDED_YML_FILES}" | wc -l)
  if [[ $_V == 1 ]]; then
    echo ""
    BarrierMajor 2
    echo "  ** MODIFIED FILES FOUND **"
    echo "  * ${YML_COUNT} non-project, modified YML files to be added:"
    BarrierMinor
    echo "${MODDED_YML_FILES}"
    ConfirmToContinue
    BarrierMajor 3
  else
    echo "NOTICE: ${YML_COUNT} non-project, modified YML files were found and will be added to ${PROJ_DIR}."
  fi
  echo "${MODDED_YML_FILES}" >> "${COMMANDS_FILE}.ROO.modified.bash"

  GenerateDiffs "${ABS_CONF_EXPORT_DIR}" "${ABS_PROJ_CONF_DIR}" "${COMMANDS_FILE}.ROO.modified.bash" "${CONF_EXPORT_DIR}" "${DIFFS}" "${PROJ_DIR}" 'modified'

  GenerateOptionalDiffs "${ABS_PROJ_CONF_DIR}" 'modified'

  unset MODDED_YML_FILES
else
  if [[ $_V == 1 ]]; then
    BarrierMinor 2
    Verbose "NOTE: No modified, non-project YML files detected. Skipping.\n"
    BarrierMinor
  fi
fi

# Generate one-off warning about YML files that have been deleted from ${CONF_EXPORT_DIR} since the start config directory was built.
> "${SCRIPT_ROOT}/_all_start_ymls.tmp"
> "${SCRIPT_ROOT}/_orphaned_start_ymls.tmp"
GetYMLData "${COPY_EXPORT_START_DIR}" 0 >> "${SCRIPT_ROOT}/_all_start_ymls.tmp"
ORPHANED_YMLS=$(comm --check-order -23 "${SCRIPT_ROOT}/_all_start_ymls.tmp" "${SCRIPT_ROOT}/_all_ymls.tmp")

if [[ -n $ORPHANED_YMLS ]]; then
  YML_COUNT=$(echo "${ORPHANED_YMLS}" | wc -l)
  if [[ $_V == 1 ]]; then
    echo ""
    BarrierMajor 3
    Verbose "NOTICE: ${YML_COUNT} YML files have disappeared from %s since the start configs were set.\n" ${CONF_EXPORT_DIR}
    Verbose "These YMLs will not be included.\n"
    BarrierMinor
    echo "${ORPHANED_YMLS}"
    ConfirmToContinue
    BarrierMajor 3
  else
    echo "NOTICE: ${YML_COUNT} YML files have disappeared from ${CONF_EXPORT_DIR} since the start configs were set."
    echo "These YMLs will not be included."
  fi
fi

# cleanup of ROO tmp files
find "${SCRIPT_ROOT}" -maxdepth 1 -type f -name "_*_ymls.tmp" -exec rm {} \;

############################ END Run only once (ROO)




# Open final diff file (in ./config for single, in SCRIPT_ROOT for all) in TEXT_EDITOR for review
if [[ -s "${OUTPUT_TOTAL}" ]]; then
  Verbose "\nOpening %s in %s...\n"  "${OUTPUT}" "${TEXT_EDITOR}"
  "${TEXT_EDITOR}" "${OUTPUT_TOTAL}"
  Verbose "Review complete.\n"
else
  Issue "No changes in ${OUTPUT} to review. Skipping... and deleting all generated diff and command files." "${WCT_OK}"
  [[ "${PATCH_MODE}" == 1 ]] && Verbose "No patch to be made. Skipping...\n" && PATCH_MODE=0
  MANUAL_DIFF_REVIEW=0
fi

# Patch processing, patch commands output
if [[ "${PATCH_MODE}" == 1 ]]; then
  BarrierMajor 3
  for ((i=0; i <= ${#PATCH_COMMANDS[@]}; i++)); do
    [[ $i == 0 ]] && echo "The following patch command(s) can applied from each of their ./config directories, on a per-project changes:" && echo ""
    if [[ -f "${PATCHES_GENERATED[$i]}" ]]; then
      printf " * %s\n" "${PATCH_COMMANDS[$i]}"
    fi
  done
  if [[ $FIRST_PROJECT != "${LAST_PROJECT}" && -f "${OUTPUT_TOTAL}${PATCH_SUFFIX}" ]]; then
    # Clean out junk comments from _ALL .patch file
    sed -i -e 's|^##NO-PATCH##.*$||g' "${OUTPUT_TOTAL}${PATCH_SUFFIX}" && \
      sed -i '/^[[:space:]]*$/d' "${OUTPUT_TOTAL}${PATCH_SUFFIX}" && \
      sed -i '/^[[:blank:]]*$/ d' "${OUTPUT_TOTAL}${PATCH_SUFFIX}"
  fi
  Verbose "\nWARNING:\n"
  Verbose " - REVIEW ANY PATCHES BEFORE APPLYING! * Don't fool around and find out. * \n"
  Verbose " - ALL .patch files in the script root (when ALL is selected) cannot be applied at once. Use the patch files in individual projects instead.\n"
  BarrierMajor 3
fi

# Post-diff review - cleanup
echo ""
if [[ ${#FILES_GENERATED[@]} -ge 1 ]]; then
  if [[ ${MANUAL_DIFF_REVIEW} == 1 ]]; then
    MESSAGE="The following files were kept for review (until the next time this script is run):"
    CLEANUP='echo'
    [[ "${PATCH_MODE}" == 1 && -f "${OUTPUT_TOTAL}" ]] && FILES_GENERATED+=("${OUTPUT_TOTAL}${PATCH_SUFFIX}")
  else
    MESSAGE=$(printf "Deleting generated files")
    [[ "${PATCH_MODE}" == 1 && -f "${OUTPUT_TOTAL}" ]] && MESSAGE="${MESSAGE} (except for ${OUTPUT}${PATCH_SUFFIX})"
    MESSAGE="${MESSAGE}..."
    CLEANUP='rm -v'
  fi
  for ((i=0; i <= ${#FILES_GENERATED[@]}; i++)); do
    [[ $i == 0 ]] && echo "${MESSAGE}"
    if [[ -f "${FILES_GENERATED[$i]}" && ( ${MANUAL_DIFF_REVIEW} == 1 || "${CLEANUP}" == 'rm -v' ) ]]; then
      $(echo "${CLEANUP}") "${FILES_GENERATED[$i]}"
    fi
  done
fi

# END
echo "DONE."
exit 0
