# nx-v64z macOS Oracle Validation — Makefile
#
# Targets: all, clean, list, env, run, validate-json
#
# Build outputs go under .build/ only. Source and result directories
# are never touched by clean.
#
# Compatible with both GNU make (macOS) and BSD make (FreeBSD).

CC        ?= clang
CFLAGS     = -Wall -Wextra -O0 -g
BUILD_DIR  = .build
BIN_DIR    = $(BUILD_DIR)/bin
OBJ_DIR    = $(BUILD_DIR)/obj
COMMON_DIR = probes/common

COMMON_INCLUDES = -I$(COMMON_DIR)

# Common helper objects — explicit list
COMMON_OBJS = \
	$(OBJ_DIR)/nx_json.o \
	$(OBJ_DIR)/nx_env.o \
	$(OBJ_DIR)/nx_result.o \
	$(OBJ_DIR)/nx_mach_utils.o

# Probes — explicit list
PROBES = foundation/smoke foundation/port_names
PROBE_BINS = \
	$(BIN_DIR)/foundation/smoke \
	$(BIN_DIR)/foundation/port_names

AGENT    ?= rx

.PHONY: all clean list env run validate-json

all: $(PROBE_BINS)

# Common object compilation rules
$(OBJ_DIR)/nx_json.o: $(COMMON_DIR)/nx_json.c $(COMMON_DIR)/nx_json.h
	@mkdir -p $(OBJ_DIR)
	$(CC) $(CFLAGS) $(COMMON_INCLUDES) -c -o $@ $(COMMON_DIR)/nx_json.c

$(OBJ_DIR)/nx_env.o: $(COMMON_DIR)/nx_env.c $(COMMON_DIR)/nx_env.h $(COMMON_DIR)/nx_json.h
	@mkdir -p $(OBJ_DIR)
	$(CC) $(CFLAGS) $(COMMON_INCLUDES) -c -o $@ $(COMMON_DIR)/nx_env.c

$(OBJ_DIR)/nx_result.o: $(COMMON_DIR)/nx_result.c $(COMMON_DIR)/nx_result.h $(COMMON_DIR)/nx_json.h
	@mkdir -p $(OBJ_DIR)
	$(CC) $(CFLAGS) $(COMMON_INCLUDES) -c -o $@ $(COMMON_DIR)/nx_result.c

$(OBJ_DIR)/nx_mach_utils.o: $(COMMON_DIR)/nx_mach_utils.c $(COMMON_DIR)/nx_mach_utils.h
	@mkdir -p $(OBJ_DIR)
	$(CC) $(CFLAGS) $(COMMON_INCLUDES) -c -o $@ $(COMMON_DIR)/nx_mach_utils.c

# Probe binary rules
$(BIN_DIR)/foundation/smoke: probes/foundation/smoke.c $(COMMON_OBJS)
	@mkdir -p $(BIN_DIR)/foundation
	$(CC) $(CFLAGS) $(COMMON_INCLUDES) -o $@ probes/foundation/smoke.c $(COMMON_OBJS)

$(BIN_DIR)/foundation/port_names: probes/foundation/port_names.c $(COMMON_OBJS)
	@mkdir -p $(BIN_DIR)/foundation
	$(CC) $(CFLAGS) $(COMMON_INCLUDES) -o $@ probes/foundation/port_names.c $(COMMON_OBJS)

clean:
	rm -rf $(BUILD_DIR)

list:
	@echo "Known probes:"
	@for p in $(PROBES); do echo "  $$p"; done

env:
	@harness/collect_env.sh

run: all
	@harness/run_all.sh --agent $(AGENT)

validate-json:
	@harness/validate_json.sh
