# ===========================================================================
#  Digital Calculator - Makefile
#
#  Targets
#    make            build the native Windows console program
#    make test       build and run the automated test suite (18 cases)
#    make run        build and start the calculator interactively
#    make mips       cross-compile for MIPS32 with the MIPS SDE Lite toolchain
#    make mips-test  run the same test suite on the MIPS32 build (simulator)
#    make clean      remove build output
#
#  Native compiler : gcc (MinGW)
#  MIPS  compiler  : mips-sde-elf-gcc (MIPS SDE Lite, shipped with LoongIDE)
# ===========================================================================

CC        = gcc
CFLAGS    = -std=c99 -Wall -Wextra -pedantic -O2
SRC       = src/calculator.c
OBJ       = build/calculator.exe

MIPS_BIN  = E:/LoongIDE/mips-2011.03/bin
MIPS_GCC  = $(MIPS_BIN)/mips-sde-elf-gcc.exe
MIPS_RUN  = $(MIPS_BIN)/mips-sde-elf-run.exe
MIPS_READELF = $(MIPS_BIN)/mips-sde-elf-readelf.exe
MIPS_CFLAGS  = -mips32 -G0 -EL -msoft-float -O1 -Wall
MIPS_DIR  = build_mips
MIPS_ELF  = $(MIPS_DIR)/calculator.elf

POWERSHELL = powershell -NoProfile -ExecutionPolicy Bypass -File

.PHONY: all test run clean mips mips-test help

all: $(OBJ)

$(OBJ): $(SRC)
	$(CC) $(CFLAGS) -o $(OBJ) $(SRC)

test: $(OBJ)
	$(POWERSHELL) tests/run_tests.ps1

run: $(OBJ)
	./$(OBJ)

mips: $(MIPS_ELF)

$(MIPS_ELF): $(SRC) target/crt0.S target/sim.ld
	mkdir -p $(MIPS_DIR)
	$(MIPS_GCC) $(MIPS_CFLAGS) -c target/crt0.S -o $(MIPS_DIR)/crt0.o
	$(MIPS_GCC) $(MIPS_CFLAGS) -c $(SRC) -o $(MIPS_DIR)/calculator.o
	$(MIPS_GCC) -mips32 -G0 -EL -msoft-float -nostartfiles -T target/sim.ld \
		-Wl,--start-group -o $(MIPS_ELF) \
		$(MIPS_DIR)/crt0.o $(MIPS_DIR)/calculator.o \
		-lcs3hosted -lc -lm -lgcc -Wl,--end-group
	$(MIPS_GCC) -mips32 -G0 -EL -msoft-float -DLS1B -O0 -Wall \
		-c $(SRC) -o $(MIPS_DIR)/calculator_ls1b.o
	$(MIPS_READELF) -h $(MIPS_ELF) | grep -e Class -e Data -e Machine -e Entry
	@echo "MIPS32 image: $(MIPS_ELF)"

mips-test: $(MIPS_ELF)
	$(POWERSHELL) tests/run_tests.ps1 -ResultsSubdir results-mips \
		-Exe $(MIPS_RUN) -ExeArgs ../$(MIPS_ELF)

clean:
	rm -f $(OBJ)
	rm -rf $(MIPS_DIR)
	rm -rf tests/results tests/results-mips tests/cases

help:
	@echo Targets: all, test, run, mips, mips-test, clean
