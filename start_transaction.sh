#!/bin/sh

echo "START TRANSACTION"

# Construire l'URL pour récupérer le statut de la station de charge.
STATUS_URL="https://${API_URL}/v1/api/charging-stations/${CHARGER_ID}"
echo "Récupération du statut de la borne: $STATUS_URL"

# Récupérer le statut de la station de charge.
response=$(curl -s "$STATUS_URL" \
  -X GET \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json")

# Extraire le statut du connecteur et l'ID de transaction en cours.
status=$(echo "$response" | jq -r '.connectors[0].status')
transactionId=$(echo "$response" | jq -r '.connectors[0].currentTransactionID')

echo "Statut du connecteur: $status"
echo "ID de transaction actuelle: $transactionId"

# Si une transaction est déjà en cours (transactionId > 0), ne lance pas de nouvelle transaction.
if echo "$transactionId" | grep -qE '^[0-9]+$' && [ "$transactionId" -gt 0 ]; then
  echo "Une transaction (ID: $transactionId) est déjà en cours. Nouvelle transaction non lancée."
  exit 0
fi

# Si le statut est "Preparing", lancer la transaction.
if [ "$status" = "Preparing" ]; then
  echo "Le statut est 'Preparing'. Démarrage de la transaction..."

  START_URL="https://${API_URL}/v1/api/transactions/start"

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

  echo "Réponse du démarrage de la transaction: $start_response"

  transaction_status=$(echo "$start_response" | jq -r '.status')

  # Envoi de notification uniquement pour le retour de la commande start transaction.
  if [ "$(echo "$SEND_NOTIF" | tr '[:upper:]' '[:lower:]')" = "true" ]; then
    if [ "$transaction_status" = "Accepted" ]; then
      pushover_payload=$(cat <<EOF
{
  "token": "$PUSHOVER_TOKEN",
  "user": "$PUSHOVER_USER",
  "title": "Borne de recharge",
  "message": "La transaction a démarré avec succès."
}
EOF
)
    else
      pushover_payload=$(cat <<EOF
{
  "token": "$PUSHOVER_TOKEN",
  "user": "$PUSHOVER_USER",
  "title": "Borne de recharge",
  "message": "Erreur lors du démarrage de la transaction: statut reçu '$transaction_status'. Réponse: $start_response"
}
EOF
)
    fi
    notification_response=$(curl -s "http://api.pushover.net/1/messages.json" \
      -X POST \
      -H "Content-Type: application/json" \
      --data "$pushover_payload")
    echo "Notification response: $notification_response"
  fi

else
  echo "Le statut n'est pas 'Preparing' (statut: '$status'). Aucune transaction lancée."
fi
