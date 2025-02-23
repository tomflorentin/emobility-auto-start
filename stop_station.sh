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
transactionId=$(echo "$response" | jq -r '.connectors[0].currentTransactionID')

echo "Current transaction id : $transactionId"

# Only stop the transaction the transaction id is a number greater than 0
if echo "$transactionId" | grep -qE '^[0-9]+$' && [ "$transactionId" -gt 0 ]; then
  echo "Transaction $transactionId in progress, stopping transaction."
  STOP_URL="https://${API_URL}/v1/api/transactions/$transactionId/stop"

  curl "$STOP_URL" \
    -X PUT \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    --data-raw "$(cat <<EOF
{
  "chargingStationID": "$CHARGER_ID",
  "userID": "$USER_ID",
  "args": {
    "visualTagID": "$TAG_ID",
    "connectorId": 1
  }
}
EOF
)"
else
  echo "No transaction in progress. $transactionId"
fi
