#!/bin/bash
# =============================================================================
#  Author: GalloaFranco
#  Filename: check-lambdas-health.sh
#  Description: This script help us to analyze and observe (in the most easy way possible) the state of our lambdas.
#               With this script you can check how many lambdas are up, if they are with code or not, which response
#               you receive if it is invoke and also you can watch the last CloudWatch log.
#
#  Reference:
#
#   - https://github.com/GalloaFranco/rooster-cloud-lambda
#
# =============================================================================

MACOS='Darwin'
LINUX='Linux'

BLUE='\033[1;34m'
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROFILE='default'
unset FILTER

# =============================================================================
# Functions
# =============================================================================

spinner () {
  # =============================================================================
  # We need to use this function after job control (ampersand symbol).
  # > kill -0 checks access to pid
  # > echo -ne "\033[0K\r" # Erase previous line with spinner
  # =============================================================================
  pid=$! # Get last pid
  spin='-\|/'
  i=0
  while kill -0 $pid 2>/dev/null
  do
    i=$(( (i+1) %4 ))
    printf "\r${BLUE} ${spin:$i:1} ${NC}"
    sleep .1
  done
  echo -ne "\033[0K\r"
}

validateRequirements () {

  echo -e "${BLUE}[Info] Verifying requirements to run this script... ${NC}"

  local os=$(uname)
  local jq_dependency=$(command -v jq)
  local aws_dependency=$(command -v aws)

  if [ -z $aws_dependency ]
  then
    echo -e "${YELLOW}[Warning]: You don't have aws-cli installed, is mandatory to have this install and configure in your machine ${NC}"
    exit
  fi

  if [ -z $jq_dependency ]
  then
    echo -e "${BLUE}[Info] Installing jq... ${NC}"
    if [ $os = "${MACOS}" ]
    then
      brew install jq
    fi
    if [ $os = "${LINUX}" ]
    then
      sudo apt-get install jq
    fi
  else
    echo -e "${BLUE}[Info] All ok! ${NC}"
  fi
}

codeSizeScript () {

  echo -e "${BLUE}▶︎ Ingress the minimum size for the lambda code (in bytes, 100000 = 100kb) : ${NC}"
  read -e size

  echo -e "${BLUE}[Info] Starting scan... ${NC}"

  local minimum_size=${size}

  local query='Functions[?starts_with(FunctionName, `'"${FILTER}"'`) == `true`].FunctionName'

  local lambdas=$(aws --profile "${PROFILE}" lambda list-functions  --query "$query" --output text) 2>/dev/null & spinner

  local my_array=($(echo "${lambdas}" | sed 's/ *$//g'))

  local counter=0

  for i in "${my_array[@]}"
  do
   counter=$[$counter+1]
   local response=$(aws --profile "${PROFILE}" lambda get-function --function-name "${i}" --query 'Configuration.CodeSize' --output text) 2>/dev/null & spinner

   if [ $response -le $minimum_size ]
   then
    echo -e "${RED}[Error] LambdaName: ${i} CodeSize: ${response} (bytes) ${NC}"
   else
    echo -e "${GREEN}[Ok] LambdaName: $i CodeSize: ${response} (bytes) ${NC}"
   fi
  done
}

responseAnalysis () {

  echo -e "${BLUE}[Info] Starting scan... ${NC}"

  local query='Functions[?starts_with(FunctionName, `'"${FILTER}"'`) == `true`].FunctionName'

  local lambdas=$(aws --profile ${PROFILE} lambda list-functions  --query "${query}" --output text) 2>/dev/null & spinner

  local my_array=($(echo ${lambdas} | sed 's/ *$//g'))

  local counter=0

  for i in "${my_array[@]}"
  do
   counter=$[$counter+1]
   local response=$(aws --profile ${PROFILE} lambda invoke --function-name ${i} response.txt) 2>/dev/null & spinner
   local status_code=$(echo ${response} | jq -r .StatusCode)
   local function_error=$(echo ${response} | jq -r .FunctionError)

   rm response.txt

   if [ "${status_code}" = "200" ] && [ "${function_error}" = "null" ]
   then
    echo -e "${GREEN}[Ok] LambdaName: $i StatusCode: ${status_code} function_error: none ${NC}"
   elif [ "${status_code}" = "200" ] && [ "${function_error}" != "null" ]
   then
    echo -e "${YELLOW}[Warning] LambdaName: $i StatusCode: ${status_code} function_error: ${function_error} ${NC}"
   else
    echo -e "${RED}[Error] LambdaName: $i StatusCode: ${status_code} function_error: ${function_error} ${NC}"
   fi
  done

  echo -e "${BLUE}[Info] Total of lambda functions: ${counter} ${NC}"
  echo -e "${BLUE}[Info] Scan done! ${NC}"

}

showLastLog () {

  echo -e "${BLUE}▶︎ ︎Ingress the name of the lambda: ${NC}"
  read -e lambda_name

  echo -e "${BLUE}[Info] Starting scan... ${NC}"

  local group_name=$(aws logs describe-log-groups --profile ${PROFILE} --query 'logGroups[*].logGroupName' | grep $lambda_name) 2>/dev/null & spinner

  local group_name_fixed=$(echo $group_name | sed 's/,//g' | sed 's/\"//g')

  log_stream=$(aws logs describe-log-streams \
  --profile ${PROFILE} \
  --log-group-name ${group_name_fixed} \
  --query 'logStreams[*].logStreamName' \
  --max-items 1 \
  --order-by LastEventTime \
  --descending)

  local log_stream_fixed=$(echo $log_stream | sed 's/\[//' |  sed 's/.$//' | sed 's/\"//g')

  local result=$(aws logs get-log-events --profile ${PROFILE} --log-group-name ${group_name_fixed} --log-stream-name ${log_stream_fixed}) 2>/dev/null & spinner
  echo $result | jq

}

showMenu () {

  echo -e "${YELLOW}============= Menu ============= ${NC}"

  local options=("response analysis" "code size analysis" "view last log" "exit")
  select script in "${options[@]}"
  do
     case $script in
            "response analysis")
              validateRequirements
              responseAnalysis
              break
              ;;
            "code size analysis")
              validateRequirements
              codeSizeScript
              break
              ;;
            "view last log")
              validateRequirements
              showLastLog
              break
              ;;
            "exit")
              echo -e "${BLUE}Bye! and thanks for use this script 👋🏻"
              exit 0
              ;;
            *)
              echo -e "${RED}[Error] Invalid option ${NC}"
              break
              ;;
        esac
  done
}

usage () {

  echo -e "${BLUE}============= ⚙️  Usage ============= ${NC}"
  echo -e "${BLUE}#       Hi there! thank you to try this suit of scripts."
  echo -e "${BLUE}#       ▶ How to execute this?"
  echo -e "${BLUE}#       bash check-lambdas-health.sh [-p profile] [-f filer] [-h help]"
  echo -e "${BLUE}#       -p      This flag is used to indicate on which aws profile make our consults, it correspond with the config or credentials profile"
  echo -e "${BLUE}#               configure on our machine (~/.aws directory). If we dont use this flag the profile selected would be \"default\"."
  echo -e "${BLUE}#       -f      This flag is used to indicate some key name to use as a filter to find more easily our lambdas."
  echo -e "${BLUE}#               If we dont use this flag the script display all the lambdas we can access"
  echo -e "${BLUE}#       -h      Shows this menu 😎"
  echo -e "${BLUE}================================= ${NC}"
  exit 0
}

main () {
  while true
  do
    showMenu
  done
}

# =============================================================================
# Execution
# =============================================================================

while getopts p:f:h opt
do
        case $opt in
                p)
                  PROFILE=$OPTARG
                  ;;
                f)
                  FILTER=$OPTARG
                  ;;
                h)
                  usage
                  exit 0
                  ;;
                *)
                  echo -e "${RED}[Error] Invalid parameter ${NC}"
                  exit 1
                  ;;
        esac
done

if [ $OPTIND -eq 1 ]
then
  echo -e "${YELLOW}[Warning] You are using default param value ${NC}"
fi

shift "$(( OPTIND - 1 ))"

main
