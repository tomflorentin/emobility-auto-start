#!/bin/sh

echo "START TRANSACTION"
# Construction de l'URL pour récupérer le statut de la station de charge.
STATUS_URL="https://${API_URL}/v1/api/charging-stations/${CHARGER_ID}"
echo "Fetching charging station status from: $STATUS_URL"

# Récupérer le statut de la station de charge.
response=$(curl -s "$STATUS_URL" \
  -X GET \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json")

# Extraire le statut du premier connecteur.
status=$(echo "$response" | jq -r '.connectors[0].status')
echo "Connector status: $status"

if [ "$status" = "Preparing" ]; then
  echo "Status is 'Preparing'. Initiating start transaction..."

  START_URL="https://${API_URL}/v1/api/transactions/start"
  # Exécuter la commande start transaction et capturer la réponse.
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

  echo "Start transaction response: $start_response"

  # Vérifier que la réponse contient le statut "Accepted"
  transaction_status=$(echo "$start_response" | jq -r '.status')

  if [ "$transaction_status" = "Accepted" ]; then
    echo "Transaction accepted."
    if [ "$(echo "$SEND_NOTIF" | tr '[:upper:]' '[:lower:]')" = "true" ]; then
      pushover_payload=$(cat <<EOF
{
  "token": "$PUSHOVER_TOKEN",
  "user": "$PUSHOVER_USER",
  "title": "Borne de recharge",
  "message": "La transaction a démarré avec succès."
}
EOF
)
      notification_response=$(curl -s "http://api.pushover.net/1/messages.json" \
        -X POST \
        -H "Content-Type: application/json" \
        --data "$pushover_payload")
      echo "Notification response: $notification_response"
    fi
  else
    echo "Transaction not accepted. Received status: $transaction_status"
    if [ "$(echo "$SEND_NOTIF" | tr '[:upper:]' '[:lower:]')" = "true" ]; then
      pushover_payload=$(cat <<EOF
{
  "token": "$PUSHOVER_TOKEN",
  "user": "$PUSHOVER_USER",
  "title": "Borne de recharge",
  "message": "Erreur lors du démarrage de la transaction: statut reçu '$transaction_status'. Réponse: $start_response"
}
EOF
)
      notification_response=$(curl -s "http://api.pushover.net/1/messages.json" \
        -X POST \
        -H "Content-Type: application/json" \
        --data "$pushover_payload")
      echo "Notification response: $notification_response"
    fi
  fi
else
  echo "Status is not 'Preparing' (status is '$status'). No transaction initiated."
fi
