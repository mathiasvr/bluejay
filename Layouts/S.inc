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
; Hardware definition file "S". like "O" but Com fets are active high, Pwm fets are active low
; X  X  RC X  CC MA MC MB    X  X  Cc Cp Bc Bp Ac Ap
;
;**** **** **** **** ****

PWM_ACTIVE_HIGH	EQU	1		; Pwm non-inverted
COMPWM_ACTIVE_HIGH	EQU	1		; Damping inverted

; Note: currently all comparator pins (Comp_ and Mux_) must be on the same port
COMPARATOR_PORT	EQU	0

IF FETON_DELAY == 0
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
;			EQU	7
;			EQU	6
Rcp_In		EQU	5
;			EQU	4
V_Mux		EQU	3
A_Mux		EQU	2
C_Mux		EQU	1
B_Mux		EQU	0

P0_DIGITAL	EQU	NOT((1 SHL A_Mux) + (1 SHL B_Mux) + (1 SHL C_Mux) + (1 SHL V_Mux))
P0_INIT		EQU	0FFh
P0_PUSHPULL	EQU	0
P0_SKIP		EQU	0FFh


;*********************
; PORT 1 definitions *
;*********************
;			EQU	7
;			EQU	6
C_pwm		EQU	5
C_com		EQU	4
B_pwm		EQU	3
B_com		EQU	2
A_pwm		EQU	1
A_com		EQU	0


P1_DIGITAL	EQU	(1 SHL A_pwm) + (1 SHL B_pwm) + (1 SHL C_pwm) + (1 SHL A_com) + (1 SHL B_com) + (1 SHL C_com)
P1_INIT		EQU	00h
P1_PUSHPULL	EQU	(1 SHL A_pwm) + (1 SHL B_pwm) + (1 SHL C_pwm) + (1 SHL A_com) + (1 SHL B_com) + (1 SHL C_com)
P1_SKIP		EQU	0FFh


;*********************
; PORT 2 definitions *
;*********************
DebugPin		EQU	0

P2_DIGITAL	EQU	(1 SHL DebugPin)
P2_PUSHPULL	EQU	(1 SHL DebugPin)
P2_SKIP		EQU	0FFh


;**** **** **** **** ****
; Inherit base layout
;**** **** **** **** ****
$include (Base.inc)
