###############################################################################
## Tool paths
###############################################################################
VERILATOR_SRC ?= /home/mclovin/verilator-3.890/share/verilator/include
SYSTEMC_HOME  ?= /home/mclovin/systemc-2.3.3

TEST_IMAGE ?= ../core/isa_sim/images/basic.elf

CORE       ?= rv32imsu

# Set PATH to include our custom Verilator
PATH := /home/mclovin/verilator-3.890/bin:$(PATH)
SYSTEMC_INCLUDE := /home/mclovin/systemc-2.3.3/include
SYSTEMC_LIBDIR := /home/mclovin/systemc-2.3.3/lib-linux64
LD_LIBRARY_PATH := /home/mclovin/systemc-2.3.3/lib-linux64:$(LD_LIBRARY_PATH)

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