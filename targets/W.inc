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
; Hardware definition file "W". This is for tristate input style FET driver chips
; RC MC MB X CC MA X X     X  Ap Bp Cp X X X X
;
;**** **** **** **** ****

TEMP_LIMIT			EQU	49	; Temperature measurement ADC value for which main motor power is limited at 80degC (low byte, assuming high byte is 1)
TEMP_LIMIT_STEP		EQU	9	; Temperature measurement ADC value increment for another 10degC

;**** **** **** **** ****
; Bootloader definitions
;**** **** **** **** ****
RTX_PORT		  		EQU 	P0		; Receive/Transmit port
RTX_MDOUT				EQU	P0MDOUT	; Set to 1 for PUSHPULL
RTX_MDIN				EQU	P0MDIN	; Set to 1 for DIGITAL
RTX_SKIP				EQU	P0SKIP	; Set to 1 for SKIP
RTX_PIN				EQU 	7		; RTX pin


;*********************
; PORT 0 definitions *
;*********************
Rcp_In		EQU	7	;i
C_Mux		EQU	6	;i
B_Mux		EQU	5	;i
;		EQU	4	;i
Comp_Com	EQU	3	;i
A_Mux		EQU	2	;i
;		EQU	1	;i
;		EQU	0	;i

P0_DIGITAL	EQU	NOT((1 SHL A_Mux) + (1 SHL B_Mux) + (1 SHL C_Mux) + (1 SHL Comp_Com))
P0_INIT		EQU	0FFh
P0_PUSHPULL	EQU	0
P0_SKIP		EQU	0FFh


Set_Pwm_Polarity MACRO
IF FETON_DELAY == 0
	mov	PCA0POL, #00h				; Pwm noninverted
ELSE
	mov	PCA0POL, #01h				; Damping inverted, pwm noninverted
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
;		EQU	7	;i
A_pwm		EQU	6	;o
B_pwm		EQU	5	;o
C_pwm		EQU	4	;o
;		EQU	3	;i
;		EQU	2	;i
;		EQU	1	;i
;		EQU	0	;i
; pwm outputs start as analog in -> floating
; this ensures all mosfet drivers start with floating outputs
P1_DIGITAL	EQU	NOT((1 SHL A_pwm) + (1 SHL B_pwm) + (1 SHL C_pwm))
P1_INIT		EQU	00h
P1_PUSHPULL	EQU	((1 SHL A_pwm) + (1 SHL B_pwm) + (1 SHL C_pwm))
;
P1_SKIP		EQU    0FFh


ApwmFET_on MACRO
	setb     P1.A_pwm		; set pin to high
	orl P1MDIN, #(1 SHL A_pwm)	; enable pin driver
ENDM
ApwmFET_off MACRO
	anl P1MDIN, #(NOT(1 SHL A_pwm))	; analog in -> pullup, driver and digital in is disable = floating
ENDM
BpwmFET_on MACRO
	setb P1.B_pwm		; set pin to high
	orl P1MDIN, #(1 SHL B_pwm)	; enable pin driver
ENDM
BpwmFET_off MACRO
	anl P1MDIN, #(NOT(1 SHL B_pwm))	; analog in -> pullup, driver and digital in is disable = floating
ENDM
CpwmFET_on MACRO
	setb     P1.C_pwm		; set pin to high
	orl P1MDIN, #(1 SHL C_pwm)	; enable pin driver
ENDM
CpwmFET_off MACRO
	anl P1MDIN, #(NOT(1 SHL C_pwm))	; analog in -> pullup, driver and digital in is disable = floating
ENDM
All_pwmFETs_Off MACRO
	anl P1MDIN, #(NOT((1 SHL A_pwm) + (1 SHL B_pwm) + (1 SHL C_pwm)))	; analog in -> pullup, driver and digital in is disable = floating
ENDM

AcomFET_on MACRO
	clr P1.A_pwm			; set pin to low
	orl P1MDIN, #(1 SHL A_pwm)	; enable pin driver
ENDM
AcomFET_off MACRO
	anl P1MDIN, #(NOT(1 SHL A_pwm))	; analog in -> pullup, driver and digital in is disable = floating
ENDM
BcomFET_on MACRO
	clr P1.B_pwm			; set pin to low
	orl P1MDIN, #(1 SHL B_pwm)	; enable pin driver
ENDM
BcomFET_off MACRO
	anl P1MDIN, #(NOT(1 SHL B_pwm))	; analog in -> pullup, driver and digital in is disable = floating
ENDM
CcomFET_on MACRO
	clr P1.C_pwm			; set pin to low
	orl P1MDIN, #(1 SHL C_pwm)	; enable pin driver
ENDM
CcomFET_off MACRO
	anl P1MDIN, #(NOT(1 SHL C_pwm))	; analog in -> pullup, driver and digital in is disable = floating
ENDM
All_comFETs_Off MACRO
	anl P1MDIN, #(NOT((1 SHL A_pwm) + (1 SHL B_pwm) + (1 SHL C_pwm)))	; analog in -> pullup, driver and digital in is disable = floating
ENDM
Set_Pwm_A MACRO
	mov	P1SKIP, #(NOT(1 SHL A_pwm));
	orl	P1MDIN, #(1 SHL A_pwm)	; enable pin driver
ENDM
Set_Pwm_B MACRO
	mov	P1SKIP, #(NOT(1 SHL B_pwm));
	orl	P1MDIN, #(1 SHL B_pwm)	; enable pin driver
ENDM
Set_Pwm_C MACRO
	mov	P1SKIP, #(NOT(1 SHL C_pwm));
	orl	P1MDIN, #(1 SHL C_pwm)	; enable pin driver
ENDM
Set_Pwms_Off MACRO
	mov	P1SKIP, #P1_SKIP;
ENDM



Set_Comp_Phase_A MACRO
	mov	CMP0MX, #((A_Mux) SHL 4)+((Comp_Com) SHL 0);
ENDM
Set_Comp_Phase_B MACRO
	mov	CMP0MX, #((B_Mux) SHL 4)+((Comp_Com) SHL 0);
ENDM
Set_Comp_Phase_C MACRO
	mov	CMP0MX, #((C_Mux) SHL 4)+((Comp_Com) SHL 0);
ENDM
Read_Comp_Out MACRO
	mov	A, CMP0CN0	; Read comparator output
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
Initialize_Xbar MACRO
	mov	XBR2, #40h	; Xbar enabled
	mov	XBR1, #02h	; CEX0 and CEX1 routed to pins
ENDM
Initialize_Comparator MACRO
	mov	CMP0CN0, #80h	; Comparator enabled, no hysteresis
	mov	CMP0MD, #00h	; Comparator response time 100ns
ENDM

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
