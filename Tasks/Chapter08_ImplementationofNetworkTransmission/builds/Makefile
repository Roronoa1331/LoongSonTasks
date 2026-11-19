#-----------------------------------------------------------------------------
# Chapter 08 - Loongson 1B network transmission
#
# Multi-configuration build file (GNU make + LoongIDE MIPS toolchain).
#
# Every experiment uses the same source tree; only the four TEST_* macros in
# ../lwip_test.h select which demo is compiled in.  Each experiment therefore
# gets its own output directory so all four firmwares can be kept side by side:
#
#     builds/tcp_server/  builds/tcp_client/
#     builds/udp_server/  builds/udp_client/
#
# Invoke it through build.ps1, which sets the macros and the directories:
#     .\build.ps1 -Experiment tcp_server
#-----------------------------------------------------------------------------

TOOLCHAIN ?= E:/LoongIDE/mips-2015.05/bin

CC      := $(TOOLCHAIN)/mips-sde-elf-gcc.exe
OBJCOPY := $(TOOLCHAIN)/mips-sde-elf-objcopy.exe
SIZE    := $(TOOLCHAIN)/mips-sde-elf-size.exe
RM      := rm -rf

EXP    ?= tcp_client
ROOT   := ..
OUT    := $(EXP)
OBJDIR := $(OUT)/obj

ARCHFLAGS := -mips32 -G0 -EL -msoft-float
DEFS      := -DLS1B -DOS_RTTHREAD

# Same include set as Chapter08_ImplementationofNetworkTransmission.lxp,
# plus the project root and "include" which LoongIDE adds implicitly.
INCLUDES := \
	-I$(ROOT) \
	-I$(ROOT)/include \
	-I$(ROOT)/RTT4/include \
	-I$(ROOT)/RTT4/port/include \
	-I$(ROOT)/RTT4/port/mips \
	-I$(ROOT)/RTT4/components/finsh \
	-I$(ROOT)/RTT4/components/dfs/include \
	-I$(ROOT)/RTT4/components/drivers/include \
	-I$(ROOT)/RTT4/components/libc/time \
	-I$(ROOT)/RTT4/bsp-ls1x \
	-I$(ROOT)/ls1x-drv/include \
	-I$(ROOT)/yaffs2/direct \
	-I$(ROOT)/yaffs2/port \
	-I$(ROOT)/lwIP-1.4.1/include \
	-I$(ROOT)/lwIP-1.4.1/include/ipv4 \
	-I$(ROOT)/lwIP-1.4.1/port/include

CFLAGS := $(ARCHFLAGS) $(DEFS) -O0 -g -Wall -c -fmessage-length=0 -pipe \
          $(INCLUDES) -MMD -MP

# Recursive wildcard: $(call rwildcard,dir,*.c)
rwildcard = $(foreach d,$(wildcard $(1)*),$(call rwildcard,$(d)/,$(2))$(filter $(subst *,%,$(2)),$(d)))

CSRCS := $(call rwildcard,$(ROOT)/,*.c)
SSRCS := $(call rwildcard,$(ROOT)/,*.S)

COBJS := $(patsubst $(ROOT)/%.c,$(OBJDIR)/%.o,$(CSRCS))
SOBJS := $(patsubst $(ROOT)/%.S,$(OBJDIR)/%.o,$(SSRCS))

# start.S provides the entry point and must be linked first (as LoongIDE does)
STARTO := $(OBJDIR)/RTT4/port/start.o
OBJS   := $(filter-out $(STARTO),$(SOBJS)) $(COBJS)
DEPS   := $(OBJS:.o=.d)

LINKCMDS := $(ROOT)/ld.script
OUT_ELF  := $(OUT)/$(EXP).exe
OUT_BIN  := $(OUT)/$(EXP).bin
OUT_MAP  := $(OUT)/$(EXP).map

.PHONY: all clean
all: $(OUT_ELF)

$(OUT_ELF): $(STARTO) $(OBJS) $(LINKCMDS)
	@echo 'Linking  $(OUT_ELF)'
	@$(CC) $(ARCHFLAGS) -nostartfiles -static -T $(LINKCMDS) \
		-Wl,-Map=$(OUT_MAP) -o $(OUT_ELF) -e start \
		$(STARTO) $(OBJS) -lc -lm
	@$(OBJCOPY) -O binary $(OUT_ELF) $(OUT_BIN)
	@$(SIZE) $(OUT_ELF)

$(OBJDIR)/%.o: $(ROOT)/%.c
	@echo 'CC  $<'
	@$(CC) $(CFLAGS) -MF"$(@:%.o=%.d)" -MT"$(@)" -o "$@" "$<"

$(OBJDIR)/%.o: $(ROOT)/%.S
	@echo 'AS  $<'
	@$(CC) $(CFLAGS) -MF"$(@:%.o=%.d)" -MT"$(@)" -o "$@" "$<"

clean:
	@$(RM) $(OBJDIR) $(OUT_ELF) $(OUT_BIN) $(OUT_MAP)

-include $(DEPS)
