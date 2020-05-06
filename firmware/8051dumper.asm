;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 8051dumper.asm: Dump internal ROM contents of 8051 to serial port.
;;
;;

                PROCESSOR 8051
                INCLUDE "SFR.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; GPIOs
OUT_EA          ALIAS   "P1.0"      ; Inverted and connected to EAn pin
OUT_REDLEDn     ALIAS   "P1.1"      ; Red LED in RESET button
OUT_GRNLEDn     ALIAS   "P1.2"      ; Green LED in START button
IN_GRNBTNn      ALIAS   "P1.3"      ; Green START button
IN_R32Kn        ALIAS   "P1.4"      ; Dump size knob: 8058 (32k)
IN_R16Kn        ALIAS   "P1.5"      ; Dump size knob: 8054 (16k)
IN_R8Kn         ALIAS   "P1.6"      ; Dump size knob: 8052 (8k)
IN_R4Kn         ALIAS   "P1.7"      ; Dump size knob: 8051 (4k)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Internal RAM (uninitialized data segment)
                SEGU    "IRAM"

                ORG     0x0000
FOO:            DS      1
BAR:            DS      7

; Rest of RAM is stack. Initial stack pointer should be 1 byte before
; beginning of stack because PUSH operations pre-increment the stack pointer.
STACK:          DS      0x80-$


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Code segment starting at base of external program memory EEPROM
                SEG     "code"

                ; Reset vector (3 bytes)
                ORG     0x0000
RESET:          LJMP    INIT

                ; External Request 0 Interrupt Service Routine (8 bytes)
                ORG     0x0003
ER0_ISR:        SJMP    RESET

                ; Internal Timer/Counter 0 Interrupt Service Routine (8 bytes)
                ORG     0x000B
ITC0_ISR:       SJMP    RESET

                ; External Request 1 Interrupt Service Routine (8 bytes)
                ORG     0x0013
ER1_ISR:        SJMP    RESET

                ; Internal Timer/Counter 1 Interrupt Service Routine (8 bytes)
                ORG     0x001B
ITC1_ISR:       SJMP    RESET

                ; Internal Serial Port Interrupt Service Routine (8 bytes)
                ORG     0x0023
ISP_ISR:        SJMP    RESET

                ; Some other damn interrupt
                ORG     0x002B
FOO_ISR:        SJMP    RESET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Following code/data will be accessed in a mirror image of the 32k EEPROM
;; at 0x8000. We will raise the EAn pin with a GPIO in order to overlay
;; internal ROM at address 0x0000. We will not use any interrupts because
;; interrupt vectors will contain unpredictable code from internal ROM.

                ORG     0x0032
                RORG    0x8032

IDSTR:          DB      "8051dumper v1.0 by NF6X", 0x0D, 0x0A, 0x00

;; 
INIT:
                MOV     IE, #0x00               ; Disable all interrupts
                MOV     P1, #0xFF               ; GPIOs all input/high
                MOV     SP, #STACK-1            ; Initialize stack pointer


; Configure serial port for Mode 1, 9600 8n1
;   SMOD = 0 ==> K = 1
;   Oscillator frequency = 11.0592 MHz
;   TH1 = 256 - (K * Fosc)/(32 * 12 * Baud)
;   TH1 = 256 - (1 * 11059200)/(32 * 12 * 9600) = 253 = 0xFD
                MOV     PCON, #0x00             ; SMOD = 0
                MOV     SCON, #0x50             ; Mode 1
                MOV     TMOD, #0x21             ; T1: Mode 2, T0: Mode 1
                MOV     TH1,  #0xFD             ; 9600 baud
                MOV     TL1,  #0xFD             ; 9600 baud
                SETB    TCON_TR1                ; Enable timer


; Send ID string 
                MOV     DPTR, #IDSTR
                ACALL   SENDSTR


; Blink green LED until green START button pressed.
; Flash LED 2x per second at 20% duty cycle, checking
; button every 100ms.
WAITSTART:      CLR     OUT_GRNLEDn             ; On for 100ms
                ACALL   DELAY100ms
                JNB     IN_GRNBTNn, DUMP        ; Button pressed?
                SETB    OUT_GRNLEDn             ; Off for 400ms
                ACALL   DELAY100ms
                JNB     IN_GRNBTNn, DUMP        ; Button pressed?
                ACALL   DELAY100ms
                JNB     IN_GRNBTNn, DUMP        ; Button pressed?
                ACALL   DELAY100ms
                JNB     IN_GRNBTNn, DUMP        ; Button pressed?
                ACALL   DELAY100ms
                JNB     IN_GRNBTNn, DUMP        ; Button pressed?
                SJMP    WAITSTART

; Read dump size knob and begin dumping code.
DUMP:           SETB    OUT_GRNLEDn             ; Green LED off
                CLR     OUT_REDLEDn             ; Red LED on
                CLR     OUT_EA                  ; Select INTERNAL ROM at 0x0000

                

                SJMP    $


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Delay 100ms
;; Uses Timer 0, delaying 50ms twice
;; Oscillator frequency = 11.0592 MHz
;;   ==> 50ms = 11059200 / (12 * 20) = 46080 = 0xB400 counts
;;   ==> (TH0,TL0) = 0x10000 - 0xB400 = 0x4C00
;; This all ignores subroutine call overhead and so forth.

DELAY100ms:     CLR     TCON_TR0                ; Timer off
                MOV     TH0, #0x4C              ; 50ms delay
                MOV     TL0, #0x00
                CLR     TCON_TF0                ; Clear overflow
                SETB    TCON_TR0                ; Timer on
                JNB     TCON_TF0, $             ; Wait for overflow
                CLR     TCON_TR0                ; Timer off
                MOV     TH0, #0x4C              ; 50ms delay
                MOV     TL0, #0x00
                CLR     TCON_TF0                ; Clear overflow
                SETB    TCON_TR0                ; Timer on
                JNB     TCON_TF0, $             ; Wait for overflow
                CLR     TCON_TR0                ; Timer off
                RET


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Send NUL-terminated string in ROM pointed to by DPTR.
;; Trashes A, DPTR

SENDSTR:        CLR     A                       ; Get byte from ROM
                MOVC    A, @A+DPTR
                JZ      .DONE                   ; Done if it is NUL
                CLR     SCON_TI                 ; Send byte
                MOV     SBUF, A
                JNB     SCON_TI, $              ; Loop until character sent
                INC     DPTR                    ; Send next byte
                SJMP    SENDSTR
.DONE:          RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;

                END
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

