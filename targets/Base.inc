


;**** **** **** **** ****
; Bootloader definitions
;**** **** **** **** ****
RTX_PORT				EQU	P0		; Receive/Transmit port
RTX_MDOUT				EQU	P0MDOUT	; Set to 1 for PUSHPULL
RTX_MDIN				EQU	P0MDIN	; Set to 1 for DIGITAL
RTX_SKIP				EQU	P0SKIP	; Set to 1 for SKIP
RTX_PIN				EQU	Rcp_In	; RTX pin




IF PWM_ACTIVE_HIGH == 1		; fet active high
pON	LIT	'setb'
pOFF	LIT	'clr'
ELSE						; fet active low
pON	LIT	'clr'
pOFF	LIT	'setb'
ENDIF

IF COMPWM_ACTIVE_HIGH == 1	; comfet active high
cON	LIT	'setb'
cOFF	LIT	'clr'
ELSE						; comfet active low
cON	LIT	'clr'
cOFF	LIT	'setb'
ENDIF


IF COMP_PORT == 0
CMP_CN0	EQU	CMP0CN0
CMP_MD	EQU	CMP0MD
CMP_MX	EQU	CMP0MX
ELSE
CMP_CN0	EQU	CMP1CN0
CMP_MD	EQU	CMP1MD
CMP_MX	EQU	CMP1MX
ENDIF

Initialize_Xbar MACRO
	mov	XBR2, #40h	;; Xbar enabled
	mov	XBR1, #02h	;; CEX0 and CEX1 routed to pins
IF ESCNO = E_
	All_pwmFETs_off	; For unlocking of HIP2103/4 driver circuits
	call wait100ms
	AcomFET_on
	BcomFET_on
	CcomFET_on
	call wait1ms
	All_comFETs_off
ENDIF
ENDM

Initialize_Comparator MACRO
	mov	CMP_CN0, #80h	;; Comparator enabled, no hysteresis
	mov	CMP_MD, #00h	;; Comparator response time 100ns
ENDM


Read_Comp_Out MACRO
	mov	A, CMP_CN0	;; Read comparator output
IF ESCNO == O_
	cpl	A
ENDIF
ENDM

; Set comparator multiplexer to phase A
Set_Comp_Phase_A MACRO
	mov CMP_MX, #((A_Mux SHL 4) + Comp_Com)
ENDM

; Set comparator multiplexer to phase B
Set_Comp_Phase_B MACRO
	mov CMP_MX, #((B_Mux SHL 4) + Comp_Com)
ENDM

; Set comparator multiplexer to phase C
Set_Comp_Phase_C MACRO
	mov CMP_MX, #((C_Mux SHL 4) + Comp_Com)
ENDM




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


IF ALL_FETS_ON_PORT1 == 1

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

ENDIF
