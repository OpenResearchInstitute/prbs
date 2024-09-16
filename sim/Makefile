# Makefile

# defaults
SIM ?= nvc
TOPLEVEL_LANG ?= vhdl
GUI = 1
SCRIPT_FILE =

ifeq ($(SIM),ghdl)
	COMPILE_ARGS = --std=08
endif

SIM_ARGS = --wave=prbs.ghw

SRC = ../src

# use VHDL_SOURCES for VHDL files
VHDL_SOURCES += $(SRC)/prbs_gen.vhd $(SRC)/prbs_mon.vhd ./prbs_tb.vhd

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = prbs_tb

# MODULE is the basename of the Python test file
MODULE = prbs_sim

TESTCASE = prbs_loopback_test

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
