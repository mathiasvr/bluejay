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
; Hardware definition file "I"
; X  X  RC X  MC MB MA CC    X  X  Ac Bc Cc Ap Bp Cp
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
;			EQU	7
;			EQU	6
RTX_PIN		EQU	5
;			EQU	4
C_Mux		EQU	3
B_Mux		EQU	2
A_Mux		EQU	1
V_Mux		EQU	0

P0_DIGITAL	EQU	NOT((1 SHL A_Mux) + (1 SHL B_Mux) + (1 SHL C_Mux) + (1 SHL V_Mux))
P0_INIT		EQU	0FFh
P0_PUSHPULL	EQU	0
P0_SKIP		EQU	0FFh


;*********************
; PORT 1 definitions *
;*********************
;			EQU	7
;			EQU	6
A_Com		EQU	5
B_Com		EQU	4
C_Com		EQU	3
A_Pwm		EQU	2
B_Pwm		EQU	1
C_Pwm		EQU	0


P1_DIGITAL	EQU	(1 SHL A_Pwm) + (1 SHL B_Pwm) + (1 SHL C_Pwm) + (1 SHL A_Com) + (1 SHL B_Com) + (1 SHL C_Com)
P1_INIT		EQU	00h
P1_PUSHPULL	EQU	(1 SHL A_Pwm) + (1 SHL B_Pwm) + (1 SHL C_Pwm) + (1 SHL A_Com) + (1 SHL B_Com) + (1 SHL C_Com)
P1_SKIP		EQU	0FFh


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
$include (Base.inc)
