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
; Hardware definition file "V"
; Cc X  RC X  MC CC MB MA    X  Ap Ac Bp X  X  Bc Cp
;
;**** **** **** **** ****

TEMP_LIMIT			EQU 	49	; Temperature measurement ADC value for which main motor power is limited at 80degC (low byte, assuming high byte is 1)
TEMP_LIMIT_STEP		EQU	9	; Temperature measurement ADC value increment for another 10degC




;*********************
; PORT 0 definitions *
;*********************
CcomFET		EQU	7	;o
;			EQU	6	;i
Rcp_In		EQU	5	;i
;			EQU	4	;i
Mux_C		EQU	3	;i
Comp_Com	EQU	2	;i
Mux_B		EQU	1	;i
Mux_A		EQU	0	;i

P0_SKIP_ALL	EQU	0FFh

P0_DIGITAL	EQU	NOT((1 SHL Mux_A)+(1 SHL Mux_B)+(1 SHL Mux_C)+(1 SHL Comp_Com))
P0_INIT		EQU	NOT(1 SHL CcomFET)
P0_PUSHPULL	EQU	(1 SHL CcomFET)
P0_SKIP		EQU	P0_SKIP_ALL

PWM_ACTIVE_HIGH	EQU	1
COMPWM_ACTIVE_HIGH	EQU	1

Set_Pwm_Polarity MACRO
IF FETON_DELAY == 0
	mov	PCA0POL, #00h				; Pwm noninverted
ELSE
; Damping inverted, pwm noninverted
IF PCA0_POWER_MODULE == PCA0CPM0
	mov	PCA0POL, #((COMPWM_ACTIVE_HIGH SHL 1) + (1 - PWM_ACTIVE_HIGH))
ELSE
	mov	PCA0POL, #(((1-PWM_ACTIVE_HIGH) SHL 1) + COMPWM_ACTIVE_HIGH)
ENDIF
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
	PCA0_POWER_MODULE	EQU	PCA0CPM1
	PCA0_POWER_L		EQU	PCA0CPL1
	PCA0_POWER_H		EQU	PCA0CPH1

	PCA0_DAMP_MODULE	EQU	PCA0CPM0
	PCA0_DAMP_L		EQU	PCA0CPL0
	PCA0_DAMP_H		EQU	PCA0CPH0
ENDIF


;*********************
; PORT 1 definitions *
;*********************
;			EQU	7	;i
ApwmFET		EQU	6	;i
AcomFET		EQU	5	;i
BpwmFET		EQU	4	;o
;    		EQU	3	;o
;    		EQU	2	;o
BcomFET		EQU	1	;o
CpwmFET		EQU	0	;o

; todo: hack
P1_SKIP_ALL	EQU 	((1 SHL ApwmFET)+(1 SHL BpwmFET)+(1 SHL CpwmFET)+(1 SHL AcomFET)+(1 SHL BcomFET) + (1 SHL 2) + (1 SHL 3))

P_ApwmFET		EQU	P1.ApwmFET
P_AcomFET		EQU	P1.AcomFET
P_BpwmFET		EQU	P1.BpwmFET
P_BcomFET		EQU	P1.BcomFET
P_CpwmFET		EQU	P1.CpwmFET
P_CcomFET		EQU	P0.CcomFET

; Note: currently all comparator pins (Comp_ and Mux_) must be on the same port
COMP_PORT		EQU	0

ALL_FETS_ON_PORT1	EQU	0

$include (Base.inc)

P1_DIGITAL	EQU	(1 SHL ApwmFET)+(1 SHL BpwmFET)+(1 SHL CpwmFET)+(1 SHL AcomFET)+(1 SHL BcomFET)
P1_INIT		EQU 	00h
P1_PUSHPULL	EQU	(1 SHL ApwmFET)+(1 SHL BpwmFET)+(1 SHL CpwmFET)+(1 SHL AcomFET)+(1 SHL BcomFET)
P1_SKIP		EQU	P1_SKIP_ALL



Set_Pwm_A MACRO
IF FETON_DELAY == 0
	cON	P_AcomFET
	mov	P0SKIP, #P0_SKIP_ALL
	mov	P1SKIP, #(P1_SKIP_ALL AND (NOT (1 SHL ApwmFET)))
ELSE
	mov	P0SKIP, #P0_SKIP_ALL
	mov	P1SKIP, #(P1_SKIP_ALL AND (NOT ((1 SHL ApwmFET)+(1 SHL AcomFET))))
ENDIF
ENDM
Set_Pwm_B MACRO
IF FETON_DELAY == 0
	cON	P_BcomFET
	mov	P0SKIP, #P0_SKIP_ALL
	mov	P1SKIP, #(P1_SKIP_ALL AND (NOT (1 SHL BpwmFET)))
ELSE
	mov	P0SKIP, #P0_SKIP_ALL
	mov	P1SKIP, #(P1_SKIP_ALL AND (NOT ((1 SHL BpwmFET)+(1 SHL BcomFET))))
ENDIF
ENDM
Set_Pwm_C MACRO
IF FETON_DELAY == 0
	cON	P_CcomFET
	mov	P0SKIP, #P0_SKIP_ALL
	mov	P1SKIP, #(P1_SKIP_ALL AND (NOT (1 SHL CpwmFET)))
ELSE
	mov	P0SKIP, #(P0_SKIP_ALL AND (NOT (1 SHL CcomFET)))
	mov	P1SKIP, #(P1_SKIP_ALL AND (NOT (1 SHL CpwmFET)))
ENDIF
ENDM
Set_Pwms_Off MACRO
	mov	P0SKIP, #P0_SKIP_ALL
	mov	P1SKIP, #P1_SKIP_ALL
ENDM




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
