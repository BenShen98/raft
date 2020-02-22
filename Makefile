
# distributed algorithms, n.dulay, 4 feb 2020
# Makefile, raft consensus, v1
# Leyang Shen (ls2617)

SHELL := /bin/bash

SERVERS  = 5
CLIENTS  = 5
START    = Raft.start
MAX_TIME = 10000
CONFIGJSON=

HOST	:= 127.0.0.1

# --------------------------------------------------------------------

TIME    := $(shell date +%H:%M:%S)
SECS    := $(shell date +%S)
COOKIE  := $(shell echo $$PPID)

NODE_SUFFIX := ${SECS}_${LOGNAME}@${HOST}

ELIXIR  := elixir --no-halt --cookie ${COOKIE} --name
MIX 	:= -S mix run -e ${START} ${MAX_TIME} ${NODE_SUFFIX} ${SERVERS} ${CLIENTS}

# --------------------------------------------------------------------

compile: install
	mix compile

run run_multi: compile
	@for (( i=0; i<${SERVERS}; i++ )); do \
	${ELIXIR} server$${i}_${NODE_SUFFIX} ${MIX} multi_node_wait ${CONFIGJSON} & \
	done;

	@for (( i=0; i<${CLIENTS}; i++ )); do \
	${ELIXIR} client$${i}_${NODE_SUFFIX} ${MIX} multi_node_wait ${CONFIGJSON} & \
	done

	@sleep 2
	@ ${ELIXIR} raft_${NODE_SUFFIX} ${MIX} multi_node_start ${CONFIGJSON}


clean:
	mix clean
	@rm -f erl_crash.dump

install:
	mix deps.get

# -- 'make ps' will list Elixir nodes running locally
ps:
	@echo ------------------------------------------------------------
	epmd -names


