# Current version
TAG			:= $(shell git describe --tags --abbrev=0)
VERSION		?= $(TAG)

# Target parameters
LAYOUTS		= A B C D E F G H I J K L M N O P Q R S T U V W Z
MCUS		= H L
DEADTIMES	= 0 5 10 15 20 25 30 40 50 70 90 120

# Example single target
LAYOUT		?= A
MCU			?= H
DEADTIME	?= 5

# Directory configuration
OUTPUT_DIR	?= build
HEX_DIR		?= $(OUTPUT_DIR)/hex

# Path to the keil binaries
KEIL_PATH	?= ~/.wine/drive_c/Keil_v5/C51/BIN

# Assembler and linker binaries
AX51_BIN	= $(KEIL_PATH)/AX51.exe
LX51_BIN	= $(KEIL_PATH)/LX51.exe
OX51_BIN	= $(KEIL_PATH)/Ohx51.exe
AX51		= wine $(AX51_BIN)
LX51		= wine $(LX51_BIN)
OX51		= wine $(OX51_BIN)

# Set up flags
#AX51_FLAGS	= DEBUG NOMOD51
AX51_FLAGS	= NOMOD51 REGISTERBANK(0,1,2) NOLIST NOSYMBOLS
LX51_FLAGS	=

# Source files
ASM_SRC		= Bluejay.asm
ASM_INC		= $(LAYOUTS:%=Layouts/%.inc) Layouts/Base.inc Common.inc BLHeliBootLoad.inc Silabs/SI_EFM8BB1_Defs.inc Silabs/SI_EFM8BB2_Defs.inc

# Check that wine/simplicity studio is available
EXECUTABLES	= $(AX51_BIN) $(LX51_BIN) $(OX51_BIN)
DUMMYVAR	:= $(foreach exec, $(EXECUTABLES), \
				$(if $(wildcard $(exec)),found, \
				$(error "Could not find $(exec). Make sure to set the correct paths to the simplicity install location")))

# Set up efm8load
EFM8_LOAD_BIN	?= tools/efm8load.py
EFM8_LOAD_PORT	?= /dev/ttyUSB0
EFM8_LOAD_BAUD	?= 115200

# Delete object files on error and warnings
.DELETE_ON_ERROR:

# AX51 mixes up input defines when run in parallel. Maybe because you cannot change the TMP directory per invocation.
.NOTPARALLEL:

define MAKE_OBJ
OBJS += $(1)_$(2)_$(3)_$(VERSION).OBJ
$(OUTPUT_DIR)/$(1)_$(2)_$(3)_$(VERSION).OBJ : $(ASM_SRC) $(ASM_INC)
	$(eval _ESC			:= $(1))
	$(eval _ESC_INT		:= $(shell printf "%d" "'${_ESC}"))
	$(eval _ESCNO		:= $(shell echo $$(( $(_ESC_INT) - 65 + 1))))
	$(eval _MCU_48MHZ	:= $(subst L,0,$(subst H,1,$(2))))
	$(eval _DEADTIME	:= $(3))
	$$(eval _LST		:= $$(patsubst %.OBJ,%.LST,$$@))
	@mkdir -p $(OUTPUT_DIR)
	@echo "AX51 : $$@"
	@$(AX51) $(ASM_SRC) \
		"DEFINE(ESCNO=$(_ESCNO)) " \
		"DEFINE(MCU_48MHZ=$(_MCU_48MHZ)) "\
		"DEFINE(DEADTIME=$(_DEADTIME)) "\
		"OBJECT($$@) "\
		"PRINT($$(_LST)) "\
		"$(AX51_FLAGS)" > /dev/null 2>&1 || (grep -B 3 -E "\*\*\* (ERROR|WARNING)" $$(_LST); exit 1)
endef

SINGLE_TARGET_HEX = $(HEX_DIR)/$(LAYOUT)_$(MCU)_$(DEADTIME)_$(VERSION).hex

single_target : $(SINGLE_TARGET_HEX)

# Create all obj targets using macro expansion
$(foreach _l, $(LAYOUTS), \
	$(foreach _m, $(MCUS), \
		$(foreach _d, $(DEADTIMES), \
			$(eval $(call MAKE_OBJ,$(_l),$(_m),$(_d))))))

HEX_TARGETS = $(OBJS:%.OBJ=$(HEX_DIR)/%.hex)

all : $(HEX_TARGETS)
	@echo "\nbuild finished. built $(shell ls -Aq $(HEX_DIR) | wc -l) hex targets\n"

$(OUTPUT_DIR)/%.OMF : $(OUTPUT_DIR)/%.OBJ
	$(eval MAP := $(OUTPUT_DIR)/$(shell echo $(basename $(notdir $@)).MAP | tr 'a-z' 'A-Z'))
	@echo "LX51 : linking $< to $@"
#	Linking should produce exactly 1 warning
	@$(LX51) "$<" TO "$@" "$(LX51_FLAGS)" > /dev/null 2>&1; \
		test $$? -lt 2 && grep -q "1 WARNING" $(MAP) || \
		(grep -A 3 -E "\*\*\* (ERROR|WARNING)" $(MAP); exit 1)

$(HEX_DIR)/%.hex : $(OUTPUT_DIR)/%.OMF
	@mkdir -p $(HEX_DIR)
	@echo "OHX  : generating hex file $@"
	@$(OX51) "$<" "HEXFILE ($@)" > /dev/null 2>&1 || (echo "Error: Could not make hex file"; exit 1)

# Check if most recent commit changes production code (hex output)
check_commit: $(SINGLE_TARGET_HEX)
	@mv $(SINGLE_TARGET_HEX) $(SINGLE_TARGET_HEX:.hex=_after.hex)
	@git checkout HEAD~1
	@make $(SINGLE_TARGET_HEX)
	@git checkout -
	@diff $(SINGLE_TARGET_HEX) $(SINGLE_TARGET_HEX:.hex=_after.hex)

changelog:
	@npx -q mathiasvr/generate-changelog --exclude build,chore,ci,docs,refactor,style,other

help:
	@echo ""
	@echo "Usage examples"
	@echo "========================================================"
	@echo "make all                         # Build all targets"
	@echo "make LAYOUT=A MCU=H DEADTIME=5   # Build a single target"
	@echo

clean:
	@rm -f $(OUTPUT_DIR)/*.{OBJ,MAP,OMF,LST}

efm8load: single_target
	$(EFM8_LOAD_BIN) -p $(EFM8_LOAD_PORT) -b $(EFM8_LOAD_BAUD) -w $(SINGLE_TARGET_HEX)

.PHONY: single_target all changelog help clean efm8load check_commit
