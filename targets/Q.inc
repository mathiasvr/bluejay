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
; Hardware definition file "Q"
; Cp Bp Ap L1 L0 X  RC X     X  MA MB MC CC Cc Bc Ac
;
;**** **** **** **** ****





;*********************
; PORT 0 definitions *
;*********************
C_pwm		EQU	7	;o
B_pwm		EQU	6	;o
A_pwm		EQU	5	;o
LED_1		EQU	4	;i
LED_0		EQU	3	;i
;			EQU	2	;i
Rcp_In		EQU	1	;i
;			EQU	0	;i



P0_DIGITAL	EQU	0FFh
P0_INIT		EQU	(1 SHL Rcp_In)
P0_PUSHPULL	EQU	(1 SHL LED_0) + (1 SHL LED_1) + (1 SHL A_pwm) + (1 SHL B_pwm) + (1 SHL C_pwm)
P0_SKIP		EQU	0FFh

PWM_ACTIVE_HIGH	EQU	1
COMPWM_ACTIVE_HIGH	EQU	1


; Damping inverted, pwm noninverted


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
A_Mux		EQU	6	;i
B_Mux		EQU	5	;i
C_Mux		EQU	4	;i
Comp_Com		EQU	3	;o
C_com		EQU	2	;o
B_com		EQU	1	;o
A_com		EQU	0	;o



P_ApwmFET		EQU	P0.A_pwm
P_AcomFET		EQU	P1.A_com
P_BpwmFET		EQU	P0.B_pwm
P_BcomFET		EQU	P1.B_com
P_CpwmFET		EQU	P0.C_pwm
P_CcomFET		EQU	P1.C_com

; Note: currently all comparator pins (Comp_ and Mux_) must be on the same port
COMP_PORT		EQU	1

$set(CUSTOM_PWM_PHASE, CUSTOM_LED)

$include (Base.inc)

P1_DIGITAL	EQU	(1 SHL A_com) + (1 SHL B_com) + (1 SHL C_com)
P1_INIT		EQU	00h
P1_PUSHPULL	EQU	(1 SHL A_com) + (1 SHL B_com) + (1 SHL C_com)
P1_SKIP		EQU	0FFh



Set_Pwm_A MACRO
IF FETON_DELAY == 0
	cON	P_AcomFET
	mov	P0SKIP, #(NOT (1 SHL A_pwm))
	mov	P1SKIP, #0FFh
ELSE
	mov	P0SKIP, #(NOT (1 SHL A_pwm))
	mov	P1SKIP, #(NOT (1 SHL A_com))
ENDIF
ENDM
Set_Pwm_B MACRO
IF FETON_DELAY == 0
	cON	P_BcomFET
	mov	P0SKIP, #(NOT (1 SHL B_pwm))
	mov	P1SKIP, #0FFh
ELSE
	mov	P0SKIP, #(NOT (1 SHL B_pwm))
	mov	P1SKIP, #(NOT (1 SHL B_com))
ENDIF
ENDM
Set_Pwm_C MACRO
IF FETON_DELAY == 0
	cON	P_CcomFET
	mov	P0SKIP, #(NOT (1 SHL C_pwm))
	mov	P1SKIP, #0FFh
ELSE
	mov	P0SKIP, #(NOT (1 SHL C_pwm))
	mov	P1SKIP, #(NOT (1 SHL C_com))
ENDIF
ENDM
Set_Pwms_Off MACRO
	mov	P0SKIP, #0FFh
	mov	P1SKIP, #0FFh
ENDM



;*********************
; PORT 2 definitions *
;*********************
DebugPin		EQU	0	;o

P2_DIGITAL	EQU	(1 SHL DebugPin)
P2_PUSHPULL	EQU	(1 SHL DebugPin)
P2_SKIP		EQU	0FFh


;**********************
; MCU specific macros *
;**********************



Set_LED_0 MACRO
	setb	P0.LED_0
ENDM
Clear_LED_0 MACRO
	clr	P0.LED_0
ENDM
Set_LED_1 MACRO
	setb	P0.LED_1
ENDM
Clear_LED_1 MACRO
	clr	P0.LED_1
ENDM
Set_LED_2 MACRO
ENDM
Clear_LED_2 MACRO
ENDM
Set_LED_3 MACRO
ENDM
Clear_LED_3 MACRO
ENDM
