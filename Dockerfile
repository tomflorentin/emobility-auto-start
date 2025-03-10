FROM alpine:latest

# 1. Install needed packages
RUN apk --no-cache add curl bash cronie jq

# 2. Copy your scripts
RUN mkdir /cron-scripts
COPY start_transaction.sh /cron-scripts/start_transaction.sh
#COPY stop_station.sh /cron-scripts/unlock_station.sh
RUN chmod +x /cron-scripts/*.sh

RUN echo '0 * * * * /cron-scripts/start_transaction.sh >> /proc/1/fd/1 2>&1' > /etc/crontabs/root

# ------------------------------------------------------------------------------
# 4. Create an entrypoint script that:
#    - Grabs environment variables from the container (API_URL, etc.)
#    - Appends them to /etc/crontabs/root so cron sees them
#    - Finally runs cron in the foreground (-f)
# ------------------------------------------------------------------------------
RUN echo '#!/bin/sh'                                          >  /entrypoint.sh \
 && echo ''                                                   >> /entrypoint.sh \
 && echo '# Grab relevant env vars and place them on top of /etc/crontabs/root' >> /entrypoint.sh \
 && echo 'env | grep -E "^(API_URL|CHARGER_ID|TAG_ID|USER_ID|TOKEN)=" > /env-vars.txt' >> /entrypoint.sh \
 && echo 'cat /env-vars.txt /etc/crontabs/root > /tmp/crontab'>> /entrypoint.sh \
 && echo 'mv /tmp/crontab /etc/crontabs/root'                 >> /entrypoint.sh \
 && echo ''                                                   >> /entrypoint.sh \
 && echo 'echo "Using the following environment variables in cron:"' >> /entrypoint.sh \
 && echo 'cat /env-vars.txt'                                  >> /entrypoint.sh \
 && echo ''                                                   >> /entrypoint.sh \
 && echo '# Start cron in foreground so container does not exit' >> /entrypoint.sh \
 && echo 'exec crond -f'                                      >> /entrypoint.sh

# 5. Make entrypoint script executable
RUN chmod +x /entrypoint.sh

# 6. Use our entrypoint script
ENTRYPOINT ["/entrypoint.sh"]
