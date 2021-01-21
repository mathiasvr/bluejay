# set current revision
REVISION		?= v0.7

# targets
TARGETS			= A B C D E F G H I J K L M N O P Q R S T U V W
MCUS			= H L
FETON_DELAYS	= 0 5 10 15 20 25 30 40 50 70 90
PWM_FREQUENCIES	= 24 48 96

# example single target
TARGET			?= F
MCU				?= H
FETON_DELAY		?= 40
PWM_FREQUENCY	?= 24

WINE_BIN		?= /usr/local/bin/wine

# path to the keil binaries
KEIL_PATH		?= ~/Downloads/keil_8051/9.60/BIN

# directory config
OUTPUT_DIR		?= build
OUTPUT_DIR_HEX	?= $(OUTPUT_DIR)/hex
LOG_DIR			?= $(OUTPUT_DIR)/logs

# define the assembler/linker scripts
AX51_BIN = $(KEIL_PATH)/AX51.exe
LX51_BIN = $(KEIL_PATH)/LX51.exe
OX51_BIN = $(KEIL_PATH)/Ohx51.exe
AX51 = $(WINE_BIN) $(AX51_BIN)
LX51 = $(WINE_BIN) $(LX51_BIN)
OX51 = $(WINE_BIN) $(OX51_BIN)

# set up flags
AX51_FLAGS = DEBUG NOMOD51
#AX51_FLAGS = NOMOD51 NOLIST
LX51_FLAGS =

# set up sources
ASM_SRC = Bluejay.asm
ASM_INC = $(TARGETS:%=targets/%.inc) Common.inc BLHeliBootLoad.inc Silabs/SI_EFM8BB1_Defs.inc Silabs/SI_EFM8BB2_Defs.inc

# check that wine/simplicity studio is available
EXECUTABLES = $(WINE_BIN) $(AX51_BIN) $(LX51_BIN) $(OX51_BIN)
DUMMYVAR := $(foreach exec, $(EXECUTABLES), \
				$(if $(wildcard $(exec)),found, \
				$(error "Could not find $(exec). Make sure to set the correct paths to the simplicity install location")))

# delete object files on error and warnings
.DELETE_ON_ERROR:

# make sure the list of obj files is expanded twice
.SECONDEXPANSION:
OBJS =

define MAKE_OBJ
OBJS += $(1)_$(2)_$(3)_$(4)_$(REVISION).OBJ
$(OUTPUT_DIR)/$(1)_$(2)_$(3)_$(4)_$(REVISION).OBJ : $(ASM_SRC) $(ASM_INC)
	$(eval _ESC			:= $(1))
	$(eval _ESC_INT		:= $(shell printf "%d" "'${_ESC}"))
	$(eval _ESCNO		:= $(shell echo $$(( $(_ESC_INT) - 65 + 1))))
	$(eval _MCU_48MHZ	:= $(subst L,0,$(subst H,1,$(2))))
	$(eval _FETON_DELAY	:= $(3))
	$(eval _PWM_FREQ	:= $(subst 24,0,$(subst 48,1,$(subst 96,2,$(4)))))
	$(eval _LOG			:= $(LOG_DIR)/$(1)_$(2)_$(3)_$(4)_$(REVISION).log)
	@mkdir -p $(OUTPUT_DIR)
	@mkdir -p $(LOG_DIR)
	@echo "AX51 : $$@"
	@$(AX51) $(ASM_SRC) \
		"DEFINE(ESCNO=$(_ESCNO)) " \
		"DEFINE(MCU_48MHZ=$(_MCU_48MHZ)) "\
		"DEFINE(FETON_DELAY=$(_FETON_DELAY)) "\
		"DEFINE(PWM_FREQ=$(_PWM_FREQ)) "\
		"OBJECT($$@) "\
		"$(AX51_FLAGS)" > $(_LOG) 2>&1 || (mv ./Bluejay.LST $(OUTPUT_DIR)/; tail $(_LOG); exit 1)
	@mv ./Bluejay.LST $(OUTPUT_DIR)/

endef

HEX_TARGETS = $(OBJS:%.OBJ=$(OUTPUT_DIR_HEX)/%.hex)

EFM8_LOAD_BIN  ?= efm8load.py
EFM8_LOAD_PORT ?= /dev/ttyUSB0
EFM8_LOAD_BAUD ?= 57600

SINGLE_TARGET_HEX = $(OUTPUT_DIR_HEX)/$(TARGET)_$(MCU)_$(FETON_DELAY)_$(PWM_FREQUENCY)_$(REVISION).hex

single_target : $(SINGLE_TARGET_HEX)

all : $$(HEX_TARGETS)
	@echo "\nbuild finished. built $(shell ls -Aq $(OUTPUT_DIR_HEX) | wc -l) hex targets\n"

# create all obj targets using macro expansion
$(foreach _t,$(TARGETS), \
	$(foreach _m, $(MCUS), \
		$(foreach _f, $(FETON_DELAYS), \
			$(foreach _p, $(PWM_FREQUENCIES), \
				$(eval $(call MAKE_OBJ,$(_t),$(_m),$(_f),$(_p)))))))


$(OUTPUT_DIR)/%.OMF : $(OUTPUT_DIR)/%.OBJ
	$(eval LOG := $(LOG_DIR)/$(basename $(notdir $@)).log)
	@echo "LX51 : linking $< to $@"
#	# Linking should produce exactly 1 warning
	@$(LX51) "$<" TO "$@" "$(LX51_FLAGS)" >> $(LOG) 2>&1; test $$? -lt 2 && grep -q "1 WARNING" $(LOG) || (tail $(LOG); exit 1)

$(OUTPUT_DIR_HEX)/%.hex : $(OUTPUT_DIR)/%.OMF
	$(eval LOG := $(LOG_DIR)/$(basename $(notdir $@)).log)
	@mkdir -p $(OUTPUT_DIR_HEX)
	@echo "OHX  : generating hex file $@"
	@$(OX51) "$<" "HEXFILE ($@)" >> $(LOG) 2>&1 || (tail $(LOG); exit 1)

changelog:
	@npx -q commitlint --config .github/workflows/commitlint.config.js --from v0.1.0
	@npx -q mathiasvr/generate-changelog --exclude build,chore,ci,docs,refactor,style,other

help:
	@echo ""
	@echo "usage examples:"
	@echo "================================================================"
	@echo "make all                              # build all targets"
	@echo "make TARGET=A MCU=H FETON_DELAY=5     # to build a single target"
	@echo

clean:
	@rm -f $(OUTPUT_DIR)/*.{OBJ,MAP,OMF,LST}
	@rm -f $(LOG_DIR)/*.log

efm8load: single_target
	$(EFM8_LOAD_BIN) -p $(EFM8_LOAD_PORT) -b $(EFM8_LOAD_BAUD) -w $(SINGLE_TARGET_HEX)


.PHONY: all clean help efm8load
