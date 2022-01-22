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
$include (Layouts/A.inc)				; Select pinout A
ELSEIF ESCNO == B_
$include (Layouts/B.inc)				; Select pinout B
ELSEIF ESCNO == C_
$include (Layouts/C.inc)				; Select pinout C
ELSEIF ESCNO == D_
$include (Layouts/D.inc)				; Select pinout D
ELSEIF ESCNO == E_
$include (Layouts/E.inc)				; Select pinout E
ELSEIF ESCNO == F_
$include (Layouts/F.inc)				; Select pinout F
ELSEIF ESCNO == G_
$include (Layouts/G.inc)				; Select pinout G
ELSEIF ESCNO == H_
$include (Layouts/H.inc)				; Select pinout H
ELSEIF ESCNO == I_
$include (Layouts/I.inc)				; Select pinout I
ELSEIF ESCNO == J_
$include (Layouts/J.inc)				; Select pinout J
ELSEIF ESCNO == K_
$include (Layouts/K.inc)				; Select pinout K
ELSEIF ESCNO == L_
$include (Layouts/L.inc)				; Select pinout L
ELSEIF ESCNO == M_
$include (Layouts/M.inc)				; Select pinout M
ELSEIF ESCNO == N_
$include (Layouts/N.inc)				; Select pinout N
ELSEIF ESCNO == O_
$include (Layouts/O.inc)				; Select pinout O
ELSEIF ESCNO == P_
$include (Layouts/P.inc)				; Select pinout P
ELSEIF ESCNO == Q_
$include (Layouts/Q.inc)				; Select pinout Q
ELSEIF ESCNO == R_
$include (Layouts/R.inc)				; Select pinout R
ELSEIF ESCNO == S_
$include (Layouts/S.inc)				; Select pinout S
ELSEIF ESCNO == T_
$include (Layouts/T.inc)				; Select pinout T
ELSEIF ESCNO == U_
$include (Layouts/U.inc)				; Select pinout U
ELSEIF ESCNO == V_
$include (Layouts/V.inc)				; Select pinout V
ELSEIF ESCNO == W_
$include (Layouts/W.inc)				; Select pinout W
;ELSEIF ESCNO == X_
;$include (Layouts/X.inc)			; Select pinout X
;ELSEIF ESCNO == Y_
;$include (Layouts/Y.inc)			; Select pinout Y
ELSEIF ESCNO == Z_
$include (Layouts/Z.inc)				; Select pinout Z
ENDIF

SIGNATURE_001			EQU	0E8h		; Device signature
IF MCU_48MHZ == 0
SIGNATURE_002			EQU	0B1h
ELSE
SIGNATURE_002			EQU	0B2h
ENDIF

;**** **** **** **** ****
; Constant definitions
;**** **** **** **** ****
ESC_C	EQU	"A" + ESCNO - 1		; ESC target letter

IF MCU_48MHZ == 0					; MCU letter (24Mhz=L, 48Mhz=H)
MCU_C	EQU	"L"
ELSE
MCU_C	EQU	"H"
ENDIF
ENDIF

; Dead time number as chars
DT_C2	EQU	"0" + (DEADTIME / 100)
DT_C1	EQU	"0" + ((DEADTIME / 10) MOD 10)
DT_C0	EQU	"0" + (DEADTIME MOD 10)

CSEG AT 1A40h						; ESC layout tag
IF DEADTIME < 100
Eep_ESC_Layout:	DB	"#", ESC_C, "_", MCU_C, "_", DT_C1, DT_C0, "#        "
ELSE
Eep_ESC_Layout:	DB	"#", ESC_C, "_", MCU_C, "_", DT_C2, DT_C1, DT_C0, "#       "
ENDIF

CSEG AT 1A50h						; Project and MCU tag (16 Bytes)
IF MCU_48MHZ == 0
Eep_ESC_MCU:		DB	"#BLHELI$EFM8B10#"
ELSE
Eep_ESC_MCU:		DB	"#BLHELI$EFM8B21#"
ENDIF

Interrupt_Table_Definition MACRO
CSEG AT 0							;; Code segment start
	jmp	reset
CSEG AT 03h						;; Int0 interrupt
	jmp	int0_int
CSEG AT 0Bh						;; Timer0 overflow interrupt
	jmp	t0_int
CSEG AT 13h						;; Int1 interrupt
	jmp	int1_int
CSEG AT 1Bh						;; Timer1 overflow interrupt
	jmp	t1_int
CSEG AT 2Bh						;; Timer2 overflow interrupt
	jmp	t2_int
CSEG AT 5Bh						;; PCA interrupt
	jmp	pca_int
CSEG AT 73h						;; Timer3 overflow/compare interrupt
	jmp	t3_int
ENDM

Initialize_PCA MACRO
	mov	PCA0CN0, #40h				;; PCA enabled
	mov	PCA0MD, #08h				;; PCA clock is system clock

	mov	A, #80h					;; Enable PCA auto-reload registers
	add	A, Pwm_Bits_H				;; Set pwm cycle length (8-11 bits)
	mov	PCA0PWM, A

IF PWM_CENTERED == 1
	mov	PCA0CENT, #07h				;; Center aligned pwm
ELSE
	mov	PCA0CENT, #00h				;; Edge aligned pwm
ENDIF
ENDM

Set_MCU_Clk_24MHz MACRO
	mov	CLKSEL, #13h				;; Set clock to 24MHz (Oscillator 1 divided by 2)

	mov	SFRPAGE, #10h
	mov	PFE0CN, #00h				;; Set flash timing for 24MHz and disable prefetch engine
	mov	SFRPAGE, #00h

	clr	Flag_Clock_At_48MHz
ENDM

Set_MCU_Clk_48MHz MACRO
	mov	SFRPAGE, #10h
	mov	PFE0CN, #30h				;; Set flash timing for 48MHz and enable prefetch engine
	mov	SFRPAGE, #00h

	mov	CLKSEL, #03h				;; Set clock to 48MHz (Oscillator 1)

	setb	Flag_Clock_At_48MHz
ENDM

