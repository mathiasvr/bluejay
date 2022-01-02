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
; Hardware definition file "W". This is for tristate input style FET driver chips
; RC MC MB X CC MA X X     X  Ap Bp Cp X X X X
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
	PCA0CPM_POWER	EQU	PCA0CPM1
	PCA0CPL_POWER	EQU	PCA0CPL1
	PCA0CPH_POWER	EQU	PCA0CPH1

	PCA0CPM_DAMP	EQU	PCA0CPM0
	PCA0CPL_DAMP	EQU	PCA0CPL0
	PCA0CPH_DAMP	EQU	PCA0CPH0
ENDIF


;*********************
; PORT 0 definitions *
;*********************
RTX_PIN		EQU	7
C_Mux		EQU	6
B_Mux		EQU	5
;			EQU	4
V_Mux		EQU	3
A_Mux		EQU	2
;			EQU	1
;			EQU	0

P0_DIGITAL	EQU	NOT((1 SHL A_Mux) + (1 SHL B_Mux) + (1 SHL C_Mux) + (1 SHL V_Mux))
P0_INIT		EQU	0FFh
P0_PUSHPULL	EQU	0
P0_SKIP		EQU	0FFh


;*********************
; PORT 1 definitions *
;*********************
;			EQU	7
A_Pwm		EQU	6
B_Pwm		EQU	5
C_Pwm		EQU	4
;			EQU	3
;			EQU	2
;			EQU	1
;			EQU	0


; pwm outputs start as analog in -> floating
; this ensures all mosfet drivers start with floating outputs
P1_DIGITAL	EQU	NOT((1 SHL A_Pwm) + (1 SHL B_Pwm) + (1 SHL C_Pwm))
P1_INIT		EQU	00h
P1_PUSHPULL	EQU	((1 SHL A_Pwm) + (1 SHL B_Pwm) + (1 SHL C_Pwm))
P1_SKIP		EQU	0FFh


A_Pwm_Fet_On MACRO
	setb	P1.A_Pwm				; set pin to high
	orl	P1MDIN, #(1 SHL A_Pwm)	; enable pin driver
ENDM

A_Pwm_Fet_Off MACRO
	anl	P1MDIN, #(NOT(1 SHL A_Pwm))	; analog in -> pullup, driver and digital in is disable = floating
ENDM

B_Pwm_Fet_On MACRO
	setb	P1.B_Pwm				; set pin to high
	orl	P1MDIN, #(1 SHL B_Pwm)	; enable pin driver
ENDM

B_Pwm_Fet_Off MACRO
	anl	P1MDIN, #(NOT(1 SHL B_Pwm))	; analog in -> pullup, driver and digital in is disable = floating
ENDM

C_Pwm_Fet_On MACRO
	setb	P1.C_Pwm				; set pin to high
	orl	P1MDIN, #(1 SHL C_Pwm)	; enable pin driver
ENDM

C_Pwm_Fet_Off MACRO
	anl	P1MDIN, #(NOT(1 SHL C_Pwm))	; analog in -> pullup, driver and digital in is disable = floating
ENDM

All_Pwm_Fets_Off MACRO
	anl	P1MDIN, #(NOT((1 SHL A_Pwm) + (1 SHL B_Pwm) + (1 SHL C_Pwm)))	; analog in -> pullup, driver and digital in is disable = floating
ENDM

A_Com_Fet_On MACRO
	clr	P1.A_Pwm				; set pin to low
	orl	P1MDIN, #(1 SHL A_Pwm)	; enable pin driver
ENDM

A_Com_Fet_Off MACRO
	anl	P1MDIN, #(NOT(1 SHL A_Pwm))	; analog in -> pullup, driver and digital in is disable = floating
ENDM

B_Com_Fet_On MACRO
	clr	P1.B_Pwm				; set pin to low
	orl	P1MDIN, #(1 SHL B_Pwm)	; enable pin driver
ENDM

B_Com_Fet_Off MACRO
	anl	P1MDIN, #(NOT(1 SHL B_Pwm))	; analog in -> pullup, driver and digital in is disable = floating
ENDM

C_Com_Fet_On MACRO
	clr	P1.C_Pwm				; set pin to low
	orl	P1MDIN, #(1 SHL C_Pwm)	; enable pin driver
ENDM

C_Com_Fet_Off MACRO
	anl	P1MDIN, #(NOT(1 SHL C_Pwm))	; analog in -> pullup, driver and digital in is disable = floating
ENDM

All_Com_Fets_Off MACRO
	anl	P1MDIN, #(NOT((1 SHL A_Pwm) + (1 SHL B_Pwm) + (1 SHL C_Pwm)))	; analog in -> pullup, driver and digital in is disable = floating
ENDM

Set_Pwm_Phase_A MACRO
	mov	P1SKIP, #(NOT(1 SHL A_Pwm));
	orl	P1MDIN, #(1 SHL A_Pwm)	; enable pin driver
ENDM

Set_Pwm_Phase_B MACRO
	mov	P1SKIP, #(NOT(1 SHL B_Pwm));
	orl	P1MDIN, #(1 SHL B_Pwm)	; enable pin driver
ENDM

Set_Pwm_Phase_C MACRO
	mov	P1SKIP, #(NOT(1 SHL C_Pwm));
	orl	P1MDIN, #(1 SHL C_Pwm)	; enable pin driver
ENDM

Set_All_Pwm_Phases_Off MACRO
	mov	P1SKIP, #P1_SKIP;
ENDM


;*********************
; PORT 2 definitions *
;*********************
DebugPin		EQU	0

P2_DIGITAL	EQU	(1 SHL DebugPin)
P2_PUSHPULL	EQU	(1 SHL DebugPin)
P2_SKIP		EQU	(1 SHL DebugPin)


;**** **** **** **** ****
; Inherit base layout
;**** **** **** **** ****
$set(CUSTOM_PWM_PHASE, CUSTOM_FET_TOGGLING)
$include (Base.inc)
