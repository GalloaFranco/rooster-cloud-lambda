#!/bin/bash
# =============================================================================
#  Author: GalloaFranco
#  Filename: check-lambdas-response.sh
#  Description: This script invoke lambda functions using aws cli, with this invocation we can see the response (statusCode, FunctionError, etc) of each  lambda, at least all the lambdas we can permission to see.
#  Reference:
#
#   - https://gist.github.com/GalloaFranco/941d424ce6d8f7419e0150b0dd32c9e0
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

query='Functions[?starts_with(FunctionName, `'"$2"'`) == `true`].FunctionName'

lambdas=$(aws --profile $1 lambda list-functions  --query "$query" --output text)

my_array=(`echo $lambdas | sed 's/ *$//g'`)

counter=0

for i in "${my_array[@]}"
do
 counter=$[$counter+1]
 response=$(aws --profile $1 lambda invoke --function-name $i response.json)
 statusCode=$(echo $response | jq -r .StatusCode)
 functionError=$(echo $response | jq -r .FunctionError)

 rm response.json

 if [ $statusCode = "200" ] && [ $functionError = "null" ]
 then
  echo -e "${GREEN} [OK] LambdaName: $i StatusCode: $statusCode functionError: none ${NC}"
 elif [ $statusCode = "200" ] && [ $functionError != "null" ]
 then
  echo -e "${YELLOW} [WARNING] LambdaName: $i StatusCode: $statusCode functionError: $functionError ${NC}"
 else
  echo -e "${RED} [ERROR] LambdaName: $i StatusCode: $statusCode functionError: $functionError ${NC}"
 fi
done

echo -e "${LIGHTBLUE} [Info] Total of lambda functions: $counter ${NC}"
echo -e "${LIGHTBLUE} [Info] Scan done! ${NC}"
