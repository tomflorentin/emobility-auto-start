#!/bin/sh

# Get the status charging-stations/:id
echo "START TRANSACTION"
# Construct the URL for retrieving the charging station status.
STATUS_URL="https://${API_URL}/v1/api/charging-stations/${CHARGER_ID}"
echo "Fetching charging station status from: $STATUS_URL"

# Fetch the charging station status.
response=$(curl -s "$STATUS_URL" \
  -X GET \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json")

# Extract the status from the first connector.
status=$(echo "$response" | jq -r '.connectors[0].status')

echo "Connector status: $status"

# Only start the transaction if the status is "Preparing".
if [ "$status" = "Preparing" ]; then
  echo "Status is 'Preparing'. Initiating start transaction..."

  START_URL="https://${API_URL}/v1/api/transactions/start"

  # Execute the start transaction command and capture its response.
  start_response=$(curl -s "$START_URL" \
    -X PUT \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    --data-raw "$(cat <<EOF
{
  "chargingStationID": "$CHARGER_ID",
  "userID": "$USER_ID",
  "args": {
    "tagID": "$TAG_ID",
    "connectorId": 1
  }
}
EOF
)")

  # Log the response of the start transaction in the terminal.
  echo "Start transaction response: $start_response"
else
  echo "Status is not 'Preparing' (status is '$status'). Aborting start transaction."
fi
