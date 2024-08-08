#!/bin/bash
# Load the .env file
if [ -f .env ]; then
    # Export each line in the .env file as a variable
    export $(grep -v '^#' .env | xargs)
else
    echo ".env file not found!"
    exit 1
fi
# Set public id
public_ip=$(curl -s ifconfig.me)


# Initialize an empty array for changes
changes_array="[]"

# Iterate through environment variables and construct the changes array
i=1
while [ -n "$(eval echo \${CHANGE_NAME_${i}})" ]; do
    name=$(eval echo \${CHANGE_NAME_${i}})
    type="A"
    ttl=60
    value=$public_ip

    # Construct a JSON object for each change
    change=$(jq -n \
        --arg name "$name" \
        --arg type "$type" \
        --arg ttl "$ttl" \
        --arg value "$value" \
        '{
            Action: "UPSERT",
            ResourceRecordSet: {
                Name: $name,
                Type: $type,
                TTL: ($ttl | tonumber),
                ResourceRecords: [
                    {
                        Value: $value
                    }
                ]
            }
        }'
    )

    # Append the change to the changes array
    changes_array=$(echo "$changes_array" | jq --argjson change "$change" '. += [$change]')

    i=$((i + 1))
done

# Create the final JSON with the comment and changes
json_data=$(jq -n \
    --arg comment "Update record to reflect new IP address for a system" \
    --argjson changes "$changes_array" \
    '{
        Comment: $comment,
        Changes: $changes
    }'
)

# Output the JSON data to a file
echo "$json_data" > output.json

# echo "$json_data" 
# Update route53
aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch file://./output.json
# echo $HOSTED_ZONE_ID