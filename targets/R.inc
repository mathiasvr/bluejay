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
; Hardware definition file "R".
; X  X  RC X  MC MB MA CC    X  X  Ac Bc Cc Ap Bp Cp
;
;**** **** **** **** ****

TEMP_LIMIT			EQU	49	; Temperature measurement ADC value for which main motor power is limited at 80degC (low byte, assuming high byte is 1)
TEMP_LIMIT_STEP		EQU	9	; Temperature measurement ADC value increment for another 10degC




;*********************
; PORT 0 definitions *
;*********************
;			EQU	7	;i
;  			EQU	6	;i
Rcp_In		EQU	5	;i
;			EQU	4	;i
C_Mux		EQU	3	;i
B_Mux		EQU	2	;i
A_Mux		EQU	1	;i
Comp_Com		EQU	0	;i

P0_DIGITAL	EQU	NOT((1 SHL A_Mux) + (1 SHL B_Mux) + (1 SHL C_Mux) + (1 SHL Comp_Com))
P0_INIT		EQU	0FFh
P0_PUSHPULL	EQU	0
P0_SKIP		EQU	0FFh

PWM_ACTIVE_HIGH	EQU	1
COMPWM_ACTIVE_HIGH	EQU	1

Set_Pwm_Polarity MACRO
; Damping inverted, pwm noninverted
IF PCA0_POWER_MODULE == PCA0CPM0
	mov	PCA0POL, #((COMPWM_ACTIVE_HIGH SHL 1) + (1 - PWM_ACTIVE_HIGH))
ELSE
	mov	PCA0POL, #(((1-PWM_ACTIVE_HIGH) SHL 1) + COMPWM_ACTIVE_HIGH)
ENDIF
ENDM

IF FETON_DELAY == 0
	PCA0_POWER_MODULE	EQU	PCA0CPM0
	PCA0_POWER_L		EQU	PCA0CPL0
	PCA0_POWER_H		EQU	PCA0CPH0

	PCA0_DAMP_MODULE	EQU	PCA0CPM1
	PCA0_DAMP_L		EQU	PCA0CPL1
	PCA0_DAMP_H		EQU	PCA0CPH1
ELSE
	PCA0_POWER_MODULE	EQU	PCA0CPM0
	PCA0_POWER_L		EQU	PCA0CPL0
	PCA0_POWER_H		EQU	PCA0CPH0

	PCA0_DAMP_MODULE	EQU	PCA0CPM1
	PCA0_DAMP_L		EQU	PCA0CPL1
	PCA0_DAMP_H		EQU	PCA0CPH1
ENDIF

;*********************
; PORT 1 definitions *
;*********************
;			EQU	7	;i
;			EQU	6	;i
A_com		EQU	5	;o
B_com		EQU	4	;o
C_com		EQU	3	;o
A_pwm		EQU	2	;o
B_pwm		EQU	1	;o
C_pwm		EQU	0	;o

P1_SKIP_ALL	EQU	(1 SHL A_pwm) + (1 SHL A_com) + (1 SHL B_pwm) + (1 SHL B_com) + (1 SHL C_pwm) + (1 SHL C_com)

P_ApwmFET		EQU	P1.A_pwm
P_AcomFET		EQU	P1.A_com
P_BpwmFET		EQU	P1.B_pwm
P_BcomFET		EQU	P1.B_com
P_CpwmFET		EQU	P1.C_pwm
P_CcomFET		EQU	P1.C_com

; Note: currently all comparator pins (Comp_ and Mux_) must be on the same port
COMP_PORT		EQU	0

ALL_FETS_ON_PORT1	EQU	1

$include (Base.inc)

P1_DIGITAL	EQU	(1 SHL A_pwm) + (1 SHL B_pwm) + (1 SHL C_pwm) + (1 SHL A_com) + (1 SHL B_com) + (1 SHL C_com)
P1_INIT		EQU	00h
P1_PUSHPULL	EQU	(1 SHL A_pwm) + (1 SHL B_pwm) + (1 SHL C_pwm) + (1 SHL A_com) + (1 SHL B_com) + (1 SHL C_com)
P1_SKIP		EQU	P1_SKIP_ALL








;*********************
; PORT 2 definitions *
;*********************
DebugPin		EQU	0	;o

P2_PUSHPULL	EQU	(1 SHL DebugPin)


;**********************
; MCU specific macros *
;**********************




Set_LED_0 MACRO
ENDM
Clear_LED_0 MACRO
ENDM
Set_LED_1 MACRO
ENDM
Clear_LED_1 MACRO
ENDM
Set_LED_2 MACRO
ENDM
Clear_LED_2 MACRO
ENDM
Set_LED_3 MACRO
ENDM
Clear_LED_3 MACRO
ENDM
