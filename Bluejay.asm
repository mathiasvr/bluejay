$NOMOD51
;**** **** **** **** ****
;
; Bluejay digital ESC firmware for controlling brushless motors in multirotors
;
; Copyright 2020 Mathias Rasmussen
; Copyright 2011, 2012 Steffen Skaug
;
; This file is part of Bluejay.
;
; Bluejay is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; Bluejay is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with Bluejay.  If not, see <http://www.gnu.org/licenses/>.
;
;**** **** **** **** ****
;
; Bluejay is a fork of BLHeli_S <https://github.com/bitdump/BLHeli> by Steffen Skaug.
;
; The input signal can be DShot with rates: DShot150, DShot300 and DShot600.
;
; This file is best viewed with tab width set to 5.
;
;**** **** **** **** ****
; Master clock is internal 24MHz oscillator (or 48MHz, for which the times below are halved)
; Although 24/48 are used in the code, the exact clock frequencies are 24.5MHz or 49.0 MHz
; Timer 0 (41.67ns counts) always counts up and is used for
; - RC pulse measurement
; - DShot telemetry pulse timing
; Timer 1 (41.67ns counts) always counts up and is used for
; - DShot frame sync detection
; Timer 2 (500ns counts) always counts up and is used for
; - RC pulse timeout counts and commutation times
; Timer 3 (500ns counts) always counts up and is used for
; - Commutation timeouts
; PCA0 (41.67ns counts) always counts up and is used for
; - Hardware PWM generation
;
;**** **** **** **** ****
; Motor control:
; - Brushless motor control with 6 states for each electrical 360 degrees
; - An advance timing of 0deg has zero cross 30deg after one commutation and 30deg before the next
; - Timing advance in this implementation is set to 15deg nominally
; - Motor pwm is always damped light (aka complementary pwm, regenerative braking)
; Motor sequence starting from zero crossing:
; - Timer wait: Wt_Comm			15deg	; Time to wait from zero cross to actual commutation
; - Timer wait: Wt_Advance		15deg	; Time to wait for timing advance. Nominal commutation point is after this
; - Timer wait: Wt_Zc_Scan		7.5deg	; Time to wait before looking for zero cross
; - Scan for zero cross			22.5deg	; Nominal, with some motor variations
;
; Motor startup:
; There is a startup phase and an initial run phase, before normal bemf commutation run begins.
;
;**** **** **** **** ****
; List of enumerated supported ESCs
A_	EQU	1		; X  X  RC X  MC MB MA CC	X  X  Cc Cp Bc Bp Ac Ap
B_	EQU	2		; X  X  RC X  MC MB MA CC	X  X  Ap Ac Bp Bc Cp Cc
C_	EQU	3		; Ac Ap MC MB MA CC X  RC	X  X  X  X  Cc Cp Bc Bp
D_	EQU	4		; X  X  RC X  CC MA MC MB	X  X  Cc Cp Bc Bp Ac Ap	Com fets inverted
E_	EQU	5		; L1 L0 RC X  MC MB MA CC	X  L2 Cc Cp Bc Bp Ac Ap	A with LEDs
F_	EQU	6		; X  X  RC X  MA MB MC CC	X  X  Cc Cp Bc Bp Ac Ap
G_	EQU	7		; X  X  RC X  CC MA MC MB	X  X  Cc Cp Bc Bp Ac Ap	Like D, but non-inverted com fets
H_	EQU	8		; RC X  X  X  MA MB CC MC	X  Ap Bp Cp X  Ac Bc Cc
I_	EQU	9		; X  X  RC X  MC MB MA CC	X  X  Ac Bc Cc Ap Bp Cp
J_	EQU	10		; L2 L1 L0 RC CC MB MC MA	X  X  Cc Bc Ac Cp Bp Ap	LEDs
K_	EQU	11		; X  X  MC X  MB CC MA RC	X  X  Ap Bp Cp Cc Bc Ac	Com fets inverted
L_	EQU	12		; X  X  RC X  CC MA MB MC	X  X  Ac Bc Cc Ap Bp Cp
M_	EQU	13		; MA MC CC MB RC L0 X  X 	X  Cc Bc Ac Cp Bp Ap X	LED
N_	EQU	14		; X  X  RC X  MC MB MA CC	X  X  Cp Cc Bp Bc Ap Ac
O_	EQU	15		; X  X  RC X  CC MA MC MB	X  X  Cc Cp Bc Bp Ac Ap	Like D, but low side pwm
P_	EQU	16		; X  X  RC MA CC MB MC X 	X  Cc Bc Ac Cp Bp Ap X
Q_	EQU	17		; Cp Bp Ap L1 L0 X  RC X 	X  MA MB MC CC Cc Bc Ac	LEDs
R_	EQU	18		; X  X  RC X  MC MB MA CC	X  X  Ac Bc Cc Ap Bp Cp
S_	EQU	19		; X  X  RC X  CC MA MC MB	X  X  Cc Cp Bc Bp Ac Ap	Like O, but com fets inverted
T_	EQU	20		; RC X  MA X  MB CC MC X 	X  X  Cp Bp Ap Ac Bc Cc
U_	EQU	21		; MA MC CC MB RC L0 L1 L2	X  Cc Bc Ac Cp Bp Ap X	Like M, but with 3 LEDs
V_	EQU	22		; Cc X  RC X  MC CC MB MA	X  Ap Ac Bp X  X  Bc Cp
W_	EQU	23		; RC MC MB X  CC MA X X		X  Ap Bp Cp X  X  X  X	Tristate gate driver

;**** **** **** **** ****
; Select the port mapping to use (or unselect all for use with external batch compile file)
;ESCNO			EQU	A_

;**** **** **** **** ****
; Select the MCU type (or unselect for use with external batch compile file)
;MCU_48MHZ		EQU	0

;**** **** **** **** ****
; Select the fet dead time (or unselect for use with external batch compile file)
;FETON_DELAY		EQU	15	; 20.4ns per step

;**** **** **** **** ****
; Select the pwm frequency (or unselect for use with external batch compile file)
;PWM_FREQ			EQU	0	; 0=24, 1=48, 2=96 kHz


PWM_CENTERED	EQU	FETON_DELAY > 0		; Use center aligned pwm on ESCs with dead time

IF MCU_48MHZ < 2 AND PWM_FREQ	< 3
	; Number of bits in pwm high byte
	PWM_BITS_H	EQU	(2 + MCU_48MHZ - PWM_CENTERED - PWM_FREQ)
ENDIF

$include (Common.inc)					; Include common source code for EFM8BBx based ESCs

;**** **** **** **** ****
; Programming defaults
DEFAULT_PGM_STARTUP_PWR			EQU	9	; 1=0.031 2=0.047 3=0.063 4=0.094 5=0.125 6=0.188 7=0.25 8=0.38 9=0.50 10=0.75 11=1.00 12=1.25 13=1.50
DEFAULT_PGM_COMM_TIMING			EQU	3	; 1=Low		2=MediumLow	3=Medium		4=MediumHigh	5=High
DEFAULT_PGM_DEMAG_COMP			EQU	2	; 1=Disabled	2=Low		3=High
DEFAULT_PGM_DIRECTION			EQU	1	; 1=Normal	2=Reversed	3=Bidir		4=Bidir rev
DEFAULT_PGM_BEEP_STRENGTH		EQU	40	; Beep strength
DEFAULT_PGM_BEACON_STRENGTH		EQU	80	; Beacon strength
DEFAULT_PGM_BEACON_DELAY			EQU	4	; 1=1m		2=2m			3=5m			4=10m		5=Infinite
DEFAULT_PGM_ENABLE_TEMP_PROT		EQU	7	; 0=Disabled	1=80C	2=90C	3=100C	4=110C	5=120C	6=130C	7=140C
DEFAULT_PGM_ENABLE_POWER_PROT		EQU	1	; 1=Enabled	0=Disabled
DEFAULT_PGM_BRAKE_ON_STOP		EQU	0	; 1=Enabled	0=Disabled
DEFAULT_PGM_LED_CONTROL			EQU	0	; Byte for LED control. 2bits per LED, 0=Off, 1=On

;**** **** **** **** ****
; Temporary register definitions
Temp1		EQU	R0
Temp2		EQU	R1
Temp3		EQU	R2
Temp4		EQU	R3
Temp5		EQU	R4
Temp6		EQU	R5
Temp7		EQU	R6
Temp8		EQU	R7

;**** **** **** **** ****
; RAM definitions
; Bit-addressable data segment
DSEG AT 20h
Bit_Access:				DS	1				; MUST BE AT THIS ADDRESS. Variable at bit accessible address (for non interrupt routines)
Bit_Access_Int:			DS	1				; Variable at bit accessible address (for interrupts)

Flags_Startup:				DS	1				; State flags. Reset upon init_start
Flag_Startup_Phase			BIT	Flags_Startup.0	; Set when in startup phase
Flag_Initial_Run_Phase		BIT	Flags_Startup.1	; Set when in initial run phase, before synchronized run is achieved
; Note: Remaining bits must be cleared

Flags1:					DS	1				; State flags. Reset upon init_start
Flag_Timer3_Pending			BIT	Flags1.0			; Timer 3 pending flag
Flag_Demag_Detected			BIT	Flags1.1			; Set when excessive demag time is detected
Flag_Comp_Timed_Out			BIT	Flags1.2			; Set when comparator reading timed out
Flag_Motor_Running			BIT	Flags1.3
Flag_Motor_Started			BIT	Flags1.4			; Set when motor is started
Flag_Dir_Change_Brake		BIT	Flags1.5			; Set when braking before direction change
Flag_High_Rpm				BIT	Flags1.6			; Set when motor rpm is high (Comm_Period4x_H less than 2)
Flag_Low_Pwm_Power			BIT	Flags1.7			; Set when pwm duty cycle is below 50%

Flags2:					DS	1				; State flags. NOT reset upon init_start
Flag_Pgm_Dir_Rev			BIT	Flags2.0			; Programmed direction. 0=normal, 1=reversed
Flag_Pgm_Bidir_Rev			BIT	Flags2.1			; Programmed bidirectional direction. 0=normal, 1=reversed
Flag_Pgm_Bidir				BIT	Flags2.2			; Programmed bidirectional operation. 0=normal, 1=bidirectional
Flag_Skip_Timer2_Int		BIT	Flags2.3			; Set for 48MHz MCUs when timer 2 interrupt shall be ignored
Flag_Clock_At_48MHz			BIT	Flags2.4			; Set if 48MHz MCUs run at 48MHz
Flag_Rcp_Stop				BIT	Flags2.5			; Set if the RC pulse value is zero
Flag_Rcp_Dir_Rev			BIT	Flags2.6			; RC pulse direction in bidirectional mode
Flag_Rcp_DShot_Inverted		BIT	Flags2.7			; DShot RC pulse input is inverted (and supports telemetry)

Flags3:					DS	1				; State flags. NOT reset upon init_start
Flag_Telemetry_Pending		BIT	Flags3.0			; DShot telemetry data packet is ready to be sent

Tlm_Data_L:				DS	1				; DShot telemetry data (lo byte)
Tlm_Data_H:				DS	1				; DShot telemetry data (hi byte)
Tmp_B:					DS	1

;**** **** **** **** ****
; Direct addressing data segment
DSEG AT 30h
Rcp_Outside_Range_Cnt:		DS	1	; RC pulse outside range counter (incrementing)
Rcp_Timeout_Cntd:			DS	1	; RC pulse timeout counter (decrementing)
Rcp_Stop_Cnt:				DS	1	; Counter for RC pulses below stop value

Power_On_Wait_Cnt_L:		DS	1	; Power on wait counter (lo byte)
Power_On_Wait_Cnt_H:		DS	1	; Power on wait counter (hi byte)

Startup_Cnt:				DS	1	; Startup phase commutations counter (incrementing)
Startup_Zc_Timeout_Cntd:		DS	1	; Startup zero cross timeout counter (decrementing)
Initial_Run_Rot_Cntd:		DS	1	; Initial run rotations counter (decrementing)
Startup_Stall_Cnt:			DS	1	; Counts start/run attempts that resulted in stall. Reset upon a proper stop
Demag_Detected_Metric:		DS	1	; Metric used to gauge demag event frequency
Demag_Pwr_Off_Thresh:		DS	1	; Metric threshold above which power is cut
Low_Rpm_Pwr_Slope:			DS	1	; Sets the slope of power increase for low rpm

Timer2_X:					DS	1	; Timer 2 extended byte
Prev_Comm_L:				DS	1	; Previous commutation timer 3 timestamp (lo byte)
Prev_Comm_H:				DS	1	; Previous commutation timer 3 timestamp (hi byte)
Prev_Comm_X:				DS	1	; Previous commutation timer 3 timestamp (ext byte)
Prev_Prev_Comm_L:			DS	1	; Pre-previous commutation timer 3 timestamp (lo byte)
Prev_Prev_Comm_H:			DS	1	; Pre-previous commutation timer 3 timestamp (hi byte)
Comm_Period4x_L:			DS	1	; Timer 3 counts between the last 4 commutations (lo byte)
Comm_Period4x_H:			DS	1	; Timer 3 counts between the last 4 commutations (hi byte)
Comparator_Read_Cnt:		DS	1	; Number of comparator reads done

Wt_Adv_Start_L:			DS	1	; Timer 3 start point for commutation advance timing (lo byte)
Wt_Adv_Start_H:			DS	1	; Timer 3 start point for commutation advance timing (hi byte)
Wt_Zc_Scan_Start_L:			DS	1	; Timer 3 start point from commutation to zero cross scan (lo byte)
Wt_Zc_Scan_Start_H:			DS	1	; Timer 3 start point from commutation to zero cross scan (hi byte)
Wt_Zc_Tout_Start_L:			DS	1	; Timer 3 start point for zero cross scan timeout (lo byte)
Wt_Zc_Tout_Start_H:			DS	1	; Timer 3 start point for zero cross scan timeout (hi byte)
Wt_Comm_Start_L:			DS	1	; Timer 3 start point from zero cross to commutation (lo byte)
Wt_Comm_Start_H:			DS	1	; Timer 3 start point from zero cross to commutation (hi byte)

Power_Pwm_Reg_L:			DS	1	; Power pwm register setting (lo byte)
Power_Pwm_Reg_H:			DS	1	; Power pwm register setting (hi byte). 0x3F is minimum power
Damp_Pwm_Reg_L:			DS	1	; Damping pwm register setting (lo byte)
Damp_Pwm_Reg_H:			DS	1	; Damping pwm register setting (hi byte)

Pwm_Limit:				DS	1	; Maximum allowed pwm (8-bit)
Pwm_Limit_By_Rpm:			DS	1	; Maximum allowed pwm for low or high rpm (8-bit)
Pwm_Limit_Beg:				DS	1	; Initial pwm limit (8-bit)

Adc_Conversion_Cnt:			DS	1	; Adc conversion counter
Current_Average_Temp:		DS	1	; Current average temperature (lo byte ADC reading, assuming hi byte is 1)
Temp_Prot_Limit:			DS	1	; Temperature protection limit

Beep_Strength:				DS	1	; Strength of beeps

Flash_Key_1:				DS	1	; Flash key one
Flash_Key_2:				DS	1	; Flash key two

DShot_Pwm_Thr:				DS	1	; DShot pulse width threshold value (timer 0 ticks)
DShot_Timer_Preset:			DS	1	; DShot timer preset for frame sync detection (timer 1 lo byte)
DShot_Frame_Start_L:		DS	1	; DShot frame start timestamp (timer 2 lo byte)
DShot_Frame_Start_H:		DS	1	; DShot frame start timestamp (timer 2 hi byte)
DShot_Frame_Length_Thr:		DS	1	; DShot frame length criteria (timer 2 ticks)

DShot_Cmd:				DS	1	; DShot command
DShot_Cmd_Cnt:				DS	1	; DShot command count

; Pulse durations for GCR encoding DShot telemetry data
DShot_GCR_Pulse_Time_1:		DS	1	; Encodes binary: 1
DShot_GCR_Pulse_Time_2:		DS	1	; Encodes binary: 01
DShot_GCR_Pulse_Time_3:		DS	1	; Encodes binary: 001

DShot_GCR_Pulse_Time_1_Tmp:	DS	1
DShot_GCR_Pulse_Time_2_Tmp:	DS	1
DShot_GCR_Pulse_Time_3_Tmp:	DS	1

DShot_GCR_Start_Delay:		DS	1

;**** **** **** **** ****
; Indirect addressing data segments
ISEG AT 080h						; The variables below must be in this sequence
_Pgm_Gov_P_Gain:			DS	1	; Governor P gain
_Pgm_Gov_I_Gain:			DS	1	; Governor I gain
_Pgm_Gov_Mode:				DS	1	; Governor mode
_Pgm_Low_Voltage_Lim:		DS	1	; Low voltage limit
_Pgm_Motor_Gain:			DS	1	; Motor gain
_Pgm_Motor_Idle:			DS	1	; Motor idle speed
Pgm_Startup_Pwr:			DS	1	; Startup power
_Pgm_Pwm_Freq:				DS	1	; PWM frequency
Pgm_Direction:				DS	1	; Rotation direction
_Pgm_Input_Pol:			DS	1	; Input PWM polarity
Initialized_L_Dummy:		DS	1	; Place holder
Initialized_H_Dummy:		DS	1	; Place holder
_Pgm_Enable_TX_Program:		DS	1	; Enable/disable value for TX programming
_Pgm_Main_Rearm_Start:		DS	1	; Enable/disable re-arming main every start
_Pgm_Gov_Setup_Target:		DS	1	; Main governor setup target
_Pgm_Startup_Rpm:			DS	1	; Startup RPM
_Pgm_Startup_Accel:			DS	1	; Startup acceleration
_Pgm_Volt_Comp:			DS	1	; Voltage comp
Pgm_Comm_Timing:			DS	1	; Commutation timing
_Pgm_Damping_Force:			DS	1	; Damping force
_Pgm_Gov_Range:			DS	1	; Governor range
_Pgm_Startup_Method:		DS	1	; Startup method
_Pgm_Min_Throttle:			DS	1	; Minimum throttle
_Pgm_Max_Throttle:			DS	1	; Maximum throttle
Pgm_Beep_Strength:			DS	1	; Beep strength
Pgm_Beacon_Strength:		DS	1	; Beacon strength
Pgm_Beacon_Delay:			DS	1	; Beacon delay
_Pgm_Throttle_Rate:			DS	1	; Throttle rate
Pgm_Demag_Comp:			DS	1	; Demag compensation
_Pgm_BEC_Voltage_High:		DS	1	; BEC voltage
_Pgm_Center_Throttle:		DS	1	; Center throttle (in bidirectional mode)
_Pgm_Main_Spoolup_Time:		DS	1	; Main spoolup time
Pgm_Enable_Temp_Prot:		DS	1	; Temperature protection enable
Pgm_Enable_Power_Prot:		DS	1	; Low RPM power protection enable
_Pgm_Enable_Pwm_Input:		DS	1	; Enable PWM input signal
_Pgm_Pwm_Dither:			DS	1	; Output PWM dither
Pgm_Brake_On_Stop:			DS	1	; Braking when throttle is zero
Pgm_LED_Control:			DS	1	; LED control

; The sequence of the variables below is no longer of importance
Pgm_Startup_Pwr_Decoded:		DS	1	; Programmed startup power decoded

ISEG AT 0B0h
Stack:					DS	16	; Reserved stack space

ISEG AT 0C0h
Dithering_Patterns:			DS	16	; Bit patterns for pwm dithering

ISEG AT 0D0h
Temp_Storage:				DS	48	; Temporary storage

;**** **** **** **** ****
; EEPROM code segments
; A segment of the flash is used as "EEPROM", which is not available in SiLabs MCUs
CSEG AT 1A00h
EEPROM_FW_MAIN_REVISION		EQU	0	; Main revision of the firmware
EEPROM_FW_SUB_REVISION		EQU	7	; Sub revision of the firmware
EEPROM_LAYOUT_REVISION		EQU	33	; Revision of the EEPROM layout

Eep_FW_Main_Revision:		DB	EEPROM_FW_MAIN_REVISION		; EEPROM firmware main revision number
Eep_FW_Sub_Revision:		DB	EEPROM_FW_SUB_REVISION		; EEPROM firmware sub revision number
Eep_Layout_Revision:		DB	EEPROM_LAYOUT_REVISION		; EEPROM layout revision number

_Eep_Pgm_Gov_P_Gain:		DB	0FFh
_Eep_Pgm_Gov_I_Gain:		DB	0FFh
_Eep_Pgm_Gov_Mode:			DB	0FFh
_Eep_Pgm_Low_Voltage_Lim:	DB	0FFh
_Eep_Pgm_Motor_Gain:		DB	0FFh
_Eep_Pgm_Motor_Idle:		DB	0FFh
Eep_Pgm_Startup_Pwr:		DB	DEFAULT_PGM_STARTUP_PWR		; EEPROM copy of programmed startup power
_Eep_Pgm_Pwm_Freq:			DB	0FFh
Eep_Pgm_Direction:			DB	DEFAULT_PGM_DIRECTION		; EEPROM copy of programmed rotation direction
_Eep__Pgm_Input_Pol:		DB	0FFh
Eep_Initialized_L:			DB	055h						; EEPROM initialized signature (lo byte)
Eep_Initialized_H:			DB	0AAh						; EEPROM initialized signature (hi byte)
_Eep_Enable_TX_Program:		DB	0FFh						; EEPROM TX programming enable
_Eep_Main_Rearm_Start:		DB	0FFh
_Eep_Pgm_Gov_Setup_Target:	DB	0FFh
_Eep_Pgm_Startup_Rpm:		DB	0FFh
_Eep_Pgm_Startup_Accel:		DB	0FFh
_Eep_Pgm_Volt_Comp:			DB	0FFh
Eep_Pgm_Comm_Timing:		DB	DEFAULT_PGM_COMM_TIMING		; EEPROM copy of programmed commutation timing
_Eep_Pgm_Damping_Force:		DB	0FFh
_Eep_Pgm_Gov_Range:			DB	0FFh
_Eep_Pgm_Startup_Method:		DB	0FFh
_Eep_Pgm_Min_Throttle:		DB	0FFh						; EEPROM copy of programmed minimum throttle
_Eep_Pgm_Max_Throttle:		DB	0FFh						; EEPROM copy of programmed minimum throttle
Eep_Pgm_Beep_Strength:		DB	DEFAULT_PGM_BEEP_STRENGTH	; EEPROM copy of programmed beep strength
Eep_Pgm_Beacon_Strength:		DB	DEFAULT_PGM_BEACON_STRENGTH	; EEPROM copy of programmed beacon strength
Eep_Pgm_Beacon_Delay:		DB	DEFAULT_PGM_BEACON_DELAY		; EEPROM copy of programmed beacon delay
_Eep_Pgm_Throttle_Rate:		DB	0FFh
Eep_Pgm_Demag_Comp:			DB	DEFAULT_PGM_DEMAG_COMP		; EEPROM copy of programmed demag compensation
_Eep_Pgm_BEC_Voltage_High:	DB	0FFh
_Eep_Pgm_Center_Throttle:	DB	0FFh						; EEPROM copy of programmed center throttle
_Eep_Pgm_Main_Spoolup_Time:	DB	0FFh
Eep_Pgm_Temp_Prot_Enable:	DB	DEFAULT_PGM_ENABLE_TEMP_PROT	; EEPROM copy of programmed temperature protection enable
Eep_Pgm_Enable_Power_Prot:	DB	DEFAULT_PGM_ENABLE_POWER_PROT	; EEPROM copy of programmed low rpm power protection enable
_Eep_Pgm_Enable_Pwm_Input:	DB	0FFh
_Eep_Pgm_Pwm_Dither:		DB	0FFh
Eep_Pgm_Brake_On_Stop:		DB	DEFAULT_PGM_BRAKE_ON_STOP	; EEPROM copy of programmed braking when throttle is zero
Eep_Pgm_LED_Control:		DB	DEFAULT_PGM_LED_CONTROL		; EEPROM copy of programmed LED control

Eep_Dummy:				DB	0FFh						; EEPROM address for safety reason

CSEG AT 1A60h
Eep_Name:					DB	"Bluejay (BETA)  "			; Name tag (16 Bytes)

;**** **** **** **** ****
Interrupt_Table_Definition			; SiLabs interrupts
CSEG AT 80h						; Code segment after interrupt vectors

;**** **** **** **** ****
; Table definitions
; Rampup pwm power (8-bit)
STARTUP_POWER_TABLE:	DB	1,	2,	3,	4,	6,	9,	12,	18,	25,	37,	50,	62,	75



;**** **** **** **** **** **** **** **** **** **** **** **** ****
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Macros
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;**** **** **** **** **** **** **** **** **** **** **** **** ****


DSHOT_TLM_CLOCK		EQU	24500000				; 24.5MHz
DSHOT_TLM_START_DELAY	EQU	-(5 * 25 / 4)			; Start telemetry after 5 us (~30 us after receiving DShot cmd)
DSHOT_TLM_PREDELAY		EQU	6					; 6 timer 0 ticks inherent delay

IF MCU_48MHZ == 1
	DSHOT_TLM_CLOCK_48		EQU	49000000			; 49MHz
	DSHOT_TLM_START_DELAY_48	EQU	-(16 * 49 / 4)		; Start telemetry after 15 us (~30 us after receiving DShot cmd)
	DSHOT_TLM_PREDELAY_48	EQU	8				; 8 timer 0 ticks inherent delay
ENDIF

Set_DShot_Tlm_Bitrate MACRO rate
	mov	DShot_GCR_Pulse_Time_1, #(DSHOT_TLM_PREDELAY - (1 * DSHOT_TLM_CLOCK / 4 / rate))
	mov	DShot_GCR_Pulse_Time_2, #(DSHOT_TLM_PREDELAY - (2 * DSHOT_TLM_CLOCK / 4 / rate))
	mov	DShot_GCR_Pulse_Time_3, #(DSHOT_TLM_PREDELAY - (3 * DSHOT_TLM_CLOCK / 4 / rate))

	mov	DShot_GCR_Start_Delay, #DSHOT_TLM_START_DELAY

IF MCU_48MHZ == 1
	mov	DShot_GCR_Pulse_Time_1_Tmp, #(DSHOT_TLM_PREDELAY_48 - (1 * DSHOT_TLM_CLOCK_48 / 4 / rate))
	mov	DShot_GCR_Pulse_Time_2_Tmp, #(DSHOT_TLM_PREDELAY_48 - (2 * DSHOT_TLM_CLOCK_48 / 4 / rate))
	mov	DShot_GCR_Pulse_Time_3_Tmp, #(DSHOT_TLM_PREDELAY_48 - (3 * DSHOT_TLM_CLOCK_48 / 4 / rate))
ENDIF
ENDM

Push_Mem MACRO reg, val
	mov	@reg, val					;; Write value to memory address pointed to by register
	inc	reg						;; Increment pointer
ENDM

DShot_GCR_Get_Time MACRO
	mov	A, DShot_GCR_Pulse_Time_2
	cjne	A, Tmp_B, ($+5)
	mov	A, DShot_GCR_Pulse_Time_3
ENDM

; Prepare telemetry packet while waiting for timer 3 to wrap
Wait_For_Timer3 MACRO
LOCAL wait_for_t3 done_waiting
	jb	Flag_Telemetry_Pending, wait_for_t3

	jnb	Flag_Timer3_Pending, done_waiting
	call	dshot_tlm_create_packet

wait_for_t3:
	jnb	Flag_Timer3_Pending, done_waiting
	sjmp	wait_for_t3

done_waiting:
ENDM

Early_Return_Packet_Stage MACRO num
	Early_Return_Packet_Stage_ num, %(num+1)
ENDM

Early_Return_Packet_Stage_ MACRO num next
IF num > 0
	inc	Temp5								;; Increment current packet stage
	jb	Flag_Timer3_Pending, dshot_packet_stage_&num	;; Return early if timer 3 has wrapped
	pop	PSW
	ret
dshot_packet_stage_&num:
ENDIF
IF num < 5
	cjne	Temp5, #(num), dshot_packet_stage_&next		;; If this is not current stage, skip to next
ENDIF
ENDM

Decode_DShot_2Bit MACRO dest, decode_fail
	movx	A, @Temp1
	mov	Temp7, A
	clr	C
	subb	A, Temp6					;; Subtract previous timestamp
	clr	C
	subb	A, Temp2
	jc	decode_fail				;; Check that bit is longer than minimum

	subb	A, Temp2					;; Check if bit is zero or one
	rlca	dest						;; Shift bit into data byte
	inc	Temp1					;; Next bit

	movx	A, @Temp1
	mov	Temp6, A
	clr	C
	subb	A, Temp7
	clr	C
	subb	A, Temp2
	jc	decode_fail

	subb	A, Temp2
	rlca	dest
	inc	Temp1
ENDM

;**** **** **** **** ****
; Compound instructions for convenience
xcha MACRO var1, var2				;; Exchange via accumulator
	mov	A, var1
	xch	A, var2
	mov	var1, A
ENDM

rrca MACRO var						;; Rotate right through carry via accumulator
	mov	A, var
	rrc	A
	mov	var, A
ENDM

rlca MACRO var						;; Rotate left through carry via accumulator
	mov	A, var
	rlc	A
	mov	var, A
ENDM

rla MACRO var						;; Rotate left via accumulator
	mov	A, var
	rl	A
	mov	var, A
ENDM

ljc MACRO label					;; Long jump if carry set
LOCAL skip
	jnc	skip
	jmp	label
skip:
ENDM



;**** **** **** **** **** **** **** **** **** **** **** **** ****
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Interrupt handlers
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;**** **** **** **** **** **** **** **** **** **** **** **** ****


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Timer 0 interrupt routine (High priority)
;
; Generate DShot telemetry signal
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
t0_int:
	push	PSW
	mov	PSW, #10h					; Select register bank 2 for this interrupt

	dec	Temp1
	cjne	Temp1, #(Temp_Storage-1), t0_int_dshot_tlm_transition

	; If last pulse is high telemetry is finished
	jb	RTX_PORT.RTX_PIN, t0_int_dshot_tlm_finish

	inc	Temp1					; Otherwise wait for it to return to high

t0_int_dshot_tlm_transition:
	cpl	RTX_PORT.RTX_PIN			; Invert signal level

	mov	TL0, @Temp1				; Schedule next update

	pop	PSW
	reti

t0_int_dshot_tlm_finish:
	; Configure RTX_PIN for digital input
	anl	RTX_MDOUT, #(NOT (1 SHL RTX_PIN))	; Set RTX_PIN output mode to open-drain
	setb	RTX_PORT.RTX_PIN			; Float high

	clr	IE_ET0					; Disable timer 0 interrupts

	; todo: dshot150
	;mov	CKCON0, Temp2				; Restore normal DShot timer 0/1 clock settings
	mov	CKCON0, #0Ch
	mov	TMOD, #0AAh				; Timer 0/1 gated by INT0/1

	clr	TCON_IE0					; Clear int0 pending flag
	clr	TCON_IE1					; Clear int1 pending flag

	mov	TL0, #0					; Reset timer 0 count
	setb	IE_EX0					; Enable int0 interrupts
	setb	IE_EX1					; Enable int1 interrupts
	Enable_PCA_Interrupt			; Enable pca interrupts

	clr	Flag_Telemetry_Pending

	pop	PSW
	reti


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Timer 1 interrupt routine
;
; Decode DShot frame
; Process new throttle value and update pwm registers
; Schedule DShot telemetry
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
t1_int:
	clr	IE_EX0					; Disable int0 interrupts
	clr	TCON_TR1					; Stop timer 1
	mov	TL1, DShot_Timer_Preset		; Reset sync timer

	push	PSW
	mov	PSW, #8h					; Select register bank 1 for this interrupt
	push	ACC
	push	B

	clr	TMR2CN0_TR2				; Timer 2 disabled
	mov	Temp2, TMR2L				; Read timer value
	mov	Temp3, TMR2H
	setb	TMR2CN0_TR2				; Timer 2 enabled

	; Check frame time length
	clr	C
	mov	A, Temp2
	subb	A, DShot_Frame_Start_L
	mov	Temp2, A
	mov	A, Temp3
	subb	A, DShot_Frame_Start_H
	jnz	t1_int_frame_fail			; Frame too long

	clr	C
	mov	A, Temp2
	subb	A, DShot_Frame_Length_Thr
	jc	t1_int_frame_fail			; Frame too short
	subb	A, DShot_Frame_Length_Thr
	jnc	t1_int_frame_fail			; Frame too long

	; Check that correct number of pulses is received
	cjne	Temp1, #16, t1_int_frame_fail	; Read current pointer

	; Decode transmitted data
	mov	Temp1, #0					; Set pointer
	mov	Temp2, DShot_Pwm_Thr		; DShot pulse width criteria
	mov	Temp6, #0					; Reset timestamp

	; Decode DShot data Msb. Use more code space to save time (by not using loop)
	Decode_DShot_2Bit	Temp5, t1_int_frame_fail
	Decode_DShot_2Bit	Temp5, t1_int_frame_fail
	sjmp	t1_int_decode_lsb

t1_int_frame_fail:
	sjmp	t1_int_outside_range

t1_int_decode_lsb:
	; Decode DShot data Lsb
	Decode_DShot_2Bit	Temp4, t1_int_outside_range
	Decode_DShot_2Bit	Temp4, t1_int_outside_range
	Decode_DShot_2Bit	Temp4, t1_int_outside_range
	Decode_DShot_2Bit	Temp4, t1_int_outside_range
	sjmp	t1_int_decode_checksum

t1_int_outside_range:
	inc	Rcp_Outside_Range_Cnt
	mov	A, Rcp_Outside_Range_Cnt
	jnz	($+4)
	dec	Rcp_Outside_Range_Cnt

	clr	C
	mov	A, Rcp_Outside_Range_Cnt
	subb	A, #50					; Allow a given number of outside pulses
	jc	t1_int_exit_timeout			; If outside limits - ignore first pulses

	setb	Flag_Rcp_Stop				; Set pulse length to zero
	clr	A
	mov	DShot_Cmd, A				; Clear DShot command
	mov	DShot_Cmd_Cnt, A			; Clear DShot command count

	ajmp	t1_int_exit_no_tlm			; Exit without resetting timeout

t1_int_exit_timeout:
	mov	Rcp_Timeout_Cntd, #10		; Set timeout count
	ajmp	t1_int_exit_no_tlm

t1_int_decode_checksum:
	; Decode DShot data checksum
	Decode_DShot_2Bit	Temp3, t1_int_outside_range
	Decode_DShot_2Bit	Temp3, t1_int_outside_range

	; XOR check (in inverted data, which is ok), only low nibble is considered
	mov	A, Temp4
	swap	A
	xrl	A, Temp4
	xrl	A, Temp5
	xrl	A, Temp3
	jnb	Flag_Rcp_DShot_Inverted, ($+4)
	cpl	A						; Invert checksum if using inverted DShot
	anl	A, #0Fh
	jnz	t1_int_outside_range		; XOR check

	; Invert DShot data and subtract 96 (still 12 bits)
	clr	C
	mov	A, Temp4
	cpl	A
	mov	Temp3, A
	subb	A, #96
	mov	Temp4, A
	mov	A, Temp5
	cpl	A
	anl	A, #0Fh
	subb	A, #0
	mov	Temp5, A
	jnc	t1_normal_range

	mov	A, Temp3					; Check for 0 or DShot command
	mov	Temp5, #0
	mov	Temp4, #0
	jz	t1_normal_range

	mov	Temp3, #0
	clr	C						; We are in the special DShot range
	rrc	A						; Divide by 2
	jnc	t1_dshot_set_cmd			; Check for tlm bit set (if not telemetry, Temp3 will be zero and result in invalid command)

	mov	Temp3, A
	cjne	A, DShot_Cmd, t1_dshot_set_cmd

	inc	DShot_Cmd_Cnt
	sjmp	t1_normal_range

t1_dshot_set_cmd:
	mov	DShot_Cmd, Temp3
	mov	DShot_Cmd_Cnt, #0

t1_normal_range:
	; Check for bidirectional operation (0=stop, 96-2095->fwd, 2096-4095->rev)
	jnb	Flag_Pgm_Bidir, t1_int_not_bidir	; If not bidirectional operation - branch

	; Subtract 2000 (still 12 bits)
	clr	C
	mov	A, Temp4
	subb	A, #0D0h
	mov	B, A
	mov	A, Temp5
	subb	A, #07h
	clr	Flag_Rcp_Dir_Rev
	jc	t1_int_bidir_rev_chk		; If result is negative - branch

	mov	Temp4, B
	mov	Temp5, A

	setb	Flag_Rcp_Dir_Rev

t1_int_bidir_rev_chk:
	jb	Flag_Pgm_Bidir_Rev, ($+5)
	cpl	Flag_Rcp_Dir_Rev

	clr	C						; Multiply throttle value by 2
	rlca	Temp4
	rlca	Temp5

t1_int_not_bidir:
	; From here Temp5/Temp4 should be at most 3999 (4095-96)
	mov	A, Temp4					; Divide by 16 (12 to 8-bit)
	anl	A, #0F0h
	orl	A, Temp5					; Note: Assumes Temp5 to be 4-bit
	swap	A
	mov	B, #5					; Divide by 5 (80 in total)
	div	AB
	mov	Temp3, A
	; Align to 11 bits
	;clr	C						; Note: Cleared by div
	rrca	Temp5
	mov	A, Temp4
	rrc	A
	; Scale from 2000 to 2048
	add	A, Temp3
	mov	Temp4, A
	mov	A, Temp5
	addc	A, #0
	mov	Temp5, A
	jnb	ACC.3, ($+7)				; Limit to 11-bit maximum
	mov	Temp4, #0FFh
	mov	Temp5, #07h

	; Do not boost when changing direction in bidirectional mode
	jb	Flag_Motor_Started, t1_int_startup_boosted

	mov	A, Flags_Startup			; Boost pwm during direct start
	jz	t1_int_startup_boosted

	mov	Temp6, Startup_Stall_Cnt		; Add more boost when failing to start motor

	inc	Temp6
	mov	B, #31

t1_int_stall_boost_loop:
	mov	A, Temp4
	add	A, B
	mov	Temp4, A
	mov	A, Temp5
	addc	A, #0
	mov	Temp5, A

	rla	B						; Nonlinear increase

	djnz	Temp6, t1_int_stall_boost_loop

	mov	A, Temp5					; Limit to 11-bit maximum
	jnb	ACC.3, ($+7)
	mov	Temp4, #0FFh
	mov	Temp5, #07h

t1_int_startup_boosted:
	; Set 8-bit value
	mov	A, Temp4
	anl	A, #0F8h
	orl	A, Temp5					; Assumes Temp5 to be 3-bit (11-bit rcp)
	swap	A
	rl	A
	mov	Temp2, A

	jnz	t1_int_rcp_not_zero

	mov	A, Temp4					; Only set Rcp_Stop if all all 11 bits are zero
	jnz	t1_int_rcp_not_zero

	setb	Flag_Rcp_Stop
	sjmp	t1_int_zero_rcp_checked

t1_int_rcp_not_zero:
	mov	Rcp_Stop_Cnt, #0			; Reset rcp stop counter
	clr	Flag_Rcp_Stop				; Pulse ready

t1_int_zero_rcp_checked:
	; Decrement outside range counter
	mov	A, Rcp_Outside_Range_Cnt
	jz	($+4)
	dec	Rcp_Outside_Range_Cnt

	; Set pwm limit
	clr	C
	mov	A, Pwm_Limit				; Limit to the smallest
	mov	Temp6, A					; Store limit in Temp6
	subb	A, Pwm_Limit_By_Rpm
	jc	($+4)
	mov	Temp6, Pwm_Limit_By_Rpm

	; Check against limit
	clr	C
	mov	A, Temp6
	subb	A, Temp2					; 8-bit rc pulse
	jnc	t1_int_scale_pwm_resolution

IF PWM_BITS_H == 0					; 8-bit pwm
	mov	A, Temp6
	mov	Temp2, A
ELSE
	mov	A, Temp6					; Multiply limit by 8 for 11-bit pwm
	mov	B, #8
	mul	AB
	mov	Temp4, A
	mov	Temp5, B
ENDIF

t1_int_scale_pwm_resolution:
; Scale pwm resolution and invert
IF PWM_BITS_H == 3					; 11-bit pwm
	mov	A, Temp5
	cpl	A
	anl	A, #7
	mov	Temp3, A
	mov	A, Temp4
	cpl	A
	mov	Temp2, A
ELSEIF PWM_BITS_H == 2				; 10-bit pwm
	clr	C
	mov	A, Temp5
	rrc	A
	cpl	A
	anl	A, #3
	mov	Temp3, A
	mov	A, Temp4
	rrc	A
	cpl	A
	mov	Temp2, A
ELSEIF PWM_BITS_H == 1				; 9-bit pwm
	mov	B, Temp5
	mov	A, Temp4
	mov	C, B.0
	rrc	A
	mov	C, B.1
	rrc	A
	cpl	A
	mov	Temp2, A
	mov	A, Temp5
	rr	A
	rr	A
	cpl	A
	anl	A, #1
	mov	Temp3, A
ELSEIF PWM_BITS_H == 0				; 8-bit pwm
	mov	A, Temp2					; Temp2 already 8-bit
	cpl	A
	mov	Temp2, A
	mov	Temp3, #0
ENDIF

; 10-bit effective dithering of 8/9-bit pwm
IF PWM_BITS_H < 2
	mov	A, Temp4					; 11-bit low byte
	cpl	A
	rr	A
	anl	A, #((1 SHL (2-PWM_BITS_H))-1); Get index into dithering pattern table

	add	A, #Dithering_Patterns
	mov	Temp1, A					; Reuse DShot pwm pointer since it is not currently in use.
	mov	A, @Temp1					; Retrieve pattern
	rl	A						; Rotate pattern
	mov	@Temp1, A					; Store pattern

	jnb	ACC.0, dithering_done

	mov	A, Temp2
	add	A, #1
	mov	Temp2, A
IF PWM_BITS_H != 0
	mov	A, Temp3
	addc	A, #0
	mov	Temp3, A
	jnb	ACC.PWM_BITS_H, dithering_done
	dec	Temp2
	dec	Temp3
ELSE
	jnz	dithering_done
	dec	Temp2
ENDIF

dithering_done:
ENDIF

; Set pwm registers
IF FETON_DELAY != 0
	clr	C
	mov	A, Temp2					; Skew damping fet timing
IF MCU_48MHZ == 0
	subb	A, #((FETON_DELAY+1) SHR 1)
ELSE
	subb	A, #(FETON_DELAY)
ENDIF
	mov	Temp4, A
	mov	A, Temp3
	subb	A, #0
	mov	Temp5, A
	jnc	t1_int_set_pwm_damp_set

	clr	A
	mov	Temp4, A
	mov	Temp5, A

t1_int_set_pwm_damp_set:
ENDIF

	mov	Power_Pwm_Reg_L, Temp2
	mov	Power_Pwm_Reg_H, Temp3

IF FETON_DELAY != 0
	mov	Damp_Pwm_Reg_L, Temp4
	mov	Damp_Pwm_Reg_H, Temp5
ENDIF

	mov	Rcp_Timeout_Cntd, #10		; Set timeout count

	; Prepare DShot telemetry
	jnb	Flag_Rcp_DShot_Inverted, t1_int_exit_no_tlm	; Only send telemetry for inverted DShot
	jnb	Flag_Telemetry_Pending, t1_int_exit_no_tlm	; Check if telemetry packet is ready

	; Prepare timer 0 for sending telemetry data
	; todo: dshot150
	;mov	Temp2, CKCON0				; Save value to restore later
	mov	CKCON0, #01h				; Timer 0 is system clock divided by 4
	mov	TMOD, #0A2h				; Timer 0 runs free not gated by INT0

	; Configure RTX_PIN for digital output
	setb	RTX_PORT.RTX_PIN			; Default to high level
	orl	RTX_MDOUT, #(1 SHL RTX_PIN)	; Set output mode to push-pull

	mov	Temp1, #0					; Set pointer to start

	; Note: Delay must be large enough to ensure port is ready for output
	mov	TL0, DShot_GCR_Start_Delay	; Telemetry will begin after this delay
	clr	TCON_TF0					; Clear timer 0 overflow flag
	setb	IE_ET0					; Enable timer 0 interrupts

	sjmp	t1_int_exit_no_int

t1_int_exit_no_tlm:
	mov	Temp1, #0					; Set pointer to start
	mov	TL0, #0					; Reset timer 0
	setb	IE_EX0					; Enable int0 interrupts
	setb	IE_EX1					; Enable int1 interrupts
	Enable_PCA_Interrupt			; Enable pca interrupts

t1_int_exit_no_int:
	pop	B						; Restore preserved registers
	pop	ACC
	pop	PSW
	reti


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Timer 2 interrupt routine
;
; Update RC pulse timeout and stop counters
; Happens every 32ms
; Requirements: Temp variables can NOT be used since PSW.x is not set
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
t2_int:
	push	ACC
	clr	TMR2CN0_TF2H				; Clear interrupt flag
	inc	Timer2_X

IF MCU_48MHZ == 1
	jnb	Flag_Clock_At_48MHz, t2_int_start	; Always run if clock is 24MHz

	jbc	Flag_Skip_Timer2_Int, t2_int_exit	; Flag set? - Skip interrupt and clear flag

t2_int_start:
	setb	Flag_Skip_Timer2_Int		; Skip next interrupt
ENDIF
	; Update RC pulse timeout counter
	mov	A, Rcp_Timeout_Cntd			; RC pulse timeout count zero?
	jz	($+4)					; Yes - do not decrement
	dec	Rcp_Timeout_Cntd			; No - decrement

	jnb	Flag_Rcp_Stop, t2_int_exit	; Exit if pulse is above stop value

	; Update RC pulse stop counter
	inc	Rcp_Stop_Cnt				; Increment stop counter
	mov	A, Rcp_Stop_Cnt
	jnz	($+4)					; Branch if counter has not wrapped
	dec	Rcp_Stop_Cnt				; Set stop counter back to max

t2_int_exit:
	pop	ACC						; Restore preserved registers
	reti


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Timer 3 interrupt routine
;
; Used for commutation timing
; Requirements: Temp variables can NOT be used since PSW.x is not set
;               ACC can not be used, as it is not pushed to stack
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
t3_int:
	clr	IE_EA					; Disable all interrupts
	anl	EIE1, #7Fh				; Disable timer 3 interrupts
	anl	TMR3CN0, #07Fh				; Clear timer 3 interrupt flag
	mov	TMR3RLL, #0FAh				; Set a short delay before next interrupt
	mov	TMR3RLH, #0FFh
	clr	Flag_Timer3_Pending			; Flag that timer has wrapped
	setb	IE_EA					; Enable all interrupts
	reti


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Int0 interrupt routine (High priority)
;
; Read and store DShot pwm signal for decoding
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
int0_int:
	push	ACC
	mov	A, TL0					; Read pwm for DShot immediately
	mov	TL1, DShot_Timer_Preset		; Reset sync timer

	; Temp1 in register bank 1 points to pwm timings
	push	PSW
	mov	PSW, #8h
	movx	@Temp1, A					; Store pwm
	inc	Temp1
	pop	PSW

	pop	ACC
	reti


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Int1 interrupt routine
;
; Used for RC pulse timing
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
int1_int:
	clr	IE_EX1					; Disable int1 interrupts
	setb	TCON_TR1					; Start timer 1
	clr	TMR2CN0_TR2				; Timer 2 disabled
	mov	DShot_Frame_Start_L, TMR2L	; Read timer value
	mov	DShot_Frame_Start_H, TMR2H
	setb	TMR2CN0_TR2				; Timer 2 enabled
reti


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; PCA interrupt routine
;
; Update pwm registers according to PCA clock signal
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
pca_int:
	clr	IE_EA					; Disable all interrupts
	push	ACC

IF FETON_DELAY != 0					; HI/LO enable style drivers
	mov	A, PCA0L					; Read low byte first, to transfer high byte to holding register
	mov	A, PCA0H

	jnb	Flag_Low_Pwm_Power, pca_int_hi_pwm

	; Power below 50%, update pca in the 0x00-0x0F range
	jb	ACC.PWM_BITS_H, pca_int_exit	; PWM edge selection bit (continue if up edge)

	sjmp	pca_int_set_pwm

pca_int_hi_pwm:
	; Power above 50%, update pca in the 0x20-0x2F range
	jnb	ACC.PWM_BITS_H, pca_int_exit	; PWM edge selection bit (continue if down edge)

pca_int_set_pwm:
	IF PWM_BITS_H != 0
		jb	ACC.(PWM_BITS_H-1), pca_int_exit
	ELSE
		mov	A, PCA0L
		jb	ACC.7, pca_int_exit
	ENDIF
ENDIF

; Set power pwm auto-reload registers
IF PWM_BITS_H != 0
	mov	PCA0_POWER_L, Power_Pwm_Reg_L
	mov	PCA0_POWER_H, Power_Pwm_Reg_H
ELSE
	mov	PCA0_POWER_H, Power_Pwm_Reg_L
ENDIF

IF FETON_DELAY != 0
	; Set damp pwm auto-reload registers
	IF PWM_BITS_H != 0
		mov	PCA0_DAMP_L, Damp_Pwm_Reg_L
		mov	PCA0_DAMP_H, Damp_Pwm_Reg_H
	ELSE
		mov	PCA0_DAMP_H, Damp_Pwm_Reg_L
	ENDIF
ENDIF

	setb	Flag_Low_Pwm_Power
IF PWM_BITS_H != 0
	mov	A, Power_Pwm_Reg_H
	jb	ACC.(PWM_BITS_H-1), ($+5)
ELSE
	mov	A, Power_Pwm_Reg_L
	jb	ACC.7, ($+5)
ENDIF
	clr	Flag_Low_Pwm_Power

	Disable_COVF_Interrupt
IF FETON_DELAY == 0					; EN/PWM style drivers
	Disable_CCF_Interrupt
ENDIF

	anl	EIE1, #0EFh				; Pwm updated, disable pca interrupts

pca_int_exit:
	Clear_COVF_Interrupt
IF FETON_DELAY == 0
	Clear_CCF_Interrupt
ENDIF

	pop	ACC						; Restore preserved registers
	setb	IE_EA					; Enable all interrupts
	reti



;**** **** **** **** **** **** **** **** **** **** **** **** ****
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Misc utility functions
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;**** **** **** **** **** **** **** **** **** **** **** **** ****


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Wait a number of milliseconds (Multiple entry points)
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
wait1ms:
	mov	Temp2, #1
	sjmp	wait_ms_o

wait5ms:
	mov	Temp2, #5
	sjmp	wait_ms_o

wait10ms:
	mov	Temp2, #10
	sjmp	wait_ms_o

wait100ms:
	mov	Temp2, #100
	sjmp	wait_ms_o

wait200ms:
	mov	Temp2, #200
	sjmp	wait_ms_o

wait250ms:
	mov	Temp2, #250
	sjmp	wait_ms_o

wait_ms_o:						; Outer loop
	mov	Temp1, #23
wait_ms_m:						; Middle loop
	clr	A
	djnz	ACC, $					; Inner loop (41.8us - 1024 cycles)
	djnz	Temp1, wait_ms_m
	djnz	Temp2, wait_ms_o
	ret


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Beeper routines (Multiple entry points)
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
beep_f1:
	mov	Temp3, #66				; Off wait loop length (Tone)
	mov	Temp4, #(3500 / 66)			; Number of beep pulses (Duration)
	sjmp	beep

beep_f2:
	mov	Temp3, #45
	mov	Temp4, #(3500 / 45)
	sjmp	beep

beep_f3:
	mov	Temp3, #38
	mov	Temp4, #(3500 / 38)
	sjmp	beep

beep_f4:
	mov	Temp3, #25
	mov	Temp4, #(3500 / 25)
	sjmp	beep

beep_f5:
	mov	Temp3, #20
	mov	Temp4, #(3500 / 20)
	sjmp	beep

beep_f1_short:
	mov	Temp3, #66
	mov	Temp4, #(2000 / 66)
	sjmp	beep

beep_f2_short:
	mov	Temp3, #45
	mov	Temp4, #(2000 / 45)
	sjmp	beep

beep:
	mov	A, Beep_Strength
	djnz	ACC, beep_start			; Start if beep strength is not 1
	ret

beep_start:
	mov	Temp2, #2

beep_onoff:
	clr	A
	BcomFET_off					; BcomFET off
	djnz	ACC, $					; Allow some time after comfet is turned off
	BpwmFET_on					; BpwmFET on (in order to charge the driver of the BcomFET)
	djnz	ACC, $					; Let the pwmfet be turned on a while
	BpwmFET_off					; BpwmFET off again
	djnz	ACC, $					; Allow some time after pwmfet is turned off
	BcomFET_on					; BcomFET on
	djnz	ACC, $					; Allow some time after comfet is turned on

	mov	A, Temp2					; Turn on pwmfet
	jb	ACC.0, beep_apwmfet_on
	ApwmFET_on
beep_apwmfet_on:
	jnb	ACC.0, beep_cpwmfet_on
	CpwmFET_on
beep_cpwmfet_on:

	mov	A, Beep_Strength			; On time according to beep strength
	djnz	ACC, $

	mov	A, Temp2					; Turn off pwmfet
	jb	ACC.0, beep_apwmfet_off
	ApwmFET_off
beep_apwmfet_off:
	jnb	ACC.0, beep_cpwmfet_off
	CpwmFET_off
beep_cpwmfet_off:

	mov	A, #150					; Off for 25 us
	djnz	ACC, $

	djnz	Temp2, beep_onoff			; Toggle next pwmfet

	mov	A, Temp3
beep_off:							; Fets off loop
	mov	Temp1, #200
	djnz	Temp1, $
	djnz	ACC, beep_off				; Off time according to beep frequency

	djnz	Temp4, beep_start			; Number of beep pulses (duration)

	BcomFET_off
	ret


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; LED control
;
; Controls LEDs
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
led_control:
	mov	Temp1, #Pgm_LED_Control
	mov	A, @Temp1
	mov	Temp2, A
	anl	A, #03h
	Set_LED_0
	jnz	led_0_done
	Clear_LED_0
led_0_done:
	mov	A, Temp2
	anl	A, #0Ch
	Set_LED_1
	jnz	led_1_done
	Clear_LED_1
led_1_done:
	mov	A, Temp2
	anl	A, #030h
	Set_LED_2
	jnz	led_2_done
	Clear_LED_2
led_2_done:
	mov	A, Temp2
	anl	A, #0C0h
	Set_LED_3
	jnz	led_3_done
	Clear_LED_3
led_3_done:
	ret



;**** **** **** **** **** **** **** **** **** **** **** **** ****
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Power and temperature control
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;**** **** **** **** **** **** **** **** **** **** **** **** ****


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Switch power off routine
;
; Switches all fets off
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
switch_power_off:
	All_pwmFETs_Off				; Turn off all pwm fets
	All_comFETs_Off				; Turn off all commutation fets
	Set_Pwms_Off
	ret


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Set pwm limit low rpm
;
; Sets power limit for low rpm and disables demag for low rpm
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
set_pwm_limit:
	jb	Flag_High_Rpm, set_pwm_limit_high_rpm	; If high rpm, limit pwm by rpm instead

;set_pwm_limit_low_rpm:
	; Set pwm limit
	mov	Temp1, #0FFh				; Default full power
	jb	Flag_Startup_Phase, set_pwm_limit_low_rpm_exit	; Exit if startup phase set

	mov	Temp2, #Pgm_Enable_Power_Prot	; Check if low RPM power protection is enabled
	mov	A, @Temp2
	jz	set_pwm_limit_low_rpm_exit	; Exit if disabled

	mov	A, Comm_Period4x_H
	jz	set_pwm_limit_low_rpm_exit	; Avoid divide by zero

	mov	A, #255					; Divide 255 by Comm_Period4x_H
	mov	B, Comm_Period4x_H
	div	AB
	mov	B, Low_Rpm_Pwr_Slope		; Multiply by slope
	jnb	Flag_Initial_Run_Phase, ($+6)	; More protection for initial run phase
	mov	B, #5
	mul	AB
	mov	Temp1, A					; Set new limit
	xch	A, B
	jz	($+4)					; Limit to max

	mov	Temp1, #0FFh

	clr	C
	mov	A, Temp1					; Limit to min
	subb	A, Pwm_Limit_Beg
	jnc	set_pwm_limit_low_rpm_exit

	mov	Temp1, Pwm_Limit_Beg

set_pwm_limit_low_rpm_exit:
	mov	Pwm_Limit_By_Rpm, Temp1
	ret


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Set pwm limit high rpm
;
; Sets power limit for high rpm
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
set_pwm_limit_high_rpm:
	clr	C
	mov	A, Comm_Period4x_L
IF MCU_48MHZ == 1
	subb	A, #0A0h					; Limit Comm_Period to 160, which is 500k erpm
ELSE
	subb	A, #0E4h					; Limit Comm_Period to 228, which is 350k erpm
ENDIF
	mov	A, Comm_Period4x_H
	subb	A, #00h

	mov	A, Pwm_Limit_By_Rpm
	jnc	set_pwm_limit_high_rpm_inc_limit

	dec	A
	sjmp	set_pwm_limit_high_rpm_store

set_pwm_limit_high_rpm_inc_limit:
	inc	A

set_pwm_limit_high_rpm_store:
	jz	($+4)
	mov	Pwm_Limit_By_Rpm, A

	ret


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Check motor temperature and limit power
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
check_temp_and_limit_power:
	inc	Adc_Conversion_Cnt			; Increment conversion counter
	clr	C
	mov	A, Adc_Conversion_Cnt		; Is conversion count equal to temp rate?
	subb	A, #8
	jc	temp_increase_pwm_limit		; No - increase pwm limit

	; Wait for ADC conversion to complete
	jnb	ADC0CN0_ADINT, check_temp_and_limit_power
	; Read ADC result
	Read_Adc_Result
	; Stop ADC
	Stop_Adc

	mov	Adc_Conversion_Cnt, #0		; Yes - temperature check. Reset counter
	mov	A, Temp2					; Move ADC MSB to Temp3
	mov	Temp3, A
	mov	Temp2, #Pgm_Enable_Temp_Prot	; Is temp protection enabled?
	mov	A, @Temp2
	jz	temp_check_exit			; No - branch

	mov	A, Temp3					; Is temperature reading below 256?
	jnz	temp_average_inc_dec		; No - proceed

	mov	A, Current_Average_Temp		; Yes - decrement average
	jz	temp_average_updated		; Already zero - no change
	sjmp	temp_average_dec			; Decrement

temp_average_inc_dec:
	clr	C
	mov	A, Temp1					; Check if current temperature is above or below average
	subb	A, Current_Average_Temp
	jz	temp_average_updated_load_acc	; Equal - no change

	mov	A, Current_Average_Temp		; Above - increment average
	jnc	temp_average_inc

	jz	temp_average_updated		; Below - decrement average if average is not already zero
temp_average_dec:
	dec	A						; Decrement average
	sjmp	temp_average_updated

temp_average_inc:
	inc	A						; Increment average
	jz	temp_average_dec
	sjmp	temp_average_updated

temp_average_updated_load_acc:
	mov	A, Current_Average_Temp
temp_average_updated:
	mov	Current_Average_Temp, A
	clr	C
	subb	A, Temp_Prot_Limit			; Is temperature below first limit?
	jc	temp_check_exit			; Yes - exit

	mov	Pwm_Limit, #192			; No - limit pwm

	clr	C
	subb	A, #(TEMP_LIMIT_STEP/2)		; Is temperature below second limit
	jc	temp_check_exit			; Yes - exit

	mov	Pwm_Limit, #128			; No - limit pwm

	clr	C
	subb	A, #(TEMP_LIMIT_STEP/2)		; Is temperature below third limit
	jc	temp_check_exit			; Yes - exit

	mov	Pwm_Limit, #64				; No - limit pwm

	clr	C
	subb	A, #(TEMP_LIMIT_STEP/2)		; Is temperature below final limit
	jc	temp_check_exit			; Yes - exit

	mov	Pwm_Limit, #0				; No - limit pwm

temp_check_exit:
	ret

temp_increase_pwm_limit:
	mov	A, Pwm_Limit
	add	A, #16					; Increase pwm limit
	jnc	($+4)					; Check if above maximum
	mov	A, #255					; Set maximum value

	mov	Pwm_Limit, A				; Set new pwm limit
	ret



;**** **** **** **** **** **** **** **** **** **** **** **** ****
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Commutation and timing
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;**** **** **** **** **** **** **** **** **** **** **** **** ****


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Initialize timing routine
;
; Part of initialization before motor start
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
initialize_timing:
	mov	Comm_Period4x_L, #00h		; Set commutation period registers
	mov	Comm_Period4x_H, #0F0h
	ret


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Calculate next commutation timing routine
;
; Called immediately after each commutation
; Also sets up timer 3 to wait advance timing
; Two entry points are used
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
calc_next_comm_timing:				; Entry point for run phase
	; Read commutation time
	clr	IE_EA
	clr	TMR2CN0_TR2				; Timer 2 disabled
	mov	Temp1, TMR2L				; Load timer 2 value
	mov	Temp2, TMR2H
	mov	Temp3, Timer2_X
	jnb	TMR2CN0_TF2H, ($+4)			; Check if interrupt is pending
	inc	Temp3					; If it is pending, then timer has already wrapped
	setb	TMR2CN0_TR2				; Timer 2 enabled
	setb	IE_EA
IF MCU_48MHZ == 1
	clr	C
	rrca	Temp3
	rrca	Temp2
	rrca	Temp1
ENDIF
	; Calculate this commutation time
	mov	Temp4, Prev_Comm_L
	mov	Temp5, Prev_Comm_H
	mov	Prev_Comm_L, Temp1			; Store timestamp as previous commutation
	mov	Prev_Comm_H, Temp2
	clr	C
	mov	A, Temp1
	subb	A, Temp4					; Calculate the new commutation time
	mov	Temp1, A
	mov	A, Temp2
	subb	A, Temp5
	jb	Flag_Startup_Phase, calc_next_comm_startup

IF MCU_48MHZ == 1
	anl	A, #7Fh
ENDIF
	mov	Temp2, A
	jnb	Flag_High_Rpm, calc_next_comm_normal	; Branch normal rpm
	ajmp	calc_next_comm_timing_fast			; Branch high rpm

calc_next_comm_startup:
	mov	Temp6, Prev_Comm_X
	mov	Prev_Comm_X, Temp3			; Store extended timestamp as previous commutation
	mov	Temp2, A
	mov	A, Temp3
	subb	A, Temp6					; Calculate the new extended commutation time
IF MCU_48MHZ == 1
	anl	A, #7Fh
ENDIF
	mov	Temp3, A
	jz	calc_next_comm_startup_no_X

	mov	Temp1, #0FFh
	mov	Temp2, #0FFh
	sjmp	calc_next_comm_startup_average

calc_next_comm_startup_no_X:
	mov	Temp7, Prev_Prev_Comm_L
	mov	Temp8, Prev_Prev_Comm_H
	mov	Prev_Prev_Comm_L, Temp4
	mov	Prev_Prev_Comm_H, Temp5
	mov	Temp1, Prev_Comm_L			; Reload this commutation time
	mov	Temp2, Prev_Comm_H

	; Calculate the new commutation time based upon the two last commutations (to reduce sensitivity to offset)
	clr	C
	mov	A, Temp1
	subb	A, Temp7
	mov	Temp1, A
	mov	A, Temp2
	subb	A, Temp8
	mov	Temp2, A

calc_next_comm_startup_average:
	clr	C
	mov	A, Comm_Period4x_H			; Average with previous and save
	rrc	A
	mov	Temp4, A
	mov	A, Comm_Period4x_L
	rrc	A
	mov	Temp3, A
	mov	A, Temp1
	add	A, Temp3
	mov	Comm_Period4x_L, A
	mov	A, Temp2
	addc	A, Temp4
	mov	Comm_Period4x_H, A
	jnc	($+8)

	mov	Comm_Period4x_L, #0FFh
	mov	Comm_Period4x_H, #0FFh

	sjmp	calc_new_wait_times_setup

calc_next_comm_normal:
	; Calculate new commutation time
	mov	Temp3, Comm_Period4x_L		; Comm_Period4x(-l-h) holds the time of 4 commutations
	mov	Temp4, Comm_Period4x_H
	mov	Temp5, Comm_Period4x_L		; Copy variables
	mov	Temp6, Comm_Period4x_H
	mov	Temp7, #4					; Divide Comm_Period4x 4 times as default
	mov	Temp8, #2					; Divide new commutation time 2 times as default
	clr	C
	mov	A, Temp4
	subb	A, #04h
	jc	calc_next_comm_avg_period_div

	dec	Temp7					; Reduce averaging time constant for low speeds
	dec	Temp8

	clr	C
	mov	A, Temp4
	subb	A, #08h
	jc	calc_next_comm_avg_period_div

	jb	Flag_Initial_Run_Phase, calc_next_comm_avg_period_div	; Do not average very fast during initial run

	dec	Temp7					; Reduce averaging time constant more for even lower speeds
	dec	Temp8

calc_next_comm_avg_period_div:
	clr	C
	rrca	Temp6					; Divide by 2
	rrca	Temp5
	djnz	Temp7, calc_next_comm_avg_period_div

	clr	C
	mov	A, Temp3
	subb	A, Temp5					; Subtract a fraction
	mov	Temp3, A
	mov	A, Temp4
	subb	A, Temp6
	mov	Temp4, A
	mov	A, Temp8					; Divide new time
	jz	calc_next_comm_new_period_div_done

calc_next_comm_new_period_div:
	clr	C
	rrca	Temp2					; Divide by 2
	rrca	Temp1
	djnz	Temp8, calc_next_comm_new_period_div

calc_next_comm_new_period_div_done:
	mov	A, Temp3
	add	A, Temp1					; Add the divided new time
	mov	Temp3, A
	mov	A, Temp4
	addc	A, Temp2
	mov	Temp4, A
	mov	Comm_Period4x_L, Temp3		; Store Comm_Period4x_X
	mov	Comm_Period4x_H, Temp4
	jnc	calc_new_wait_times_setup	; If period larger than 0xffff - go to slow case

	mov	Temp4, #0FFh
	mov	Comm_Period4x_L, Temp4		; Set commutation period registers to very slow timing (0xffff)
	mov	Comm_Period4x_H, Temp4

calc_new_wait_times_setup:
	; Set high rpm bit (if above 156k erpm)
	clr	C
	mov	A, Temp4
	subb	A, #2
	jnc	($+4)

	setb	Flag_High_Rpm				; Set high rpm bit

	; Load programmed commutation timing
	jnb	Flag_Startup_Phase, calc_new_wait_per_startup_done	; Set dedicated timing during startup

	mov	Temp8, #3
	sjmp	calc_new_wait_per_demag_done

calc_new_wait_per_startup_done:
	mov	Temp1, #Pgm_Comm_Timing		; Load timing setting
	mov	A, @Temp1
	mov	Temp8, A					; Store in Temp8
	clr	C
	mov	A, Demag_Detected_Metric		; Check demag metric
	subb	A, #130
	jc	calc_new_wait_per_demag_done

	inc	Temp8					; Increase timing

	clr	C
	mov	A, Demag_Detected_Metric
	subb	A, #160
	jc	($+3)

	inc	Temp8					; Increase timing again

	clr	C
	mov	A, Temp8					; Limit timing to max
	subb	A, #6
	jc	($+4)

	mov	Temp8, #5					; Set timing to max

calc_new_wait_per_demag_done:
	; Set timing reduction
	mov	Temp7, #2
	; Load current commutation timing
	mov	A, Comm_Period4x_H			; Divide 4 times
	swap	A
	anl	A, #00Fh
	mov	Temp2, A
	mov	A, Comm_Period4x_H
	swap	A
	anl	A, #0F0h
	mov	Temp1, A
	mov	A, Comm_Period4x_L
	swap	A
	anl	A, #00Fh
	add	A, Temp1
	mov	Temp1, A

	clr	C
	mov	A, Temp1
	subb	A, Temp7
	mov	Temp3, A
	mov	A, Temp2
	subb	A, #0
	mov	Temp4, A
	jc	load_min_time				; Check that result is still positive
	jnz	calc_next_comm_timing_exit	; Check that result is still above minimum
	mov	A, Temp3
	jnz	calc_next_comm_timing_exit

load_min_time:
	mov	Temp3, #1					; Set minimum time
	mov	Temp4, #0

	sjmp	calc_next_comm_timing_exit

;**** **** **** **** ****
; Calculate next commutation timing fast routine
; Fast calculation (Comm_Period4x_H less than 2)
calc_next_comm_timing_fast:
	; Calculate new commutation time
	mov	Temp3, Comm_Period4x_L		; Comm_Period4x(-l-h) holds the time of 4 commutations
	mov	Temp4, Comm_Period4x_H
	mov	A, Temp4					; Divide by 2 4 times
	swap	A
	mov	Temp7, A
	mov	A, Temp3
	swap	A
	anl	A, #0Fh
	orl	A, Temp7
	mov	Temp5, A
	clr	C
	mov	A, Temp3					; Subtract a fraction
	subb	A, Temp5
	mov	Temp3, A
	mov	A, Temp4
	subb	A, #0
	mov	Temp4, A
	clr	C
	mov	A, Temp1
	rrc	A						; Divide by 2 2 times
	clr	C
	rrc	A
	mov	Temp1, A
	mov	A, Temp3					; Add the divided new time
	add	A, Temp1
	mov	Temp3, A
	mov	A, Temp4
	addc	A, #0
	mov	Temp4, A
	mov	Comm_Period4x_L, Temp3		; Store Comm_Period4x_X
	mov	Comm_Period4x_H, Temp4
	clr	C
	subb	A, #2					; If erpm below 156k - go to normal case
	jc	($+4)

	clr	Flag_High_Rpm				; Clear high rpm bit

	; Set timing reduction
	mov	Temp1, #2
	mov	A, Temp4					; Divide by 2 4 times
	swap	A
	mov	Temp7, A
	mov	Temp4, #0
	mov	A, Temp3
	swap	A
	anl	A, #0Fh
	orl	A, Temp7
	mov	Temp3, A
	clr	C
	subb	A, Temp1
	mov	Temp3, A
	jc	load_min_time_fast			; Check that result is still positive
	jnz	calc_new_wait_times_fast_done	; Check that result is still above minimum

load_min_time_fast:
	mov	Temp3, #1					; Set minimum time

calc_new_wait_times_fast_done:
	mov	Temp1, #Pgm_Comm_Timing		; Load timing setting
	mov	A, @Temp1
	mov	Temp8, A					; Store in Temp8

calc_next_comm_timing_exit:


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Wait advance timing routine
; NOTE: Be VERY careful if using temp registers. They are passed over this routine
;
; Waits for the advance timing to elapse and sets up the next zero cross wait
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
wait_advance_timing:
	Wait_For_Timer3

	; Setup next wait time
	mov	TMR3RLL, Wt_ZC_Tout_Start_L
	mov	TMR3RLH, Wt_ZC_Tout_Start_H
	setb	Flag_Timer3_Pending
	orl	EIE1, #80h				; Enable timer 3 interrupts


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Calculate new wait times routine
;
; Calculates new wait times
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
calc_new_wait_times:
	clr	C
	clr	A
	subb	A, Temp3					; Negate
	mov	Temp1, A
	clr	A
	subb	A, Temp4
	mov	Temp2, A
IF MCU_48MHZ == 1
	clr	C
	rlca	Temp1					; Multiply by 2
	rlca	Temp2
ENDIF

	jb	Flag_High_Rpm, calc_new_wait_times_fast	; Branch if high rpm

	mov	A, Temp1					; Copy values
	mov	Temp3, A
	mov	A, Temp2
	mov	Temp4, A
	setb	C						; Negative numbers - set carry
	mov	A, Temp2
	rrc	A						; Divide by 2
	mov	Temp6, A
	mov	A, Temp1
	rrc	A
	mov	Temp5, A
	mov	Wt_Zc_Tout_Start_L, Temp1	; Set 15deg time for zero cross scan timeout
	mov	Wt_Zc_Tout_Start_H, Temp2
	clr	C
	mov	A, Temp8					; (Temp8 has Pgm_Comm_Timing)
	subb	A, #3					; Is timing normal?
	jz	store_times_decrease		; Yes - branch

	mov	A, Temp8
	jb	ACC.0, adjust_timing_two_steps; If an odd number - branch

	mov	A, Temp1					; Add 7.5deg and store in Temp1/2
	add	A, Temp5
	mov	Temp1, A
	mov	A, Temp2
	addc	A, Temp6
	mov	Temp2, A
	mov	A, Temp5					; Store 7.5deg in Temp3/4
	mov	Temp3, A
	mov	A, Temp6
	mov	Temp4, A
	sjmp	store_times_up_or_down

adjust_timing_two_steps:
	mov	A, Temp1					; Add 15deg and store in Temp1/2
	setb	C						; Add 1 to final result (Temp1/2 * 2 + 1)
	addc	A, Temp1
	mov	Temp1, A
	mov	A, Temp2
	addc	A, Temp2
	mov	Temp2, A
	mov	Temp3, #0FFh				; Store minimum time in Temp3/4
	mov	Temp4, #0FFh

store_times_up_or_down:
	clr	C
	mov	A, Temp8
	subb	A, #3					; Is timing higher than normal?
	jc	store_times_decrease		; No - branch

store_times_increase:
	mov	Wt_Comm_Start_L, Temp3		; Now commutation time (~60deg) divided by 4 (~15deg nominal)
	mov	Wt_Comm_Start_H, Temp4
	mov	Wt_Adv_Start_L, Temp1		; New commutation advance time (~15deg nominal)
	mov	Wt_Adv_Start_H, Temp2
	mov	Wt_Zc_Scan_Start_L, Temp5	; Use this value for zero cross scan delay (7.5deg)
	mov	Wt_Zc_Scan_Start_H, Temp6
	sjmp	calc_new_wait_times_exit

store_times_decrease:
	mov	Wt_Comm_Start_L, Temp1		; Now commutation time (~60deg) divided by 4 (~15deg nominal)
	mov	Wt_Comm_Start_H, Temp2
	mov	Wt_Adv_Start_L, Temp3		; New commutation advance time (~15deg nominal)
	mov	Wt_Adv_Start_H, Temp4
	mov	Wt_Zc_Scan_Start_L, Temp5	; Use this value for zero cross scan delay (7.5deg)
	mov	Wt_Zc_Scan_Start_H, Temp6

	; Set very short delays for all but advance time during startup, in order to widen zero cross capture range
	jnb	Flag_Startup_Phase, calc_new_wait_times_exit
	mov	Wt_Comm_Start_L, #0F0h
	mov	Wt_Comm_Start_H, #0FFh
	mov	Wt_Zc_Scan_Start_L, #0F0h
	mov	Wt_Zc_Scan_Start_H, #0FFh
	mov	Wt_Zc_Tout_Start_L, #0F0h
	mov	Wt_Zc_Tout_Start_H, #0FFh

	sjmp	calc_new_wait_times_exit

;**** **** **** **** ****
; Calculate new wait times fast routine
calc_new_wait_times_fast:
	mov	A, Temp1					; Copy values
	mov	Temp3, A
	setb	C						; Negative numbers - set carry
	rrc	A						; Divide by 2
	mov	Temp5, A
	mov	Wt_Zc_Tout_Start_L, Temp1	; Set 15deg time for zero cross scan timeout
	clr	C
	mov	A, Temp8					; (Temp8 has Pgm_Comm_Timing)
	subb	A, #3					; Is timing normal?
	jz	store_times_decrease_fast	; Yes - branch

	mov	A, Temp8
	jb	ACC.0, adjust_timing_two_steps_fast	; If an odd number - branch

	mov	A, Temp1					; Add 7.5deg and store in Temp1
	add	A, Temp5
	mov	Temp1, A
	mov	A, Temp5					; Store 7.5deg in Temp3
	mov	Temp3, A
	sjmp	store_times_up_or_down_fast

adjust_timing_two_steps_fast:
	mov	A, Temp1					; Add 15deg and store in Temp1
	add	A, Temp1
	add	A, #1
	mov	Temp1, A
	mov	Temp3, #0FFh				; Store minimum time in Temp3

store_times_up_or_down_fast:
	clr	C
	mov	A, Temp8
	subb	A, #3					; Is timing higher than normal?
	jc	store_times_decrease_fast	; No - branch

store_times_increase_fast:
	mov	Wt_Comm_Start_L, Temp3		; Now commutation time (~60deg) divided by 4 (~15deg nominal)
	mov	Wt_Adv_Start_L, Temp1		; New commutation advance time (~15deg nominal)
	mov	Wt_Zc_Scan_Start_L, Temp5	; Use this value for zero cross scan delay (7.5deg)
	sjmp	calc_new_wait_times_exit

store_times_decrease_fast:
	mov	Wt_Comm_Start_L, Temp1		; Now commutation time (~60deg) divided by 4 (~15deg nominal)
	mov	Wt_Adv_Start_L, Temp3		; New commutation advance time (~15deg nominal)
	mov	Wt_Zc_Scan_Start_L, Temp5	; Use this value for zero cross scan delay (7.5deg)

calc_new_wait_times_exit:


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Wait before zero cross scan routine
;
; Waits for the zero cross scan wait time to elapse
; Also sets up timer 3 for the zero cross scan timeout time
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
wait_before_zc_scan:
	Wait_For_Timer3

	mov	Startup_Zc_Timeout_Cntd, #2
setup_zc_scan_timeout:
	setb	Flag_Timer3_Pending
	orl	EIE1, #80h				; Enable timer 3 interrupts
	mov	A, Flags_Startup
	jz	wait_before_zc_scan_exit

	mov	Temp1, Comm_Period4x_L		; Set long timeout when starting
	mov	Temp2, Comm_Period4x_H
	clr	C
	rrca	Temp2
	rrca	Temp1
IF MCU_48MHZ == 0
	clr	C
	rrca	Temp2
	rrca	Temp1
ENDIF
	jnb	Flag_Startup_Phase, setup_zc_scan_timeout_startup_done

	mov	A, Temp2
	add	A, #40h					; Increase timeout somewhat to avoid false wind up
	mov	Temp2, A

setup_zc_scan_timeout_startup_done:
	clr	IE_EA
	anl	EIE1, #7Fh				; Disable timer 3 interrupts
	mov	TMR3CN0, #00h				; Timer 3 disabled and interrupt flag cleared
	clr	C
	clr	A
	subb	A, Temp1					; Set timeout
	mov	TMR3L, A
	clr	A
	subb	A, Temp2
	mov	TMR3H, A
	mov	TMR3CN0, #04h				; Timer 3 enabled and interrupt flag cleared
	setb	Flag_Timer3_Pending
	orl	EIE1, #80h				; Enable timer 3 interrupts
	setb	IE_EA

wait_before_zc_scan_exit:
	ret


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Wait for comparator to go low/high routines
;
; Waits for the zero cross scan wait time to elapse
; Then scans for comparator going low/high
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
wait_for_comp_out_low:
	setb	Flag_Demag_Detected			; Set demag detected flag as default
	mov	Comparator_Read_Cnt, #0		; Reset number of comparator reads
	mov	Bit_Access, #00h			; Desired comparator output
	jnb	Flag_Dir_Change_Brake, ($+6)
	mov	Bit_Access, #40h
	sjmp	wait_for_comp_out_start

wait_for_comp_out_high:
	setb	Flag_Demag_Detected			; Set demag detected flag as default
	mov	Comparator_Read_Cnt, #0		; Reset number of comparator reads
	mov	Bit_Access, #40h			; Desired comparator output
	jnb	Flag_Dir_Change_Brake, ($+6)
	mov	Bit_Access, #00h

wait_for_comp_out_start:
	; Set number of comparator readings
	mov	Temp1, #1					; Number of OK readings required
	mov	Temp2, #1					; Max number of readings required
	jb	Flag_High_Rpm, comp_scale_samples	; Branch if high rpm

	mov	A, Flags_Startup			; Clear demag detected flag if start phases
	jz	($+4)
	clr	Flag_Demag_Detected

	; Too low value (~<15) causes rough running at pwm harmonics.
	; Too high a value (~>35) causes the RCT4215 630 to run rough on full throttle
	mov	Temp2, #20
	mov	A, Comm_Period4x_H			; Set number of readings higher for lower speeds
	clr	C
	rrc	A
	jnz	($+3)
	inc	A
	mov	Temp1, A
	clr	C
	subb	A, #20
	jc	($+4)

	mov	Temp1, #20

	jnb	Flag_Startup_Phase, comp_scale_samples

	mov	Temp1, #27				; Set many samples during startup, approximately one pwm period
	mov	Temp2, #27

comp_scale_samples:
IF MCU_48MHZ == 1
	clr	C
	rlca	Temp1
	clr	C
	rlca	Temp2
ENDIF

comp_check_timeout:
	jb	Flag_Timer3_Pending, comp_check_timeout_not_timed_out	; Has zero cross scan timeout elapsed?

	mov	A, Comparator_Read_Cnt			; Check that comparator has been read
	jz	comp_check_timeout_not_timed_out	; If not read - branch

	jnb	Flag_Startup_Phase, comp_check_timeout_timeout_extended	; Extend timeout during startup

	djnz	Startup_Zc_Timeout_Cntd, comp_check_timeout_extend_timeout

comp_check_timeout_timeout_extended:
	setb	Flag_Comp_Timed_Out
	sjmp	setup_comm_wait

comp_check_timeout_extend_timeout:
	call	setup_zc_scan_timeout
comp_check_timeout_not_timed_out:
	inc	Comparator_Read_Cnt			; Increment comparator read count
	Read_Comp_Out					; Read comparator output
	anl	A, #40h
	cjne	A, Bit_Access, comp_read_wrong

	; Comp read ok
	mov	A, Startup_Cnt				; Force a timeout for the first commutation
	jz	wait_for_comp_out_start

	jb	Flag_Demag_Detected, wait_for_comp_out_start	; Do not accept correct comparator output if it is demag

	djnz	Temp1, comp_check_timeout	; Decrement readings counter - repeat comparator reading if not zero

	clr	Flag_Comp_Timed_Out

	sjmp	setup_comm_wait

comp_read_wrong:
	jnb	Flag_Startup_Phase, comp_read_wrong_not_startup

	inc	Temp1					; Increment number of OK readings required
	clr	C
	mov	A, Temp1
	subb	A, Temp2					; If above initial requirement - do not increment further
	jc	($+3)
	dec	Temp1

	sjmp	comp_check_timeout			; Continue to look for good ones

comp_read_wrong_not_startup:
	jb	Flag_Demag_Detected, comp_read_wrong_extend_timeout

	inc	Temp1					; Increment number of OK readings required
	clr	C
	mov	A, Temp1
	subb	A, Temp2
	jc	comp_check_timeout			; If below initial requirement - take another reading
	sjmp	wait_for_comp_out_start		; Otherwise - go back and restart

comp_read_wrong_extend_timeout:
	clr	Flag_Demag_Detected			; Clear demag detected flag
	anl	EIE1, #7Fh				; Disable timer 3 interrupts
	mov	TMR3CN0, #00h				; Timer 3 disabled and interrupt flag cleared
	jnb	Flag_High_Rpm, comp_read_wrong_low_rpm	; Branch if not high rpm

	mov	TMR3L, #00h				; Set timeout to ~1ms
IF MCU_48MHZ == 1
	mov	TMR3H, #0F0h
ELSE
	mov	TMR3H, #0F8h
ENDIF
comp_read_wrong_timeout_set:
	mov	TMR3CN0, #04h				; Timer 3 enabled and interrupt flag cleared
	setb	Flag_Timer3_Pending
	orl	EIE1, #80h				; Enable timer 3 interrupts
	jmp	wait_for_comp_out_start		; If comparator output is not correct - go back and restart

comp_read_wrong_low_rpm:
	mov	A, Comm_Period4x_H			; Set timeout to ~4x comm period 4x value
	mov	Temp7, #0FFh				; Default to long
IF MCU_48MHZ == 1
	clr	C
	rlc	A
	jc	comp_read_wrong_load_timeout

ENDIF
	clr	C
	rlc	A
	jc	comp_read_wrong_load_timeout

	clr	C
	rlc	A
	jc	comp_read_wrong_load_timeout

	mov	Temp7, A

comp_read_wrong_load_timeout:
	clr	C
	clr	A
	subb	A, Temp7
	mov	TMR3L, #0
	mov	TMR3H, A
	sjmp	comp_read_wrong_timeout_set


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Setup commutation timing routine
;
; Sets up and starts wait from commutation to zero cross
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
setup_comm_wait:
	clr	IE_EA
	anl	EIE1, #7Fh				; Disable timer 3 interrupts
	mov	TMR3CN0, #00h				; Timer 3 disabled and interrupt flag cleared
	mov	TMR3L, Wt_Comm_Start_L
	mov	TMR3H, Wt_Comm_Start_H
	mov	TMR3CN0, #04h				; Timer 3 enabled and interrupt flag cleared
	; Setup next wait time
	mov	TMR3RLL, Wt_Adv_Start_L
	mov	TMR3RLH, Wt_Adv_Start_H
	setb	Flag_Timer3_Pending
	orl	EIE1, #80h				; Enable timer 3 interrupts
	setb	IE_EA					; Enable interrupts again


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Evaluate comparator integrity
;
; Checks comparator signal behavior versus expected behavior
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
evaluate_comparator_integrity:
	mov	A, Flags_Startup
	jz	eval_comp_check_timeout

	jb	Flag_Initial_Run_Phase, ($+5)			; Do not increment beyond startup phase
	inc	Startup_Cnt						; Increment counter
	sjmp	eval_comp_exit

eval_comp_check_timeout:
	jnb	Flag_Comp_Timed_Out, eval_comp_exit	; Has timeout elapsed?
	jb	Flag_Dir_Change_Brake, eval_comp_exit	; Do not exit run mode if it is braking
	jb	Flag_Demag_Detected, eval_comp_exit	; Do not exit run mode if it is a demag situation
	dec	SP								; Routine exit without "ret" command
	dec	SP
	ljmp	run_to_wait_for_power_on_fail			; Yes - exit run mode

eval_comp_exit:
	ret


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Wait for commutation routine
;
; Waits from zero cross to commutation
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
wait_for_comm:
	; Update demag metric
	mov	A, Demag_Detected_Metric		; Sliding average of 8, 256 when demag and 0 when not. Limited to minimum 120
	mov	B, #7
	mul	AB						; Multiply by 7

	jnb	Flag_Demag_Detected, ($+4)	; Add new value for current demag status
	inc	B

	mov	C, B.0					; Divide by 8
	rrc	A
	mov	C, B.1
	rrc	A
	mov	C, B.2
	rrc	A
	mov	Demag_Detected_Metric, A
	clr	C
	subb	A, #120					; Limit to minimum 120
	jnc	($+5)
	mov	Demag_Detected_Metric, #120

	clr	C
	mov	A, Demag_Detected_Metric		; Check demag metric
	subb	A, Demag_Pwr_Off_Thresh
	jc	wait_for_comm_wait			; Cut power if many consecutive demags. This will help retain sync during hard accelerations

	All_pwmFETs_off
	Set_Pwms_Off

wait_for_comm_wait:
	Wait_For_Timer3

	; Setup next wait time
	mov	TMR3RLL, Wt_Zc_Scan_Start_L
	mov	TMR3RLH, Wt_Zc_Scan_Start_H
	setb	Flag_Timer3_Pending
	orl	EIE1, #80h				; Enable timer 3 interrupts
	ret


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Commutation routines
;
; Performs commutation switching
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
; Comm phase 1 to comm phase 2
comm1_comm2:
	Set_RPM_Out
	jb	Flag_Pgm_Dir_Rev, comm1_comm2_rev

	clr	IE_EA					; Disable all interrupts
	BcomFET_off					; Turn off comfet
	AcomFET_on					; Turn on comfet
	Set_Pwm_C						; To reapply power after a demag cut
	setb	IE_EA
	Set_Comp_Phase_B				; Set comparator phase
	ret

comm1_comm2_rev:
	clr	IE_EA					; Disable all interrupts
	BcomFET_off					; Turn off comfet
	CcomFET_on					; Turn on comfet (reverse)
	Set_Pwm_A						; To reapply power after a demag cut
	setb	IE_EA
	Set_Comp_Phase_B				; Set comparator phase
	ret

; Comm phase 2 to comm phase 3
comm2_comm3:
	Clear_RPM_Out
	jb	Flag_Pgm_Dir_Rev, comm2_comm3_rev

	clr	IE_EA					; Disable all interrupts
	CpwmFET_off					; Turn off pwmfet
	Set_Pwm_B						; To reapply power after a demag cut
	AcomFET_on
	setb	IE_EA
	Set_Comp_Phase_C				; Set comparator phase
	ret

comm2_comm3_rev:
	clr	IE_EA					; Disable all interrupts
	ApwmFET_off					; Turn off pwmfet (reverse)
	Set_Pwm_B						; To reapply power after a demag cut
	CcomFET_on
	setb	IE_EA
	Set_Comp_Phase_A				; Set comparator phase (reverse)
	ret

; Comm phase 3 to comm phase 4
comm3_comm4:
	Set_RPM_Out
	jb	Flag_Pgm_Dir_Rev, comm3_comm4_rev

	clr	IE_EA					; Disable all interrupts
	AcomFET_off					; Turn off comfet
	CcomFET_on					; Turn on comfet
	Set_Pwm_B						; To reapply power after a demag cut
	setb	IE_EA
	Set_Comp_Phase_A				; Set comparator phase
	ret

comm3_comm4_rev:
	clr	IE_EA					; Disable all interrupts
	CcomFET_off					; Turn off comfet (reverse)
	AcomFET_on					; Turn on comfet (reverse)
	Set_Pwm_B						; To reapply power after a demag cut
	setb	IE_EA
	Set_Comp_Phase_C				; Set comparator phase (reverse)
	ret

; Comm phase 4 to comm phase 5
comm4_comm5:
	Clear_RPM_Out
	jb	Flag_Pgm_Dir_Rev, comm4_comm5_rev

	clr	IE_EA					; Disable all interrupts
	BpwmFET_off					; Turn off pwmfet
	Set_Pwm_A						; To reapply power after a demag cut
	CcomFET_on
	setb	IE_EA
	Set_Comp_Phase_B				; Set comparator phase
	ret

comm4_comm5_rev:
	clr	IE_EA					; Disable all interrupts
	BpwmFET_off					; Turn off pwmfet
	Set_Pwm_C
	AcomFET_on					; To reapply power after a demag cut
	setb	IE_EA
	Set_Comp_Phase_B				; Set comparator phase
	ret

; Comm phase 5 to comm phase 6
comm5_comm6:
	Set_RPM_Out
	jb	Flag_Pgm_Dir_Rev, comm5_comm6_rev

	clr	IE_EA					; Disable all interrupts
	CcomFET_off					; Turn off comfet
	BcomFET_on					; Turn on comfet
	Set_Pwm_A						; To reapply power after a demag cut
	setb	IE_EA
	Set_Comp_Phase_C				; Set comparator phase
	ret

comm5_comm6_rev:
	clr	IE_EA					; Disable all interrupts
	AcomFET_off					; Turn off comfet (reverse)
	BcomFET_on					; Turn on comfet
	Set_Pwm_C						; To reapply power after a demag cut
	setb	IE_EA
	Set_Comp_Phase_A				; Set comparator phase (reverse)
	ret

; Comm phase 6 to comm phase 1
comm6_comm1:
	Clear_RPM_Out
	jb	Flag_Pgm_Dir_Rev, comm6_comm1_rev

	clr	IE_EA					; Disable all interrupts
	ApwmFET_off					; Turn off pwmfet
	Set_Pwm_C
	BcomFET_on					; To reapply power after a demag cut
	setb	IE_EA
	Set_Comp_Phase_A				; Set comparator phase
	ret

comm6_comm1_rev:
	clr	IE_EA					; Disable all interrupts
	CpwmFET_off					; Turn off pwmfet (reverse)
	Set_Pwm_A
	BcomFET_on					; To reapply power after a demag cut
	setb	IE_EA
	Set_Comp_Phase_C				; Set comparator phase (reverse)
	ret



;**** **** **** **** **** **** **** **** **** **** **** **** ****
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; DShot
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;**** **** **** **** **** **** **** **** **** **** **** **** ****


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Detect DShot RCP level
;
; Determine if RCP signal level is normal or inverted DShot
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
detect_rcp_level:
	mov	A, #50					; Must detect the same level 50 times (25 us)
	mov	C, RTX_PORT.RTX_PIN

detect_rcp_level_read:
	jc	($+5)
	jb	RTX_PORT.RTX_PIN, detect_rcp_level	; Level changed from low to high - start over
	jnc	($+5)
	jnb	RTX_PORT.RTX_PIN, detect_rcp_level	; Level changed from high to low - start over
	djnz	ACC, detect_rcp_level_read

	mov	Flag_Rcp_DShot_Inverted, C
	ret


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Check DShot command
;
; Determine received DShot command and perform action
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
dshot_cmd_check:
	mov	A, DShot_Cmd
	jz	dshot_cmd_exit_no_clear

	mov	Temp1, A
	clr	C
	subb	A, #6					; Beacon beeps for command 1-5
	jnc	dshot_cmd_direction_1

	call	beacon_beep
	call wait200ms

	sjmp	dshot_cmd_exit

dshot_cmd_direction_1:
	; Change programmed motor direction to normal
	cjne	Temp1, #7, dshot_cmd_direction_2

	clr	C
	mov	A, DShot_Cmd_Cnt
	subb	A, #6					; Needs to receive it 6 times in a row
	jc	dshot_cmd_exit_no_clear

	mov	A, #1
	jnb	Flag_Pgm_Bidir, ($+5)
	mov	A, #3
	mov	Temp1, #Pgm_Direction
	mov	@Temp1, A
	clr	Flag_Pgm_Dir_Rev
	clr	Flag_Pgm_Bidir_Rev

	sjmp	dshot_cmd_exit

dshot_cmd_direction_2:
	; Change programmed motor direction to reversed
	cjne	Temp1, #8, dshot_cmd_direction_bidir_off

	clr	C
	mov	A, DShot_Cmd_Cnt
	subb	A, #6					; Needs to receive it 6 times in a row
	jc	dshot_cmd_exit_no_clear

	mov	A, #2
	jnb	Flag_Pgm_Bidir, ($+5)
	mov	A, #4
	mov	Temp1, #Pgm_Direction
	mov	@Temp1, A
	setb	Flag_Pgm_Dir_Rev
	setb	Flag_Pgm_Bidir_Rev

	sjmp	dshot_cmd_exit

dshot_cmd_direction_bidir_off:
	; Change programmed motor mode to normal (not bidirectional)
	cjne	Temp1, #9, dshot_cmd_direction_bidir_on

	clr	C
	mov	A, DShot_Cmd_Cnt
	subb	A, #6					; Needs to receive it 6 times in a row
	jc	dshot_cmd_exit_no_clear

	jnb	Flag_Pgm_Bidir, dshot_cmd_exit

	clr	C
	mov	Temp1, #Pgm_Direction
	mov	A, @Temp1
	subb	A, #2
	mov	@Temp1, A
	clr	Flag_Pgm_Bidir

	sjmp	dshot_cmd_exit

dshot_cmd_direction_bidir_on:
	; Change programmed motor mode to bidirectional
	cjne	Temp1, #10, dshot_cmd_direction_normal

	clr	C
	mov	A, DShot_Cmd_Cnt
	subb	A, #6					; Needs to receive it 6 times in a row
	jc	dshot_cmd_exit_no_clear

	jb	Flag_Pgm_Bidir, dshot_cmd_exit

	mov	Temp1, #Pgm_Direction
	mov	A, @Temp1
	add	A, #2
	mov	@Temp1, A
	setb	Flag_Pgm_Bidir

dshot_cmd_exit:
	mov	DShot_Cmd, #0
	mov	DShot_Cmd_Cnt, #0

dshot_cmd_exit_no_clear:
	ret

dshot_cmd_direction_normal:
	; Change programmed motor direction to that stored in eeprom
	cjne	Temp1, #20, dshot_cmd_direction_reverse

	clr	C
	mov	A, DShot_Cmd_Cnt
	subb	A, #6					; Needs to receive it 6 times in a row
	jc	dshot_cmd_exit_no_clear

	clr	IE_EA					; DPTR used in interrupts
	mov	DPTR, #Eep_Pgm_Direction		; Read from flash
	mov	A, #0
	movc	A, @A+DPTR
	setb	IE_EA
	mov	Temp1, #Pgm_Direction
	mov	@Temp1, A
	rrc	A						; Lsb to carry
	clr	Flag_Pgm_Dir_Rev
	clr	Flag_Pgm_Bidir_Rev
	jc	($+4)
	setb	Flag_Pgm_Dir_Rev
	jc	($+4)
	setb	Flag_Pgm_Bidir_Rev

	sjmp	dshot_cmd_exit

dshot_cmd_direction_reverse:			; Temporary reverse
	; Change programmed motor direction to the reverse of what is stored in eeprom
	cjne	Temp1, #21, dshot_cmd_save_settings

	clr	C
	mov	A, DShot_Cmd_Cnt
	subb	A, #6					; Needs to receive it 6 times in a row
	jc	dshot_cmd_exit_no_clear

	clr	IE_EA					; DPTR used in interrupts
	mov	DPTR, #Eep_Pgm_Direction		; Read from flash
	mov	A, #0
	movc	A, @A+DPTR
	setb	IE_EA
	mov	Temp1, A
	cjne	Temp1, #1, ($+5)
	mov	A, #2
	cjne	Temp1, #2, ($+5)
	mov	A, #1
	cjne	Temp1, #3, ($+5)
	mov	A, #4
	cjne	Temp1, #4, ($+5)
	mov	A, #3
	mov	Temp1, #Pgm_Direction
	mov	@Temp1, A
	rrc	A						; Lsb to carry
	clr	Flag_Pgm_Dir_Rev
	clr	Flag_Pgm_Bidir_Rev
	jc	($+4)
	setb	Flag_Pgm_Dir_Rev
	jc	($+4)
	setb	Flag_Pgm_Bidir_Rev

	sjmp	dshot_cmd_exit

dshot_cmd_save_settings:
	cjne	Temp1, #12, dshot_cmd_exit

	clr	C
	mov	A, DShot_Cmd_Cnt
	subb	A, #6					; Needs to receive it 6 times in a row
	jc	dshot_cmd_exit_no_clear

	mov	Flash_Key_1, #0A5h			; Initialize flash keys to valid values
	mov	Flash_Key_2, #0F1h

	call	erase_and_store_all_in_eeprom

	mov	Flash_Key_1, #0			; Initialize flash keys to invalid values
	mov	Flash_Key_2, #0

	setb	IE_EA

	jmp	dshot_cmd_exit


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; DShot beacon beep
;
; Beep with beacon strength
; Beep type 1-5 in Temp1
;
; Note: This routine switches off power
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
beacon_beep:
	clr	IE_EA					; Disable all interrupts
	call	switch_power_off			; Switch power off in case braking is set
	mov	Temp2, #Pgm_Beacon_Strength	; Set beacon beep strength
	mov	Beep_Strength, @Temp2

	cjne	Temp1, #1, beacon_beep2
	call	beep_f1
	sjmp	beacon_beep_exit

beacon_beep2:
	cjne	Temp1, #2, beacon_beep3
	call	beep_f2
	sjmp	beacon_beep_exit

beacon_beep3:
	cjne	Temp1, #3, beacon_beep4
	call	beep_f3
	sjmp	beacon_beep_exit

beacon_beep4:
	cjne	Temp1, #4, beacon_beep5
	call	beep_f4
	sjmp	beacon_beep_exit

beacon_beep5:
	call	beep_f5

beacon_beep_exit:
	mov	Temp2, #Pgm_Beep_Strength	; Set normal beep strength
	mov	Beep_Strength, @Temp2
	setb	IE_EA					; Enable all interrupts
	ret


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; DShot telemetry create packet
;
; Create DShot telemetry packet and prepare it for being sent
; The routine is divided into 6 sections that can return early
; in order to reduce commutation interference
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
dshot_tlm_create_packet:
	push	PSW
	mov	PSW, #10h					; Select register bank 2

	Early_Return_Packet_Stage 0

	; Read commutation period
	clr	IE_EA
	mov	Tlm_Data_L, Comm_Period4x_L
	mov	Tlm_Data_H, Comm_Period4x_H
	setb	IE_EA

	; Multiply period by 3/4 (1/2 + 1/4)
	mov	A, Tlm_Data_L
	mov	C, Tlm_Data_H.0
	rrc	A
	mov	Temp2, A
	mov	C, Tlm_Data_H.1
	rrc	A
	add	A, Temp2
	mov	Tlm_Data_L, A

	mov	A, Tlm_Data_H
	rr	A
	clr	ACC.7
	mov	Temp2, A
	rr	A
	clr	ACC.7
	addc	A, Temp2
	mov	Tlm_Data_H, A

	Early_Return_Packet_Stage 1
	mov	A, Tlm_Data_H

	; 12-bit encode telemetry data
	jnz	dshot_12bit_encode
	mov	A, Tlm_Data_L				; Already 12-bit
	jnz	dshot_tlm_12bit_encoded

	; If period is zero then reset to FFFFh (FFFh for 12-bit)
	mov	Tlm_Data_H, #0Fh
	mov	Tlm_Data_L, #0FFh

dshot_tlm_12bit_encoded:
	Early_Return_Packet_Stage 2
	mov	A, Tlm_Data_L

	; Compute inverted xor checksum (4-bit)
	swap	A
	xrl	A, Tlm_Data_L
	xrl	A, Tlm_Data_H
	cpl	A

	; GCR encode the telemetry data (16-bit)
	mov	Temp1, #Temp_Storage		; Store pulse timings in Temp_Storage
	mov	Tmp_B, DShot_GCR_Pulse_Time_1	; Final transition time

	call	dshot_gcr_encode			; GCR encode lowest 4-bit of A (store through Temp1)

	Early_Return_Packet_Stage 3

	mov	A, Tlm_Data_L
	call	dshot_gcr_encode

	Early_Return_Packet_Stage 4

	mov	A, Tlm_Data_L
	swap	A
	call	dshot_gcr_encode

	Early_Return_Packet_Stage 5

	mov	A, Tlm_Data_H
	call	dshot_gcr_encode

	Push_Mem	Temp1, Tmp_B			; Initial transition time

	mov	Temp5, #0
	setb	Flag_Telemetry_Pending

	pop	PSW
	ret


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; DShot 12-bit encode
;
; Encodes 16-bit e-period as a 12-bit value of the form:
; <e e e m m m m m m m m m> where M SHL E ~ e-period [us]
;
; Note: Not callable to improve performance
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
dshot_12bit_encode:
	; Encode 16-bit e-period as a 12-bit value
	jb	ACC.7, dshot_12bit_7		; ACC = Tlm_Data_H
	jb	ACC.6, dshot_12bit_6
	jb	ACC.5, dshot_12bit_5
	jb	ACC.4, dshot_12bit_4
	jb	ACC.3, dshot_12bit_3
	jb	ACC.2, dshot_12bit_2
	jb	ACC.1, dshot_12bit_1
	mov	A, Tlm_Data_L				; Already 12-bit (E=0)
	ajmp	dshot_tlm_12bit_encoded

dshot_12bit_7:
	;mov	A, Tlm_Data_H
	mov	C, Tlm_Data_L.7
	rlc	A
	mov	Tlm_Data_L, A
	mov	Tlm_Data_H, #0fh
	ajmp	dshot_tlm_12bit_encoded

dshot_12bit_6:
	;mov	A, Tlm_Data_H
	mov	C, Tlm_Data_L.7
	rlc	A
	mov	C, Tlm_Data_L.6
	rlc	A
	mov	Tlm_Data_L, A
	mov	Tlm_Data_H, #0dh
	ajmp	dshot_tlm_12bit_encoded

dshot_12bit_5:
	;mov	A, Tlm_Data_H
	mov	C, Tlm_Data_L.7
	rlc	A
	mov	C, Tlm_Data_L.6
	rlc	A
	mov	C, Tlm_Data_L.5
	rlc	A
	mov	Tlm_Data_L, A
	mov	Tlm_Data_H, #0bh
	ajmp	dshot_tlm_12bit_encoded

dshot_12bit_4:
	mov	A, Tlm_Data_L
	anl	A, #0f0h
	clr	Tlm_Data_H.4
	orl	A, Tlm_Data_H
	swap	A
	mov	Tlm_Data_L, A
	mov	Tlm_Data_H, #09h
	ajmp	dshot_tlm_12bit_encoded

dshot_12bit_3:
	mov	A, Tlm_Data_L
	mov	C, Tlm_Data_H.0
	rrc	A
	mov	C, Tlm_Data_H.1
	rrc	A
	mov	C, Tlm_Data_H.2
	rrc	A
	mov	Tlm_Data_L, A
	mov	Tlm_Data_H, #07h
	ajmp	dshot_tlm_12bit_encoded

dshot_12bit_2:
	mov	A, Tlm_Data_L
	mov	C, Tlm_Data_H.0
	rrc	A
	mov	C, Tlm_Data_H.1
	rrc	A
	mov	Tlm_Data_L, A
	mov	Tlm_Data_H, #05h
	ajmp	dshot_tlm_12bit_encoded

dshot_12bit_1:
	mov	A, Tlm_Data_L
	mov	C, Tlm_Data_H.0
	rrc	A
	mov	Tlm_Data_L, A
	mov	Tlm_Data_H, #03h
	ajmp	dshot_tlm_12bit_encoded


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; DShot GCR encode
;
; GCR encode e-period data for DShot telemetry
;
; Input
; - Temp1: Data pointer for storing pulse timings
; - A: 4-bit value to GCR encode
; - B: Time that must be added to transition
; Output
; - B: Time remaining to be added to next transition
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
dshot_gcr_encode:
	anl	A, #0Fh
	rl	A	; Multiply by 2 to match jump offsets
	mov	DPTR, #dshot_gcr_encode_jump_table
	jmp	@A+DPTR

dshot_gcr_encode_jump_table:
	ajmp	dshot_gcr_encode_0_11001
	ajmp	dshot_gcr_encode_1_11011
	ajmp	dshot_gcr_encode_2_10010
	ajmp	dshot_gcr_encode_3_10011
	ajmp	dshot_gcr_encode_4_11101
	ajmp	dshot_gcr_encode_5_10101
	ajmp	dshot_gcr_encode_6_10110
	ajmp	dshot_gcr_encode_7_10111
	ajmp	dshot_gcr_encode_8_11010
	ajmp	dshot_gcr_encode_9_01001
	ajmp	dshot_gcr_encode_A_01010
	ajmp	dshot_gcr_encode_B_01011
	ajmp	dshot_gcr_encode_C_11110
	ajmp	dshot_gcr_encode_D_01101
	ajmp	dshot_gcr_encode_E_01110
	ajmp	dshot_gcr_encode_F_01111

; GCR encoding is ordered by least significant bit first,
; and represented as pulse durations.
dshot_gcr_encode_0_11001:
	Push_Mem	Temp1, Tmp_B
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_3
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_1
	mov	Tmp_B, DShot_GCR_Pulse_Time_1
	ret

dshot_gcr_encode_1_11011:
	Push_Mem	Temp1, Tmp_B
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_1
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_2
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_1
	mov	Tmp_B, DShot_GCR_Pulse_Time_1
	ret

dshot_gcr_encode_2_10010:
	DShot_GCR_Get_Time
	Push_Mem	Temp1, A
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_3
	mov	Tmp_B, DShot_GCR_Pulse_Time_1
	ret

dshot_gcr_encode_3_10011:
	Push_Mem	Temp1, Tmp_B
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_1
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_3
	mov	Tmp_B, DShot_GCR_Pulse_Time_1
	ret

dshot_gcr_encode_4_11101:
	Push_Mem	Temp1, Tmp_B
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_2
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_1
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_1
	mov	Tmp_B, DShot_GCR_Pulse_Time_1
	ret

dshot_gcr_encode_5_10101:
	Push_Mem	Temp1, Tmp_B
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_2
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_2
	mov	Tmp_B, DShot_GCR_Pulse_Time_1
	ret

dshot_gcr_encode_6_10110:
	DShot_GCR_Get_Time
	Push_Mem	Temp1, A
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_1
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_2
	mov	Tmp_B, DShot_GCR_Pulse_Time_1
	ret

dshot_gcr_encode_7_10111:
	Push_Mem	Temp1, Tmp_B
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_1
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_1
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_2
	mov	Tmp_B, DShot_GCR_Pulse_Time_1
	ret

dshot_gcr_encode_8_11010:
	DShot_GCR_Get_Time
	Push_Mem	Temp1, A
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_2
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_1
	mov	Tmp_B, DShot_GCR_Pulse_Time_1
	ret

dshot_gcr_encode_9_01001:
	Push_Mem	Temp1, Tmp_B
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_3
	mov	Tmp_B, DShot_GCR_Pulse_Time_2
	ret

dshot_gcr_encode_A_01010:
	DShot_GCR_Get_Time
	Push_Mem	Temp1, A
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_2
	mov	Tmp_B, DShot_GCR_Pulse_Time_2
	ret

dshot_gcr_encode_B_01011:
	Push_Mem	Temp1, Tmp_B
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_1
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_2
	mov	Tmp_B, DShot_GCR_Pulse_Time_2
	ret

dshot_gcr_encode_C_11110:
	DShot_GCR_Get_Time
	Push_Mem	Temp1, A
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_1
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_1
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_1
	mov	Tmp_B, DShot_GCR_Pulse_Time_1
	ret

dshot_gcr_encode_D_01101:
	Push_Mem	Temp1, Tmp_B
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_2
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_1
	mov	Tmp_B, DShot_GCR_Pulse_Time_2
	ret

dshot_gcr_encode_E_01110:
	DShot_GCR_Get_Time
	Push_Mem	Temp1, A
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_1
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_1
	mov	Tmp_B, DShot_GCR_Pulse_Time_2
	ret

dshot_gcr_encode_F_01111:
	Push_Mem	Temp1, Tmp_B
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_1
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_1
	Push_Mem	Temp1, DShot_GCR_Pulse_Time_1
	mov	Tmp_B, DShot_GCR_Pulse_Time_2
	ret



;**** **** **** **** **** **** **** **** **** **** **** **** ****
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; ESC programming (EEPROM emulation)
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;**** **** **** **** **** **** **** **** **** **** **** **** ****


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Read all eeprom parameters routine
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
read_all_eeprom_parameters:
	; Check initialized signature
	mov	DPTR, #Eep_Initialized_L
	mov	Temp1, #Bit_Access
	call	read_eeprom_byte
	mov	A, Bit_Access
	cjne	A, #055h, read_eeprom_store_defaults
	inc	DPTR						; Now Eep_Initialized_H
	call	read_eeprom_byte
	mov	A, Bit_Access
	cjne	A, #0AAh, read_eeprom_store_defaults
	jmp	read_eeprom_read

read_eeprom_store_defaults:
	mov	Flash_Key_1, #0A5h
	mov	Flash_Key_2, #0F1h
	call	set_default_parameters
	call	erase_and_store_all_in_eeprom
	mov	Flash_Key_1, #0
	mov	Flash_Key_2, #0
	jmp	read_eeprom_exit

read_eeprom_read:
	; Read eeprom
	mov	DPTR, #_Eep_Pgm_Gov_P_Gain
	mov	Temp1, #_Pgm_Gov_P_Gain
	mov	Temp4, #10				; 10 parameters
read_eeprom_block1:
	call	read_eeprom_byte
	inc	DPTR
	inc	Temp1
	djnz	Temp4, read_eeprom_block1

	mov	DPTR, #_Eep_Enable_TX_Program
	mov	Temp1, #_Pgm_Enable_TX_Program
	mov	Temp4, #26				; 26 parameters
read_eeprom_block2:
	call	read_eeprom_byte
	inc	DPTR
	inc	Temp1
	djnz	Temp4, read_eeprom_block2

	mov	DPTR, #Eep_Dummy			; Set pointer to uncritical area

read_eeprom_exit:
	ret


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Erase flash and store all parameter value in EEPROM routine
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
erase_and_store_all_in_eeprom:
	clr	IE_EA					; Disable interrupts
	call	read_tags
	call	erase_flash				; Erase flash

	mov	DPTR, #Eep_FW_Main_Revision	; Store firmware main revision
	mov	A, #EEPROM_FW_MAIN_REVISION
	call	write_eeprom_byte_from_acc

	inc	DPTR						; Now firmware sub revision
	mov	A, #EEPROM_FW_SUB_REVISION
	call	write_eeprom_byte_from_acc

	inc	DPTR						; Now layout revision
	mov	A, #EEPROM_LAYOUT_REVISION
	call	write_eeprom_byte_from_acc

	; Write eeprom
	mov	DPTR, #_Eep_Pgm_Gov_P_Gain
	mov	Temp1, #_Pgm_Gov_P_Gain
	mov	Temp4, #10				; 10 parameters
write_eeprom_block1:
	call	write_eeprom_byte
	inc	DPTR
	inc	Temp1
	djnz	Temp4, write_eeprom_block1

	mov	DPTR, #_Eep_Enable_TX_Program
	mov	Temp1, #_Pgm_Enable_TX_Program
	mov	Temp4, #26				; 26 parameters
write_eeprom_block2:
	call	write_eeprom_byte
	inc	DPTR
	inc	Temp1
	djnz	Temp4, write_eeprom_block2

	call	write_tags
	call	write_eeprom_signature
	mov	DPTR, #Eep_Dummy			; Set pointer to uncritical area
	ret


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Read eeprom byte routine
;
; Gives data in A and in address given by Temp1. Assumes address in DPTR
; Also assumes address high byte to be zero
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
read_eeprom_byte:
	clr	A
	movc	A, @A+DPTR				; Read from flash
	mov	@Temp1, A
	ret


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Write eeprom byte routine
;
; Assumes data in address given by Temp1, or in accumulator. Assumes address in DPTR
; Also assumes address high byte to be zero
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
write_eeprom_byte:
	mov	A, @Temp1
write_eeprom_byte_from_acc:
	orl	PSCTL, #01h				; Set the PSWE bit
	anl	PSCTL, #0FDh				; Clear the PSEE bit
	mov	Temp8, A
	clr	C
	mov	A, DPH					; Check that address is not in bootloader area
	subb	A, #1Ch
	jc	($+3)

	ret

	mov	A, Temp8
	mov	FLKEY, Flash_Key_1			; First key code
	mov	FLKEY, Flash_Key_2			; Second key code
	movx	@DPTR, A					; Write to flash
	anl	PSCTL, #0FEh				; Clear the PSWE bit
	ret


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Erase flash routine (erases the flash segment used for "eeprom" variables)
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
erase_flash:
	orl	PSCTL, #02h				; Set the PSEE bit
	orl	PSCTL, #01h				; Set the PSWE bit
	mov	FLKEY, Flash_Key_1			; First key code
	mov	FLKEY, Flash_Key_2			; Second key code
	mov	DPTR, #Eep_Initialized_L
	movx	@DPTR, A
	anl	PSCTL, #0FCh				; Clear the PSEE and PSWE bits
	ret


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Write eeprom signature routine
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
write_eeprom_signature:
	mov	DPTR, #Eep_Initialized_L
	mov	A, #055h
	call	write_eeprom_byte_from_acc

	mov	DPTR, #Eep_Initialized_H
	mov	A, #0AAh
	call	write_eeprom_byte_from_acc
	ret


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Read all tags from flash and store in temporary storage
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
read_tags:
	mov	Temp3, #48				; Number of tags
	mov	Temp2, #Temp_Storage		; Set RAM address
	mov	Temp1, #Bit_Access
	mov	DPTR, #Eep_ESC_Layout		; Set flash address
read_tag:
	call	read_eeprom_byte
	mov	A, Bit_Access
	mov	@Temp2, A					; Write to RAM
	inc	Temp2
	inc	DPTR
	djnz Temp3, read_tag
	ret


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Write all tags from temporary storage and store in flash
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
write_tags:
	mov	Temp3, #48				; Number of tags
	mov	Temp2, #Temp_Storage		; Set RAM address
	mov	DPTR, #Eep_ESC_Layout		; Set flash address
write_tag:
	mov	A, @Temp2					; Read from RAM
	call	write_eeprom_byte_from_acc
	inc	Temp2
	inc	DPTR
	djnz Temp3, write_tag
	ret



;**** **** **** **** **** **** **** **** **** **** **** **** ****
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Settings
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;**** **** **** **** **** **** **** **** **** **** **** **** ****


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Set default parameters
;
; Sets default programming parameters
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
set_default_parameters:
	mov	Temp1, #_Pgm_Gov_P_Gain
	Push_Mem	Temp1, #0FFh						; _Pgm_Gov_P_Gain
	Push_Mem	Temp1, #0FFh						; _Pgm_Gov_I_Gain
	Push_Mem	Temp1, #0FFh						; _Pgm_Gov_Mode
	Push_Mem	Temp1, #0FFh						; _Pgm_Low_Voltage_Lim
	Push_Mem	Temp1, #0FFh						; _Pgm_Motor_Gain
	Push_Mem	Temp1, #0FFh						; _Pgm_Motor_Idle
	Push_Mem	Temp1, #DEFAULT_PGM_STARTUP_PWR		; Pgm_Startup_Pwr
	Push_Mem	Temp1, #0FFh						; _Pgm_Pwm_Freq
	Push_Mem	Temp1, #DEFAULT_PGM_DIRECTION			; Pgm_Direction
	Push_Mem	Temp1, #0FFh						; _Pgm_Input_Pol

	inc	Temp1								; Skip Initialized_L_Dummy
	inc	Temp1								; Skip Initialized_H_Dummy

	Push_Mem	Temp1, #0FFh						; _Pgm_Enable_TX_Program
	Push_Mem	Temp1, #0FFh						; _Pgm_Main_Rearm_Start
	Push_Mem	Temp1, #0FFh						; _Pgm_Gov_Setup_Target
	Push_Mem	Temp1, #0FFh						; _Pgm_Startup_Rpm
	Push_Mem	Temp1, #0FFh						; _Pgm_Startup_Accel
	Push_Mem	Temp1, #0FFh						; _Pgm_Volt_Comp
	Push_Mem	Temp1, #DEFAULT_PGM_COMM_TIMING		; Pgm_Comm_Timing
	Push_Mem	Temp1, #0FFh						; _Pgm_Damping_Force
	Push_Mem	Temp1, #0FFh						; _Pgm_Gov_Range
	Push_Mem	Temp1, #0FFh						; _Pgm_Startup_Method
	Push_Mem	Temp1, #0FFh						; _Pgm_Min_Throttle
	Push_Mem	Temp1, #0FFh						; _Pgm_Max_Throttle
	Push_Mem	Temp1, #DEFAULT_PGM_BEEP_STRENGTH		; Pgm_Beep_Strength
	Push_Mem	Temp1, #DEFAULT_PGM_BEACON_STRENGTH	; Pgm_Beacon_Strength
	Push_Mem	Temp1, #DEFAULT_PGM_BEACON_DELAY		; Pgm_Beacon_Delay
	Push_Mem	Temp1, #0FFh						; _Pgm_Throttle_Rate
	Push_Mem	Temp1, #DEFAULT_PGM_DEMAG_COMP		; Pgm_Demag_Comp
	Push_Mem	Temp1, #0FFh						; _Pgm_BEC_Voltage_High
	Push_Mem	Temp1, #0FFh						; _Pgm_Center_Throttle
	Push_Mem	Temp1, #0FFh						; _Pgm_Main_Spoolup_Time
	Push_Mem	Temp1, #DEFAULT_PGM_ENABLE_TEMP_PROT	; Pgm_Enable_Temp_Prot
	Push_Mem	Temp1, #DEFAULT_PGM_ENABLE_POWER_PROT	; Pgm_Enable_Power_Prot
	Push_Mem	Temp1, #0FFh						; _Pgm_Enable_Pwm_Input
	Push_Mem	Temp1, #0FFh						; _Pgm_Pwm_Dither
	Push_Mem	Temp1, #DEFAULT_PGM_BRAKE_ON_STOP		; Pgm_Brake_On_Stop
	Push_Mem	Temp1, #DEFAULT_PGM_LED_CONTROL		; Pgm_LED_Control

	ret


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Decode settings
;
; Decodes various settings
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
decode_settings:
	; Load programmed direction
	mov	Temp1, #Pgm_Direction
	mov	A, @Temp1
	clr	C
	subb	A, #3
	setb	Flag_Pgm_Bidir
	jnc	($+4)

	clr	Flag_Pgm_Bidir

	clr	Flag_Pgm_Dir_Rev
	mov	A, @Temp1
	jnb	ACC.1, ($+5)
	setb	Flag_Pgm_Dir_Rev
	mov	C, Flag_Pgm_Dir_Rev
	mov	Flag_Pgm_Bidir_Rev, C
	; Decode startup power
	mov	Temp1, #Pgm_Startup_Pwr
	mov	A, @Temp1
	dec	A
	mov	DPTR, #STARTUP_POWER_TABLE
	movc	A, @A+DPTR
	mov	Temp1, #Pgm_Startup_Pwr_Decoded
	mov	@Temp1, A
	; Decode low rpm power slope
	mov	Temp1, #Pgm_Startup_Pwr
	mov	A, @Temp1
	mov	Low_Rpm_Pwr_Slope, A
	clr	C
	subb	A, #2
	jnc	($+5)
	mov	Low_Rpm_Pwr_Slope, #2
	; Decode demag compensation
	mov	Temp1, #Pgm_Demag_Comp
	mov	A, @Temp1
	mov	Demag_Pwr_Off_Thresh, #255	; Set default

	cjne	A, #2, decode_demag_high

	mov	Demag_Pwr_Off_Thresh, #160	; Settings for demag comp low

decode_demag_high:
	cjne	A, #3, decode_demag_done

	mov	Demag_Pwr_Off_Thresh, #130	; Settings for demag comp high

decode_demag_done:
	; Decode temperature protection limit
	mov	Temp1, #Pgm_Enable_Temp_Prot
	mov	A, @Temp1
	mov	Temp1, A
	jz	decode_temp_done

	mov	A, #(TEMP_LIMIT-TEMP_LIMIT_STEP)
decode_temp_step:
	add	A, #TEMP_LIMIT_STEP
	djnz	Temp1, decode_temp_step

decode_temp_done:
	mov	Temp_Prot_Limit, A

	; Initialize pwm dithering bit patterns
IF PWM_BITS_H == 1
	mov	Temp1, #Dithering_Patterns
	Push_Mem	Temp1, #00h
	Push_Mem	Temp1, #55h
ELSEIF PWM_BITS_H == 0
	mov	Temp1, #Dithering_Patterns
	Push_Mem	Temp1, #00h
	Push_Mem	Temp1, #11h
	Push_Mem	Temp1, #55h
	Push_Mem	Temp1, #77h
ENDIF
	ret



;**** **** **** **** **** **** **** **** **** **** **** **** ****
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Main program
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;**** **** **** **** **** **** **** **** **** **** **** **** ****


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Main program entry point
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
pgm_start:
	mov	Flash_Key_1, #0			; Initialize flash keys to invalid values
	mov	Flash_Key_2, #0
	mov	WDTCN, #0DEh				; Disable watchdog (WDT)
	mov	WDTCN, #0ADh
	mov	SP, #Stack				; Initialize stack (16 bytes of indirect RAM)
	orl	VDM0CN, #080h				; Enable the VDD monitor
	mov	RSTSRC, #06h				; Set missing clock and VDD monitor as a reset source if not 1S capable
	mov	CLKSEL, #00h				; Set clock divider to 1 (Oscillator 0 at 24MHz)
	call	switch_power_off
	; Ports initialization
	mov	P0, #P0_INIT
	mov	P0MDIN, #P0_DIGITAL
	mov	P0MDOUT, #P0_PUSHPULL
	mov	P0, #P0_INIT
	mov	P0SKIP, #P0_SKIP
	mov	P1, #P1_INIT
	mov	P1MDIN, #P1_DIGITAL
	mov	P1MDOUT, #P1_PUSHPULL
	mov	P1, #P1_INIT
	mov	P1SKIP, #P1_SKIP
	mov	P2MDOUT, #P2_PUSHPULL
	Initialize_Xbar				; Initialize the XBAR and related functionality
	call	switch_power_off			; Switch power off again, after initializing ports

	; Clear RAM
	clr	A						; Clear accumulator
	mov	Temp1, A					; Clear Temp1
	clear_ram:
	mov	@Temp1, A					; Clear RAM address
	djnz	Temp1, clear_ram			; Decrement address and repeat

	call	set_default_parameters		; Set default programmed parameters
	call	read_all_eeprom_parameters	; Read all programmed parameters
	mov	Temp1, #Pgm_Beep_Strength	; Read programmed beep strength
	mov	Beep_Strength, @Temp1		; Set beep strength
	; Initializing beeps
	clr	IE_EA					; Disable interrupts explicitly
	call	wait100ms
	call	beep_f1
	call	wait5ms
	call	beep_f2
	call	wait5ms
	call	beep_f1
	call	wait5ms
	call	beep_f3
	call	wait200ms
	call	beep_f2
	call	beep_f4
	call	beep_f4

	call	led_control				; Set LEDs to programmed values

	call	wait250ms					; Wait for flight controller to get ready
	call	wait250ms

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; No signal entry point
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
init_no_signal:
	clr	IE_EA					; Disable interrupts explicitly
	mov	Flash_Key_1, #0			; Initialize flash keys to invalid values
	mov	Flash_Key_2, #0

	mov	Temp1, #250				; Check if input signal is high for more than 15ms
input_high_check_1:
	mov	Temp2, #250
input_high_check_2:
	jnb	RTX_PORT.RTX_PIN, bootloader_done	; Look for low
	djnz	Temp2, input_high_check_2
	djnz	Temp1, input_high_check_1

	ljmp	1C00h					; Jump to bootloader

bootloader_done:
	call	decode_settings
	mov	Temp1, #Pgm_Beep_Strength	; Set beep strength
	mov	Beep_Strength, @Temp1
	call	switch_power_off
IF MCU_48MHZ == 1
	Set_MCU_Clk_24MHz				; Set clock frequency
ENDIF
	; Setup timers for DShot
	mov	TCON, #51h				; Timer 0/1 run and INT0 edge triggered
	mov	CKCON0, #01h				; Timer 0/1 clock is system clock divided by 4 (for DShot150)
	mov	TMOD, #0AAh				; Timer 0/1 set to 8bits auto reload and gated by INT0/1
	mov	TH0, #0					; Auto reload value zero
	mov	TH1, #0

	mov	TMR2CN0, #04h				; Timer 2 enabled (system clock divided by 12)
	mov	TMR3CN0, #04h				; Timer 3 enabled (system clock divided by 12)

	Initialize_PCA					; Initialize PCA
	Set_Pwm_Polarity				; Set pwm polarity
	Enable_Power_Pwm_Module			; Enable power pwm module
	Enable_Damp_Pwm_Module			; Enable damping pwm module
	Initialize_Comparator			; Initialize comparator
	Initialize_Adc					; Initialize ADC operation
	call	wait1ms

	mov	Startup_Stall_Cnt, #0		; Reset stall count

	mov	DShot_Cmd, #0				; Clear DShot command
	mov	DShot_Cmd_Cnt, #0			; Clear DShot command count

	call	detect_rcp_level			; Detect RCP level (normal or inverted DShot)

	; Route RCP according to detected DShot signal (normal or inverted)
	mov	IT01CF, #(80h + (RTX_PIN SHL 4) + RTX_PIN) ; Route RCP input to INT0/1, with INT1 inverted
	jnb	Flag_Rcp_DShot_Inverted, ($+6)
	mov	IT01CF, #(08h + (RTX_PIN SHL 4) + RTX_PIN) ; Route RCP input to INT0/1, with INT0 inverted

	; Setup interrupts for DShot
	mov	IE, #2Dh					; Enable timer 1/2 interrupts and INT0/1 interrupts
	mov	EIE1, #90h				; Enable timer 3 and PCA0 interrupts
	mov	IP, #03h					; High priority to timer 0 and INT0 interrupts

	setb	IE_EA					; Enable all interrupts

	; Setup variables for DShot150
	; TODO: dshot150 not supported for now
; IF MCU_48MHZ == 1
; 	mov	DShot_Timer_Preset, #128		; Load DShot sync timer preset (for DShot150)
; ELSE
; 	mov	DShot_Timer_Preset, #192
; ENDIF
; 	; TODO: we cannot currently support DShot150 on 48MHz (because of DShot_Frame_Length_Thr)
; IF MCU_48MHZ == 0
; 	mov	DShot_Pwm_Thr, #10			; Load DShot qualification pwm threshold (for DShot150)
; 	mov	DShot_Frame_Length_Thr, #160	; Load DShot frame length criteria

; 	Set_DShot_Tlm_Bitrate	187500	; = 5/4 * 150000

; 	; Test whether signal is DShot150
; 	mov	Rcp_Outside_Range_Cnt, #10	; Set out of range counter
; 	call	wait100ms					; Wait for new RC pulse
; 	mov	DShot_Pwm_Thr, #8			; Load DShot regular pwm threshold
; 	clr	C
; 	mov	A, Rcp_Outside_Range_Cnt		; Check if pulses were accepted
; 	subb	A, #10
; 	mov	DShot_Cmd, #0
; 	mov	DShot_Cmd_Cnt, #0
; 	jc	arming_begin
; ENDIF

	mov	CKCON0, #0Ch				; Timer 0/1 clock is system clock (for DShot300/600)

	; Setup variables for DShot300
	mov	DShot_Timer_Preset, #128		; Load DShot sync timer preset (for DShot300)
	mov	DShot_Pwm_Thr, #16			; Load DShot pwm threshold (for DShot300)
	mov	DShot_Frame_Length_Thr, #80	; Load DShot frame length criteria

	Set_DShot_Tlm_Bitrate	375000	; = 5/4 * 300000

	; Test whether signal is DShot300
	mov	Rcp_Outside_Range_Cnt, #10	; Set out of range counter
	call	wait100ms					; Wait for new RC pulse
	mov	A, Rcp_Outside_Range_Cnt		; Check if pulses were accepted
	mov	DShot_Cmd, #0
	mov	DShot_Cmd_Cnt, #0
	jz	arming_begin

	; Setup variables for DShot600
	mov	DShot_Timer_Preset, #192		; Load DShot sync timer preset (for DShot600)
	mov	DShot_Pwm_Thr, #8			; Load DShot pwm threshold (for DShot600)
	mov	DShot_Frame_Length_Thr, #40	; Load DShot frame length criteria

	Set_DShot_Tlm_Bitrate	750000	; = 5/4 * 600000

	; Test whether signal is DShot600
	mov	Rcp_Outside_Range_Cnt, #10	; Set out of range counter
	call	wait100ms					; Wait for new RC pulse
	mov	A, Rcp_Outside_Range_Cnt		; Check if pulses were accepted
	mov	DShot_Cmd, #0
	mov	DShot_Cmd_Cnt, #0
	jz	arming_begin

	ljmp	init_no_signal

arming_begin:
	clr	IE_EA
	call	beep_f1_short				; Beep signal that RC pulse is ready
	setb	IE_EA

arming_wait:
	call	wait100ms
	jnb	Flag_Rcp_Stop, arming_wait	; Wait until throttle is zero

	clr	IE_EA
	call	beep_f2_short				; Beep signal that ESC is armed
	setb	IE_EA

wait_for_power_on:					; Armed and waiting for power on
	clr	A
	mov	Comm_Period4x_L, A			; Reset commutation period for telemetry
	mov	Comm_Period4x_H, A
	mov	Power_On_Wait_Cnt_L, A		; Clear beacon wait counter
	mov	Power_On_Wait_Cnt_H, A

wait_for_power_on_loop:
	inc	Power_On_Wait_Cnt_L			; Increment low wait counter
	mov	A, Power_On_Wait_Cnt_L
	cpl	A
	jnz	wait_for_power_on_no_beep	; Counter wrapping (about 3 sec)

	inc	Power_On_Wait_Cnt_H			; Increment high wait counter
	mov	Temp1, #Pgm_Beacon_Delay
	mov	A, @Temp1
	mov	Temp1, #20				; 1 min
	dec	A
	jz	beep_delay_set

	mov	Temp1, #40				; 2 min
	dec	A
	jz	beep_delay_set

	mov	Temp1, #100				; 5 min
	dec	A
	jz	beep_delay_set

	mov	Temp1, #200				; 10 min
	dec	A
	jz	beep_delay_set

	mov	Power_On_Wait_Cnt_H, #0		; Reset counter for infinite delay

beep_delay_set:
	clr	C
	mov	A, Power_On_Wait_Cnt_H
	subb	A, Temp1					; Check against chosen delay
	jc	wait_for_power_on_no_beep	; Has delay elapsed?

	dec	Power_On_Wait_Cnt_H			; Decrement high wait counter for continued beeping

	mov	Temp1, #4					; Beep tone 4
	call	beacon_beep

wait_for_power_on_no_beep:
	jb	Flag_Telemetry_Pending, wait_for_power_telemetry_done
	setb	Flag_Timer3_Pending			; Set flag to avoid early return
	call	dshot_tlm_create_packet		; Create telemetry packet (0 rpm)

wait_for_power_telemetry_done:
	call	wait10ms
	mov	A, Rcp_Timeout_Cntd			; Load RC pulse timeout counter value
	jnz	wait_for_power_on_not_missing	; If it is not zero - proceed

	ljmp	init_no_signal				; If pulses missing - go back to detect input signal

wait_for_power_on_not_missing:
	jnb	Flag_Rcp_Stop,	wait_for_power_on_nonzero	; Higher than stop, Yes - proceed

	mov	A, DShot_Cmd
	jz	wait_for_power_on_loop		; Check DShot command if not zero, otherwise wait for power

	call	dshot_cmd_check
	sjmp	wait_for_power_on_not_missing	; Check DShot command again, in case it needs to be received multiple times

wait_for_power_on_nonzero:
	call	wait100ms					; Wait to see if start pulse was only a glitch

	mov	DShot_Cmd, #0				; Reset DShot command
	mov	DShot_Cmd_Cnt, #0

	mov	A, Rcp_Timeout_Cntd			; Load RC pulse timeout counter value
	jnz	init_start				; If it is not zero - proceed

	ljmp	init_no_signal				; If it is zero (pulses missing) - go back to detect input signal


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Motor start entry point
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
init_start:
	clr	IE_EA					; Disable interrupts
	call	switch_power_off
	setb	IE_EA					; Enable interrupts

	clr	A
	mov	Flags1, A					; Clear flags1
	mov	Flags_Startup, A			; Clear startup flags
	mov	Demag_Detected_Metric, A		; Clear demag metric

	call	wait1ms

	; Read initial average temperature
	Start_Adc						; Start adc conversion

	jnb	ADC0CN0_ADINT, $			; Wait for adc conversion to complete

	Read_Adc_Result				; Read initial temperature
	mov	A, Temp2
	jnz	($+3)					; Is reading below 256?
	mov	Temp1, A					; Yes - set average temperature value to zero

	mov	Current_Average_Temp, Temp1	; Set initial average temperature

	mov	Adc_Conversion_Cnt, #8		; Make sure a temp reading is done
	call	check_temp_and_limit_power
	mov	Adc_Conversion_Cnt, #8		; Make sure a temp reading is done next time

	; Set up start operating conditions
	clr	IE_EA					; Disable interrupts
	mov	Temp2, #Pgm_Startup_Pwr_Decoded
	mov	Pwm_Limit_Beg, @Temp2		; Set initial pwm limit
	mov	Pwm_Limit, Pwm_Limit_Beg
	mov	Pwm_Limit_By_Rpm, Pwm_Limit_Beg
	setb	IE_EA					; Enable interrupts

	; Begin startup sequence
IF MCU_48MHZ == 1
	Set_MCU_Clk_48MHz

	; Scale DShot criteria for 48MHz
	clr	C
	rlca	DShot_Timer_Preset			; Scale sync timer preset

	clr	C
	rlca	DShot_Frame_Length_Thr		; Scale frame length criteria

	clr	C
	rlca	DShot_Pwm_Thr				; Scale pulse width criteria

	; Scale DShot telemetry for 24MHz
	xcha	DShot_GCR_Pulse_Time_1, DShot_GCR_Pulse_Time_1_Tmp
	xcha	DShot_GCR_Pulse_Time_2, DShot_GCR_Pulse_Time_2_Tmp
	xcha	DShot_GCR_Pulse_Time_3, DShot_GCR_Pulse_Time_3_Tmp

	mov	DShot_GCR_Start_Delay, #DSHOT_TLM_START_DELAY_48
ENDIF
	jnb	Flag_Pgm_Bidir, init_start_bidir_done	; Check if bidirectional operation

	clr	Flag_Pgm_Dir_Rev			; Set spinning direction. Default fwd
	jnb	Flag_Rcp_Dir_Rev, ($+5)		; Check force direction
	setb	Flag_Pgm_Dir_Rev			; Set spinning direction

;**** **** **** **** ****
; Motor start beginning
init_start_bidir_done:
	setb	Flag_Startup_Phase			; Set startup phase flag
	mov	Startup_Cnt, #0			; Reset counter
	call	comm5_comm6				; Initialize commutation
	call	comm6_comm1
	call	initialize_timing			; Initialize timing
	call	calc_next_comm_timing		; Set virtual commutation point
	call	initialize_timing			; Initialize timing
	call	calc_next_comm_timing
	call	initialize_timing			; Initialize timing



;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Run entry point
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****

; Run 1 = B(p-on) + C(n-pwm) - comparator A evaluated
; Out_cA changes from low to high
run1:
	call	wait_for_comp_out_high		; Wait for high
;		setup_comm_wait			; Setup wait time from zero cross to commutation
;		evaluate_comparator_integrity	; Check whether comparator reading has been normal
	call	wait_for_comm				; Wait from zero cross to commutation
	call	comm1_comm2				; Commutate
	call	calc_next_comm_timing		; Calculate next timing and wait advance timing wait
;		wait_advance_timing			; Wait advance timing and start zero cross wait
;		calc_new_wait_times
;		wait_before_zc_scan			; Wait zero cross wait and start zero cross timeout

; Run 2 = A(p-on) + C(n-pwm) - comparator B evaluated
; Out_cB changes from high to low
run2:
	call	wait_for_comp_out_low
;		setup_comm_wait
;		evaluate_comparator_integrity
	call	set_pwm_limit				; Set pwm power limit for low or high rpm
	call	wait_for_comm
	call	comm2_comm3
	call	calc_next_comm_timing
;		wait_advance_timing
;		calc_new_wait_times
;		wait_before_zc_scan

; Run 3 = A(p-on) + B(n-pwm) - comparator C evaluated
; Out_cC changes from low to high
run3:
	call	wait_for_comp_out_high
;		setup_comm_wait
;		evaluate_comparator_integrity
	call	wait_for_comm
	call	comm3_comm4
	call	calc_next_comm_timing
;		wait_advance_timing
;		calc_new_wait_times
;		wait_before_zc_scan

; Run 4 = C(p-on) + B(n-pwm) - comparator A evaluated
; Out_cA changes from high to low
run4:
	call	wait_for_comp_out_low
;		setup_comm_wait
;		evaluate_comparator_integrity
	call	wait_for_comm
	call	comm4_comm5
	call	calc_next_comm_timing
;		wait_advance_timing
;		calc_new_wait_times
;		wait_before_zc_scan

; Run 5 = C(p-on) + A(n-pwm) - comparator B evaluated
; Out_cB changes from low to high
run5:
	call	wait_for_comp_out_high
;		setup_comm_wait
;		evaluate_comparator_integrity
	call	wait_for_comm
	call	comm5_comm6
	call	calc_next_comm_timing
;		wait_advance_timing
;		calc_new_wait_times
;		wait_before_zc_scan

; Run 6 = B(p-on) + A(n-pwm) - comparator C evaluated
; Out_cC changes from high to low
run6:
	Start_Adc						; Start adc conversion
	call	wait_for_comp_out_low
;		setup_comm_wait
;		evaluate_comparator_integrity
	call	wait_for_comm
	call	comm6_comm1
	call	check_temp_and_limit_power
	call	calc_next_comm_timing
;		wait_advance_timing
;		calc_new_wait_times
;		wait_before_zc_scan

	; Check if it is direct startup
	jnb	Flag_Startup_Phase, normal_run_checks

	; Set spoolup power variables
	mov	Pwm_Limit, Pwm_Limit_Beg		; Set initial max power
	; Check startup counter
	mov	Temp2, #24				; Set nominal startup parameters
	mov	Temp3, #12
	clr	C
	mov	A, Startup_Cnt				; Load counter
	subb	A, Temp2					; Is counter above requirement?
	jc	direct_start_check_rcp		; No - proceed

	clr	Flag_Startup_Phase			; Clear startup phase flag
	setb	Flag_Initial_Run_Phase		; Set initial run phase flag
	mov	Initial_Run_Rot_Cntd, Temp3	; Set initial run rotation count
	mov	Pwm_Limit, Pwm_Limit_Beg
	mov	Pwm_Limit_By_Rpm, Pwm_Limit_Beg
	sjmp	normal_run_checks

direct_start_check_rcp:
	jnb	Flag_Rcp_Stop, run1			; If pulse is above stop value - Continue to run

	ajmp	run_to_wait_for_power_on


normal_run_checks:
	; Check if it is initial run phase
	jnb	Flag_Initial_Run_Phase, initial_run_phase_done	; If not initial run phase - branch
	jb	Flag_Dir_Change_Brake, initial_run_phase_done	; If a direction change - branch

	; Decrement startup rotation count
	mov	A, Initial_Run_Rot_Cntd
	dec	A
	; Check number of initial rotations
	jnz	initial_run_check_startup_rot	; Branch if counter is not zero

	clr	Flag_Initial_Run_Phase		; Clear initial run phase flag
	setb	Flag_Motor_Started			; Set motor started
	jmp	run1						; Continue with normal run

initial_run_check_startup_rot:
	mov	Initial_Run_Rot_Cntd, A		; Not zero - store counter

	jb	Flag_Pgm_Bidir, initial_run_continue_run	; Check if bidirectional operation

	jb	Flag_Rcp_Stop,	run_to_wait_for_power_on		; Check if pulse is below stop value

initial_run_continue_run:
	jmp	run1						; Continue to run

initial_run_phase_done:
	; Reset stall count
	mov	Startup_Stall_Cnt, #0
	setb	Flag_Motor_Running

	; Exit run loop after a given time
	jb	Flag_Pgm_Bidir, run6_check_timeout	; Check if bidirectional operation

	mov	Temp1, #250
	mov	Temp2, #Pgm_Brake_On_Stop
	mov	A, @Temp2
	jz	($+4)

	mov	Temp1, #3					; About 100ms before stopping when brake is set

	clr	C
	mov	A, Rcp_Stop_Cnt			; Load stop RC pulse counter low byte value
	subb	A, Temp1					; Is number of stop RC pulses above limit?
	jnc	run_to_wait_for_power_on		; Yes, go back to wait for power on

run6_check_timeout:
	mov	A, Rcp_Timeout_Cntd			; Load RC pulse timeout counter value
	jz	run_to_wait_for_power_on		; If it is zero - go back to wait for power on

run6_check_dir:
	jnb	Flag_Pgm_Bidir, run6_check_speed		; Check if bidirectional operation

	jb	Flag_Pgm_Dir_Rev, run6_check_dir_rev	; Check if actual rotation direction
	jb	Flag_Rcp_Dir_Rev, run6_check_dir_change	; Matches force direction
	sjmp	run6_check_speed

run6_check_dir_rev:
	jnb	Flag_Rcp_Dir_Rev, run6_check_dir_change
	sjmp	run6_check_speed

run6_check_dir_change:
	jb	Flag_Dir_Change_Brake, run6_check_speed

	setb	Flag_Dir_Change_Brake		; Set brake flag
	mov	Pwm_Limit, Pwm_Limit_Beg		; Set max power while braking
	jmp	run4						; Go back to run 4, thereby changing force direction

run6_check_speed:
	mov	Temp1, #0F0h				; Default minimum speed
	jnb	Flag_Dir_Change_Brake, run6_brake_done; Is it a direction change?

	mov	Pwm_Limit, Pwm_Limit_Beg		; Set max power while braking
	mov	Temp1, #20h				; Bidirectional braking termination speed

run6_brake_done:
	clr	C
	mov	A, Comm_Period4x_H			; Is Comm_Period4x more than 32ms (~1220 eRPM)?
	subb	A, Temp1
	ljc	run1						; No - go back to run 1

	jnb	Flag_Dir_Change_Brake, run_to_wait_for_power_on	; If it is not a direction change - stop

	; Turn spinning direction
	clr	Flag_Dir_Change_Brake		; Clear brake flag
	clr	Flag_Pgm_Dir_Rev			; Set spinning direction. Default fwd
	jnb	Flag_Rcp_Dir_Rev, ($+5)		; Check force direction
	setb	Flag_Pgm_Dir_Rev			; Set spinning direction
	setb	Flag_Initial_Run_Phase
	mov	Initial_Run_Rot_Cntd, #18
	mov	Pwm_Limit, Pwm_Limit_Beg		; Set initial max power
	jmp	run1						; Go back to run 1

run_to_wait_for_power_on_fail:
	jb	Flag_Motor_Running, run_to_wait_for_power_on
	inc	Startup_Stall_Cnt			; Increment stall count if motors did not properly start

run_to_wait_for_power_on:
	clr	IE_EA					; Disable all interrupts
	call	switch_power_off
	mov	Flags1, #0				; Clear flags1
	mov	Flags_Startup, #0			; Clear startup flags

IF MCU_48MHZ == 1
	Set_MCU_Clk_24MHz

	; Scale DShot criteria for 24MHz
	setb	C
	rrca	DShot_Timer_Preset			; Scale sync timer preset

	clr	C
	rrca	DShot_Frame_Length_Thr		; Scale frame length criteria

	clr	C
	rrca	DShot_Pwm_Thr				; Scale pulse width criteria

	; Scale DShot telemetry for 24MHz
	xcha	DShot_GCR_Pulse_Time_1, DShot_GCR_Pulse_Time_1_Tmp
	xcha	DShot_GCR_Pulse_Time_2, DShot_GCR_Pulse_Time_2_Tmp
	xcha	DShot_GCR_Pulse_Time_3, DShot_GCR_Pulse_Time_3_Tmp

	mov	DShot_GCR_Start_Delay, #DSHOT_TLM_START_DELAY
ENDIF

	setb	IE_EA					; Enable all interrupts
	call	wait100ms					; Wait for pwm to be stopped
	call	switch_power_off

	mov	Temp1, #Pgm_Brake_On_Stop	; Check if using brake on stop
	mov	A, @Temp1
	jz	run_to_wait_for_power_on_brake_done

	AcomFET_on
	BcomFET_on
	CcomFET_on

run_to_wait_for_power_on_brake_done:
	jnb	Flag_Rcp_Stop, ($+6)		; Check if RCP is zero, then it is a normal stop
	mov	Startup_Stall_Cnt, #0

	clr	C
	mov	A, Startup_Stall_Cnt
	subb	A, #10					; Maximum consecutive stalls before stopping
	ljc	wait_for_power_on			; Go back to wait for power on

	ljmp	init_no_signal				; Stalled too many times



;**** **** **** **** **** **** **** **** **** **** **** **** ****

$include (BLHeliBootLoad.inc)			; Include source code for bootloader

;**** **** **** **** **** **** **** **** **** **** **** **** ****



CSEG AT 19FDh
reset:
ljmp	pgm_start



END
