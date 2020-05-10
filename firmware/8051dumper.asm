;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 8051dumper.asm: Dump internal ROM contents of 8051 to serial port.
;;
;;

                PROCESSOR 8051
                INCLUDE "SFR.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; GPIOs
;;
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
;;
                SEGU    "IRAM"

; 0x00..0x1F contains the four register banks.
; 0x20..0x2F is the bit addressable area.
; 0x30..0x7F is the scratch pad area.

                ORG     0x0030
IROMSIZE:       DS      1           ; High byte of internal ROM size
CKSUM:          DS      1           ; Checksum accumulator for line
HINYBBLE:       DS      1           ; Temp buffer for HEXBYTE
LONYBBLE:       DS      1           ; Temp buffer for HEXBYTE

; Intel Hex line buffer for 16 byte record
BUF_START:      DS      1           ; Start code ":"
BUF_BYTECOUNT:  DS      2           ; Byte count "10"
BUF_ADDR:       DS      4           ; Start address of record
BUF_RECTYPE:    DS      1           ; Record type
BUF_DATA:       DS      32          ; Record data
BUF_CKSUM:      DS      2           ; Checksum
BUF_EOL:        DS      3           ; CRLF and terminating NUL



; Rest of RAM is stack. Initial stack pointer should be 1 byte before
; beginning of stack because PUSH operations pre-increment the stack pointer.
STACK:          DS      0x0080-$


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Code segment starting at base of external program memory EEPROM
;;
                SEG     "code"

                ; Reset vector (3 bytes)
                ORG     0x0000
RESET:          LJMP    MAIN

                ; External Request 0 Interrupt Service Routine (8 bytes)
                ORG     0x0003
ER0_ISR:        LJMP    ERROR

                ; Internal Timer/Counter 0 Interrupt Service Routine (8 bytes)
                ORG     0x000B
ITC0_ISR:       LJMP    ERROR

                ; External Request 1 Interrupt Service Routine (8 bytes)
                ORG     0x0013
ER1_ISR:        LJMP    ERROR

                ; Internal Timer/Counter 1 Interrupt Service Routine (8 bytes)
                ORG     0x001B
ITC1_ISR:       LJMP    ERROR

                ; Internal Serial Port Interrupt Service Routine (8 bytes)
                ORG     0x0023
ISP_ISR:        LJMP    ERROR

                ; Some other damn interrupt
                ORG     0x002B
FOO_ISR:        LJMP    ERROR



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Following code/data will be accessed in a mirror image of the 32k EEPROM
;; at 0x8000. We will raise the EAn pin with a GPIO in order to overlay
;; internal ROM at address 0x0000. We will not use any interrupts because
;; interrupt vectors will contain unpredictable code from internal ROM.
;;
                ORG     0x0032
                RORG    0x8032

IDSTR:          DB      "8051dumper v1.0 by NF6X", 0x0D, 0x0A, 0x00
KNOBSTR:        DB      "ERROR: Could not read ROM size knob!", 0x0D, 0x0A, 0x00
ENDSTR:         DB      ":00000001FF", 0x0D, 0x0A, 0x00

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Main entry point
;;
MAIN:
                MOV     IE, #0x00               ; Disable all interrupts
                MOV     P1, #0xFF               ; GPIOs all input/high
                MOV     SP, #STACK-1            ; Initialize stack pointer
                CLR     OUT_EA                  ; Select INTERNAL ROM at 0x0000


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
                ACALL   SENDROM


; Blink green LED until green START button pressed.
; Flash LED 2x per second at 20% duty cycle, checking
; button every 100ms.
WAITSTART:      CLR     OUT_GRNLEDn             ; On for 100ms
                ACALL   DELAY100ms
                JNB     IN_GRNBTNn, READKNOB    ; Button pressed?
                SETB    OUT_GRNLEDn             ; Off for 400ms
                ACALL   DELAY100ms
                JNB     IN_GRNBTNn, READKNOB    ; Button pressed?
                ACALL   DELAY100ms
                JNB     IN_GRNBTNn, READKNOB    ; Button pressed?
                ACALL   DELAY100ms
                JNB     IN_GRNBTNn, READKNOB    ; Button pressed?
                ACALL   DELAY100ms
                JNB     IN_GRNBTNn, READKNOB    ; Button pressed?
                SJMP    WAITSTART

; Read dump size knob and begin dumping code.
READKNOB:       SETB    OUT_GRNLEDn             ; Green LED off
 
.TST32K:        JB      IN_R32Kn, .TST16K       ; Knob set to 32k?
                MOV     IROMSIZE, #0x80         ; Yes, 32k
                SJMP    INITBUF
.TST16K:        JB      IN_R16Kn, .TST8K        ; Knob set to 16k?
                MOV     IROMSIZE, #0x40         ; Yes, 16k
                SJMP    INITBUF
.TST8K:         JB      IN_R8Kn, .TST4K         ; Knob set to 8k?
                MOV     IROMSIZE, #0x20         ; Yes, 8k
                SJMP    INITBUF
.TST4K:         JB      IN_R4Kn, .TSTFAIL       ; Knob set to 4k?
                MOV     IROMSIZE, #0x10         ; Yes, 4k
                SJMP    INITBUF
.TSTFAIL:       MOV     DPTR, #KNOBSTR          ; Cannot read knob!
                ACALL   SENDROM
                LJMP    ERROR


; Initialize the line buffer and ROM data pointer
INITBUF:        MOV     BUF_START, #':'
                MOV     BUF_BYTECOUNT, #'1'
                MOV     BUF_BYTECOUNT+1, #'0'
                MOV     BUF_EOL, #0x0D
                MOV     BUF_EOL+1, #0x0A
                MOV     BUF_EOL+2, #0x00
                MOV     DPTR, #0000 


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Dump one Intel Hex record of 16 bytes at a time until done.
;; Toggle red LED for each line to show activity.
;;
DUMPLOOP:       MOV     A, DPH                  ; Has DPTR hit end of IROM?
                CJNE    A, IROMSIZE, DUMPRECORD
                SJMP    EOF                     ; Finished with IROM

; Dump one 16-byte record
DUMPRECORD:
                CPL     OUT_REDLEDn
                MOV     CKSUM, #0x10            ; Init checksum w/ record length
                MOV     R0, #BUF_ADDR           ; Point to address field
                MOV     A, DPH                  ; High address byte
                ACALL   HEXBYTE
                MOV     A, DPL                  ; Low address byte
                ACALL   HEXBYTE
                CLR     A                       ; Record type
                ACALL   HEXBYTE

DUMPBYTE:       CLR     A                       ; Read byte from IROM
                MOVC    A, @A+DPTR
                ACALL   HEXBYTE                 ; Add it to line buffer
                MOV     A, DPL                  ; End of record?
                ANL     A, #0x0F 
                CLR     C
                SUBB    A, #0x0F
                JZ      EOR                     ; Yes, at end of 16-byte record
                INC     DPTR                    ; No, increment IROM pointer
                SJMP    DUMPBYTE                ; Add next byte

EOR:            MOV     A, CKSUM                ; Add checksum to record
                CPL     A
                ADD     A, #1
                ACALL   HEXBYTE
                ACALL   SENDRECORD              ; Send out this record
                INC     DPTR

                SJMP    DUMPLOOP


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Send out end of file record, turn green LED on and red LED off,
;; and loop forever.
;;
EOF:            MOV     DPTR, #ENDSTR
                ACALL   SENDROM
                CLR     OUT_GRNLEDn             ; Green LED on
                SETB    OUT_REDLEDn             ; Red LED off
                SJMP    $

               
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Add hex representation of A to buffer at R0 and accumulate checksum.
;;
HEXBYTE:        MOV     HINYBBLE, A             ; Add byte to checksum
                MOV     LONYBBLE, A
                ADD     A, CKSUM
                MOV     CKSUM, A

                MOV     A, HINYBBLE             ; Isolate high nybble
                SWAP    A
                ANL     A, #0x0F
                ADD     A, #'0'
                MOV     HINYBBLE, A
                CLR     C
                SUBB    A, #':'
                JC      .LO
                MOV     A, HINYBBLE
                ADD     A, #7
                MOV     HINYBBLE, A

.LO:            MOV     A, LONYBBLE             ; Isolate low nybble
                ANL     A, #0x0F
                ADD     A, #'0'
                MOV     LONYBBLE, A
                CLR     C
                SUBB    A, #':'
                JC      .STHI
                MOV     A, LONYBBLE
                ADD     A, #7
                MOV     LONYBBLE, A

.STHI:          MOV     A, HINYBBLE             ; Store high nybble hex char
                MOV     @R0, A
                INC     R0
                MOV     A, LONYBBLE             ; Store low nybble hex char
                MOV     @R0, A
                INC     R0

                RET


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Send out the current record. Trashes and R0.
;;
SENDRECORD:     MOV     R0, #BUF_START          ; Init pointer
.SENDCHAR:      MOV     A, @R0                  ; Get next char
                JZ      .DONE                   ; Done if it is NUL
                CLR     SCON_TI                 ; Send byte
                MOV     SBUF, A
                JNB     SCON_TI, $              ; Loop until character sent
                INC     R0
                SJMP    .SENDCHAR
.DONE:          RET


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Error handler
;; Turn on red LED and loop forever
;;
ERROR:          SETB    OUT_GRNLEDn             ; Green LED off
                CLR     OUT_REDLEDn             ; Red LED on
                SJMP    $




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Delay 100ms
;; Uses Timer 0, delaying 50ms twice
;; Oscillator frequency = 11.0592 MHz
;;   ==> 50ms = 11059200 / (12 * 20) = 46080 = 0xB400 counts
;;   ==> (TH0,TL0) = 0x10000 - 0xB400 = 0x4C00
;; This all ignores subroutine call overhead and so forth.
;;
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
;;
SENDROM:        CLR     A                       ; Get byte from ROM
                MOVC    A, @A+DPTR
                JZ      .DONE                   ; Done if it is NUL
                CLR     SCON_TI                 ; Send byte
                MOV     SBUF, A
                JNB     SCON_TI, $              ; Loop until character sent
                INC     DPTR                    ; Send next byte
                SJMP    SENDROM
.DONE:          RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
                END
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

