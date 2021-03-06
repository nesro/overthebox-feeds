#!/bin/sh

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
#       Copyright (C) 2012-4 Michael D. Taht, Toke Høiland-Jørgensen, Sebastian Moeller


. /lib/functions.sh

. /etc/qos/sqm.conf

ACTION="${1:-start}"
RUN_IFACE="$2"
ACTION_UPLOAD="$3"
ACTION_DOWNLOAD="$4"

[ -d "${SQM_QDISC_STATE_DIR}" ] || ${SQM_LIB_DIR}/update-available-qdiscs

# Stopping all active interfaces
if [ "$ACTION" = "stop" -a -z "$RUN_IFACE" ]; then
    for f in ${SQM_STATE_DIR}/*.state; do
        # Source the state file prior to stopping; we need the $IFACE and
        # $SCRIPT variables saved in there.
        [ -f "$f" ] && ( . $f; IFACE=$IFACE SCRIPT=$SCRIPT SQM_DEBUG=$SQM_DEBUG SQM_DEBUG_LOG=$SQM_DEBUG_LOG OUTPUT_TARGET=$OUTPUT_TARGET ${SQM_LIB_DIR}/stop-sqm )
    done
    exit 0
fi

# For each interface
config_load network
run_sqm_scripts() {
    local section="$1"

    export IFACE=$(config_get "$section" ifname)
    [ -z "$RUN_IFACE" -o "$RUN_IFACE" = "$IFACE" ] || return

    [ -z "$(config_get "$section" trafficcontrol)" ] && return
    [ $(config_get "$section" trafficcontrol) == "off" ] && {
        CUR_STATE_FILE="${SQM_STATE_DIR}/${IFACE}.state"
        if [ -f "${CUR_STATE_FILE}" ]; then
            "${SQM_LIB_DIR}/stop-sqm"
        fi
    }

    if [ -n "$ACTION_UPLOAD" -a -n "$ACTION_DOWNLOAD" ]; then
        export UPLINK="$ACTION_UPLOAD"
        export DOWNLINK="$ACTION_DOWNLOAD"
    else
        export UPLINK=$(config_get "$section" upload)
        export DOWNLINK=$(config_get "$section" download)
    fi

    export LLAM=$(config_get "$section" linklayer_adaptation_mechanism)
    export LINKLAYER=$(config_get "$section" linklayer)
    export OVERHEAD=$(config_get "$section" overhead)
    export STAB_MTU=$(config_get "$section" tcMTU)
    export STAB_TSIZE=$(config_get "$section" tcTSIZE)
    export STAB_MPU=$(config_get "$section" tcMPU)
    export ILIMIT=$(config_get "$section" ilimit)
    export ELIMIT=$(config_get "$section" elimit)
    export ITARGET=$(config_get "$section" itarget)
    export ETARGET=$(config_get "$section" etarget)
    export IECN=$(config_get "$section" ingress_ecn)
    export EECN=$(config_get "$section" egress_ecn)
    export IQDISC_OPTS=$(config_get "$section" iqdisc_opts)
    export EQDISC_OPTS=$(config_get "$section" eqdisc_opts)
    export TARGET=$(config_get "$section" target)
    export SQUASH_DSCP=$(config_get "$section" squash_dscp)
    export SQUASH_INGRESS=$(config_get "$section" squash_ingress)

    local qdisc script
    config_get qdisc "$section" qdisc "sfq"
    config_get script "$section" script "otb.qos"
    export QDISC=$qdisc
    export SCRIPT=$script

    #sm: if SQM_DEBUG was passed in via the command line make it available to the other scripts
    [ -z "$SQM_DEBUG" ] && export SQM_DEBUG

    #sm: only stop-sqm if there is something running
    CUR_STATE_FILE="${SQM_STATE_DIR}/${IFACE}.state"
    if [ -f "${CUR_STATE_FILE}" ]; then
	"${SQM_LIB_DIR}/stop-sqm"
    fi

    [ "$ACTION" = "start" ] && "${SQM_LIB_DIR}/start-sqm"
}
config_foreach run_sqm_scripts
