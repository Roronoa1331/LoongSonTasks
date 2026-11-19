# ---------------------------------------------------------------------------
# Bare-metal Digital Calculator for the Loongson LS1B200 (MIPS32).
#
# The same project can also be opened in LoongIDE with calculator_baremetal.lxp;
# both build paths compile exactly the sources listed here.
#
#   make            build Build/calculator_baremetal.exe and .bin
#   make clean      remove the build directory
# ---------------------------------------------------------------------------

CC := E:/LoongIDE/mips-2015.05/bin/mips-sde-elf-gcc.exe
OBJCOPY := E:/LoongIDE/mips-2015.05/bin/mips-sde-elf-objcopy.exe
SIZE := E:/LoongIDE/mips-2015.05/bin/mips-sde-elf-size.exe
BUILD := Build

CFLAGS := -mips32 -G0 -EL -msoft-float -O0 -g -Wall -fno-builtin \
	-I. -Iinclude -Icore/include -Icore/mips
ASFLAGS := $(CFLAGS)
LDFLAGS := -mips32 -G0 -EL -msoft-float -nostartfiles -nodefaultlibs \
	-nostdlib -static -T ld.script -Wl,-Map=$(BUILD)/calculator_baremetal.map -e start
LIBS := -lc -lm -lgcc

OBJS := $(BUILD)/start.o \
	$(BUILD)/cache.o \
	$(BUILD)/irq_s.o \
	$(BUILD)/ls1b_exception_handler.o \
	$(BUILD)/ls1b_interrupt_handler.o \
	$(BUILD)/bsp_start.o \
	$(BUILD)/uart5.o \
	$(BUILD)/syscalls.o \
	$(BUILD)/calculator.o

all: $(BUILD)/calculator_baremetal.exe $(BUILD)/calculator_baremetal.bin

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/start.o: core/start.S | $(BUILD)
	$(CC) $(ASFLAGS) -c $< -o $@

$(BUILD)/cache.o: core/cache.S | $(BUILD)
	$(CC) $(ASFLAGS) -c $< -o $@

$(BUILD)/irq_s.o: core/irq_s.S | $(BUILD)
	$(CC) $(ASFLAGS) -c $< -o $@

$(BUILD)/ls1b_exception_handler.o: core/ls1b_exception_handler.S | $(BUILD)
	$(CC) $(ASFLAGS) -c $< -o $@

$(BUILD)/ls1b_interrupt_handler.o: core/ls1b_interrupt_handler.S | $(BUILD)
	$(CC) $(ASFLAGS) -c $< -o $@

$(BUILD)/bsp_start.o: bsp_start.c include/uart5.h | $(BUILD)
	$(CC) $(CFLAGS) -DCALCULATOR_BAREMETAL -c $< -o $@

$(BUILD)/uart5.o: uart5.c include/uart5.h | $(BUILD)
	$(CC) $(CFLAGS) -c uart5.c -o $@

$(BUILD)/syscalls.o: syscalls.c include/uart5.h | $(BUILD)
	$(CC) $(CFLAGS) -c syscalls.c -o $@

$(BUILD)/calculator.o: src/calculator.c | $(BUILD)
	$(CC) $(CFLAGS) -DCALCULATOR_BAREMETAL -c $< -o $@

$(BUILD)/calculator_baremetal.exe: $(OBJS) ld.script
	$(CC) $(LDFLAGS) -o $@ $(OBJS) $(LIBS)
	$(SIZE) $@

$(BUILD)/calculator_baremetal.bin: $(BUILD)/calculator_baremetal.exe
	$(OBJCOPY) -O binary $< $@

clean:
	rm -rf $(BUILD)

.PHONY: all clean
