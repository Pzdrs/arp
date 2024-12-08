PROCESSOR 16F1508
    
#define	    LED	    PORTC,5
    
; window -> TMW -> conf. bits -> ctl c ctr v
; CONFIG1
CONFIG  FOSC = INTOSC         ; Oscillator Selection Bits (INTOSC oscillator: I/O function on CLKIN pin)
CONFIG  WDTE = OFF            ; Watchdog Timer Enable (WDT disabled)
CONFIG  PWRTE = OFF           ; Power-up Timer Enable (PWRT disabled)
CONFIG  MCLRE = ON            ; MCLR Pin Function Select (MCLR/VPP pin function is MCLR)
CONFIG  CP = OFF              ; Flash Program Memory Code Protection (Program memory code protection is disabled)
CONFIG  BOREN = ON            ; Brown-out Reset Enable (Brown-out Reset enabled)
CONFIG  CLKOUTEN = OFF        ; Clock Out Enable (CLKOUT function is disabled. I/O or oscillator function on the CLKOUT pin)
CONFIG  IESO = ON             ; Internal/External Switchover Mode (Internal/External Switchover Mode is enabled)
CONFIG  FCMEN = ON            ; Fail-Safe Clock Monitor Enable (Fail-Safe Clock Monitor is enabled)

; CONFIG2
CONFIG  WRT = OFF             ; Flash Memory Self-Write Protection (Write protection off)
CONFIG  STVREN = ON           ; Stack Overflow/Underflow Reset Enable (Stack Overflow or Underflow will cause a Reset)
CONFIG  BORV = LO             ; Brown-out Reset Voltage Selection (Brown-out Reset Voltage (Vbor), low trip point selected.)
CONFIG  LPBOR = OFF           ; Low-Power Brown Out Reset (Low-Power BOR is disabled)
CONFIG  LVP = ON              ; Low-Voltage Programming Enable (Low-voltage programming enabled)

#include <xc.inc> 
  
;VARIABLE DEFINITIONS
;COMMON RAM 0x70 to 0x7F
; Current letter index
LIDX	EQU 0x70
MISMATCHES  EQU	0x71
tmp	EQU 0x72
	
L0	EQU 0x73
L1	EQU 0x74
L2	EQU 0x75
L3	EQU 0x76
L4	EQU 0x77
L5	EQU 0x78
	
    
;**********************************************************************
PSECT PROGMEM0,delta=2, abs

RESETVEC:
    ORG		0x00 
    PAGESEL	Setup
    GOTO	Setup
	
    ORG		0x04
    ; Zajima nas jenom UART RX interrupt
    BANKSEL	PIR1
    BTFSC	PIR1,5    
    CALL	uart_rx_isr
    RETFIE

uart_rx_isr:
    ; RCIF je read-only takze nic manualne neclearuju, jenom musim precist byte z bufferu
    ; BCF   PIR1,5
    
    ; Indirect adresovani - podle indexu se znak ulozi na spravny misto v RAMce
    MOVF    LIDX, W        
    ADDLW   L0             
    MOVWF   FSR0L          
    CLRF    FSR0H
    
    BANKSEL RCREG           
    MOVF    RCREG, W        
    MOVWF   INDF0             
    
    ; Znak jsme si ulozili, inkrementujeme index
    INCF    LIDX, 1     
    
    ; Zkontrolujem jestli to nebyl 6. znak
    MOVLW   6 
    SUBWF   LIDX, W
    
    BTFSC   STATUS, 2   
    GOTO    check_strings
    
    RETURN
   
; Kontrola jestli prvni a ctvrty pismeno jsou equal
check_strings:    
    MOVF    L0, W
    MOVWF   tmp

    MOVF    L3, W
    SUBWF   tmp, W
    BTFSC   STATUS, 2
    GOTO    check_L1_L4
    INCFSZ  MISMATCHES, 1

; Kontrola jestli druhy a paty pismeno jsou equal
check_L1_L4:
    MOVF    L1, W
    MOVWF   tmp

    MOVF    L4, W
    SUBWF   tmp, W
    BTFSC   STATUS, 2
    GOTO    check_L2_L5
    INCFSZ  MISMATCHES, 1

; Kontrola jestli treti a sesty pismeno jsou equal
check_L2_L5:
    MOVF    L2, W
    MOVWF   tmp

    MOVF    L5, W
    SUBWF   tmp, W
    BTFSC   STATUS, 2 
    GOTO    eval_mismatches
    INCFSZ  MISMATCHES, 1

; Vyhodnoceni
; Nebyl jsem schopnej to udelat pres jeden subtract a carry flag magic
eval_mismatches:
    ; Kontrola, jestli nebyl zadnej mismatch
    MOVLW   0
    SUBWF   MISMATCHES, W
    BTFSC   STATUS, 2
    GOTO    Letters_pass
    
    ; Kontrola, jestli byl prave jeden mismatch
    MOVLW   1
    SUBWF   MISMATCHES, W
    BTFSC   STATUS, 2
    GOTO    Letters_pass
    
    ; Jestli pocet mismatchu nebyl ani 0 ani 1 musel bejt >= 2 -> fail
    GOTO    Letters_fail
Letters_pass:
    BANKSEL TXREG
    
    MOVLW	'O'
    MOVWF	TXREG
    CALL	uart_tx_done
    
    MOVLW	'K'
    MOVWF	TXREG
    
    GOTO    Cleanup
Letters_fail:
    BANKSEL TXREG
    
    MOVLW   'E'
    MOVWF   TXREG
    CALL    uart_tx_done
    MOVLW   'R'
    MOVWF   TXREG
    CALL    uart_tx_done
    MOVLW   'R'
    MOVWF   TXREG
    CALL    uart_tx_done
    MOVLW   'O'
    MOVWF   TXREG
    CALL    uart_tx_done
    MOVLW   'R'
    MOVWF   TXREG
    
    GOTO    Cleanup
Cleanup:
    CLRF    MISMATCHES
    CLRF    LIDX
    RETFIE
uart_tx_done:
    BTFSS   TXSTA,1
    GOTO uart_tx_done
    RETURN
Setup:	
    MOVLB	1		;Banka1
    MOVLW	01101000B	;4MHz Medium
    MOVWF	OSCCON		;nastaveni hodin

    CALL	Config_IOs

    ;config UART
    MOVLB	3		;Banka3 s UART
    BSF		TXSTA,5		;TXEN	;povoleni odesilani dat
    BSF		TXSTA,2		;BRGH	;jiny zpusob vypoctu baudrate
    BSF		RCSTA,4	;CREN	;povoleni prijimani dat
    
    ; baud rate generator
    CLRF	SPBRGH
    MOVLW	25		;25 => 9615 bps s BRGH pri Fosc = 4MHz
    MOVWF	SPBRGL
    
    ; zapnu global interrupt
    BSF		INTCON,7
    ; zapnu peripherial interrupty
    BSF		INTCON,6
    ; zapnu interrupt na UART receive
    MOVLB	1
    BSF		PIE1,5
    
    ; jelikoz to je incrementuju tak si projistotu udelam init clear
    CLRF	LIDX
    CLRF	MISMATCHES
    
    MOVLB	3
    ; serial port enable
    BSF		RCSTA,7

; Loop tady musi bejt jinak to nefunguje idk why
Loop:
    GOTO	Loop

	
#include	"Config_IOs.inc"
END