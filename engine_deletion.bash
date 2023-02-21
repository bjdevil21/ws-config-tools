#!/usr/bin/env bash
#############################
# Elasticsearch engine cleanup
##############################

# SETUP
# shellcheck disable=SC2188
source ./lib/_global.bash || exit 1
BashVersionCheck 4 3
UserRootDirCheck
source ./lib/engine_deletion.functions || exit 1
. "${USER_DIR_ROOT}"/.bashrc  # Bash FYI - . is the same as source

# OPTIONS
while getopts "mqhvV" option; do
  case "${option}" in
  m) # Manual review
    ED_MANUAL_REVIEW=1
    ;;
  q) # Run on QA
    ED_MODE="${ED_QA}"
    ED_KEY="${QA_AS_API_KEY}"
    ;;
  h) # Outputs help content
    Help;;
  v) # Return script version
    echo "${ED_VERSION}"
    exit 0;;
  V) # Verbose output
    _V=1;;
  \?) # Default: Invalid option
    Issue "Invalid option. Try -h for help." "${WCT_ERROR}"
    exit 1;;
  esac
done

# Setting target URL after options
ED_URL="https://${ED_MODE}${ED_URL_SUFFIX}"

BarrierMajor 1
echo " -- Faculty/Staff and Student engine cleanout --"
BarrierMajor 2

# 1) Get meta data from GET all engines
ED_PAGE_DATA=$(curl -s -X GET "${ED_URL}" -H 'Content-Type: application/json' -H "Authorization: Bearer $ED_KEY")
# echo "${ED_PAGE_DATA}" | jq .
ED_PAGES=$(echo "${ED_PAGE_DATA}" | jq '.meta.page')
ED_TOTAL_PAGES=$(echo "${ED_PAGES}" | jq '.total_pages')
ED_PAGE_SIZE=$(echo "${ED_PAGES}" | jq '.size')
ED_TOTAL_RESULTS=$(echo "${ED_PAGES}" | jq '.total_results')
> ./_all_engines.tmp

if [[ $ED_TOTAL_PAGES == 0 || $ED_TOTAL_RESULTS == 0 ]]; then
  BarrierMajor
  Issue "EMERGENCY: No search engines found on ${ED_MODE}! Investigate this immediately by checking out the engines at cloud.elastic.co." "${WCT_ERROR}"
  BarrierMajor
  exit 1
fi

[[ $_V == 1 ]] && echo "There are ${ED_TOTAL_RESULTS} total engines spread across ${ED_TOTAL_PAGES} pages. Filtering list down..."

# Run for loop to get ALL engines and cat into file based on total_pages
for ((ii=1; ii <= ${ED_TOTAL_PAGES}; ii++)); do
  # -- Manipulate output with jQ to only return engine names that match a certain pattern
  printf "\nChecking page %d of %d engines..." "$ii" "$ED_TOTAL_PAGES"
  curl -s -X GET "${ED_URL}" -H 'Content-Type: application/json' -H "Authorization: Bearer $ED_KEY" -d "{'page':{'current': $ii, 'size': $ED_PAGE_SIZE}}"  | jq -r '.results[].name | match("^(web-dir-.+?-20.*)$", "ig") | .string' \
    > ./_current_page_engines.tmp
  cat ./_current_page_engines.tmp >> ./_all_engines.tmp
  printf "DONE\n"
  ED_CURR_PAGE_COUNT=$(wc -l < ./_current_page_engines.tmp)
  if [[ $_V == 1 ]]; then
    BarrierMinor 1
    if [[ ${ED_CURR_PAGE_COUNT} -gt 0 ]]; then
      Verbose "Page %d had $(wc -l < ./_current_page_engines.tmp) fac/staff or student engines:\n" "${ii}"
      BarrierMinor
      cat ./_current_page_engines.tmp
    else
      Verbose "Page %d had no fac/staff or student engines. Skipping...\n" "${ii}"
    fi
    BarrierMinor
  fi
done

# Ensure engines are in order by date DESC
perl -pi -e 's/^(web-dir\D+?)(20\d+?)$/$2___$1$2/g' ./_all_engines.tmp
sort -r ./_all_engines.tmp > ./_all_engines_resorted.tmp
perl -pi -e 's/^(\d+?)___(.+?)$/$2/g' ./_all_engines_resorted.tmp && mv ./_all_engines_resorted.tmp ./_all_engines.tmp

# Remove newest six engines (3 days worth) at top from the 'delete me' list
cp ./_all_engines.tmp ./_delete_these_engines.tmp && sed -n '1,6p' ./_delete_these_engines.tmp > ./_keep_these_engines.tmp && sed -i '1,6d' ./_delete_these_engines.tmp

# Pre-deletion health checks
ED_KEEP_ENG=$(wc -l < ./_keep_these_engines.tmp)
ED_DEL_ENG=$(wc -l < ./_delete_these_engines.tmp)
if [[ $_V == 1 ]]; then
  BarrierMajor 1
  echo " ** ACTION SUMMARY **"
  BarrierMajor 2
else
  echo ""
fi
echo "The following ${ED_KEEP_ENG} engines will be kept intact:"
BarrierMinor
cat ./_keep_these_engines.tmp

# Issue: Fewer than 6 total fac/staff and student engines
if [[ ${ED_KEEP_ENG} -lt 6 ]]; then
  KEEP_WARN_MSG="Only ${ED_KEEP_ENG} "
  [[ ${ED_KEEP_ENG} == 0 ]] && KEEP_WARN_MSG="No " # No engines??
  Issue "${KEEP_WARN_MSG} fac/staff or student engines found. Investigate this ${ED_MODE} shortfall ASAP. No deletions will be done.\n" "${WCT_ERROR}"
  exit 1
fi

# There are some deleteable engines...
if [[ ${ED_DEL_ENG} -gt 0 ]]; then
  echo ""
  echo "The following ${ED_DEL_ENG} engines will be DELETED:"
  BarrierMinor
  cat ./_delete_these_engines.tmp
  ConfirmToContinue "delete these engines from ${ED_MODE}" 'N'
  if [[ ${WCT_CONFIRM} == "Y" ]]; then
    mapfile ED_DELETE_ENGINES < ./_delete_these_engines.tmp
    for jj in "${!ED_DELETE_ENGINES[@]}"; do
      Verbose "Deleting ${ED_DELETE_ENGINES[$jj]//[$'\t\r\n']}...\n"
      curl -s -X DELETE "https://${ED_MODE}.ent.us-west-2.aws.found.io/api/as/v1/engines/${ED_DELETE_ENGINES[$jj]//[$'\t\r\n']}" -H 'Content-Type: application/json' -H "Authorization: Bearer $ED_KEY" | jq
      Verbose "DONE\n"
    done
  else
    echo "OK: Skipping engine deletion..."
  fi
  BarrierMajor 3
else
  BarrierMinor
  Issue "There were no engines to be deleted. Exiting." "${WCT_OK}"
  exit 0
fi

#curl -X DELETE "https://asuis.ent.us-west-2.aws.found.io/api/as/v1/engines" -H 'Content-Type: application/json' -H "Authorization: Bearer $ED_API_KEY" | jq

if [[ ${ED_MANUAL_REVIEW} == 1 ]]; then
  echo "NOTE: Leaving .tmp files for further review. Remember to delete them."
  echo ""
else
  Verbose "* Cleaning up any tmp files..."
  find . -type f -name "*_engines.tmp" -exec rm -v {} \;
  Verbose "DONE\n"
fi

echo "DONE."
exit 0
