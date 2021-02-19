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
; Base layout
;
; The inheriting layout should
; - Specify PWM_ACTIVE_HIGH, COMPWM_ACTIVE_HIGH and COMPARATOR_PORT
; - Set CUSTOM_* flags to override default implementation
;
;**** **** **** **** ****


;**** **** **** **** ****
; Bootloader definitions
;**** **** **** **** ****
RTX_PORT		EQU	P0				; Receive/Transmit port
RTX_MDOUT		EQU	P0MDOUT			; Set to 1 for PUSHPULL
RTX_MDIN		EQU	P0MDIN			; Set to 1 for DIGITAL
RTX_SKIP		EQU	P0SKIP			; Set to 1 for SKIP
RTX_PIN		EQU	Rcp_In			; RTX pin


;**** **** **** **** ****
; PWM pin routing and polarity setup
;**** **** **** **** ****
$if NOT CUSTOM_PWM_SETUP

Initialize_Xbar MACRO
	mov	XBR2, #40h				;; Xbar enabled
	mov	XBR1, #02h				;; CEX0 and CEX1 routed to pins
ENDM

Set_Pwm_Polarity MACRO
IF PCA0_POWER_MODULE == PCA0CPM0
	mov	PCA0POL, #((COMPWM_ACTIVE_HIGH SHL 1) + (1 - PWM_ACTIVE_HIGH))
ELSE
	mov	PCA0POL, #(((1 - PWM_ACTIVE_HIGH) SHL 1) + COMPWM_ACTIVE_HIGH)
ENDIF
ENDM

$endif


;**** **** **** **** ****
; PWM channels and updating
;**** **** **** **** ****
$if NOT CUSTOM_PWM_UPDATE

Enable_Power_Pwm_Module MACRO
IF FETON_DELAY == 0
	mov	PCA0_POWER_MODULE, #4Ah		;; Enable comparator of module, enable match, set pwm mode
ELSE
	mov	PCA0_POWER_MODULE, #42h		;; Enable comparator of module, set pwm mode
ENDIF
ENDM

Enable_Damp_Pwm_Module MACRO
IF FETON_DELAY == 0
	mov	PCA0_DAMP_MODULE, #00h		;; Disable
ELSE
	mov	PCA0_DAMP_MODULE, #42h		;; Enable comparator of module, set pwm mode
ENDIF
ENDM

Set_Power_Pwm_Reg_L MACRO value
	mov	PCA0_POWER_L, value
ENDM

Set_Power_Pwm_Reg_H MACRO value
	mov	PCA0_POWER_H, value
ENDM

Set_Damp_Pwm_Reg_L MACRO value
	mov	PCA0_DAMP_L, value
ENDM

Set_Damp_Pwm_Reg_H MACRO value
	mov	PCA0_DAMP_H, value
ENDM

$endif


;**** **** **** **** ****
; Comparator setup and phase change
;**** **** **** **** ****
IF COMPARATOR_PORT == 0
CMP_CN0		EQU	CMP0CN0
CMP_MD		EQU	CMP0MD
CMP_MX		EQU	CMP0MX
ELSE
CMP_CN0		EQU	CMP1CN0
CMP_MD		EQU	CMP1MD
CMP_MX		EQU	CMP1MX
ENDIF

$if NOT CUSTOM_COMP_SETUP

Initialize_Comparator MACRO
	mov	CMP_CN0, #80h				;; Comparator enabled, no hysteresis
	mov	CMP_MD, #00h				;; Comparator response time 100ns
ENDM

Read_Comp_Out MACRO
	mov	A, CMP_CN0				;; Read comparator output
ENDM

$endif

; Set comparator multiplexer to phase A
Set_Comp_Phase_A MACRO
	mov	CMP_MX, #((A_Mux SHL 4) + V_Mux)
ENDM

; Set comparator multiplexer to phase B
Set_Comp_Phase_B MACRO
	mov	CMP_MX, #((B_Mux SHL 4) + V_Mux)
ENDM

; Set comparator multiplexer to phase C
Set_Comp_Phase_C MACRO
	mov	CMP_MX, #((C_Mux SHL 4) + V_Mux)
ENDM


;**** **** **** **** ****
; PWM phase change
;**** **** **** **** ****
$if NOT CUSTOM_PWM_PHASE

; All pwm and com pins must be on port 1
P_ApwmFET		EQU	P1.A_pwm
P_AcomFET		EQU	P1.A_com
P_BpwmFET		EQU	P1.B_pwm
P_BcomFET		EQU	P1.B_com
P_CpwmFET		EQU	P1.C_pwm
P_CcomFET		EQU	P1.C_com

Set_Pwm_A MACRO
IF FETON_DELAY == 0
	cON	P_AcomFET
	mov	P1SKIP, #(NOT (1 SHL A_pwm))
ELSE
	mov	P1SKIP, #(NOT ((1 SHL A_pwm) + (1 SHL A_com)))
ENDIF
ENDM

Set_Pwm_B MACRO
IF FETON_DELAY == 0
	cON	P_BcomFET
	mov	P1SKIP, #(NOT (1 SHL B_pwm))
ELSE
	mov	P1SKIP, #(NOT ((1 SHL B_pwm) + (1 SHL B_com)))
ENDIF
ENDM

Set_Pwm_C MACRO
IF FETON_DELAY == 0
	cON	P_CcomFET
	mov	P1SKIP, #(NOT (1 SHL C_pwm))
ELSE
	mov	P1SKIP, #(NOT ((1 SHL C_pwm) + (1 SHL C_com)))
ENDIF
ENDM

Set_Pwms_Off MACRO
	mov	P1SKIP, #0FFh
ENDM

$endif


;**** **** **** **** ****
; Toggling FETs on/off
;**** **** **** **** ****
$if NOT CUSTOM_FET_TOGGLING

IF PWM_ACTIVE_HIGH == 1				; PWM FET active high
pON	LIT	'setb'
pOFF	LIT	'clr'
ELSE								; PWM FET active low
pON	LIT	'clr'
pOFF	LIT	'setb'
ENDIF

IF COMPWM_ACTIVE_HIGH == 1			; COM FET active high
cON	LIT	'setb'
cOFF	LIT	'clr'
ELSE								; COM FET active low
cON	LIT	'clr'
cOFF	LIT	'setb'
ENDIF

ApwmFET_on MACRO
	pON	P_ApwmFET
IF FETON_DELAY == 0
	cON	P_AcomFET
ENDIF
ENDM

ApwmFET_off MACRO
IF FETON_DELAY != 0
	pOFF	P_ApwmFET
ELSE
	cOFF	P_AcomFET
ENDIF
ENDM

BpwmFET_on MACRO
	pON	P_BpwmFET
IF FETON_DELAY == 0
	cON	P_BcomFET
ENDIF
ENDM

BpwmFET_off MACRO
IF FETON_DELAY != 0
	pOFF	P_BpwmFET
ELSE
	cOFF	P_BcomFET
ENDIF
ENDM

CpwmFET_on MACRO
	pON	P_CpwmFET
IF FETON_DELAY == 0
	cON	P_CcomFET
ENDIF
ENDM

CpwmFET_off MACRO
IF FETON_DELAY != 0
	pOFF	P_CpwmFET
ELSE
	cOFF	P_CcomFET
ENDIF
ENDM

All_pwmFETs_Off MACRO
	ApwmFET_off
	BpwmFET_off
	CpwmFET_off
ENDM


AcomFET_on MACRO
IF FETON_DELAY == 0
	pOFF	P_ApwmFET
ENDIF
	cON	P_AcomFET
ENDM

AcomFET_off MACRO
	cOFF	P_AcomFET
ENDM

BcomFET_on MACRO
IF FETON_DELAY == 0
	pOFF	P_BpwmFET
ENDIF
	cON	P_BcomFET
ENDM

BcomFET_off MACRO
	cOFF	P_BcomFET
ENDM

CcomFET_on MACRO
IF FETON_DELAY == 0
	pOFF	P_CpwmFET
ENDIF
	cON	P_CcomFET
ENDM

CcomFET_off MACRO
	cOFF	P_CcomFET
ENDM

All_comFETs_Off MACRO
	AcomFET_off
	BcomFET_off
	CcomFET_off
ENDM

$endif


;**** **** **** **** ****
; ADC and temperature measurement
;**** **** **** **** ****
TEMP_LIMIT		EQU	49			; Temperature measurement ADC value for which main motor power is limited at 80degC (low byte, assuming high byte is 1)
TEMP_LIMIT_STEP	EQU	9			; Temperature measurement ADC value increment for another 10degC

Initialize_Adc MACRO
	mov	REF0CN, #0Ch				;; Set vdd (3.3V) as reference. Enable temp sensor and bias
IF MCU_48MHZ == 0
	mov	ADC0CF, #59h				;; ADC clock 2MHz, PGA gain 1
ELSE
	mov	ADC0CF, #0B9h				;; ADC clock 2MHz, PGA gain 1
ENDIF
	mov	ADC0MX, #10h				;; Select temp sensor input
	mov	ADC0CN0, #80h				;; ADC enabled
	mov	ADC0CN1, #01h				;; Common mode buffer enabled
ENDM

Start_Adc MACRO
	mov	ADC0CN0, #90h				;; ADC start
ENDM

Read_Adc_Result MACRO
	mov	Temp1, ADC0L
	mov	Temp2, ADC0H
ENDM

Stop_Adc MACRO
ENDM


;**** **** **** **** ****
; LEDs
;**** **** **** **** ****
$if NOT CUSTOM_LED

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

$endif
