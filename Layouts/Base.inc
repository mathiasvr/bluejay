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
; Base layout
;
; The inheriting layout should
; - Specify PWM_ACTIVE_HIGH, COM_ACTIVE_HIGH and COMPARATOR_PORT
; - Set CUSTOM_* flags to override default implementation
;
;**** **** **** **** ****


;**** **** **** **** ****
; Bootloader definitions
;**** **** **** **** ****
; Note: The RTX pin must be on port 0 because we use the IT01CF register for interrupts
RTX_PORT		EQU	P0				; Receive/Transmit port
RTX_MDOUT		EQU	P0MDOUT			; Set to 1 for PUSHPULL
RTX_MDIN		EQU	P0MDIN			; Set to 1 for DIGITAL
RTX_SKIP		EQU	P0SKIP			; Set to 1 for SKIP
RTX_PIN		EQU	Rcp_In			; RTX pin


;**** **** **** **** ****
; PWM pin routing and polarity setup
;**** **** **** **** ****
$if NOT CUSTOM_PWM_SETUP

Initialize_Crossbar MACRO
	mov	XBR2, #40h				;; Crossbar enabled
	mov	XBR1, #02h				;; CEX0 and CEX1 routed to pins
ENDM

Set_Pwm_Polarity MACRO
IF PCA0CPM_POWER == PCA0CPM0
	mov	PCA0POL, #((COM_ACTIVE_HIGH SHL 1) + (1 - PWM_ACTIVE_HIGH))
ELSE
	mov	PCA0POL, #(((1 - PWM_ACTIVE_HIGH) SHL 1) + COM_ACTIVE_HIGH)
ENDIF
ENDM

$endif


;**** **** **** **** ****
; PWM channels and updating
;**** **** **** **** ****
$if NOT CUSTOM_PWM_UPDATE

Enable_Power_Pwm_Module MACRO
IF DEADTIME == 0
	mov	PCA0CPM_POWER, #4Ah		;; Enable comparator of module, enable match, set pwm mode
ELSE
	mov	PCA0CPM_POWER, #42h		;; Enable comparator of module, set pwm mode
ENDIF
ENDM

Enable_Damp_Pwm_Module MACRO
IF DEADTIME == 0
	mov	PCA0CPM_DAMP, #00h		;; Disable
ELSE
	mov	PCA0CPM_DAMP, #42h		;; Enable comparator of module, set pwm mode
ENDIF
ENDM

Set_Power_Pwm_Reg_L MACRO value
	mov	PCA0CPL_POWER, value
ENDM

Set_Power_Pwm_Reg_H MACRO value
	mov	PCA0CPH_POWER, value
ENDM

Set_Damp_Pwm_Reg_L MACRO value
	mov	PCA0CPL_DAMP, value
ENDM

Set_Damp_Pwm_Reg_H MACRO value
	mov	PCA0CPH_DAMP, value
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

$endif

Read_Comp_Out MACRO
	mov	A, CMP_CN0				;; Read comparator output
ENDM

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


; Toggle FETs 'on' and 'off'
IF PWM_ACTIVE_HIGH == 1				; PWM FET active high
pON	LIT	'setb'
pOFF	LIT	'clr'
ELSE								; PWM FET active low
pON	LIT	'clr'
pOFF	LIT	'setb'
ENDIF

IF COM_ACTIVE_HIGH == 1				; COM FET active high
cON	LIT	'setb'
cOFF	LIT	'clr'
ELSE								; COM FET active low
cON	LIT	'clr'
cOFF	LIT	'setb'
ENDIF


;**** **** **** **** ****
; PWM phase change
;**** **** **** **** ****
$if NOT CUSTOM_PWM_PHASE

; All pwm and complementary pwm pins must be on port 1 to use the base code below
P_A_pwm		EQU	P1.A_pwm
P_A_com		EQU	P1.A_com
P_B_pwm		EQU	P1.B_pwm
P_B_com		EQU	P1.B_com
P_C_pwm		EQU	P1.C_pwm
P_C_com		EQU	P1.C_com

Set_Pwm_A MACRO
IF DEADTIME == 0
	cON	P_A_com
	mov	P1SKIP, #(NOT (1 SHL A_pwm))
ELSE
	mov	P1SKIP, #(NOT ((1 SHL A_pwm) + (1 SHL A_com)))
ENDIF
ENDM

Set_Pwm_B MACRO
IF DEADTIME == 0
	cON	P_B_com
	mov	P1SKIP, #(NOT (1 SHL B_pwm))
ELSE
	mov	P1SKIP, #(NOT ((1 SHL B_pwm) + (1 SHL B_com)))
ENDIF
ENDM

Set_Pwm_C MACRO
IF DEADTIME == 0
	cON	P_C_com
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

A_Pwm_Fet_On MACRO
	pON	P_A_pwm
IF DEADTIME == 0
	cON	P_A_com
ENDIF
ENDM

A_Pwm_Fet_Off MACRO
IF DEADTIME != 0
	pOFF	P_A_pwm
ELSE
	cOFF	P_A_com
ENDIF
ENDM

B_Pwm_Fet_On MACRO
	pON	P_B_pwm
IF DEADTIME == 0
	cON	P_B_com
ENDIF
ENDM

B_Pwm_Fet_Off MACRO
IF DEADTIME != 0
	pOFF	P_B_pwm
ELSE
	cOFF	P_B_com
ENDIF
ENDM

C_Pwm_Fet_On MACRO
	pON	P_C_pwm
IF DEADTIME == 0
	cON	P_C_com
ENDIF
ENDM

C_Pwm_Fet_Off MACRO
IF DEADTIME != 0
	pOFF	P_C_pwm
ELSE
	cOFF	P_C_com
ENDIF
ENDM

All_Pwm_Fets_Off MACRO
	A_Pwm_Fet_Off
	B_Pwm_Fet_Off
	C_Pwm_Fet_Off
ENDM


A_Com_Fet_On MACRO
IF DEADTIME == 0
	pOFF	P_A_pwm
ENDIF
	cON	P_A_com
ENDM

A_Com_Fet_Off MACRO
	cOFF	P_A_com
ENDM

B_Com_Fet_On MACRO
IF DEADTIME == 0
	pOFF	P_B_pwm
ENDIF
	cON	P_B_com
ENDM

B_Com_Fet_Off MACRO
	cOFF	P_B_com
ENDM

C_Com_Fet_On MACRO
IF DEADTIME == 0
	pOFF	P_C_pwm
ENDIF
	cON	P_C_com
ENDM

C_Com_Fet_Off MACRO
	cOFF	P_C_com
ENDM

All_Com_Fets_Off MACRO
	A_Com_Fet_Off
	B_Com_Fet_Off
	C_Com_Fet_Off
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
	mov	ADC0CN0, #90h				;; Enable ADC and initiate conversion
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
