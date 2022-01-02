;**** **** **** **** ****
;
; Bluejay digital ESC firmware for controlling brushless motors in multirotors
;
; Copyright 2020-2022 Mathias Rasmussen
; Copyright 2011-2017 Steffen Skaug
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
; Hardware definition file "C"
; Ac Ap MC MB MA CC X  RC    X  X  X  X  Cc Cp Bc Bp
;
;**** **** **** **** ****

PWM_ACTIVE_HIGH	EQU	1		; Pwm non-inverted
COM_ACTIVE_HIGH	EQU	1		; Damping inverted

COMPARATOR_PORT	EQU	0		; All comparator (mux) pins must be on the same port
COMPARATOR_INVERT	EQU	0		; Comparator output non-inverted

IF DEADTIME == 0
	PCA0CPM_POWER	EQU	PCA0CPM0
	PCA0CPL_POWER	EQU	PCA0CPL0
	PCA0CPH_POWER	EQU	PCA0CPH0

	PCA0CPM_DAMP	EQU	PCA0CPM1
	PCA0CPL_DAMP	EQU	PCA0CPL1
	PCA0CPH_DAMP	EQU	PCA0CPH1
ELSE
	PCA0CPM_POWER	EQU	PCA0CPM0
	PCA0CPL_POWER	EQU	PCA0CPL0
	PCA0CPH_POWER	EQU	PCA0CPH0

	PCA0CPM_DAMP	EQU	PCA0CPM1
	PCA0CPL_DAMP	EQU	PCA0CPL1
	PCA0CPH_DAMP	EQU	PCA0CPH1
ENDIF


;*********************
; PORT 0 definitions *
;*********************
A_Com		EQU	7
A_Pwm		EQU	6
C_Mux		EQU	5
B_Mux		EQU	4
A_Mux		EQU	3
V_Mux		EQU	2
;			EQU	1
RTX_PIN		EQU	0


P0_DIGITAL	EQU	NOT((1 SHL A_Mux) + (1 SHL B_Mux) + (1 SHL C_Mux) + (1 SHL V_Mux))
P0_INIT		EQU	NOT((1 SHL A_Pwm) + (1 SHL A_Com))
P0_PUSHPULL	EQU	(1 SHL A_Pwm) + (1 SHL A_Com)
P0_SKIP		EQU	0FFh


;*********************
; PORT 1 definitions *
;*********************
;			EQU	7
;			EQU	6
;			EQU	5
;			EQU	4
C_Com		EQU	3
C_Pwm		EQU	2
B_Com		EQU	1
B_Pwm		EQU	0


P1_DIGITAL	EQU	(1 SHL B_Pwm) + (1 SHL C_Pwm) + (1 SHL B_Com) + (1 SHL C_Com)
P1_INIT		EQU	00h
P1_PUSHPULL	EQU	(1 SHL B_Pwm) + (1 SHL C_Pwm) + (1 SHL B_Com) + (1 SHL C_Com)
P1_SKIP		EQU	0FFh


;*********************
; PORT 2 definitions *
;*********************
DebugPin		EQU	0

P2_DIGITAL	EQU	(1 SHL DebugPin)
P2_PUSHPULL	EQU	(1 SHL DebugPin)
P2_SKIP		EQU	(1 SHL DebugPin)


;**** **** **** **** ****
; PWM Phase
;**** **** **** **** ****
P_A_Pwm		EQU	P0.A_Pwm
P_A_Com		EQU	P0.A_Com
P_B_Pwm		EQU	P1.B_Pwm
P_B_Com		EQU	P1.B_Com
P_C_Pwm		EQU	P1.C_Pwm
P_C_Com		EQU	P1.C_Com

Set_Pwm_Phase_A MACRO
IF DEADTIME == 0
	cON	P_A_Com
	mov	P0SKIP, #(NOT (1 SHL A_Pwm))
	mov	P1SKIP, #0FFh
ELSE
	mov	P0SKIP, #(NOT ((1 SHL A_Pwm) + (1 SHL A_Com)))
	mov	P1SKIP, #0FFh
ENDIF
ENDM

Set_Pwm_Phase_B MACRO
IF DEADTIME == 0
	cON	P_B_Com
	mov	P0SKIP, #0FFh
	mov	P1SKIP, #(NOT (1 SHL B_Pwm))
ELSE
	mov	P0SKIP, #0FFh
	mov	P1SKIP, #(NOT ((1 SHL B_Pwm) + (1 SHL B_Com)))
ENDIF
ENDM

Set_Pwm_Phase_C MACRO
IF DEADTIME == 0
	cON	P_C_Com
	mov	P0SKIP, #0FFh
	mov	P1SKIP, #(NOT (1 SHL C_Pwm))
ELSE
	mov	P0SKIP, #0FFh
	mov	P1SKIP, #(NOT ((1 SHL C_Pwm) + (1 SHL C_Com)))
ENDIF
ENDM

Set_All_Pwm_Phases_Off MACRO
	mov	P0SKIP, #0FFh
	mov	P1SKIP, #0FFh
ENDM


;**** **** **** **** ****
; Inherit base layout
;**** **** **** **** ****
$set(CUSTOM_PWM_PHASE)
$include (Base.inc)
