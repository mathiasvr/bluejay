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
; Testing only! - using "@" as layout identifier.
; Not BLHeli_S compatible!
;
; Using 3 pwm channels (duplicate damp) to accommodate swapped Bp/Bc pair
; Outputs are open-drain
;
; Am Cm Bm Vm __ RX __ __	Ac Ap Bp Bc Cc Cp __ __
;
;**** **** **** **** ****

PWM_ACTIVE_HIGH	EQU	1		; Pwm non-inverted
COM_ACTIVE_HIGH	EQU	0		; Damping non-inverted

COMPARATOR_PORT	EQU	0		; All comparator (mux) pins must be on the same port

IF DEADTIME == 0
	ERROR_NOT_IMPLEMENTED

ELSE
	PCA0CPM_POWER	EQU	PCA0CPM1
	PCA0CPL_POWER	EQU	PCA0CPL1
	PCA0CPH_POWER	EQU	PCA0CPH1

	PCA0CPM_DAMP	EQU	PCA0CPM0
	PCA0CPL_DAMP	EQU	PCA0CPL0
	PCA0CPH_DAMP	EQU	PCA0CPH0

	PCA0CPM_DAMP2	EQU	PCA0CPM2	; Duplicate damping channel
	PCA0CPL_DAMP2	EQU	PCA0CPL2
	PCA0CPH_DAMP2	EQU	PCA0CPH2
ENDIF

;*********************
; PORT 0 definitions *
;*********************
TMP_0		EQU	7
;			EQU	6
RTX_PIN		EQU	5
;			EQU	4
V_Mux		EQU	3
B_Mux		EQU	2
C_Mux		EQU	1
A_Mux		EQU	0

P0_DIGITAL	EQU	NOT((1 SHL A_Mux) + (1 SHL B_Mux) + (1 SHL C_Mux) + (1 SHL V_Mux))
P0_INIT		EQU	0FFh
P0_PUSHPULL	EQU	0
P0_SKIP		EQU	0FFh


;*********************
; PORT 1 definitions *
;*********************
;			EQU	7
;			EQU	6
C_Pwm		EQU	5
C_Com		EQU	4
B_Com		EQU	3
B_Pwm		EQU	2
A_Pwm		EQU	1
A_Com		EQU	0

P1_DIGITAL	EQU	(1 SHL A_Pwm) + (1 SHL B_Pwm) + (1 SHL C_Pwm) + (1 SHL A_Com) + (1 SHL B_Com) + (1 SHL C_Com)
P1_INIT		EQU	(1 SHL A_Com) + (1 SHL B_Com) + (1 SHL C_Com)	; Active low com fets
P1_PUSHPULL	EQU	0			; All outputs are open-drain
P1_SKIP		EQU	0FFh


;*********************
; PORT 2 definitions *
;*********************
DebugPin		EQU	0

P2_DIGITAL	EQU	(1 SHL DebugPin)
P2_PUSHPULL	EQU	(1 SHL DebugPin)
P2_SKIP		EQU	(1 SHL DebugPin)


;**** **** **** **** ****
; PWM Setup
;**** **** **** **** ****
Initialize_Crossbar MACRO
	mov	XBR2, #40h			;; Crossbar enabled
	mov	XBR1, #03h			;; CEX0, CEX1 and CEX2 routed to pins
ENDM

Set_Pwm_Polarity MACRO
	mov	PCA0POL, #((COM_ACTIVE_HIGH SHL 2) + ((1 - PWM_ACTIVE_HIGH) SHL 1) + COM_ACTIVE_HIGH)
ENDM


;**** **** **** **** ****
; PWM Phase
;**** **** **** **** ****
P_A_Pwm		EQU	P1.A_Pwm
P_A_Com		EQU	P1.A_Com
P_B_Pwm		EQU	P1.B_Pwm
P_B_Com		EQU	P1.B_Com
P_C_Pwm		EQU	P1.C_Pwm
P_C_Com		EQU	P1.C_Com

Set_Pwm_Phase_A MACRO
	mov	P1SKIP, #0FFh			;; Ensure channels on port 1 does not change (swap)
	mov	P0SKIP, #0FFh
	mov	P1SKIP, #(NOT ((1 SHL A_Pwm) + (1 SHL A_Com)))
ENDM

Set_Pwm_Phase_B MACRO
	mov	P1SKIP, #0FFh			;; Ensure channels on port 1 does not change (swap)
	mov	P0SKIP, #(NOT (1 SHL TMP_0))	;; Normal damping in TMP_0
	mov	P1SKIP, #(NOT ((1 SHL B_Pwm) + (1 SHL B_Com)))	;; Power in B_Pwm and duplicate damping in B_Com
ENDM

Set_Pwm_Phase_C MACRO
	mov	P1SKIP, #0FFh			;; Ensure channels on port 1 does not change (swap)
	mov	P0SKIP, #0FFh
	mov	P1SKIP, #(NOT ((1 SHL C_Pwm) + (1 SHL C_Com)))
ENDM

Set_All_Pwm_Phases_Off MACRO
	mov	P1SKIP, #0FFh
	mov	P0SKIP, #0FFh
ENDM


;**** **** **** **** ****
; PWM Update
;**** **** **** **** ****
Enable_Power_Pwm_Module MACRO
	mov	PCA0CPM_POWER, #42h		;; Enable comparator of module, set pwm mode
ENDM

Enable_Damp_Pwm_Module MACRO
	mov	PCA0CPM_DAMP, #42h		;; Enable comparator of module, set pwm mode
	mov	PCA0CPM_DAMP2, #42h		;; Enable comparator of module, set pwm mode
ENDM

Set_Power_Pwm_Reg_L MACRO value
	mov	PCA0CPL_POWER, value
ENDM

Set_Power_Pwm_Reg_H MACRO value
	mov	PCA0CPH_POWER, value
ENDM

Set_Damp_Pwm_Reg_L MACRO value
	mov	PCA0CPL_DAMP, value
	mov	PCA0CPL_DAMP2, value	;; Duplicate damp channel
ENDM

Set_Damp_Pwm_Reg_H MACRO value
	mov	PCA0CPH_DAMP, value
	mov	PCA0CPH_DAMP2, value	;; Duplicate damp channel
ENDM


;**** **** **** **** ****
; Inherit base layout
;**** **** **** **** ****
$set(CUSTOM_PWM_SETUP, CUSTOM_PWM_PHASE, CUSTOM_PWM_UPDATE)
$include (Base.inc)
