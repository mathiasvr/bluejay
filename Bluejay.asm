;**** **** **** **** ****
;
; Bluejay digital ESC firmware for controlling brushless motors in multirotors
;
; Copyright 2020, 2021 Mathias Rasmussen
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
				; PORT 0					PORT 1					PWM	COM	PWM	LED
				; P0 P1 P2 P3 P4 P5 P6 P7	P0 P1 P2 P3 P4 P5 P6 P7		inv	inv	side	n
				; -----------------------	-----------------------		------------------
A_	EQU	1		; Vn Am Bm Cm __ RX __ __	Ap Ac Bp Bc Cp Cc __ __		no	no	high	_
B_	EQU	2		; Vn Am Bm Cm __ RX __ __	Cc Cp Bc Bp Ac Ap __ __		no	no	high	_
C_	EQU	3		; RX __ Vn Am Bm Cm Ap Ac	Bp Bc Cp Cc __ __ __ __		no	no	high	_
D_	EQU	4		; Bm Cm Am Vn __ RX __ __	Ap Ac Bp Bc Cp Cc __ __		no	yes	high	_
E_	EQU	5		; Vn Am Bm Cm __ RX L0 L1	Ap Ac Bp Bc Cp Cc L2 __		no	no	high	3	Pinout like A, with LEDs
F_	EQU	6		; Vn Cm Bm Am __ RX __ __	Ap Ac Bp Bc Cp Cc __ __		no	no	high	_
G_	EQU	7		; Bm Cm Am Vn __ RX __ __	Ap Ac Bp Bc Cp Cc __ __		no	no	high	_	Pinout like D, but non-inverted com fets
H_	EQU	8		; Cm Vn Bm Am __ __ __ RX	Cc Bc Ac __ Cp Bp Ap __		no	no	high	_
I_	EQU	9		; Vn Am Bm Cm __ RX __ __	Cp Bp Ap Cc Bc Ac __ __		no	no	high	_
J_	EQU	10		; Am Cm Bm Vn RX L0 L1 L2	Ap Bp Cp Ac Bc Cc __ __		no	no	high	3
K_	EQU	11		; RX Am Vn Bm __ Cm __ __	Ac Bc Cc Cp Bp Ap __ __		no	yes	high	_
L_	EQU	12		; Cm Bm Am Vn __ RX __ __	Cp Bp Ap Cc Bc Ac __ __		no	no	high	_
M_	EQU	13		; __ __ L0 RX Bm Vn Cm Am	__ Ap Bp Cp Ac Bc Cc __		no	no	high	1
N_	EQU	14		; Vn Am Bm Cm __ RX __ __	Ac Ap Bc Bp Cc Cp __ __		no	no	high	_
O_	EQU	15		; Bm Cm Am Vn __ RX __ __	Ap Ac Bp Bc Cp Cc __ __		no	yes	low	_	Pinout Like D, but low side pwm
P_	EQU	16		; __ Cm Bm Vn Am RX __ __	__ Ap Bp Cp Ac Bc Cc __		no	no	high	_
Q_	EQU	17		; __ RX __ L0 L1 Ap Bp Cp	Ac Bc Cc Vn Cm Bm Am __		no	no	high	2
R_	EQU	18		; Vn Am Bm Cm __ RX __ __	Cp Bp Ap Cc Bc Ac __ __		no	no	high	_	Same as I
S_	EQU	19		; Bm Cm Am Vn __ RX __ __	Ac Ap Bc Bp Cc Cp __ __		no	no	high	_
T_	EQU	20		; __ Cm Vn Bm __ Am __ RX	Cc Bc Ac Ap Bp Cp __ __		no	no	high	_
U_	EQU	21		; L2 L1 L0 RX Bm Vn Cm Am	__ Ap Bp Cp Ac Bc Cc __		no	no	high	3	Pinout like M, with 3 LEDs
V_	EQU	22		; Am Bm Vn Cm __ RX __ Cc	Cp Bc __ __ Bp Ac Ap __		no	no	high	_
W_	EQU	23		; __ __ Am Vn __ Bm Cm RX	__ __ __ __ Cp Bp Ap __		n/a	n/a	high	_	Tristate gate driver
X_	EQU	24
Y_	EQU	25
Z_	EQU	26		; Bm Cm Am Vn __ RX __ __	Ac Ap Bc Bp Cc Cp __ __		yes	no	high	-	Pinout like S, but inverted pwm fets

;**** **** **** **** ****
; Select the port mapping to use (or unselect all for use with external batch compile file)
;ESCNO			EQU	A_

;**** **** **** **** ****
; Select the MCU type (or unselect for use with external batch compile file)
;MCU_48MHZ		EQU	0

;**** **** **** **** ****
; Select the fet dead time (or unselect for use with external batch compile file)
;DEADTIME			EQU	15	; 20.4ns per step

;**** **** **** **** ****
; Select the pwm frequency (or unselect for use with external batch compile file)
;PWM_FREQ			EQU	0	; 0=24, 1=48, 2=96 kHz


PWM_CENTERED	EQU	DEADTIME > 0			; Use center aligned pwm on ESCs with dead time

IF MCU_48MHZ < 2 AND PWM_FREQ	< 3
	; Number of bits in pwm high byte
	PWM_BITS_H	EQU	(2 + MCU_48MHZ - PWM_CENTERED - PWM_FREQ)
ENDIF

$include (Common.inc)					; Include common source code for EFM8BBx based ESCs

;**** **** **** **** ****
; Programming defaults
DEFAULT_PGM_RPM_POWER_SLOPE		EQU	9	; 0=Off, 1..13 (Power limit factor in relation to rpm)
DEFAULT_PGM_COMM_TIMING			EQU	4	; 1=Low		2=MediumLow	3=Medium		4=MediumHigh	5=High
DEFAULT_PGM_DEMAG_COMP			EQU	2	; 1=Disabled	2=Low		3=High
DEFAULT_PGM_DIRECTION			EQU	1	; 1=Normal	2=Reversed	3=Bidir		4=Bidir rev
DEFAULT_PGM_BEEP_STRENGTH		EQU	40	; 0..255 (BLHeli_S is 1..255)
DEFAULT_PGM_BEACON_STRENGTH		EQU	80	; 0..255
DEFAULT_PGM_BEACON_DELAY			EQU	4	; 1=1m		2=2m			3=5m			4=10m		5=Infinite
DEFAULT_PGM_ENABLE_TEMP_PROT		EQU	7	; 0=Disabled	1=80C	2=90C	3=100C	4=110C	5=120C	6=130C	7=140C

DEFAULT_PGM_BRAKE_ON_STOP		EQU	0	; 1=Enabled	0=Disabled
DEFAULT_PGM_LED_CONTROL			EQU	0	; Byte for LED control. 2bits per LED, 0=Off, 1=On

DEFAULT_PGM_STARTUP_POWER_MIN		EQU	51	; 0..255 => (1000..1125 Throttle): value * (1000 / 2047) + 1000
DEFAULT_PGM_STARTUP_BEEP			EQU	1	; 0=Short beep, 1=Melody
DEFAULT_PGM_DITHERING			EQU	1	; 0=Disabled, 1=Enabled

DEFAULT_PGM_STARTUP_POWER_MAX		EQU	25	; 0..255 => (1000..2000 Throttle): Maximum startup power
DEFAULT_PGM_BRAKING_STRENGTH		EQU	255	; 0..255 => 0..100 % Braking

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
Bit_Access:				DS	1			; MUST BE AT THIS ADDRESS. Variable at bit accessible address (for non interrupt routines)
Bit_Access_Int:			DS	1			; Variable at bit accessible address (for interrupts)

Flags0:					DS	1			; State flags. Reset upon motor_start
Flag_Startup_Phase			BIT	Flags0.0		; Set when in startup phase
Flag_Initial_Run_Phase		BIT	Flags0.1		; Set when in initial run phase (or startup phase), before synchronized run is achieved.
Flag_Motor_Dir_Rev			BIT	Flags0.2		; Set if the current spinning direction is reversed

Flags1:					DS	1			; State flags. Reset upon motor_start
Flag_Timer3_Pending			BIT	Flags1.0		; Timer 3 pending flag
Flag_Demag_Detected			BIT	Flags1.1		; Set when excessive demag time is detected
Flag_Comp_Timed_Out			BIT	Flags1.2		; Set when comparator reading timed out
Flag_Motor_Running			BIT	Flags1.3
Flag_Motor_Started			BIT	Flags1.4		; Set when motor is started
Flag_Dir_Change_Brake		BIT	Flags1.5		; Set when braking before direction change
Flag_High_Rpm				BIT	Flags1.6		; Set when motor rpm is high (Comm_Period4x_H less than 2)

Flags2:					DS	1			; State flags. NOT reset upon motor_start
;						BIT	Flags2.0
Flag_Pgm_Dir_Rev			BIT	Flags2.1		; Set if the programmed direction is reversed
Flag_Pgm_Bidir				BIT	Flags2.2		; Set if the programmed control mode is bidirectional operation
Flag_Skip_Timer2_Int		BIT	Flags2.3		; Set for 48MHz MCUs when timer 2 interrupt shall be ignored
Flag_Clock_At_48MHz			BIT	Flags2.4		; Set if 48MHz MCUs run at 48MHz
Flag_Rcp_Stop				BIT	Flags2.5		; Set if the RC pulse value is zero or if timeout occurs
Flag_Rcp_Dir_Rev			BIT	Flags2.6		; RC pulse direction in bidirectional mode
Flag_Rcp_DShot_Inverted		BIT	Flags2.7		; DShot RC pulse input is inverted (and supports telemetry)

Flags3:					DS	1			; State flags. NOT reset upon motor_start
Flag_Telemetry_Pending		BIT	Flags3.0		; DShot telemetry data packet is ready to be sent
Flag_Dithering				BIT	Flags3.1		; PWM dithering enabled
Flag_Had_Signal			BIT	Flags3.2		; Used to detect reset after having had a valid signal

Tlm_Data_L:				DS	1			; DShot telemetry data (lo byte)
Tlm_Data_H:				DS	1			; DShot telemetry data (hi byte)

;**** **** **** **** ****
; Direct addressing data segment
DSEG AT 30h
Rcp_Outside_Range_Cnt:		DS	1	; RC pulse outside range counter (incrementing)
Rcp_Timeout_Cntd:			DS	1	; RC pulse timeout counter (decrementing)
Rcp_Stop_Cnt:				DS	1	; Counter for RC pulses below stop value

Beacon_Delay_Cnt:			DS	1	; Counter to trigger beacon during wait for start

Startup_Cnt:				DS	1	; Startup phase commutations counter (incrementing)
Startup_Zc_Timeout_Cntd:		DS	1	; Startup zero cross timeout counter (decrementing)
Initial_Run_Rot_Cntd:		DS	1	; Initial run rotations counter (decrementing)
Startup_Stall_Cnt:			DS	1	; Counts start/run attempts that resulted in stall. Reset upon a proper stop
Demag_Detected_Metric:		DS	1	; Metric used to gauge demag event frequency
Demag_Pwr_Off_Thresh:		DS	1	; Metric threshold above which power is cut
Low_Rpm_Pwr_Slope:			DS	1	; Sets the slope of power increase for low rpm

Timer2_X:					DS	1	; Timer 2 extended byte
Prev_Comm_L:				DS	1	; Previous commutation timer 2 timestamp (lo byte)
Prev_Comm_H:				DS	1	; Previous commutation timer 2 timestamp (hi byte)
Prev_Comm_X:				DS	1	; Previous commutation timer 2 timestamp (ext byte)
Prev_Prev_Comm_L:			DS	1	; Pre-previous commutation timer 2 timestamp (lo byte)
Prev_Prev_Comm_H:			DS	1	; Pre-previous commutation timer 2 timestamp (hi byte)
Comm_Period4x_L:			DS	1	; Timer 2 ticks between the last 4 commutations (lo byte)
Comm_Period4x_H:			DS	1	; Timer 2 ticks between the last 4 commutations (hi byte)
Comparator_Read_Cnt:		DS	1	; Number of comparator reads done

Wt_Adv_Start_L:			DS	1	; Timer 3 start point for commutation advance timing (lo byte)
Wt_Adv_Start_H:			DS	1	; Timer 3 start point for commutation advance timing (hi byte)
Wt_Zc_Scan_Start_L:			DS	1	; Timer 3 start point from commutation to zero cross scan (lo byte)
Wt_Zc_Scan_Start_H:			DS	1	; Timer 3 start point from commutation to zero cross scan (hi byte)
Wt_Zc_Tout_Start_L:			DS	1	; Timer 3 start point for zero cross scan timeout (lo byte)
Wt_Zc_Tout_Start_H:			DS	1	; Timer 3 start point for zero cross scan timeout (hi byte)
Wt_Comm_Start_L:			DS	1	; Timer 3 start point from zero cross to commutation (lo byte)
Wt_Comm_Start_H:			DS	1	; Timer 3 start point from zero cross to commutation (hi byte)

Pwm_Limit:				DS	1	; Maximum allowed pwm (8-bit)
Pwm_Limit_By_Rpm:			DS	1	; Maximum allowed pwm for low or high rpm (8-bit)
Pwm_Limit_Beg:				DS	1	; Initial pwm limit (8-bit)

Pwm_Braking_L:				DS	1	; Max Braking pwm (lo byte)
Pwm_Braking_H:				DS	1	; Max Braking pwm (hi byte)

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
_Pgm_Gov_P_Gain:			DS	1	;
Pgm_Startup_Power_Min:		DS	1	; Minimum power during startup phase
Pgm_Startup_Beep:			DS	1	; Startup beep melody on/off
Pgm_Dithering:				DS	1	; Enable PWM dithering
Pgm_Startup_Power_Max:		DS	1	; Maximum power (limit) during startup (and starting initial run phase)
_Pgm_Rampup_Slope:			DS	1	;
Pgm_Rpm_Power_Slope:		DS	1	; Low RPM power protection slope (factor)
Pgm_Pwm_Freq:				DS	1	; PWM frequency (temporary method for display)
Pgm_Direction:				DS	1	; Rotation direction
_Pgm_Input_Pol:			DS	1	; Input PWM polarity
Initialized_L_Dummy:		DS	1	; Place holder
Initialized_H_Dummy:		DS	1	; Place holder
_Pgm_Enable_TX_Program:		DS	1	; Enable/disable value for TX programming
Pgm_Braking_Strength:		DS	1	; Set maximum braking strength (complementary pwm)
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
_Pgm_Enable_Power_Prot:		DS	1	; Low RPM power protection enable
_Pgm_Enable_Pwm_Input:		DS	1	; Enable PWM input signal
_Pgm_Pwm_Dither:			DS	1	; Output PWM dither
Pgm_Brake_On_Stop:			DS	1	; Braking when throttle is zero
Pgm_LED_Control:			DS	1	; LED control

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
EEPROM_FW_SUB_REVISION		EQU	14	; Sub revision of the firmware
EEPROM_LAYOUT_REVISION		EQU	204	; Revision of the EEPROM layout

Eep_FW_Main_Revision:		DB	EEPROM_FW_MAIN_REVISION		; EEPROM firmware main revision number
Eep_FW_Sub_Revision:		DB	EEPROM_FW_SUB_REVISION		; EEPROM firmware sub revision number
Eep_Layout_Revision:		DB	EEPROM_LAYOUT_REVISION		; EEPROM layout revision number

_Eep_Pgm_Gov_P_Gain:		DB	0FFh
Eep_Pgm_Startup_Power_Min:	DB	DEFAULT_PGM_STARTUP_POWER_MIN
Eep_Pgm_Startup_Beep:		DB	DEFAULT_PGM_STARTUP_BEEP
Eep_Pgm_Dithering:			DB	DEFAULT_PGM_DITHERING
Eep_Pgm_Startup_Power_Max:	DB	DEFAULT_PGM_STARTUP_POWER_MAX
_Eep_Pgm_Rampup_Slope:		DB	0FFh
Eep_Pgm_Rpm_Power_Slope:		DB	DEFAULT_PGM_RPM_POWER_SLOPE	; EEPROM copy of programmed rpm power slope (formerly startup power)
Eep_Pgm_Pwm_Freq:			DB	(24 SHL PWM_FREQ)			; Temporary method for display
Eep_Pgm_Direction:			DB	DEFAULT_PGM_DIRECTION		; EEPROM copy of programmed rotation direction
_Eep__Pgm_Input_Pol:		DB	0FFh
Eep_Initialized_L:			DB	055h						; EEPROM initialized signature (lo byte)
Eep_Initialized_H:			DB	0AAh						; EEPROM initialized signature (hi byte)
_Eep_Enable_TX_Program:		DB	0FFh						; EEPROM TX programming enable
Eep_Pgm_Braking_Strength:	DB	DEFAULT_PGM_BRAKING_STRENGTH
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
_Eep_Pgm_Enable_Power_Prot:	DB	0FFh						; EEPROM copy of programmed low rpm power protection enable
_Eep_Pgm_Enable_Pwm_Input:	DB	0FFh
_Eep_Pgm_Pwm_Dither:		DB	0FFh
Eep_Pgm_Brake_On_Stop:		DB	DEFAULT_PGM_BRAKE_ON_STOP	; EEPROM copy of programmed braking when throttle is zero
Eep_Pgm_LED_Control:		DB	DEFAULT_PGM_LED_CONTROL		; EEPROM copy of programmed LED control

Eep_Dummy:				DB	0FFh						; EEPROM address for safety reason

CSEG AT 1A60h
Eep_Name:					DB	"Bluejay (BETA)  "			; Name tag (16 Bytes)

CSEG AT 1A70h
Eep_Pgm_Startup_Tune:		DB	2,58,4,32,52,66,13,0,69,45,13,0,52,66,13,0,78,39,211,0,69,45,208,25,52,25,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
Eep_Dummy2:				DB	0FFh						; EEPROM address for safety reason

;**** **** **** **** ****
Interrupt_Table_Definition			; SiLabs interrupts
CSEG AT 80h						; Code segment after interrupt vectors



;**** **** **** **** **** **** **** **** **** **** **** **** ****
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Macros
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;**** **** **** **** **** **** **** **** **** **** **** **** ****


DSHOT_TLM_CLOCK		EQU	24500000				; 24.5MHz
DSHOT_TLM_START_DELAY	EQU	-(5 * 25 / 4)			; Start telemetry after 5 us (~30 us after receiving DShot cmd)
DSHOT_TLM_PREDELAY		EQU	7					; 7 timer 0 ticks inherent delay

IF MCU_48MHZ == 1
	DSHOT_TLM_CLOCK_48		EQU	49000000			; 49MHz
	DSHOT_TLM_START_DELAY_48	EQU	-(16 * 49 / 4)		; Start telemetry after 16 us (~30 us after receiving DShot cmd)
	DSHOT_TLM_PREDELAY_48	EQU	11				; 11 timer 0 ticks inherent delay
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

; DShot GCR encoding, adjust time by adding to previous item
GCR_Add_Time MACRO reg
	mov	B, @reg
	mov	A, DShot_GCR_Pulse_Time_2
	cjne	A, B, ($+5)
	mov	A, DShot_GCR_Pulse_Time_3
	mov	@reg, A
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

; Used for subdividing the DShot telemetry routine into chunks,
; that will return if timer 3 has wrapped
Early_Return_Packet_Stage MACRO num
	Early_Return_Packet_Stage_ num, %(num + 1)
ENDM

Early_Return_Packet_Stage_ MACRO num next
IF num > 0
	inc	Temp7								;; Increment current packet stage
	jb	Flag_Timer3_Pending, dshot_packet_stage_&num	;; Return early if timer 3 has wrapped
	pop	PSW
	ret
dshot_packet_stage_&num:
ENDIF
IF num < 5
	cjne	Temp7, #(num), dshot_packet_stage_&next		;; If this is not current stage, skip to next
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

ljz MACRO label					;; Long jump if accumulator is zero
LOCAL skip
	jnz	skip
	jmp	label
skip:
ENDM

imov MACRO reg, val					;; Increment pointer register and move
	inc	reg
	mov	@reg, val					;; Write value to memory address pointed to by register
ENDM

;**** **** **** **** ****
; Division
;
; ih, il: input (hi byte, lo byte)
; oh, ol: output (hi byte, lo byte)
;
Divide_By_16 MACRO ih, il, oh, ol
	mov	A, ih
	swap	A
	mov	ol, A
	anl	A, #00Fh
	mov	oh, A
	mov	A, ol
	anl	A, #0F0h
	mov	ol, A
	mov	A, il
	swap	A
	anl	A, #00Fh
	orl	A, ol
	mov	ol, A
ENDM

Divide_12Bit_By_16 MACRO ih, il, ol	;; Only if ih < 16
	mov	A, ih
	swap	A
	mov	ol, A
	mov	A, il
	swap	A
	anl	A, #00Fh
	orl	A, ol
	mov	ol, A
ENDM

Divide_By_8 MACRO ih, il, oh, ol
	mov	A, ih
	swap	A
	rl	A
	mov	ol, A
	anl	A, #01Fh
	mov	oh, A
	mov	A, ol
	anl	A, #0E0h
	mov	ol, A
	mov	A, il
	swap	A
	rl	A
	anl	A, #01Fh
	orl	A, ol
	mov	ol, A
ENDM

Divide_11Bit_By_8 MACRO ih, il, ol		;; Only if ih < 8
	mov	A, ih
	swap	A
	rl	A
	mov	ol, A
	mov	A, il
	swap	A
	rl	A
	anl	A, #01Fh
	orl	A, ol
	mov	ol, A
ENDM

Divide_By_4 MACRO ih, il, oh, ol
	clr	C
	mov	A, ih
	rrc	A
	mov	oh, A
	mov	A, il
	rrc	A
	mov	ol, A

	clr	C
	mov	A, oh
	rrc	A
	mov	oh, A
	mov	A, ol
	rrc	A
	mov	ol, A
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
; Requirements:
; - Must NOT be called while Flag_Telemetry_Pending is cleared
; - Must NOT write to Temp7, Temp8
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
t0_int:
	push	PSW
	mov	PSW, #10h					; Select register bank 2 for this interrupt

	dec	Temp1
	cjne	Temp1, #(Temp_Storage - 1), t0_int_dshot_tlm_transition

	inc	Temp1					; Set pointer to uncritical position

	; If last pulse is high, telemetry is finished,
	; otherwise wait for it to return to high
	jb	RTX_BIT, t0_int_dshot_tlm_finish

t0_int_dshot_tlm_transition:
	cpl	RTX_BIT					; Invert signal level

	mov	TL0, @Temp1				; Schedule next update

	pop	PSW
	reti

t0_int_dshot_tlm_finish:
	; Configure RTX_PIN for digital input
	anl	RTX_MDOUT, #(NOT (1 SHL RTX_PIN))	; Set RTX_PIN output mode to open-drain
	setb	RTX_BIT					; Float high

	clr	IE_ET0					; Disable timer 0 interrupts

	mov	CKCON0, Temp8				; Restore regular DShot timer 0/1 clock settings
	mov	TMOD, #0AAh				; Timer 0/1 gated by INT0/1

	clr	TCON_IE0					; Clear int0 pending flag
	clr	TCON_IE1					; Clear int1 pending flag

	mov	TL0, #0					; Reset timer 0 count
	setb	IE_EX0					; Enable int0 interrupts
	setb	IE_EX1					; Enable int1 interrupts

	clr	Flag_Telemetry_Pending		; Mark that new telemetry packet may be created

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

	; Note: Interrupts are not explicitly disabled because those of higher priority:
	; int0_int is already disabled and t0_int is assumed to be disabled at this point
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

	; RCP signal has not timed out, but pulses are not recognized as DShot
	setb	Flag_Rcp_Stop				; Set pulse length to zero
	mov	DShot_Cmd, #0				; Reset DShot command
	mov	DShot_Cmd_Cnt, #0

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
	mov	Temp3, A					; Store in case it is a DShot command
	subb	A, #96
	mov	Temp4, A
	mov	A, Temp5
	cpl	A
	anl	A, #0Fh
	subb	A, #0
	mov	Temp5, A
	jnc	t1_int_normal_range

	mov	A, Temp3					; Check for 0 or DShot command
	mov	Temp5, #0
	mov	Temp4, #0
	jz	t1_int_dshot_set_cmd		; Clear DShot command when RCP is zero

	clr	C						; We are in the special DShot range
	rrc	A						; Shift tlm bit into carry
	jnc	t1_int_dshot_clear_cmd		; Check for tlm bit set (if not telemetry, invalid command)

	cjne	A, DShot_Cmd, t1_int_dshot_set_cmd

	inc	DShot_Cmd_Cnt
	sjmp	t1_int_normal_range

t1_int_dshot_clear_cmd:
	clr	A

t1_int_dshot_set_cmd:
	mov	DShot_Cmd, A
	mov	DShot_Cmd_Cnt, #0

t1_int_normal_range:
	; Check for bidirectional operation (0=stop, 96-2095->fwd, 2096-4095->rev)
	jnb	Flag_Pgm_Bidir, t1_int_not_bidir	; If not bidirectional operation - branch

	; Subtract 2000 (still 12 bits)
	clr	C
	mov	A, Temp4
	subb	A, #0D0h
	mov	B, A
	mov	A, Temp5
	subb	A, #07h
	jc	t1_int_bidir_set			; Is result is positive?
	mov	Temp4, B					; Yes - Use the subtracted value
	mov	Temp5, A

t1_int_bidir_set:
	jnb	Flag_Pgm_Dir_Rev, ($+4)		; Check programmed direction
	cpl	C						; Reverse direction
	mov	Flag_Rcp_Dir_Rev, C			; Set rcp direction

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

	; Boost pwm during direct start
	jnb	Flag_Initial_Run_Phase, t1_int_startup_boosted

	mov	A, Temp5
	jnz	t1_int_stall_boost			; Already more power than minimum at startup

	mov	Temp2, #Pgm_Startup_Power_Min	; Read minimum startup power setting
	mov	B, @Temp2

	clr	C						; Set power to at least be minimum startup power
	mov	A, Temp4
	subb	A, B
	jnc	t1_int_stall_boost
	mov	Temp4, B

t1_int_stall_boost:
	mov	A, Startup_Stall_Cnt		; Check stall count
	jz	t1_int_startup_boosted
	mov	B, #40					; Note: Stall count should be less than 6
	mul	AB

	add	A, Temp4					; Add more power when failing to start motor (stalling)
	mov	Temp4, A
	mov	A, Temp5
	addc	A, #0
	mov	Temp5, A
	jnb	ACC.3, ($+7)				; Limit to 11-bit maximum
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
; Scale pwm resolution and invert (duty cycle is defined inversely)
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

; 11-bit effective dithering of 8/9/10-bit pwm
IF PWM_BITS_H < 3
	jnb	Flag_Dithering, t1_int_set_pwm

	mov	A, Temp4					; 11-bit low byte
	cpl	A
	anl	A, #((1 SHL (3 - PWM_BITS_H)) - 1); Get index into dithering pattern table

	add	A, #Dithering_Patterns
	mov	Temp1, A					; Reuse DShot pwm pointer since it is not currently in use.
	mov	A, @Temp1					; Retrieve pattern
	rl	A						; Rotate pattern
	mov	@Temp1, A					; Store pattern

	jnb	ACC.0, t1_int_set_pwm		; Increment if bit is set

	mov	A, Temp2
	add	A, #1
	mov	Temp2, A
	jnz	t1_int_set_pwm
IF PWM_BITS_H != 0
	mov	A, Temp3
	addc	A, #0
	mov	Temp3, A
	jnb	ACC.PWM_BITS_H, t1_int_set_pwm
	dec	Temp3					; Reset on overflow
ENDIF
	dec	Temp2
ENDIF

t1_int_set_pwm:
; Set pwm registers
IF DEADTIME != 0
	; Subtract dead time from normal pwm and store as damping pwm
	; Damping pwm duty cycle will be higher because numbers are inverted
	clr	C
	mov	A, Temp2					; Skew damping fet timing
IF MCU_48MHZ == 0
	subb	A, #((DEADTIME + 1) SHR 1)
ELSE
	subb	A, #(DEADTIME)
ENDIF
	mov	Temp4, A
	mov	A, Temp3
	subb	A, #0
	mov	Temp5, A
	jnc	t1_int_max_braking_set

	clr	A						; Set to minimum value
	mov	Temp4, A
	mov	Temp5, A
	sjmp	t1_int_pwm_braking_set		; Max braking is already zero - branch

t1_int_max_braking_set:
	clr	C
	mov	A, Temp4
	subb	A, Pwm_Braking_L
	mov	A, Temp5
	subb	A, Pwm_Braking_H			; Is braking pwm more than maximum allowed braking?
	jc	t1_int_pwm_braking_set		; Yes - branch
	mov	Temp4, Pwm_Braking_L		; No - set desired braking instead
	mov	Temp5, Pwm_Braking_H

t1_int_pwm_braking_set:
ENDIF

	; Note: Interrupts (of higher priority) are not explicitly disabled because
	; int0 is already disabled and timer 0 is assumed to be disabled at this point
IF PWM_BITS_H != 0
	; Set power pwm auto-reload registers
	Set_Power_Pwm_Reg_L	Temp2
	Set_Power_Pwm_Reg_H	Temp3
ELSE
	Set_Power_Pwm_Reg_H Temp2
ENDIF

IF DEADTIME != 0
	; Set damp pwm auto-reload registers
	IF PWM_BITS_H != 0
		Set_Damp_Pwm_Reg_L	Temp4
		Set_Damp_Pwm_Reg_H	Temp5
	ELSE
		Set_Damp_Pwm_Reg_H	Temp4
	ENDIF
ENDIF

	mov	Rcp_Timeout_Cntd, #10		; Set timeout count

	; Prepare DShot telemetry
	jnb	Flag_Rcp_DShot_Inverted, t1_int_exit_no_tlm	; Only send telemetry for inverted DShot
	jnb	Flag_Telemetry_Pending, t1_int_exit_no_tlm	; Check if telemetry packet is ready

	; Prepare timer 0 for sending telemetry data
	mov	CKCON0, #01h				; Timer 0 is system clock divided by 4
	mov	TMOD, #0A2h				; Timer 0 runs free not gated by INT0

	; Configure RTX_PIN for digital output
	setb	RTX_BIT					; Default to high level
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
;
; Requirements: No PSW instructions or Temp registers
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
t2_int:
	push	ACC
	clr	TMR2CN0_TF2H				; Clear interrupt flag
	inc	Timer2_X					; Increment extended byte

IF MCU_48MHZ == 1
	jnb	Flag_Clock_At_48MHz, t2_int_start	; Always run if clock is 24MHz

	jbc	Flag_Skip_Timer2_Int, t2_int_exit	; Flag set? - Skip interrupt and clear flag

t2_int_start:
	setb	Flag_Skip_Timer2_Int		; Skip next interrupt
ENDIF
	; Update RC pulse timeout counter
	mov	A, Rcp_Timeout_Cntd			; RC pulse timeout count zero?
	jz	t2_int_rcp_stop
	dec	Rcp_Timeout_Cntd			; No - decrement

	jnb	Flag_Rcp_Stop, t2_int_exit	; Exit if pulse is above stop value

t2_int_rcp_stop:
	setb	Flag_Rcp_Stop				; Set rcp stop in case of timeout

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
;
; Requirements: No PSW instructions or Temp/Acc/B registers
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
t3_int:
	clr	IE_EA					; Disable all interrupts
	anl	EIE1, #7Fh				; Disable timer 3 interrupts
	anl	TMR3CN0, #07Fh				; Clear timer 3 interrupt flag
	mov	TMR3RLL, #0FAh				; Short delay to avoid re-loading regular delay
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
; Requirements: No PSW instructions
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
; Requirements: No PSW instructions or Temp/Acc registers
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
int1_int:
	clr	IE_EX1					; Disable int1 interrupts
	setb	TCON_TR1					; Start timer 1

	; Note: Interrupts are not explicitly disabled because those of higher priority:
	; int0_int should not yet trigger if dshot signal is valid
	; t0_int is assumed to be disabled at this point
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
; Requirements: No PSW instructions or Temp registers
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
pca_int:
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
	mov	Temp3, #0					; Milliseconds (hi byte)
	mov	Temp2, #1					; Milliseconds (lo byte)
	sjmp	wait_ms

wait5ms:
	mov	Temp3, #0
	mov	Temp2, #5
	sjmp	wait_ms

wait10ms:
	mov	Temp3, #0
	mov	Temp2, #10
	sjmp	wait_ms

wait100ms:
	mov	Temp3, #0
	mov	Temp2, #100
	sjmp	wait_ms

wait200ms:
	mov	Temp3, #0
	mov	Temp2, #200
	sjmp	wait_ms

wait250ms:
	mov	Temp3, #0
	mov	Temp2, #250
	sjmp	wait_ms

wait_ms:
	inc	Temp2					; Increment for use with djnz
	inc	Temp3
	sjmp	wait_ms_start

wait_ms_o:						; Outer loop
	mov	Temp1, #24

wait_ms_m:						; Middle loop
	mov	A, #255
	djnz	ACC, $					; Inner loop (41.6us - 1020 cycles)
	djnz	Temp1, wait_ms_m

wait_ms_start:
	djnz	Temp2, wait_ms_o
	djnz	Temp3, wait_ms_o
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
	jnz	beep_start				; Start if beep strength is not 0
	ret

beep_start:
	mov	Temp2, #2

beep_on_off:
	clr	A
	B_Com_Fet_Off					; B com FET off
	djnz	ACC, $					; Allow some time after com fet is turned off
	B_Pwm_Fet_On					; B pwm FET on (in order to charge the driver of the B com FET)
	djnz	ACC, $					; Let the pwm fet be turned on a while
	B_Pwm_Fet_Off					; B pwm FET off again
	djnz	ACC, $					; Allow some time after pwm fet is turned off
	B_Com_Fet_On					; B com FET on
	djnz	ACC, $					; Allow some time after com fet is turned on

	mov	A, Temp2					; Turn on pwm fet
	jb	ACC.0, beep_a_pwm_on
	A_Pwm_Fet_On
beep_a_pwm_on:
	jnb	ACC.0, beep_c_pwm_on
	C_Pwm_Fet_On
beep_c_pwm_on:

	mov	A, Beep_Strength			; On time according to beep strength
	djnz	ACC, $

	mov	A, Temp2					; Turn off pwm fet
	jb	ACC.0, beep_a_pwm_off
	A_Pwm_Fet_Off
beep_a_pwm_off:
	jnb	ACC.0, beep_c_pwm_off
	C_Pwm_Fet_Off
beep_c_pwm_off:

	mov	A, #150					; Off for 25 us
	djnz	ACC, $

	djnz	Temp2, beep_on_off			; Toggle next pwm fet

	mov	A, Temp3
beep_off:							; Fets off loop
	mov	Temp1, #200
	djnz	Temp1, $
	djnz	ACC, beep_off				; Off time according to beep frequency

	djnz	Temp4, beep_start			; Number of beep pulses (duration)

	B_Com_Fet_Off
	ret

; Beep sequences
beep_signal_lost:
	call	beep_f1
	call	beep_f2
	call	beep_f3
	ret

beep_enter_bootloader:
	call	beep_f2_short
	call	beep_f1
	ret

beep_motor_stalled:
	call	beep_f3
	call	beep_f2
	call	beep_f1
	ret

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Beep melody
;
; Plays a beep melody from eeprom storage
;
; Startup tune has 64 pairs of (item1, item2) - a total of 128 items.
; the first 4 values of the 128 items are metadata
; item2 - is the duration of each pulse of the musical note, lower the value, higher the pitch
; item1 - if item2 is zero, it is the number of milliseconds of wait time, else it is the number of pulses of item2
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
startup_beep_melody:
	mov	DPTR, #(Eep_Pgm_Startup_Tune)
	clr	A
	movc	A, @A+DPTR
	cpl	A
	jz	startup_beep_done			; If first byte is 255, skip startup melody (settings may be invalid)

	mov	Temp5, #62
	mov	DPTR, #(Eep_Pgm_Startup_Tune + 04h)

startup_melody_loop:
	; Read current location at Eep_Pgm_Startup_Tune to Temp4 and increment DPTR. If the value is 0, no point trying to play this note
	clr	A
	movc	A, @A+DPTR
	inc	DPTR
	mov	Temp4, A
	jz	startup_beep_done

	; Read current location at Eep_Pgm_Startup_Tune to Temp3. If the value zero, that means this is a silent note
	clr	A
	movc	A, @A+DPTR
	mov	Temp3, A
	jz	startup_melody_item_wait_ms
	call	beep
	sjmp	startup_melody_loop_next_item

startup_melody_item_wait_ms:
	mov	A, Temp4
	mov	Temp2, A
	mov	Temp3, #0
	call	wait_ms

startup_melody_loop_next_item:
	inc	DPTR
	djnz	Temp5, startup_melody_loop

startup_beep_done:
	mov	DPTR, #Eep_Dummy2
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
	All_Pwm_Fets_Off				; Turn off all pwm fets
	All_Com_Fets_Off				; Turn off all commutation fets
	Set_All_Pwm_Phases_Off
	ret


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Set pwm limit low rpm
;
; Sets power limit for low rpm
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
set_pwm_limit:
	jb	Flag_High_Rpm, set_pwm_limit_high_rpm	; If high rpm, limit pwm by rpm instead

;set_pwm_limit_low_rpm:
	; Set pwm limit
	mov	Temp1, #0FFh				; Default full power
	jb	Flag_Startup_Phase, set_pwm_limit_low_rpm_exit	; Exit if startup phase set

	mov	A, Low_Rpm_Pwr_Slope		; Check if low RPM power protection is enabled
	jz	set_pwm_limit_low_rpm_exit	; Exit if disabled (zero)

	mov	A, Comm_Period4x_H
	jz	set_pwm_limit_low_rpm_exit	; Avoid divide by zero

	mov	A, #255					; Divide 255 by Comm_Period4x_H
	jnb	Flag_Initial_Run_Phase, ($+5)	; More protection for initial run phase
	mov	A, #127
	mov	B, Comm_Period4x_H
	div	AB
	mov	B, Low_Rpm_Pwr_Slope		; Multiply by slope
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
	subb	A, #0A0h					; Limit Comm_Period4x to 160, which is ~510k erpm
ELSE
	subb	A, #0E4h					; Limit Comm_Period4x to 228, which is ~358k erpm
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

	mov	Temp3, ADC0L				; Read ADC result
	mov	Temp4, ADC0H

	Stop_Adc

	mov	Adc_Conversion_Cnt, #0		; Yes - temperature check. Reset counter

	mov	Temp2, #Pgm_Enable_Temp_Prot	; Is temp protection enabled?
	mov	A, @Temp2
	jz	temp_check_exit			; No - branch

	mov	A, Temp4					; Is temperature reading below 256?
	jnz	temp_average_inc_dec		; No - proceed

	mov	A, Current_Average_Temp		; Yes - decrement average
	jz	temp_average_updated		; Already zero - no change
	sjmp	temp_average_dec			; Decrement

temp_average_inc_dec:
	clr	C
	mov	A, Temp3					; Check if current temperature is above or below average
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
	subb	A, #(TEMP_LIMIT_STEP / 2)	; Is temperature below second limit
	jc	temp_check_exit			; Yes - exit

	mov	Pwm_Limit, #128			; No - limit pwm

	clr	C
	subb	A, #(TEMP_LIMIT_STEP / 2)	; Is temperature below third limit
	jc	temp_check_exit			; Yes - exit

	mov	Pwm_Limit, #64				; No - limit pwm

	clr	C
	subb	A, #(TEMP_LIMIT_STEP / 2)	; Is temperature below final limit
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
; Calculate next commutation period
;
; Measure the duration of current commutation period,
; and update Comm_Period4x by averaging a fraction of it.
;
; Called immediately after each commutation
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
calc_next_comm_period:
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
	clr	C						; Divide time by 2 on 48MHz
	rrca	Temp3
	rrca	Temp2
	rrca	Temp1
ENDIF

	jb	Flag_Startup_Phase, calc_next_comm_startup

	; Calculate this commutation time
	clr	C
	mov	A, Temp1
	subb	A, Prev_Comm_L				; Calculate the new commutation time
	mov	Prev_Comm_L, Temp1			; Save timestamp as previous commutation
	mov	Temp1, A					; Store commutation period in Temp1 (lo byte)
	mov	A, Temp2
	subb	A, Prev_Comm_H
	mov	Prev_Comm_H, Temp2			; Save timestamp as previous commutation
IF MCU_48MHZ == 1
	anl	A, #7Fh
ENDIF
	mov	Temp2, A					; Store commutation period in Temp2 (hi byte)

	jnb	Flag_High_Rpm, calc_next_comm_normal	; Branch normal rpm
	ajmp	calc_next_comm_period_fast			; Branch high rpm

calc_next_comm_startup:
	; Calculate this commutation time
	mov	Temp4, Prev_Comm_L
	mov	Temp5, Prev_Comm_H
	mov	Temp6, Prev_Comm_X
	mov	Prev_Comm_L, Temp1			; Store timestamp as previous commutation
	mov	Prev_Comm_H, Temp2
	mov	Prev_Comm_X, Temp3			; Store extended timestamp as previous commutation

	clr	C
	mov	A, Temp1
	subb	A, Temp4					; Calculate the new commutation time
	mov	A, Temp2
	subb	A, Temp5
	mov	A, Temp3
	subb	A, Temp6					; Calculate the new extended commutation time
IF MCU_48MHZ == 1
	anl	A, #7Fh
ENDIF
	jz	calc_next_comm_startup_no_X

	; Extended byte is not zero, so commutation time is above 0xFFFF
	mov	Comm_Period4x_L, #0FFh
	mov	Comm_Period4x_H, #0FFh
	ajmp	calc_next_comm_done

calc_next_comm_startup_no_X:
	; Extended byte = 0, so commutation time fits within two bytes
	mov	Temp7, Prev_Prev_Comm_L
	mov	Temp8, Prev_Prev_Comm_H
	mov	Prev_Prev_Comm_L, Temp4
	mov	Prev_Prev_Comm_H, Temp5

	; Calculate the new commutation time based upon the two last commutations (to reduce sensitivity to offset)
	clr	C
	mov	A, Temp1
	subb	A, Temp7
	mov	Temp1, A
	mov	A, Temp2
	subb	A, Temp8
	mov	Temp2, A

	mov	Temp3, Comm_Period4x_L		; Comm_Period4x holds the time of 4 commutations
	mov	Temp4, Comm_Period4x_H

	sjmp	calc_next_comm_div_4_1

calc_next_comm_normal:
	; Prepare averaging by dividing Comm_Period4x and current commutation period (Temp2/1) according to speed.
	mov	Temp3, Comm_Period4x_L		; Comm_Period4x holds the time of 4 commutations
	mov	Temp4, Comm_Period4x_H

	clr	C
	mov	A, Temp4					; Is Comm_Period4x_H below 4? (above ~80k erpm)
	subb	A, #4
	jc	calc_next_comm_div_16_4		; Yes - Use averaging for high speeds

	subb	A, #4					; Is Comm_Period4x_H below 8? (above ~40k erpm)
	jc	calc_next_comm_div_8_2		; Yes - Use averaging for low speeds

	; No - Use averaging for even lower speeds

	; Do not average very fast during initial run
	jb	Flag_Initial_Run_Phase, calc_next_comm_div_8_2_slow

calc_next_comm_div_4_1:
	; Update Comm_Period4x from 1 new commutation period

	; Divide Temp4/3 by 4 and store in Temp6/5
	Divide_By_4	Temp4, Temp3, Temp6, Temp5

	sjmp	calc_next_comm_average_and_update

calc_next_comm_div_8_2:
	; Update Comm_Period4x from 1/2 new commutation period

	; Divide Temp4/3 by 8 and store in Temp5
	Divide_11Bit_By_8	Temp4, Temp3, Temp5
	mov	Temp6, #0

	clr	C						; Divide by 2
	rrca	Temp2
	rrca	Temp1

	sjmp	calc_next_comm_average_and_update

calc_next_comm_div_8_2_slow:
	; Update Comm_Period4x from 1/2 new commutation period

	; Divide Temp4/3 by 8 and store in Temp6/5
	Divide_By_8	Temp4, Temp3, Temp6, Temp5

	clr	C						; Divide by 2
	rrca	Temp2
	rrca	Temp1

	sjmp	calc_next_comm_average_and_update

calc_next_comm_div_16_4:
	; Update Comm_Period4x from 1/4 new commutation period

	; Divide Temp4/3 by 16 and store in Temp5
	Divide_12Bit_By_16	Temp4, Temp3, Temp5
	mov	Temp6, #0

	; Divide Temp2/1 by 4 and store in Temp2/1
	Divide_By_4	Temp2, Temp1, Temp2, Temp1

calc_next_comm_average_and_update:
 	; Comm_Period4x = Comm_Period4x - (Comm_Period4x / (16, 8 or 4)) + (Comm_Period / (4, 2 or 1))

	; Temp6/5: Comm_Period4x divided by (16, 8 or 4)
	clr	C						; Subtract a fraction
	mov	A, Temp3					; Comm_Period4x_L
	subb	A, Temp5
	mov	Temp3, A
	mov	A, Temp4					; Comm_Period4x_H
	subb	A, Temp6
	mov	Temp4, A

	; Temp2/1: This commutation period divided by (4, 2 or 1)
	mov	A, Temp3					; Add the divided new time
	add	A, Temp1
	mov	Comm_Period4x_L, A
	mov	A, Temp4
	addc	A, Temp2
	mov	Comm_Period4x_H, A

	jnc	calc_next_comm_done			; Is period larger than 0xffff?
	mov	Comm_Period4x_L, #0FFh		; Yes - Set commutation period registers to very slow timing (0xffff)
	mov	Comm_Period4x_H, #0FFh

calc_next_comm_done:
	clr	C
	mov	A, Comm_Period4x_H
	subb	A, #2					; Is Comm_Period4x_H below 2? (above ~160k erpm)
	jnc	($+4)
	setb	Flag_High_Rpm				; Yes - Set high rpm flag

calc_next_comm_15deg:
	; Commutation period: 360 deg / 6 runs = 60 deg
	; 60 deg / 4 = 15 deg

	; Load current commutation timing and compute 15 deg timing
	; Divide Comm_Period4x by 16 (Comm_Period1x divided by 4) and store in Temp4/3
	Divide_By_16	Comm_Period4x_H, Comm_Period4x_L, Temp4, Temp3

	; Subtract timing reduction
	clr	C
	mov	A, Temp3
	subb	A, #2				; Set timing reduction
	mov	Temp3, A
	mov	A, Temp4
	subb	A, #0
	mov	Temp4, A

	jc	calc_next_comm_15deg_set_min	; Check that result is still positive
	jnz	calc_next_comm_period_exit	; Check that result is still above minimum
	mov	A, Temp3
	jnz	calc_next_comm_period_exit

calc_next_comm_15deg_set_min:
	mov	Temp3, #1					; Set minimum waiting time (Timers cannot wait for a delay of 0)
	mov	Temp4, #0

	sjmp	calc_next_comm_period_exit

;**** **** **** **** ****
; Calculate next commutation timing fast routine
; Fast calculation (Comm_Period4x_H less than 2)
calc_next_comm_period_fast:
	; Calculate new commutation time
	mov	Temp3, Comm_Period4x_L		; Comm_Period4x holds the time of 4 commutations
	mov	Temp4, Comm_Period4x_H

	; Divide by 16 and store in Temp5
	Divide_12Bit_By_16	Temp4, Temp3, Temp5

	clr	C
	mov	A, Temp3					; Subtract a fraction
	subb	A, Temp5
	mov	Temp3, A
	mov	A, Temp4
	subb	A, #0
	mov	Temp4, A

	; Note: Temp2 is assumed to be zero (approx. Comm_Period4x_H / 4)
	mov	A, Temp1					; Divide by 4
	rr	A
	rr	A
	anl	A, #03Fh

	add	A, Temp3					; Add the divided new time
	mov	Temp3, A
	mov	A, Temp4
	addc	A, #0
	mov	Temp4, A

	mov	Comm_Period4x_L, Temp3		; Store Comm_Period4x_X
	mov	Comm_Period4x_H, Temp4

	clr	C
	subb	A, #2					; Is Comm_Period4x_H 2 or more? (below ~160k erpm)
	jc	($+4)
	clr	Flag_High_Rpm				; Yes - Clear high rpm bit

	mov	A, Temp4					; Divide Comm_Period4x by 16 and store in Temp4/3
	swap	A
	mov	Temp7, A
	mov	Temp4, #0					; Clear waiting time high byte
	mov	A, Temp3
	swap	A
	anl	A, #0Fh
	orl	A, Temp7
	clr	C
	subb	A, #2					; Timing reduction
	mov	Temp3, A
	jc	calc_next_comm_fast_set_min	; Check that result is still positive
	jnz	calc_next_comm_period_exit	; Check that result is still above minimum

calc_next_comm_fast_set_min:
	mov	Temp3, #1					; Set minimum waiting time (Timers cannot wait for a delay of 0)

calc_next_comm_period_exit:


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Wait advance timing routine
;
; Waits for the advance timing to elapse
;
; NOTE: Be VERY careful if using temp registers. They are passed over this routine
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
wait_advance_timing:
	; If it has not already, we wait here for the Wt_Adv_Start_ delay to elapse.
	Wait_For_Timer3

	; At this point timer 3 has (already) wrapped and been reloaded with the Wt_Zc_Scan_Start_ delay.
	; In case this delay has also elapsed, timer 3 has been reloaded with a short delay any number of times.
	; - The interrupt flag is set and the pending flag will clear immediately after enabling the interrupt.

	mov	TMR3RLL, Wt_ZC_Tout_Start_L	; Setup next wait time
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
	mov	Temp1, #Pgm_Comm_Timing		; Load commutation timing setting
	mov	A, @Temp1
	mov	Temp8, A					; Store in Temp8

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

	; Temp2/1 = 15deg timer 2 period

	jb	Flag_High_Rpm, calc_new_wait_times_fast	; Branch if high rpm

	; Load programmed commutation timing
	jnb	Flag_Startup_Phase, adjust_comm_timing

	mov	Temp8, #3					; Set dedicated timing during startup
	sjmp	load_comm_timing_done

adjust_comm_timing:
	; Adjust commutation timing according to demag metric
	clr	C
	mov	A, Demag_Detected_Metric		; Check demag metric
	subb	A, #130
	jc	load_comm_timing_done

	inc	Temp8					; Increase timing (if metric 130 or above)

	subb	A, #30
	jc	($+3)

	inc	Temp8					; Increase timing again (if metric 160 or above)

	clr	C
	mov	A, Temp8					; Limit timing to max
	subb	A, #6
	jc	($+4)

	mov	Temp8, #5					; Set timing to max (if timing 6 or above)

load_comm_timing_done:
	mov	A, Temp1					; Copy values
	mov	Temp3, A
	mov	A, Temp2
	mov	Temp4, A

	setb	C						; Negative numbers - set carry
	mov	A, Temp2					; Store 7.5deg in Temp5/6 (15deg / 2)
	rrc	A
	mov	Temp6, A
	mov	A, Temp1
	rrc	A
	mov	Temp5, A

	mov	Wt_Zc_Scan_Start_L, Temp5	; Set 7.5deg time for zero cross scan delay
	mov	Wt_Zc_Scan_Start_H, Temp6
	mov	Wt_Zc_Tout_Start_L, Temp1	; Set 15deg time for zero cross scan timeout
	mov	Wt_Zc_Tout_Start_H, Temp2

	clr	C
	mov	A, Temp8					; (Temp8 has Pgm_Comm_Timing)
	subb	A, #3					; Is timing normal?
	jz	store_times_decrease		; Yes - branch

	mov	A, Temp8
	jb	ACC.0, adjust_timing_two_steps; If an odd number - branch

	; Commutation timing setting is 2 or 4
	mov	A, Temp1					; Store 22.5deg in Temp1/2 (15deg + 7.5deg)
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
	; Commutation timing setting is 1 or 5
	mov	A, Temp1					; Store 30deg in Temp1/2 (15deg + 15deg)
	setb	C						; Add 1 to final result (Temp1/2 * 2 + 1)
	addc	A, Temp1
	mov	Temp1, A
	mov	A, Temp2
	addc	A, Temp2
	mov	Temp2, A

	mov	Temp3, #-1				; Store minimum time (0deg) in Temp3/4
	mov	Temp4, #-1

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
	sjmp	calc_new_wait_times_exit

store_times_decrease:
	mov	Wt_Comm_Start_L, Temp1		; Now commutation time (~60deg) divided by 4 (~15deg nominal)
	mov	Wt_Comm_Start_H, Temp2
	mov	Wt_Adv_Start_L, Temp3		; New commutation advance time (~15deg nominal)
	mov	Wt_Adv_Start_H, Temp4

	; Set very short delays for all but advance time during startup, in order to widen zero cross capture range
	jnb	Flag_Startup_Phase, calc_new_wait_times_exit
	mov	Wt_Comm_Start_L, #-16
	mov	Wt_Comm_Start_H, #-1
	mov	Wt_Zc_Scan_Start_L, #-16
	mov	Wt_Zc_Scan_Start_H, #-1
	mov	Wt_Zc_Tout_Start_L, #-16
	mov	Wt_Zc_Tout_Start_H, #-1

	sjmp	calc_new_wait_times_exit

;**** **** **** **** ****
; Calculate new wait times fast routine
calc_new_wait_times_fast:
	mov	A, Temp1					; Copy values
	mov	Temp3, A
	setb	C						; Negative numbers - set carry
	rrc	A						; Divide by 2
	mov	Temp5, A

	mov	Wt_Zc_Scan_Start_L, Temp5	; Use this value for zero cross scan delay (7.5deg)
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
	mov	Temp3, #-1				; Store minimum time in Temp3

store_times_up_or_down_fast:
	clr	C
	mov	A, Temp8
	subb	A, #3					; Is timing higher than normal?
	jc	store_times_decrease_fast	; No - branch

store_times_increase_fast:
	mov	Wt_Comm_Start_L, Temp3		; Now commutation time (~60deg) divided by 4 (~15deg nominal)
	mov	Wt_Adv_Start_L, Temp1		; New commutation advance time (~15deg nominal)
	sjmp	calc_new_wait_times_exit

store_times_decrease_fast:
	mov	Wt_Comm_Start_L, Temp1		; Now commutation time (~60deg) divided by 4 (~15deg nominal)
	mov	Wt_Adv_Start_L, Temp3		; New commutation advance time (~15deg nominal)

calc_new_wait_times_exit:


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Wait before zero cross scan routine
;
; Waits for the zero cross scan wait time to elapse
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
wait_before_zc_scan:
	; If it has not already, we wait here for the Wt_Zc_Scan_Start_ delay to elapse.
	Wait_For_Timer3

	; At this point timer 3 has (already) wrapped and been reloaded with the Wt_ZC_Tout_Start_ delay.
	; In case this delay has also elapsed, timer 3 has been reloaded with a short delay any number of times.
	; - The interrupt flag is set and the pending flag will clear immediately after enabling the interrupt.

	mov	Startup_Zc_Timeout_Cntd, #2

setup_zc_scan_timeout:
	setb	Flag_Timer3_Pending
	orl	EIE1, #80h				; Enable timer 3 interrupts

	jnb	Flag_Initial_Run_Phase, wait_before_zc_scan_exit

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
; Scans for comparator going low/high
; Exit if zero cross timeout has elapsed
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
wait_for_comp_out_low:
	mov	B, #00h					; Desired comparator output
	jnb	Flag_Dir_Change_Brake, comp_init
	mov	B, #40h
	sjmp	comp_init

wait_for_comp_out_high:
	mov	B, #40h					; Desired comparator output
	jnb	Flag_Dir_Change_Brake, comp_init
	mov	B, #00h

comp_init:
	setb	Flag_Demag_Detected			; Set demag detected flag as default
	mov	Comparator_Read_Cnt, #0		; Reset number of comparator reads

comp_start:
	; Set number of comparator readings required
	mov	Temp3, #(1 SHL MCU_48MHZ)	; Number of OK readings required
	mov	Temp4, #(1 SHL MCU_48MHZ)	; Max number of readings required
	jb	Flag_High_Rpm, comp_check_timeout	; Branch if high rpm

	jnb	Flag_Initial_Run_Phase, ($+5)
	clr	Flag_Demag_Detected			; Clear demag detected flag if start phases

	jnb	Flag_Startup_Phase, comp_not_startup
	mov	Temp3, #(27 SHL MCU_48MHZ)	; Set many samples during startup, approximately one pwm period
	mov	Temp4, #(27 SHL MCU_48MHZ)
	sjmp	comp_check_timeout

comp_not_startup:
	; Too low value (~<15) causes rough running at pwm harmonics.
	; Too high a value (~>35) causes the RCT4215 630 to run rough on full throttle
	mov	Temp4, #(20 SHL MCU_48MHZ)
	mov	A, Comm_Period4x_H			; Set number of readings higher for lower speeds
IF MCU_48MHZ == 0
	clr	C
	rrc	A
ENDIF
	jnz	($+3)
	inc	A						; Minimum 1
	mov	Temp3, A
	clr	C
	subb	A, #(20 SHL MCU_48MHZ)
	jc	($+4)
	mov	Temp3, #(20 SHL MCU_48MHZ)	; Maximum 20

comp_check_timeout:
	jb	Flag_Timer3_Pending, comp_check_timeout_not_timed_out	; Has zero cross scan timeout elapsed?

	mov	A, Comparator_Read_Cnt			; Check that comparator has been read
	jz	comp_check_timeout_not_timed_out	; If not yet read - ignore zero cross timeout

	jnb	Flag_Startup_Phase, comp_check_timeout_timeout_extended

	; Extend timeout during startup
	djnz	Startup_Zc_Timeout_Cntd, comp_check_timeout_extend_timeout

comp_check_timeout_timeout_extended:
	setb	Flag_Comp_Timed_Out
	sjmp	comp_exit

comp_check_timeout_extend_timeout:
	call	setup_zc_scan_timeout

comp_check_timeout_not_timed_out:
	inc	Comparator_Read_Cnt			; Increment comparator read count
	Read_Comparator_Output
	anl	A, #40h
	cjne	A, B, comp_read_wrong

	; Comp read ok
	mov	A, Startup_Cnt				; Force a timeout for the first commutation
	jz	comp_start

	jb	Flag_Demag_Detected, comp_start	; Do not accept correct comparator output if it is demag

	djnz	Temp3, comp_check_timeout	; Decrement readings counter - repeat comparator reading if not zero

	clr	Flag_Comp_Timed_Out
	sjmp	comp_exit

comp_read_wrong:
	jb	Flag_Startup_Phase, comp_read_wrong_startup
	jb	Flag_Demag_Detected, comp_read_wrong_extend_timeout

	inc	Temp3					; Increment number of OK readings required
	clr	C
	mov	A, Temp3
	subb	A, Temp4
	jc	comp_check_timeout			; If below initial requirement - take another reading
	sjmp	comp_start				; Otherwise - go back and restart

comp_read_wrong_startup:
	inc	Temp3					; Increment number of OK readings required
	clr	C
	mov	A, Temp3
	subb	A, Temp4					; If above initial requirement - do not increment further
	jc	($+3)
	dec	Temp3

	sjmp	comp_check_timeout			; Continue to look for good ones

comp_read_wrong_extend_timeout:
	clr	Flag_Demag_Detected			; Clear demag detected flag
	anl	EIE1, #7Fh				; Disable timer 3 interrupts
	mov	TMR3CN0, #00h				; Timer 3 disabled and interrupt flag cleared
	jnb	Flag_High_Rpm, comp_read_wrong_low_rpm	; Branch if not high rpm

	mov	TMR3L, #0					; Set timeout to ~1ms
	mov	TMR3H, #-(8 SHL MCU_48MHZ)

comp_read_wrong_timeout_set:
	mov	TMR3CN0, #04h				; Timer 3 enabled and interrupt flag cleared
	setb	Flag_Timer3_Pending
	orl	EIE1, #80h				; Enable timer 3 interrupts
	jmp	comp_start				; If comparator output is not correct - go back and restart

comp_read_wrong_low_rpm:
	mov	A, Comm_Period4x_H			; Set timeout to ~4x comm period 4x value
	mov	Temp7, #0FFh				; Default to long timeout

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

comp_exit:


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Setup commutation timing routine
;
; Clear the zero cross timeout and sets up wait from zero cross to commutation
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
setup_comm_wait:
	clr	IE_EA
	anl	EIE1, #7Fh				; Disable timer 3 interrupts

	; It is necessary to update the timer reload registers before the timer registers,
	; to avoid a reload of the previous values in case of a short Wt_Comm_Start delay.

	; Advance wait time will be loaded by timer 3 immediately after the commutation wait elapses
	mov	TMR3RLL, Wt_Adv_Start_L		; Setup next wait time
	mov	TMR3RLH, Wt_Adv_Start_H
	mov	TMR3CN0, #00h				; Timer 3 disabled and interrupt flag cleared
	mov	TMR3L, Wt_Comm_Start_L
	mov	TMR3H, Wt_Comm_Start_H
	mov	TMR3CN0, #04h				; Timer 3 enabled and interrupt flag cleared

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
	jb	Flag_Startup_Phase, eval_comp_startup	; Do not exit run mode during startup phases

	jnb	Flag_Comp_Timed_Out, eval_comp_exit	; Has timeout elapsed?
	jb	Flag_Initial_Run_Phase, eval_comp_exit	; Do not exit run mode if initial run phase
	jb	Flag_Dir_Change_Brake, eval_comp_exit	; Do not exit run mode if braking
	jb	Flag_Demag_Detected, eval_comp_exit	; Do not exit run mode if it is a demag situation

	dec	SP								; Routine exit without "ret" command
	dec	SP
	ljmp	exit_run_mode_on_timeout				; Exit run mode if timeout has elapsed

eval_comp_startup:
	inc	Startup_Cnt						; Increment startup counter

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
	jc	wait_for_comm_wait

	; Cut power if many consecutive demags. This will help retain sync during hard accelerations
	All_Pwm_Fets_Off
	Set_All_Pwm_Phases_Off

wait_for_comm_wait:
	; If it has not already, we wait here for the Wt_Comm_Start_ delay to elapse.
	Wait_For_Timer3

	; At this point timer 3 has (already) wrapped and been reloaded with the Wt_Adv_Start_ delay.
	; In case this delay has also elapsed, timer 3 has been reloaded with a short delay any number of times.
	; - The interrupt flag is set and the pending flag will clear immediately after enabling the interrupt.

	mov	TMR3RLL, Wt_Zc_Scan_Start_L	; Setup next wait time
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
comm1_comm2:						; C->A
	jb	Flag_Motor_Dir_Rev, comm1_comm2_rev

	clr	IE_EA
	B_Com_Fet_Off
	A_Com_Fet_On
	Set_Pwm_Phase_C				; Reapply power after a demag cut
	setb	IE_EA
	Set_Comparator_Phase_B
	ret

comm1_comm2_rev:					; A->C
	clr	IE_EA
	B_Com_Fet_Off
	C_Com_Fet_On
	Set_Pwm_Phase_A				; Reapply power after a demag cut
	setb	IE_EA
	Set_Comparator_Phase_B
	ret

; Comm phase 2 to comm phase 3
comm2_comm3:						; B->A
	jb	Flag_Motor_Dir_Rev, comm2_comm3_rev

	clr	IE_EA
	C_Pwm_Fet_Off					; Turn off pwm fet (Necessary for EN/PWM driver)
	Set_Pwm_Phase_B
	A_Com_Fet_On					; Reapply power after a demag cut (Necessary for EN/PWM driver)
	setb	IE_EA
	Set_Comparator_Phase_C
	ret

comm2_comm3_rev:					; B->C
	clr	IE_EA
	A_Pwm_Fet_Off					; Turn off pwm fet (Necessary for EN/PWM driver)
	Set_Pwm_Phase_B
	C_Com_Fet_On					; Reapply power after a demag cut (Necessary for EN/PWM driver)
	setb	IE_EA
	Set_Comparator_Phase_A
	ret

; Comm phase 3 to comm phase 4
comm3_comm4:						; B->C
	jb	Flag_Motor_Dir_Rev, comm3_comm4_rev

	clr	IE_EA
	A_Com_Fet_Off
	C_Com_Fet_On
	Set_Pwm_Phase_B				; Reapply power after a demag cut
	setb	IE_EA
	Set_Comparator_Phase_A
	ret

comm3_comm4_rev:					; B->A
	clr	IE_EA
	C_Com_Fet_Off
	A_Com_Fet_On
	Set_Pwm_Phase_B				; Reapply power after a demag cut
	setb	IE_EA
	Set_Comparator_Phase_C
	ret

; Comm phase 4 to comm phase 5
comm4_comm5:						; A->C
	jb	Flag_Motor_Dir_Rev, comm4_comm5_rev

	clr	IE_EA
	B_Pwm_Fet_Off					; Turn off pwm fet (Necessary for EN/PWM driver)
	Set_Pwm_Phase_A
	C_Com_Fet_On					; Reapply power after a demag cut (Necessary for EN/PWM driver)
	setb	IE_EA
	Set_Comparator_Phase_B
	ret

comm4_comm5_rev:					; C->A
	clr	IE_EA
	B_Pwm_Fet_Off					; Turn off pwm fet (Necessary for EN/PWM driver)
	Set_Pwm_Phase_C
	A_Com_Fet_On					; Reapply power after a demag cut (Necessary for EN/PWM driver)
	setb	IE_EA
	Set_Comparator_Phase_B
	ret

; Comm phase 5 to comm phase 6
comm5_comm6:						; A->B
	jb	Flag_Motor_Dir_Rev, comm5_comm6_rev

	clr	IE_EA
	C_Com_Fet_Off
	B_Com_Fet_On
	Set_Pwm_Phase_A				; Reapply power after a demag cut
	setb	IE_EA
	Set_Comparator_Phase_C
	ret

comm5_comm6_rev:					; C->B
	clr	IE_EA
	A_Com_Fet_Off
	B_Com_Fet_On
	Set_Pwm_Phase_C				; Reapply power after a demag cut
	setb	IE_EA
	Set_Comparator_Phase_A
	ret

; Comm phase 6 to comm phase 1
comm6_comm1:						; C->B
	jb	Flag_Motor_Dir_Rev, comm6_comm1_rev

	clr	IE_EA
	A_Pwm_Fet_Off					; Turn off pwm fet (Necessary for EN/PWM driver)
	Set_Pwm_Phase_C
	B_Com_Fet_On					; Reapply power after a demag cut (Necessary for EN/PWM driver)
	setb	IE_EA
	Set_Comparator_Phase_A
	ret

comm6_comm1_rev:					; A->B
	clr	IE_EA
	C_Pwm_Fet_Off					; Turn off pwm fet (Necessary for EN/PWM driver)
	Set_Pwm_Phase_A
	B_Com_Fet_On					; Reapply power after a demag cut (Necessary for EN/PWM driver)
	setb	IE_EA
	Set_Comparator_Phase_C
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
	mov	C, RTX_BIT

detect_rcp_level_read:
	jc	($+5)
	jb	RTX_BIT, detect_rcp_level	; Level changed from low to high - start over
	jnc	($+5)
	jnb	RTX_BIT, detect_rcp_level	; Level changed from high to low - start over
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
	jnc	dshot_cmd_direction_normal

	call	beacon_beep
	call	wait200ms

	sjmp	dshot_cmd_exit

dshot_cmd_direction_normal:
	clr	C						; Remaining commands must be received 6 times in a row
	mov	A, DShot_Cmd_Cnt
	subb	A, #6
	jc	dshot_cmd_exit_no_clear

	; Set motor spinning direction to normal
	cjne	Temp1, #7, dshot_cmd_direction_reverse

	clr	Flag_Pgm_Dir_Rev

	sjmp	dshot_cmd_exit

dshot_cmd_direction_reverse:
	; Set motor spinning direction to reversed
	cjne	Temp1, #8, dshot_cmd_direction_bidir_off

	setb	Flag_Pgm_Dir_Rev

	sjmp	dshot_cmd_exit

dshot_cmd_direction_bidir_off:
	; Set motor control mode to normal (not bidirectional)
	cjne	Temp1, #9, dshot_cmd_direction_bidir_on

	clr	Flag_Pgm_Bidir

	sjmp	dshot_cmd_exit

dshot_cmd_direction_bidir_on:
	; Set motor control mode to bidirectional
	cjne	Temp1, #10, dshot_cmd_direction_user_normal

	setb	Flag_Pgm_Bidir

	sjmp	dshot_cmd_exit

dshot_cmd_direction_user_normal:
	; Set motor spinning direction to user programmed direction
	cjne	Temp1, #20, dshot_cmd_direction_user_reverse

	mov	Temp2, #Pgm_Direction		; Read programmed direction
	mov	A, @Temp2
	dec	A
	mov	C, ACC.0					; Set direction
	mov	Flag_Pgm_Dir_Rev, C

	sjmp	dshot_cmd_exit

dshot_cmd_direction_user_reverse:		; Temporary reverse
	; Set motor spinning direction to reverse of user programmed direction
	cjne	Temp1, #21, dshot_cmd_save_settings

	mov	Temp2, #Pgm_Direction		; Read programmed direction
	mov	A, @Temp2
	dec	A
	mov	C, ACC.0
	cpl	C						; Set reverse direction
	mov	Flag_Pgm_Dir_Rev, C

	sjmp	dshot_cmd_exit

dshot_cmd_save_settings:
	cjne	Temp1, #12, dshot_cmd_exit

	clr	A						; Set programmed direction from flags
	mov	C, Flag_Pgm_Dir_Rev
	mov	ACC.0, C
	mov	C, Flag_Pgm_Bidir
	mov	ACC.1, C
	inc	A
	mov	Temp2, #Pgm_Direction		; Store programmed direction
	mov	@Temp2, A

	mov	Flash_Key_1, #0A5h			; Initialize flash keys to valid values
	mov	Flash_Key_2, #0F1h

	call	erase_and_store_all_in_eeprom

	mov	Flash_Key_1, #0			; Reset flash keys to invalid values
	mov	Flash_Key_2, #0

	setb	IE_EA

dshot_cmd_exit:
	mov	DShot_Cmd, #0				; Clear DShot command and exit
	mov	DShot_Cmd_Cnt, #0

dshot_cmd_exit_no_clear:
	ret

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
; Requirements:
; - Must NOT be called while Flag_Telemetry_Pending is set
; - Must NOT write to Temp7, Temp8
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
	mov	@Temp1, DShot_GCR_Pulse_Time_1; Final transition time

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

	inc	Temp1
	mov	Temp7, #0					; Reset current packet stage

	pop	PSW
	setb	Flag_Telemetry_Pending		; Mark that packet is ready to be sent
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
	imov	Temp1, DShot_GCR_Pulse_Time_3
	imov	Temp1, DShot_GCR_Pulse_Time_1
	imov	Temp1, DShot_GCR_Pulse_Time_1
	ret

dshot_gcr_encode_1_11011:
	imov	Temp1, DShot_GCR_Pulse_Time_1
	imov	Temp1, DShot_GCR_Pulse_Time_2
	imov	Temp1, DShot_GCR_Pulse_Time_1
	imov	Temp1, DShot_GCR_Pulse_Time_1
	ret

dshot_gcr_encode_2_10010:
	GCR_Add_Time	Temp1
	imov	Temp1, DShot_GCR_Pulse_Time_3
	imov	Temp1, DShot_GCR_Pulse_Time_1
	ret

dshot_gcr_encode_3_10011:
	imov	Temp1, DShot_GCR_Pulse_Time_1
	imov	Temp1, DShot_GCR_Pulse_Time_3
	imov	Temp1, DShot_GCR_Pulse_Time_1
	ret

dshot_gcr_encode_4_11101:
	imov	Temp1, DShot_GCR_Pulse_Time_2
	imov	Temp1, DShot_GCR_Pulse_Time_1
	imov	Temp1, DShot_GCR_Pulse_Time_1
	imov	Temp1, DShot_GCR_Pulse_Time_1
	ret

dshot_gcr_encode_5_10101:
	imov	Temp1, DShot_GCR_Pulse_Time_2
	imov	Temp1, DShot_GCR_Pulse_Time_2
	imov	Temp1, DShot_GCR_Pulse_Time_1
	ret

dshot_gcr_encode_6_10110:
	GCR_Add_Time	Temp1
	imov	Temp1, DShot_GCR_Pulse_Time_1
	imov	Temp1, DShot_GCR_Pulse_Time_2
	imov	Temp1, DShot_GCR_Pulse_Time_1
	ret

dshot_gcr_encode_7_10111:
	imov	Temp1, DShot_GCR_Pulse_Time_1
	imov	Temp1, DShot_GCR_Pulse_Time_1
	imov	Temp1, DShot_GCR_Pulse_Time_2
	imov	Temp1, DShot_GCR_Pulse_Time_1
	ret

dshot_gcr_encode_8_11010:
	GCR_Add_Time	Temp1
	imov	Temp1, DShot_GCR_Pulse_Time_2
	imov	Temp1, DShot_GCR_Pulse_Time_1
	imov	Temp1, DShot_GCR_Pulse_Time_1
	ret

dshot_gcr_encode_9_01001:
	imov	Temp1, DShot_GCR_Pulse_Time_3
	imov	Temp1, DShot_GCR_Pulse_Time_2
	ret

dshot_gcr_encode_A_01010:
	GCR_Add_Time	Temp1
	imov	Temp1, DShot_GCR_Pulse_Time_2
	imov	Temp1, DShot_GCR_Pulse_Time_2
	ret

dshot_gcr_encode_B_01011:
	imov	Temp1, DShot_GCR_Pulse_Time_1
	imov	Temp1, DShot_GCR_Pulse_Time_2
	imov	Temp1, DShot_GCR_Pulse_Time_2
	ret

dshot_gcr_encode_C_11110:
	GCR_Add_Time	Temp1
	imov	Temp1, DShot_GCR_Pulse_Time_1
	imov	Temp1, DShot_GCR_Pulse_Time_1
	imov	Temp1, DShot_GCR_Pulse_Time_1
	imov	Temp1, DShot_GCR_Pulse_Time_1
	ret

dshot_gcr_encode_D_01101:
	imov	Temp1, DShot_GCR_Pulse_Time_2
	imov	Temp1, DShot_GCR_Pulse_Time_1
	imov	Temp1, DShot_GCR_Pulse_Time_2
	ret

dshot_gcr_encode_E_01110:
	GCR_Add_Time	Temp1
	imov	Temp1, DShot_GCR_Pulse_Time_1
	imov	Temp1, DShot_GCR_Pulse_Time_1
	imov	Temp1, DShot_GCR_Pulse_Time_2
	ret

dshot_gcr_encode_F_01111:
	imov	Temp1, DShot_GCR_Pulse_Time_1
	imov	Temp1, DShot_GCR_Pulse_Time_1
	imov	Temp1, DShot_GCR_Pulse_Time_1
	imov	Temp1, DShot_GCR_Pulse_Time_2
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
	call	read_melody
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
	call	write_melody
	call	write_eeprom_signature
	mov	DPTR, #Eep_Dummy			; Set pointer to uncritical area
	ret


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Read eeprom byte routine
;
; Gives data in A and in address given by Temp1
; Assumes address in DPTR
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
; Assumes data in address given by Temp1, or in accumulator
; Assumes address in DPTR
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
	djnz	Temp3, read_tag
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
	djnz	Temp3, write_tag
	ret


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Read bytes from flash and store in external memory
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
read_melody:
	mov	Temp3, #140				; Number of bytes
	mov	Temp2, #0					; Set XRAM address
	mov	Temp1, #Bit_Access
	mov	DPTR, #Eep_Pgm_Startup_Tune	; Set flash address
read_melody_byte:
	call	read_eeprom_byte
	mov	A, Bit_Access
	movx	@Temp2, A					; Write to XRAM
	inc	Temp2
	inc	DPTR
	djnz	Temp3, read_melody_byte
	ret


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Write bytes from external memory and store in flash
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
write_melody:
	mov	Temp3, #140				; Number of bytes
	mov	Temp2, #0					; Set XRAM address
	mov	DPTR, #Eep_Pgm_Startup_Tune	; Set flash address
write_melody_byte:
	movx	A, @Temp2					; Read from XRAM
	call	write_eeprom_byte_from_acc
	inc	Temp2
	inc	DPTR
	djnz	Temp3, write_melody_byte
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
	mov	@Temp1, #0FFh						; _Pgm_Gov_P_Gain
	imov	Temp1, #DEFAULT_PGM_STARTUP_POWER_MIN	; Pgm_Startup_Power_Min
	imov	Temp1, #DEFAULT_PGM_STARTUP_BEEP		; Pgm_Startup_Beep
	imov	Temp1, #DEFAULT_PGM_DITHERING			; Pgm_Dithering
	imov	Temp1, #DEFAULT_PGM_STARTUP_POWER_MAX	; Pgm_Startup_Power_Max
	imov	Temp1, #0FFh						; _Pgm_Rampup_Slope
	imov	Temp1, #DEFAULT_PGM_RPM_POWER_SLOPE	; Pgm_Rpm_Power_Slope
	imov	Temp1, #(24 SHL PWM_FREQ)			; Pgm_Pwm_Freq
	imov	Temp1, #DEFAULT_PGM_DIRECTION			; Pgm_Direction
	imov	Temp1, #0FFh						; _Pgm_Input_Pol

	inc	Temp1							; Skip Initialized_L_Dummy
	inc	Temp1							; Skip Initialized_H_Dummy

	imov	Temp1, #0FFh						; _Pgm_Enable_TX_Program
	imov	Temp1, #DEFAULT_PGM_BRAKING_STRENGTH	; Pgm_Braking_Strength
	imov	Temp1, #0FFh						; _Pgm_Gov_Setup_Target
	imov	Temp1, #0FFh						; _Pgm_Startup_Rpm
	imov	Temp1, #0FFh						; _Pgm_Startup_Accel
	imov	Temp1, #0FFh						; _Pgm_Volt_Comp
	imov	Temp1, #DEFAULT_PGM_COMM_TIMING		; Pgm_Comm_Timing
	imov	Temp1, #0FFh						; _Pgm_Damping_Force
	imov	Temp1, #0FFh						; _Pgm_Gov_Range
	imov	Temp1, #0FFh						; _Pgm_Startup_Method
	imov	Temp1, #0FFh						; _Pgm_Min_Throttle
	imov	Temp1, #0FFh						; _Pgm_Max_Throttle
	imov	Temp1, #DEFAULT_PGM_BEEP_STRENGTH		; Pgm_Beep_Strength
	imov	Temp1, #DEFAULT_PGM_BEACON_STRENGTH	; Pgm_Beacon_Strength
	imov	Temp1, #DEFAULT_PGM_BEACON_DELAY		; Pgm_Beacon_Delay
	imov	Temp1, #0FFh						; _Pgm_Throttle_Rate
	imov	Temp1, #DEFAULT_PGM_DEMAG_COMP		; Pgm_Demag_Comp
	imov	Temp1, #0FFh						; _Pgm_BEC_Voltage_High
	imov	Temp1, #0FFh						; _Pgm_Center_Throttle
	imov	Temp1, #0FFh						; _Pgm_Main_Spoolup_Time
	imov	Temp1, #DEFAULT_PGM_ENABLE_TEMP_PROT	; Pgm_Enable_Temp_Prot
	imov	Temp1, #0FFh						; _Pgm_Enable_Power_Prot
	imov	Temp1, #0FFh						; _Pgm_Enable_Pwm_Input
	imov	Temp1, #0FFh						; _Pgm_Pwm_Dither
	imov	Temp1, #DEFAULT_PGM_BRAKE_ON_STOP		; Pgm_Brake_On_Stop
	imov	Temp1, #DEFAULT_PGM_LED_CONTROL		; Pgm_LED_Control

	ret


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Decode settings
;
; Decodes programmed settings and set RAM variables accordingly
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
decode_settings:
	mov	Temp1, #Pgm_Direction		; Load programmed direction
	mov	A, @Temp1
	dec	A
	mov	C, ACC.1					; Set bidirectional mode
	mov	Flag_Pgm_Bidir, C
	mov	C, ACC.0					; Set direction (Normal / Reversed)
	mov	Flag_Pgm_Dir_Rev, C

	; Check startup power
	mov	Temp1, #Pgm_Startup_Power_Max
	mov	A, #80					; Limit to at most 80
	subb	A, @Temp1
	jnc	($+4)
	mov	@Temp1, #80

	; Check low rpm power slope
	mov	Temp1, #Pgm_Rpm_Power_Slope
	mov	A, #13					; Limit to at most 13
	subb	A, @Temp1
	jnc	($+4)
	mov	@Temp1, #13

	mov	Low_Rpm_Pwr_Slope, @Temp1

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

	mov	Temp1, #Pgm_Beep_Strength	; Read programmed beep strength setting
	mov	Beep_Strength, @Temp1		; Set beep strength

	mov	Temp1, #Pgm_Braking_Strength	; Read programmed braking strength setting
	mov	A, @Temp1
IF PWM_BITS_H == 2					; Scale braking strength to pwm resolution
	rl	A
	rl	A
	mov	Temp2, A
	anl	A, #03h
	mov	Pwm_Braking_H, A
	mov	A, Temp2
	orl	A, #03h
	mov	Pwm_Braking_L, A
ELSEIF PWM_BITS_H == 1
	rl	A
	mov	Temp2, A
	anl	A, #01h
	mov	Pwm_Braking_H, A
	mov	A, Temp2
	orl	A, #01h
	mov	Pwm_Braking_L, A
ELSEIF PWM_BITS_H == 0
	mov	Pwm_Braking_H, #0
	mov	Pwm_Braking_L, A
ENDIF

	mov	Temp1, #Pgm_Dithering		; Read programmed dithering setting
	mov	A, @Temp1
	add	A, #0FFh					; Carry set if A is not zero
	mov	Flag_Dithering, C			; Set dithering enabled

IF PWM_BITS_H == 2					; Initialize pwm dithering bit patterns
	mov	Temp1, #Dithering_Patterns	; 1-bit dithering (10-bit to 11-bit)
	mov	@Temp1, #00h				; 00000000
	imov	Temp1, #55h				; 01010101
ELSEIF PWM_BITS_H == 1
	mov	Temp1, #Dithering_Patterns	; 2-bit dithering (9-bit to 11-bit)
	mov	@Temp1, #00h				; 00000000
	imov	Temp1, #11h				; 00010001
	imov	Temp1, #55h				; 01010101
	imov	Temp1, #77h				; 01110111
ELSEIF PWM_BITS_H == 0
	mov	Temp1, #Dithering_Patterns	; 3-bit dithering (8-bit to 11-bit)
	mov	@Temp1, #00h				; 00000000
	imov	Temp1, #01h				; 00000001
	imov	Temp1, #11h				; 00010001
	imov	Temp1, #25h				; 00100101
	imov	Temp1, #55h				; 01010101
	imov	Temp1, #5Bh				; 01011011
	imov	Temp1, #77h				; 01110111
	imov	Temp1, #7fh				; 01111111
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
IF MCU_48MHZ == 1
	; Not available on BB1
	mov	SFRPAGE, #20h
	mov	P2MDIN, #P2_DIGITAL
	mov	P2SKIP, #P2_SKIP
	mov	SFRPAGE, #00h
ENDIF
	Initialize_Crossbar				; Initialize the crossbar and related functionality
	call	switch_power_off			; Switch power off again, after initializing ports

	; Clear RAM
	clr	A						; Clear accumulator
	mov	Temp1, A					; Clear Temp1
	clear_ram:
	mov	@Temp1, A					; Clear RAM address
	djnz	Temp1, clear_ram			; Decrement address and repeat

	call	set_default_parameters		; Set default programmed parameters
	call	read_all_eeprom_parameters	; Read all programmed parameters
	call	decode_settings			; Decode programmed settings

	; Initializing beeps
	clr	IE_EA					; Disable interrupts explicitly
	call	wait100ms					; Wait a bit to avoid audible resets if not properly powered
	call	startup_beep_melody			; Play startup beep melody
	call	led_control				; Set LEDs to programmed values

	call	wait100ms					; Wait for flight controller to get ready

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; No signal entry point
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
init_no_signal:
	clr	IE_EA					; Disable interrupts explicitly
	mov	Flash_Key_1, #0			; Initialize flash keys to invalid values
	mov	Flash_Key_2, #0
	call	switch_power_off

IF MCU_48MHZ == 1
	Set_MCU_Clk_24MHz				; Set clock frequency
ENDIF

	mov	Temp1, #9					; Check if input signal is high for ~150ms
	mov	Temp2, #0
	mov	Temp3, #0
input_high_check:
	jnb	RTX_BIT, bootloader_done		; Look for low
	djnz	Temp3, input_high_check
	djnz	Temp2, input_high_check
	djnz	Temp1, input_high_check

	call	beep_enter_bootloader

	ljmp	1C00h					; Jump to bootloader

bootloader_done:
	jnb	Flag_Had_Signal, setup_dshot	; Check if DShot signal was lost
	call	beep_signal_lost
	call	wait250ms					; Wait for flight controller to get ready
	call	wait250ms
	call	wait250ms
	clr	Flag_Had_Signal

setup_dshot:
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

	call	detect_rcp_level			; Detect RCP level (normal or inverted DShot)

	; Route RCP according to detected DShot signal (normal or inverted)
	mov	IT01CF, #(80h + (RTX_PIN SHL 4) + RTX_PIN) ; Route RCP input to INT0/1, with INT1 inverted
	jnb	Flag_Rcp_DShot_Inverted, ($+6)
	mov	IT01CF, #(08h + (RTX_PIN SHL 4) + RTX_PIN) ; Route RCP input to INT0/1, with INT0 inverted

	; Setup interrupts for DShot
	clr	Flag_Telemetry_Pending		; Clear DShot telemetry flag
	mov	IE, #2Dh					; Enable timer 1/2 interrupts and INT0/1 interrupts
	mov	EIE1, #80h				; Enable timer 3 interrupts
	mov	IP, #03h					; High priority to timer 0 and INT0 interrupts

	setb	IE_EA					; Enable all interrupts

	; Setup variables for DShot150 (Only on 24MHz because frame length threshold cannot be scaled up)
IF MCU_48MHZ == 0
	mov	DShot_Timer_Preset, #-64		; Load DShot sync timer preset (for DShot150)
	mov	DShot_Pwm_Thr, #8			; Load DShot qualification pwm threshold (for DShot150)
	mov	DShot_Frame_Length_Thr, #160	; Load DShot frame length criteria

	Set_DShot_Tlm_Bitrate	187500	; = 5/4 * 150000

	; Test whether signal is DShot150
	mov	Rcp_Outside_Range_Cnt, #10	; Set out of range counter
	call	wait100ms					; Wait for new RC pulse
	mov	A, Rcp_Outside_Range_Cnt		; Check if pulses were accepted
	jz	arming_begin
ENDIF

	mov	CKCON0, #0Ch				; Timer 0/1 clock is system clock (for DShot300/600)

	; Setup variables for DShot300
	mov	DShot_Timer_Preset, #-128	; Load DShot sync timer preset (for DShot300)
	mov	DShot_Pwm_Thr, #16			; Load DShot pwm threshold (for DShot300)
	mov	DShot_Frame_Length_Thr, #80	; Load DShot frame length criteria

	Set_DShot_Tlm_Bitrate	375000	; = 5/4 * 300000

	; Test whether signal is DShot300
	mov	Rcp_Outside_Range_Cnt, #10	; Set out of range counter
	call	wait100ms					; Wait for new RC pulse
	mov	A, Rcp_Outside_Range_Cnt		; Check if pulses were accepted
	jz	arming_begin

	; Setup variables for DShot600 (Only on 48MHz for performance reasons)
IF MCU_48MHZ == 1
	mov	DShot_Timer_Preset, #-64		; Load DShot sync timer preset (for DShot600)
	mov	DShot_Pwm_Thr, #8			; Load DShot pwm threshold (for DShot600)
	mov	DShot_Frame_Length_Thr, #40	; Load DShot frame length criteria

	Set_DShot_Tlm_Bitrate	750000	; = 5/4 * 600000

	; Test whether signal is DShot600
	mov	Rcp_Outside_Range_Cnt, #10	; Set out of range counter
	call	wait100ms					; Wait for new RC pulse
	mov	A, Rcp_Outside_Range_Cnt		; Check if pulses were accepted
	jz	arming_begin
ENDIF

	ljmp	init_no_signal

arming_begin:
	push	PSW
	mov	PSW, #10h					; Temp8 in register bank 2 holds value
	mov	Temp8, CKCON0				; Save DShot clock settings for telemetry
	pop	PSW

	setb	Flag_Had_Signal			; Mark that a signal has been detected
	mov	Startup_Stall_Cnt, #0		; Reset stall count

	clr	IE_EA
	call	beep_f1_short				; Beep signal that RC pulse is ready
	setb	IE_EA

arming_wait:
	clr	C
	mov	A, Rcp_Stop_Cnt
	subb	A, #10
	jc	arming_wait				; Wait until rcp has been zero for ~300ms

	clr	IE_EA
	call	beep_f2_short				; Beep signal that ESC is armed
	setb	IE_EA

wait_for_start:					; Armed and waiting for power on
	clr	A
	mov	Comm_Period4x_L, A			; Reset commutation period for telemetry
	mov	Comm_Period4x_H, A
	mov	DShot_Cmd, A				; Reset DShot command (only considered in this loop)
	mov	DShot_Cmd_Cnt, A
	mov	Beacon_Delay_Cnt, A			; Clear beacon wait counter
	mov	Timer2_X, A				; Clear timer 2 extended byte

wait_for_start_loop:
	clr	C
	mov	A, Timer2_X
	subb	A, #94
	jc	wait_for_start_no_beep		; Counter wrapping (about 3 sec)

	mov	Timer2_X, #0
	inc	Beacon_Delay_Cnt			; Increment beacon wait counter

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

	mov	Beacon_Delay_Cnt, #0		; Reset beacon counter for infinite delay

beep_delay_set:
	clr	C
	mov	A, Beacon_Delay_Cnt
	subb	A, Temp1					; Check against chosen delay
	jc	wait_for_start_no_beep		; Has delay elapsed?

	dec	Beacon_Delay_Cnt			; Decrement counter for continued beeping

	mov	Temp1, #4					; Beep tone 4
	call	beacon_beep

wait_for_start_no_beep:
	jb	Flag_Telemetry_Pending, wait_for_start_check_rcp
	call	dshot_tlm_create_packet		; Create telemetry packet (0 rpm)

wait_for_start_check_rcp:
	jnb	Flag_Rcp_Stop, wait_for_start_nonzero	; Higher than stop, Yes - proceed

	mov	A, Rcp_Timeout_Cntd			; Load RC pulse timeout counter value
	ljz	init_no_signal				; If pulses are missing - go back to detect input signal

	call	dshot_cmd_check			; Check and process DShot command

	sjmp	wait_for_start_loop			; Go back to beginning of wait loop

wait_for_start_nonzero:
	call	wait100ms					; Wait to see if start pulse was glitch

	; If Rcp returned to stop - start over
	jb	Flag_Rcp_Stop, wait_for_start_loop


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Motor start entry point
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
motor_start:
	clr	IE_EA					; Disable interrupts
	call	switch_power_off
	setb	IE_EA					; Enable interrupts

	clr	A
	mov	Flags0, A					; Clear run time flags
	mov	Flags1, A
	mov	Demag_Detected_Metric, A		; Clear demag metric

	call	wait1ms

	; Read initial average temperature
	Start_Adc						; Start adc conversion

	jnb	ADC0CN0_ADINT, $			; Wait for adc conversion to complete

	mov	Current_Average_Temp, ADC0L	; Read initial temperature
	mov	A, ADC0H
	jnz	($+5)					; Is reading below 256?
	mov	Current_Average_Temp, #0		; Yes - set average temperature value to zero

	mov	Adc_Conversion_Cnt, #8		; Make sure a temp reading is done
	call	check_temp_and_limit_power
	mov	Adc_Conversion_Cnt, #8		; Make sure a temp reading is done next time

	; Set up start operating conditions
	clr	IE_EA					; Disable interrupts
	mov	Temp2, #Pgm_Startup_Power_Max
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

	; Scale DShot telemetry for 48MHz
	xcha	DShot_GCR_Pulse_Time_1, DShot_GCR_Pulse_Time_1_Tmp
	xcha	DShot_GCR_Pulse_Time_2, DShot_GCR_Pulse_Time_2_Tmp
	xcha	DShot_GCR_Pulse_Time_3, DShot_GCR_Pulse_Time_3_Tmp

	mov	DShot_GCR_Start_Delay, #DSHOT_TLM_START_DELAY_48
ENDIF

	mov	C, Flag_Pgm_Dir_Rev			; Read spin direction setting
	mov	Flag_Motor_Dir_Rev, C

	jnb	Flag_Pgm_Bidir, motor_start_bidir_done	; Check if bidirectional operation

	mov	C, Flag_Rcp_Dir_Rev			; Read force direction
	mov	Flag_Motor_Dir_Rev, C		; Set spinning direction

;**** **** **** **** ****
; Motor start beginning
motor_start_bidir_done:
	setb	Flag_Startup_Phase			; Set startup phase flags
	setb	Flag_Initial_Run_Phase
	mov	Startup_Cnt, #0			; Reset startup phase run counter
	mov	Initial_Run_Rot_Cntd, #12	; Set initial run rotation countdown
	call	comm5_comm6				; Initialize commutation
	call	comm6_comm1
	call	initialize_timing			; Initialize timing
	call	calc_next_comm_period		; Set virtual commutation point
	call	initialize_timing			; Initialize timing
	call	calc_next_comm_period
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
	call	calc_next_comm_period		; Calculate next timing and wait advance timing wait
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
	call	calc_next_comm_period
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
	call	calc_next_comm_period
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
	call	calc_next_comm_period
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
	call	calc_next_comm_period
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
	call	calc_next_comm_period
;		wait_advance_timing
;		calc_new_wait_times
;		wait_before_zc_scan

	; Check if it is direct startup
	jnb	Flag_Startup_Phase, normal_run_checks

	mov	Pwm_Limit, Pwm_Limit_Beg		; Set initial max power
	clr	C
	mov	A, Startup_Cnt				; Load startup counter
	subb	A, #24					; Is counter above requirement?
	jnc	startup_phase_done

	jnb	Flag_Rcp_Stop, run1			; If pulse is above stop value - Continue to run
	ajmp	run_to_wait_for_start

startup_phase_done:
	clr	Flag_Startup_Phase			; Clear startup phase flag
	mov	Pwm_Limit, Pwm_Limit_Beg
	mov	Pwm_Limit_By_Rpm, Pwm_Limit_Beg

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

	jb	Flag_Rcp_Stop, run_to_wait_for_start	; Check if pulse is below stop value

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
	jnc	run_to_wait_for_start		; Yes, go back to wait for power on

run6_check_timeout:
	mov	A, Rcp_Timeout_Cntd			; Load RC pulse timeout counter value
	jz	run_to_wait_for_start		; If it is zero - go back to wait for power on

run6_check_dir:
	jnb	Flag_Pgm_Bidir, run6_check_speed		; Check if bidirectional operation

	jb	Flag_Motor_Dir_Rev, run6_check_dir_rev	; Check if actual rotation direction
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
	mov	Temp1, #0F0h				; Default minimum speed (~1330 erpm)
	jnb	Flag_Dir_Change_Brake, run6_brake_done; Is it a direction change?

	mov	Pwm_Limit, Pwm_Limit_Beg		; Set max power while braking to initial power limit
	mov	Temp1, #20h				; Bidirectional braking termination speed  (~9970 erpm)

run6_brake_done:
	clr	C
	mov	A, Comm_Period4x_H			; Is Comm_Period4x below minimum speed??
	subb	A, Temp1
	ljc	run1						; No - go back to run 1

	jnb	Flag_Dir_Change_Brake, run_to_wait_for_start	; If it is not a direction change - stop

	; Turn spinning direction
	clr	Flag_Dir_Change_Brake		; Clear brake
	mov	C, Flag_Rcp_Dir_Rev			; Read force direction
	mov	Flag_Motor_Dir_Rev, C		; Set spinning direction
	setb	Flag_Initial_Run_Phase
	mov	Initial_Run_Rot_Cntd, #18
	mov	Pwm_Limit, Pwm_Limit_Beg		; Set initial max power
	jmp	run1						; Go back to run 1

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Exit run mode and power off
; on normal stop or comparator timeout
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
exit_run_mode_on_timeout:
	jb	Flag_Motor_Running, run_to_wait_for_start
	inc	Startup_Stall_Cnt			; Increment stall count if motors did not properly start

run_to_wait_for_start:
	clr	IE_EA					; Disable all interrupts
	call	switch_power_off
	mov	Flags0, #0				; Clear run time flags (in case they are used in interrupts)
	mov	Flags1, #0

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

	; Check if RCP is zero, then it is a normal stop or signal timeout
	jb	Flag_Rcp_Stop, run_to_wait_for_start_no_stall

	clr	C						; Otherwise - it's a stall
	mov	A, Startup_Stall_Cnt
	subb	A, #4					; Maximum consecutive stalls
	ljc	motor_start				; Go back and try starting motors again

	; Stalled too many times
	clr	IE_EA
	call	beep_motor_stalled
	setb	IE_EA

	ljmp	arming_begin				; Go back and wait for arming

run_to_wait_for_start_no_stall:
	mov	Startup_Stall_Cnt, #0

	mov	Temp1, #Pgm_Brake_On_Stop	; Check if using brake on stop
	mov	A, @Temp1
	jz	run_to_wait_for_start_brake_done

	A_Com_Fet_On					; Brake on stop
	B_Com_Fet_On
	C_Com_Fet_On

run_to_wait_for_start_brake_done:
	ljmp	wait_for_start				; Go back to wait for power on


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Reset
;
; Should execution ever reach this point the ESC will be reset,
; as code flash after offset 1A00 is used for EEPROM storage
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
CSEG AT 19FDh
reset:
	ljmp	pgm_start


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Bootloader
;
; Include source code for BLHeli bootloader
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;CSEG AT 1C00h
$include (BLHeliBootLoad.inc)


END
