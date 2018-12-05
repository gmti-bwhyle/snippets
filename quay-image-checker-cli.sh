#!/usr/bin/env bash

# quay image chacker, cli version 0.6-20181129-beta (do not distribute)
# by rick pelletier (rpelletier@gannett.com), 19 november 2018
# last update: 29 november 2018

# requirements: 'jq' must be installed and available


# working variables
api_url="https://quay.io/api/v1" # base url for quay api calls

function help {
  echo ""
  echo "./mage-checker-cli.sh -o [org_name] -r [repo_name] -t [tag_name]"
  echo "note: all options are required"
  echo ""
}

# process command-line args with some basic parameter hygiene
while getopts ":o:r:t:" opt; do
  case $opt in
    o)
      org_name=$(echo "$OPTARG" | sed -e 's/[^a-zA-Z 0-9_-]//g')
      ;;
    r)
      repo_name=$(echo "$OPTARG" | sed -e 's/[^a-zA-Z 0-9_-]//g')
      ;;
    t)
      image_tag=$(echo "$OPTARG" | sed -e 's/[^a-zA-Z 0-9_-]//g')
      ;;
    \?)
      echo "ERROR: Invalid option: -$OPTARG" >&2
      help
      exit 1
      ;;
    :)
      echo "ERROR: Option -$OPTARG requires an argument." >&2
      help
      exit 1
      ;;
  esac
done


# safety check (make sure 'org_name' ,'repo_name' and 'tag_name' aren't empty strings
if [ ! -z "${org_name}" ]
then
  if [ ! -z "${repo_name}" ]
  then
    if [ ! -z "${image_tag}" ]
    then
      # find image id for given repo + tag (above)
      api_call="${api_url}/repository/${org_name}/${repo_name}/tag/?onlyActiveTags=true"
      image_id=$(curl -Ls -X GET -H "Authorization: Bearer ${QUAYBOT_OAUTH_TOKEN}" -H "Content-Type: application/json" "${api_call}" | \
        jq '.tags[] | select (.name | test ("(?i)'"${image_tag}"'")) | .image_id'  | sed -e 's/"//g')

      if [ ! -z "${image_id}" ]
      then
        api_call=$(echo "${api_url}/repository/${org_name}/${repo_name}/image/${image_id}/security?vulnerabilities=true" | sed -e 's/"//g')
        scan_data=$(curl -Ls -X GET -H "Authorization: Bearer ${QUAYBOT_OAUTH_TOKEN}" -H "Content-Type: application/json" "${api_call}" | jq '.')

        # build csv output
        if [ ! -z "${scan_data}" ]
        then
          echo "${scan_data}" > ${org_name}-${repo_name}-${image_tag}.json # XXX dump copy of data to disk for later analysis
          output=$(echo -n "\"${org_name}\",\"${repo_name}\",\"${image_tag}\",\"${image_id}\",")

          for k in "Critical" "High" "Low" "Medium" "Negligible" "Unknown"
          do
            # echo -n "${k} Severity: "
            count=$(echo "${scan_data}" | jq '.. | .Severity?' | grep -i "${k}" | wc -l)

            if [ -z "${count}" ]
            then
              count="0"
            fi

            output=$(echo -n "${output}\"${count}\",")

          done
          echo "${output}" | sed -e 's/,$//g'

        else
          echo "ERROR: No scan data returned for given repo + tag"
          exit 1
        fi
      else
        echo "ERROR: No Image ID found for given repo + tag"
        exit 1
      fi
    else
    echo "ERROR: tag_name option (-t) not set?"
    help
    exit 1
    fi
  else
    echo "ERROR: repo_name option (-r) not set?"
    help
    exit 1
  fi
else
  echo "ERROR: org_name option (-o) not set?"
  help
  exit 1
fi

exit 0

# end of script
