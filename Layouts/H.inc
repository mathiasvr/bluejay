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
; Hardware definition file "H".
; RC X  X  X  MA MB CC MC    X  Ap Bp Cp X  Ac Bc Cc
;
;**** **** **** **** ****

PWM_ACTIVE_HIGH	EQU	1		; Pwm non-inverted
COMPWM_ACTIVE_HIGH	EQU	1		; Damping inverted

; Note: currently all comparator pins (Comp_ and Mux_) must be on the same port
COMPARATOR_PORT	EQU	0

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
; PORT 0 definitions *
;*********************
Rcp_In		EQU	7	;i
;			EQU	6	;i
;  			EQU	5	;i
;			EQU	4	;i
A_Mux		EQU	3	;i
B_Mux		EQU	2	;i
V_Mux		EQU	1	;i
C_Mux		EQU	0	;i

P0_DIGITAL	EQU	NOT((1 SHL A_Mux) + (1 SHL B_Mux) + (1 SHL C_Mux) + (1 SHL V_Mux))
P0_INIT		EQU	0FFh
P0_PUSHPULL	EQU	0
P0_SKIP		EQU	0FFh


;*********************
; PORT 1 definitions *
;*********************
;			EQU	7	;i
A_pwm		EQU	6	;o
B_pwm		EQU	5	;o
C_pwm		EQU	4	;o
;			EQU	3	;i
A_com		EQU	2	;o
B_com		EQU	1	;o
C_com		EQU	0	;o


P1_DIGITAL	EQU	(1 SHL A_pwm) + (1 SHL B_pwm) + (1 SHL C_pwm) + (1 SHL A_com) + (1 SHL B_com) + (1 SHL C_com)
P1_INIT		EQU	00h
P1_PUSHPULL	EQU	(1 SHL A_pwm) + (1 SHL B_pwm) + (1 SHL C_pwm) + (1 SHL A_com) + (1 SHL B_com) + (1 SHL C_com)
P1_SKIP		EQU	0FFh


;*********************
; PORT 2 definitions *
;*********************
DebugPin		EQU	0	;o

P2_DIGITAL	EQU	(1 SHL DebugPin)
P2_PUSHPULL	EQU	(1 SHL DebugPin)
P2_SKIP		EQU	0FFh


;**** **** **** **** ****
; Inherit base layout
;**** **** **** **** ****
$include (Base.inc)
