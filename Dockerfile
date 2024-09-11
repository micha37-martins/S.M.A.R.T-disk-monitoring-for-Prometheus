# Use an official Alpine Linux image as a parent image
FROM alpine:3.20.2

# Install necessary tools (Git and Curl)
RUN apk add --no-cache bash git curl jq smartmontools

# Copy your smartmon.sh script to the container
COPY src/smartmon.sh /app/smartmon.sh

# Set the cron schedule using an environment variable
ENV CRON_SCHEDULE="*/10 * * * *"

# Set the default output path using an environment variable
ENV OUTPUT_PATH=/var/lib/node_exporter/textfile_collector/smart_metrics.prom

# Create the /etc/cron.d/ directory
RUN mkdir -p /etc/cron.d/

# Create a cron job to run the smartmon.sh script every x minutes
RUN echo "$CRON_SCHEDULE /app/smartmon.sh > $OUTPUT_PATH" > /etc/cron.d/smartmon && \
    chmod 0644 /etc/cron.d/smartmon && \
    crontab /etc/cron.d/smartmon

# Start the cron daemon
CMD ["/usr/sbin/crond", "-f"]
