#!/bin/bash
## 
## This script checks if the required dependency packages have been installed
## If one or more have not been installed, then it installs them.
## It currently only works on Ubuntu 17.10 and has to be run as root.
##
## Author: Matthew Setter <matthew@matthewsetter.com>
##

SUPPORTED_DISTRIBUTIONS=( 
  "Ubuntu 17.10"
)
LOG_FILE=output.log

usage="$(basename "$0") [-h -s -d] -- script to install ownCloud's core dependencies

where:
    -h  show this help text
    -s  show a list of distributions which this script supports
    -d  do not install packages
"

##
## Determine the user's distribution
##
function get_distribution()
{
  version=$( grep -E "^VERSION_ID" /etc/os-release | awk -F'=' '{print $2}' | tr -d '"')
  name=$( grep -E "^NAME" /etc/os-release | awk -F'=' '{print $2}' | tr -d '"')

  echo "${name} ${version}"
}

function show_supported_distributions()
{
  echo "Supported Linux Distributions:"
  printf ' - %s\n' "${SUPPORTED_DISTRIBUTIONS[@]}"
  echo
}

##
## This checks if the distribution is supported
##
function check_distribution()
{
  distro=$(get_distribution)

  # Console colours
  GREEN='\e[0;32m'      # Red
  NC='\e[0m'          # No Color

  case "${SUPPORTED_DISTRIBUTIONS[@]}" in 
    "${distro}")
      echo -e "Detected allowed distribution: ${distro}. ${GREEN}Can continue${NC}."
      echo
      ;;
    *)
      echo "This script does not support ${distro}"
      echo "Exiting."
      exit -1
  esac
}

function check_dependencies()
{
  missing_dependencies=()

  # Determine the correct dependencies configuration file to read in
  distro_lower=$( echo $(get_distribution) | awk '{ gsub(" ", "-"); print tolower($0) }' )
  source "bin/dependencies/${distro_lower}.cfg"

  # Console colours
  RED='\033[0;31m'      # Red
  NC='\033[0m'          # No Color

  echo "Checking that the core dependencies have been installed."
  echo

  for package in ${!core_dependencies[@]}
  do
    pkg=${core_dependencies[$package]}
    
    if dpkg -l ${pkg} 2>/dev/null | grep -E -q "^ii"  
    then
      printf " \u2714 ${pkg} is installed\n"
    else
      printf " \u274c ${pkg} is ${RED}not${NC} installed\n"
      missing_dependencies+=(${pkg})
    fi
  done

  if (( ${#missing_dependencies[@]} != 0 ))
  then 
    if [[ -z "$DRY_RUN" ]]
    then
      echo
      echo "Some dependencies are missing. They will now be installed."
      echo 
      echo "Updating APT cache"
      echo
      apt-get update --quiet &>${LOG_FILE}

      echo "Installing missing dependencies"
      echo
      IFS=$' '
      apt-get install --quiet --assume-yes ${missing_dependencies[*]} &>>${LOG_FILE}

      echo "All dependencies have now been installed."
      echo "Check ${LOG_FILE}, if you want to know anything more about the operation of the script."
    else
      echo
      echo "Some core dependencies are missing, but they will not be installed as a dry-run was requested."
    fi
  else 
    echo 
    echo "All dependencies are installed."
    echo "Nothing left to do."
    echo "Exiting."
    exit 0
  fi
}

while getopts ':hsd' option; do
  case "$option" in
    h) echo "$usage"
       exit
       ;;
    s) 
      show_supported_distributions
      exit
       ;;
    d)
      DRY_RUN="--dry-run"
      ;;
    :) printf "missing argument for -%s\n" "$OPTARG" >&2
       echo "$usage" >&2
       exit 1
       ;;
   \?) printf "illegal option: -%s\n" "$OPTARG" >&2
       echo "$usage" >&2
       exit 1
       ;;
  esac
done
shift $((OPTIND - 1))

if [ $( whoami ) != "root" ]
then
  echo "This script needs to be run as root."
  echo "Exiting."
  exit 1
else
  check_distribution
  check_dependencies
fi