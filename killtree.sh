#!/bin/bash

# ----------------------------------------------------------

# killtree
#
# Sends signals to process trees with style.
#
# Usage: killtree[.sh] [options] [--] process_name_or_pid ...
#
# This script also contains reusable functions.
#
# Disclaimer: This tool comes with no warranty.
#
# Author: konsolebox
# Copyright Free / Public Domain
# Dec. 15, 2015

# ----------------------------------------------------------

# kill_tree (pid, [signal = SIGTERM])
#
# Creates a list of processes first then sends the signal to all of
# them synchronously.
#
function kill_tree {
	local LIST=("$1")
	list_children_ "$1"
	kill -s "${2-SIGTERM}" "${LIST[@]}"
}

# kill_tree_2 (pid, [signal = SIGTERM])
#
# This version kills processes as it goes.
#
function kill_tree_2 {
	local LIST=() S=${2-SIGTERM} A
	IFS=$'\n' read -ra LIST -d '' < <(exec pgrep -P "$1")
	kill -s "$S" "$1"

	for A in "${LIST[@]}"; do
		kill_tree_2 "$A" "$S"
	done
}

# kill_tree_3 (pid, [signal = SIGTERM])
#
# This version kills child processes first before the parent.
#
function kill_tree_3 {
	local LIST=() S=${2-SIGTERM} A
	IFS=$'\n' read -ra LIST -d '' < <(exec pgrep -P "$1")

	for A in "${LIST[@]}"; do
		kill_tree_3 "$A" "$S"
	done

	kill -s "$S" "$1"
}

# kill_children (pid, [signal = SIGTERM])
#
# Creates a list of child processes first then sends the signal to all
# of them synchronously.
#
function kill_children {
	local LIST=()
	list_children_ "$1"
	kill -s "${2-SIGTERM}" "${LIST[@]}"
}

# kill_children_2 (pid, [signal = SIGTERM])
#
# This version kills processes as it goes.
#
function kill_children_2 {
	local LIST=() S=${2-SIGTERM} A
	IFS=$'\n' read -ra LIST -d '' < <(exec pgrep -P "$1")

	for A in "${LIST[@]}"; do
		kill_tree_2 "$A" "$S"
	done
}

# kill_children_3 (pid, [signal = SIGTERM])
#
# This version kills child processes first before the parent.
#
function kill_children_3 {
	local LIST=() S=${2-SIGTERM} A
	IFS=$'\n' read -ra LIST -d '' < <(exec pgrep -P "$1")

	for A in "${LIST[@]}"; do
		kill_tree_3 "$A" "$S"
	done
}

# list_tree (pid)
#
# Saves list of found PIDs to array variable LIST.
#
function list_tree {
	LIST=("$1")
	list_children_ "$1"
}

# list_children (pid)
#
# Saves list of found PIDs to array variable LIST.
#
function list_children {
	LIST=()
	list_children_ "$1"
}

# list_children_ (pid)
#
function list_children_ {
	local ADD=() A
	IFS=$'\n' read -ra ADD -d '' < <(exec pgrep -P "$1")
	LIST+=("${ADD[@]}")

	for A in "${ADD[@]}"; do
		list_children_ "$A"
	done
}

# ----------------------------------------------------------

VERSION=2015-06-14

function show_help_info {
	echo "Sends signals to a process tree with style.

Usage: $0 [OPTIONS] [--] PROCESS_NAME_OR_ID ...

Options:
  -c, --children-only  Only send signals to child processes, not the
                       specified parents.
  -h, --help           Show this help message.
  -o, --one-at-a-time  Send signal to a process every after it gets its
                       child processes enumerated.
  -r, --reverse        Process child processes first before parents.
  -s, --signal SIGNAL  Specify the signal to be sent to every process.
                       The default is SIGTERM.
  -v, --verbose        Be verbose.  
  -V, --version        Show version.

The default signal is SIGTERM.

The options --one-at-a-time and --reverse are allowed to be used at the
same time but only the last specified option gets to become effective.

If none of those two options are specified, the default action would be
to send signals to processes simultaneously after all of them gets
enumerated.

Exit Status:
The script returns 0 only when one or more processes are processed.

Example:
$0 --children-only --reverse --signal SIGHUP 1234 zombie"
}

function fail {
	echo "$@"
	exit 1
}

function main {
	local FUNCTION_SUFFIX='' SIGNAL=SIGTERM TARGETS=() TREE_OR_CHILDREN=tree VERBOSE=false

	while [[ $# -gt 0 ]]; do
		case $1 in
		-c|--children-only)
			TREE_OR_CHILDREN=children
			;;
		-h|--help)
			show_help_info
			return 1
			;;
		-o|--one-at-a-time)
			FUNCTION_SUFFIX='_1'
			;;
		-r|--reverse)
			FUNCTION_SUFFIX='_2'
			;;
		-s)
			SIGNAL=$2
			shift
			;;
		-v|--verbose)
			VERBOSE=true
			;;
		-V|--version)
			echo "${VERSION}"
			return 1
			;;
		--)
			TARGETS+=("${@:2}")
			break
			;;
		-*)
			fail "Invalid option: $1"
			;;
		*)
			TARGETS+=("$1")
			;;
		esac

		shift
	done

	[[ ${#TARGETS[@]} -eq 0 ]] && fail "No target specified."

	if [[ ${VERBOSE} == true ]]; then
		function kill {
			echo "Process: ${@:3}"
			builtin kill "$@"
		}

		function log_verbose {
			echo "$@"
		}
	else
		function log_verbose {
			:
		}
	fi

	local TARGET_PIDS=() NAMES PIDS __

	for __ in "${TARGETS[@]}"; do
		if [[ $__ == +([[:digit:]]) ]]; then
			TARGET_PIDS+=("$__")
		else
			IFS=$'\n' read -ra PIDS -d '' < <(exec pgrep -x -- "$__")
			[[ ${#PIDS[@]} -eq 0 ]] && fail "No process found from name: $__"
			log_verbose "Processes matching $__: ${PIDS[@]}"
			TARGET_PIDS+=("${PIDS[@]}")
		fi
	done

	log_verbose "Parent targets: ${TARGET_PIDS[@]}"
	
	local FUNCTION=kill_${TREE_OR_CHILDREN}${FUNCTION_SUFFIX}

	for __ in "${TARGET_PIDS[@]}"; do
		log_verbose "Call: ${FUNCTION} $__"
		"${FUNCTION}" "$__" "${SIGNAL}"
	done

	return 0
}

main "$@"