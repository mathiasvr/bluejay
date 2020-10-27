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
; Common definitions for EFM8BB1x/2x based ESCs
;
;**** **** **** **** ****

;*********************
; Device SiLabs EFM8BB1x/2x
;*********************
IF MCU_48MHZ == 0
$include (Silabs/SI_EFM8BB1_Defs.inc)
ELSE
$include (Silabs/SI_EFM8BB2_Defs.inc)
ENDIF

;**** **** **** **** ****
; Uses internal calibrated oscillator set to 24/48Mhz
;**** **** **** **** ****

;**** **** **** **** ****
; ESC selection statements
IF ESCNO == A_
$include (targets/A.inc)	; Select pinout A
ELSEIF ESCNO == B_
$include (targets/B.inc)	; Select pinout B
ELSEIF ESCNO == C_
$include (targets/C.inc)	; Select pinout C
ELSEIF ESCNO == D_
$include (targets/D.inc)	; Select pinout D
ELSEIF ESCNO == E_
$include (targets/E.inc)	; Select pinout E
ELSEIF ESCNO == F_
$include (targets/F.inc)	; Select pinout F
ELSEIF ESCNO == G_
$include (targets/G.inc)	; Select pinout G
ELSEIF ESCNO == H_
$include (targets/H.inc)	; Select pinout H
ELSEIF ESCNO == I_
$include (targets/I.inc)	; Select pinout I
ELSEIF ESCNO == J_
$include (targets/J.inc)	; Select pinout J
ELSEIF ESCNO == K_
$include (targets/K.inc)	; Select pinout K
ELSEIF ESCNO == L_
$include (targets/L.inc)	; Select pinout L
ELSEIF ESCNO == M_
$include (targets/M.inc)	; Select pinout M
ELSEIF ESCNO == N_
$include (targets/N.inc)	; Select pinout N
ELSEIF ESCNO == O_
$include (targets/O.inc)	; Select pinout O
ELSEIF ESCNO == P_
$include (targets/P.inc)	; Select pinout P
ELSEIF ESCNO == Q_
$include (targets/Q.inc)	; Select pinout Q
ELSEIF ESCNO == R_
$include (targets/R.inc)	; Select pinout R
ELSEIF ESCNO == S_
$include (targets/S.inc)	; Select pinout S
ELSEIF ESCNO == T_
$include (targets/T.inc)	; Select pinout T
ELSEIF ESCNO == U_
$include (targets/U.inc)	; Select pinout U
ELSEIF ESCNO == V_
$include (targets/V.inc)	; Select pinout V
ELSEIF ESCNO == W_
$include (targets/W.inc)	; Select pinout W
ENDIF

;**** **** **** **** ****
; Constant definitions
;**** **** **** **** ****
ESC_LETTER	EQU	40h + ESCNO

IF MCU_48MHZ == 0
MCU_MHZ_LETTER	EQU	"L"
ELSE
MCU_MHZ_LETTER	EQU	"H"
ENDIF

CSEG AT 1A40h
IF FETON_DELAY == 0
Eep_ESC_Layout:		DB	"#",ESC_LETTER,"_",MCU_MHZ_LETTER,"_00#        "	; ESC layout tag
ELSEIF FETON_DELAY == 5
Eep_ESC_Layout:		DB	"#",ESC_LETTER,"_",MCU_MHZ_LETTER,"_05#        "
ELSEIF FETON_DELAY == 10
Eep_ESC_Layout:		DB	"#",ESC_LETTER,"_",MCU_MHZ_LETTER,"_10#        "
ELSEIF FETON_DELAY == 15
Eep_ESC_Layout:		DB	"#",ESC_LETTER,"_",MCU_MHZ_LETTER,"_15#        "
ELSEIF FETON_DELAY == 20
Eep_ESC_Layout:		DB	"#",ESC_LETTER,"_",MCU_MHZ_LETTER,"_20#        "
ELSEIF FETON_DELAY == 25
Eep_ESC_Layout:		DB	"#",ESC_LETTER,"_",MCU_MHZ_LETTER,"_25#        "
ELSEIF FETON_DELAY == 30
Eep_ESC_Layout:		DB	"#",ESC_LETTER,"_",MCU_MHZ_LETTER,"_30#        "
ELSEIF FETON_DELAY == 40
Eep_ESC_Layout:		DB	"#",ESC_LETTER,"_",MCU_MHZ_LETTER,"_40#        "
ELSEIF FETON_DELAY == 50
Eep_ESC_Layout:		DB	"#",ESC_LETTER,"_",MCU_MHZ_LETTER,"_50#        "
ELSEIF FETON_DELAY == 70
Eep_ESC_Layout:		DB	"#",ESC_LETTER,"_",MCU_MHZ_LETTER,"_70#        "
ELSEIF FETON_DELAY == 90
Eep_ESC_Layout:		DB	"#",ESC_LETTER,"_",MCU_MHZ_LETTER,"_90#        "
ENDIF

IF MCU_48MHZ == 0
CSEG AT 1A50h
Eep_ESC_MCU:			DB	"#BLHELI$EFM8B10#"	; Project and MCU tag (16 Bytes)
ELSE
CSEG AT 1A50h
Eep_ESC_MCU:			DB	"#BLHELI$EFM8B21#"	; Project and MCU tag (16 Bytes)
ENDIF

Interrupt_Table_Definition MACRO
CSEG AT 0				; Code segment start
	jmp reset
CSEG AT 03h			; Int0 interrupt
	jmp	int0_int
IF MCU_48MHZ == 1
CSEG AT 0Bh			; Timer0 overflow interrupt
	jmp	t0_int
ENDIF
CSEG AT 13h			; Int1 interrupt
	jmp	int1_int
CSEG AT 1Bh			; Timer1 overflow interrupt
	jmp	t1_int
CSEG AT 2Bh			; Timer2 overflow interrupt
	jmp	t2_int
CSEG AT 5Bh			; Pca interrupt
	jmp	pca_int
CSEG AT 73h			; Timer3 overflow/compare interrupt
	jmp	t3_int
ENDM

Decode_DShot_2Bit MACRO dest, decode_fail
	movx	A, @Temp1
	mov	Temp7, A
	clr	C
	subb	A, Temp6				; Subtract previous timestamp
	clr	C
	subb	A, Temp2
	jc	decode_fail			; Check that bit is longer than minimum

	subb	A, Temp2				; Check if bit is zero or one
	mov	A, dest				; Shift bit into data byte
	rlc	A
	mov	dest, A
	inc	Temp1				; Next bit

	movx	A, @Temp1
	mov	Temp6, A
	clr	C
	subb	A, Temp7
	clr	C
	subb	A, Temp2
	jc	decode_fail

	subb	A, Temp2
	mov	A, dest
	rlc	A
	mov	dest, A
	inc	Temp1
ENDM

Initialize_PCA MACRO
	mov	PCA0CN0, #40h			; PCA enabled
	mov	PCA0MD, #08h			; PCA clock is system clock

	mov	PCA0PWM, #(80h + PWM_BITS_H)	; PCA ARSEL set and 8/9/10/11 bits pwm
IF FETON_DELAY == 0
	mov	PCA0CENT, #00h			; Edge aligned pwm
ELSE
	mov	PCA0CENT, #03h			; Center aligned pwm
ENDIF
ENDM

Enable_Power_Pwm_Module MACRO
IF FETON_DELAY == 0
	mov	PCA0_POWER_MODULE, #4Ah	; Enable comparator of module, enable match, set pwm mode
ELSE
	mov	PCA0_POWER_MODULE, #42h	; Enable comparator of module, set pwm mode
ENDIF
ENDM

Enable_Damp_Pwm_Module MACRO
IF FETON_DELAY == 0
	mov	PCA0_DAMP_MODULE, #00h	; Disable
ELSE
	mov	PCA0_DAMP_MODULE, #42h	; Enable comparator of module, set pwm mode
ENDIF
ENDM

Clear_COVF_Interrupt MACRO
	anl	PCA0PWM, #0DFh
ENDM
Enable_COVF_Interrupt MACRO
	orl	PCA0PWM, #40h
ENDM
Disable_COVF_Interrupt MACRO
	anl	PCA0PWM, #0BFh
ENDM

; CCF interrupt is only used for FETON_DELAY == 0
Clear_CCF_Interrupt MACRO
	anl	PCA0CN0, #0FEh
ENDM
Enable_CCF_Interrupt MACRO
	orl	PCA0CPM0,#01h
ENDM
Disable_CCF_Interrupt MACRO
	anl	PCA0CPM0,#0FEh
ENDM

Enable_PCA_Interrupt MACRO
LOCAL pca_enabled set_pca_int_hi_pwm
IF FETON_DELAY != 0
	Enable_COVF_Interrupt
ELSE
	mov	A, Current_Power_Pwm_Reg_H
	jnb	ACC.(PWM_BITS_H-1), set_pca_int_hi_pwm

	Enable_COVF_Interrupt
	sjmp	pca_enabled

set_pca_int_hi_pwm:
	Enable_CCF_Interrupt
pca_enabled:
ENDIF
	orl	EIE1, #10h			; Enable pca interrupts
ENDM

Set_MCU_Clk_24MHz MACRO
	mov	CLKSEL, #13h			; Set clock to 24MHz
	mov	SFRPAGE, #10h
	mov	PFE0CN, #00h			; Set flash timing for 24MHz
	mov	SFRPAGE, #00h
	clr	Flags3.CLOCK_SET_AT_48MHZ
ENDM

Set_MCU_Clk_48MHz MACRO
	mov	SFRPAGE, #10h
	mov	PFE0CN, #30h			; Set flash timing for 48MHz
	mov	SFRPAGE, #00h
	mov	CLKSEL, #03h			; Set clock to 48MHz
	setb	Flags3.CLOCK_SET_AT_48MHZ
ENDM
