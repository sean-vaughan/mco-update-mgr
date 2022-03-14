#!/bin/bash

# Purpose:
#
# This script delays machine config pools from being updated for a specified
# number of seconds, 1200 seconds or 10 minutes by default. Machine config pool
# updates will result in pods moving off of nodes and then the nodes being
# updated and finally rebooted. Delaying these updates helps preclude unecessary
# reboots, and provides time for other workloads to be installed or updated
# before being interrupted.
#
# Rules:
#
# This script will keep machine config pool updates paused until the Updated
# condition is False, then after UPDATE_DELAY seconds, paused will be set to
# false to allow pods to be scheduled off of nodes and then nodes rebooted.
#
# If the Updated machine config pool condition is True, this script sets pause
# to true (if it's not already true).

set -euo pipefail

log() {
    echo "`date --rfc-3339=s` $@"
}

# About 20 minutes is required for a moderate amount of day-2 operations
# automation to complete from start to finish. Set the UPDATE_DELAY environment
# variable value the desired delay seconds to override the default of 1200
# seconds.
UPDATE_DELAY="${UPDATE_DELAY:-1200}" # seconds
MCP_FILE=/tmp/mcp.json

oc get mcp -o json > "${MCP_FILE}"

mcps=`jq .items[].metadata.name "${MCP_FILE}" | tr -d \" | tr \\\n ' '`
log "Machine Config Pools: ${mcps}"

mcp_jq () {
    jq "$*" "${MCP_FILE}" | tr -d \"
}

for mcp in ${mcps}
do
    CONDITIONS='.items[] | select(.metadata.name == "'${mcp}'") | .status.conditions[]'
    UPDATED=`mcp_jq "${CONDITIONS}"' | select(.type == "Updated") | .status'`

    U_TIME=`mcp_jq "$CONDITIONS"' | select(.type == "Updated") | .lastTransitionTime'`
    U_TIME_S=`date -d "${U_TIME}" '+%s'`
    TIME_SINCE_UPDATED=$(( `date '+%s'` - ${U_TIME_S} ))

    UPDATING=`mcp_jq "$CONDITIONS"' | select(.type == "Updating") | .status'`
    PAUSED=`mcp_jq '.items[] | select(.metadata.name == "'${mcp}'") | .spec.paused'`

    log "${mcp} Updated: ${UPDATED} Time: ${TIME_SINCE_UPDATED} Wait: ${UPDATE_DELAY} Updating: ${UPDATING} Paused: ${PAUSED}"

    if [ $UPDATED == 'True' ] && [ $PAUSED == 'false' ]
    # If the Updated machine config pool condition is True, this script sets pause
    # to true (if it's not already true).
    then
        log "${mcp} Updated is True and paused is false,"
        log "${mcp} setting paused to true, disabling node updates"
        log $( oc patch mcp "${mcp}" -p '{"spec":{"paused":true}}' --type merge )
    elif [ $UPDATED == "False" ] && [ $UPDATING == "False" ] \
        && [ $PAUSED == 'true' ] && [ $TIME_SINCE_UPDATED -gt $UPDATE_DELAY ]
    # When the Updated condition is False, and then after UPDATE_DELAY seconds,
    # paused will be set to false to allow pods to be scheduled off of nodes and
    # then nodes rebooted.
    then
        log "${mcp} Updated is False and ${UPDATE_DELAY} seconds or more have passed,"
        log "${mcp} setting paused to false, enabling node updates"
        log $( oc patch mcp "${mcp}" -p '{"spec":{"paused":false}}' --type merge )
    fi
done
