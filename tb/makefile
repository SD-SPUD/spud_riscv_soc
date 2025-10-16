ifneq ("$(wildcard .env)","")
include .env
endif

###############################################################################
## Tool paths
###############################################################################
VERILATOR_SRC ?= $(VERILATOR_HOME)/share/verilator/include
SYSTEMC_HOME  ?= $(SYSTEMC_HOME)

TEST_IMAGE ?= ../core/isa_sim/images/basic.elf

CORE       ?= rv32imsu

# Set PATH to include our custom Verilator
PATH := $(VERILATOR_HOME)/bin:$(PATH)
SYSTEMC_INCLUDE := $(SYSTEMC_HOME)/include
SYSTEMC_LIBDIR := $(SYSTEMC_HOME)/lib-linux64
LD_LIBRARY_PATH := $(SYSTEMC_LIBDIR):$(LD_LIBRARY_PATH)

export VERILATOR_SRC
export SYSTEMC_HOME
export PATH
export SYSTEMC_INCLUDE
export SYSTEMC_LIBDIR
export LD_LIBRARY_PATH

###############################################################################
## Makefile
###############################################################################
all: build

build:
	make -C ../core/isa_sim lib
	make -f makefile.generate_verilated CORE=$(CORE)
	make -f makefile.build_verilated
	make -f makefile.build_sysc_tb

clean:
	make -f makefile.generate_verilated  CORE=$(CORE) $@
	make -f makefile.build_verilated $@
	make -f makefile.build_sysc_tb $@
	-rm *.vcd

run: build
	./build/test.x -f $(TEST_IMAGE)
