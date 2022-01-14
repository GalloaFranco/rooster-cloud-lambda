profile=$1
filter=$2

groupName=$(aws logs describe-log-groups --profile ${profile} --query 'logGroups[*].logGroupName' | grep $filter)

groupNameFixed=$(echo $groupName | sed 's/,//g' | sed 's/\"//g')

logStream=$(aws logs describe-log-streams \
--profile ${profile} \
--log-group-name ${groupNameFixed} \
--query 'logStreams[*].logStreamName' \
--max-items 1 \
--order-by LastEventTime \
--descending)

logStreamFixed=$(echo $logStream | sed 's/\[//' |  sed 's/.$//' | sed 's/\"//g')

result=$(aws logs get-log-events --profile ${profile} --log-group-name ${groupNameFixed} --log-stream-name ${logStreamFixed})
echo $result | jq .
