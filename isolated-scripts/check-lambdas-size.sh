#!/bin/bash
# =============================================================================
#  Author: GalloaFranco
#  Filename: check-lambdas-sizes.sh
#  Description: With this script we can see the size (in bytes) of all our lambdas, at least all the lambdas we can permission to see.
#  Reference:
#
#   -  https://gist.github.com/GalloaFranco/23dffd83613d03ffb5677a42463eb997
#
#  AdditionalData: For a more neat display put | column -t at the end of the execution of this script.
#
# =============================================================================

MACOS='Darwin'
LINUX='Linux'

LIGHTBLUE='\033[1;34m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

MIN_SIZE=100000 #This represents 100Kb

echo -e "${LIGHTBLUE} [Info] Verifying requirements to run this script... ${NC}"

os=$(uname)
response=$(command -v jq)

if [ -z $response ]
then
  echo -e "${LIGHTBLUE} [Info] Installing jq... ${NC}"
  if [ $os = "${MACOS}" ]
  then
    brew install jq
  fi
  if [ $os = "${LINUX}" ]
  then
    sudo apt-get install jq
  fi
else
  echo -e "${LIGHTBLUE} [Info] All ok! ${NC}"
fi

echo -e "${LIGHTBLUE} [Info] Starting scan... ${NC}"

if [ -z $1 ]
then
 echo -e "${RED} ERROR: You must load aws profile as parameters of this script ${NC}"
 exit 0
fi

if [ -z $2 ]
then
 echo -e "${YELLOW} WARNING: You didn't provide any filter parameters, so you can find all the lambdas you can with your role ${NC}"
fi

#  With this first script parameter we can indicate which profile we can use to set in the aws cli command.
awsProfile=$1
#  With this second script parameter we can filter functions by prefix, if we don't specify nothing then the script find all the function we are allow to see.
prefixFilter=$2

query='Functions[?starts_with(FunctionName, `'"${prefixFilter}"'`) == `true`].FunctionName'

lambdas=$(aws --profile "${awsProfile}" lambda list-functions  --query "$query" --output text)

my_array=(`echo "$lambdas" | sed 's/ *$//g'`)

counter=0

for i in "${my_array[@]}"
do
 counter=$[$counter+1]
 response=$(aws --profile "${awsProfile}" lambda get-function --function-name "${i}" --query 'Configuration.CodeSize' --output text)
 
 if [ $response -le 100000 ]
 then
  echo -e "${RED} LambdaName: $i CodeSize: $response (bytes) ${NC}"
 else
  echo -e "${GREEN} LambdaName: $i CodeSize: $response (bytes) ${NC}"
 fi

done

echo -e "${LIGHTBLUE} [Info] Total of lambda functions: $counter ${NC}"
echo -e "${LIGHTBLUE} [Info] Scan done! ${NC}"
