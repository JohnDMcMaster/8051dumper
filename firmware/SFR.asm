;; 8051/8052 Special-Function Registers...
                NOLIST
;; Register             Address       Reset     Notes
ACC             EQU     0xE0        ; 0x00      Bit addressable
B               EQU     0xF0        ; 0x00      Bit addressable
DPH             EQU     0x83        ; 0x00  
DPL             EQU     0x82        ; 0x00  

IE              EQU     0xA8        ; 0x00      Bit addressable
IE_EA           ALIAS   "IE.7"      ;           All interrupts
IE_ET2          ALIAS   "IE.5"      ;           Timer 2 (8052)
IE_ES           ALIAS   "IE.4"      ;           Serial port
IE_ET1          ALIAS   "IE.3"      ;           Timer 1
IE_EX1          ALIAS   "IE.2"      ;           External interrupt 1
IE_ET0          ALIAS   "IE.1"      ;           Timer 0
IE_EX0          ALIAS   "IE.0"      ;           External interrupt 0

IP              EQU     0xB8        ; 0x00      Bit addressable
P0              EQU     0x80        ; 0xFF      Bit addressable
P1              EQU     0x90        ; 0xFF      Bit addressable
P2              EQU     0xA0        ; 0xFF      Bit addressable
P3              EQU     0xB0        ; 0xFF      Bit addressable
PCON            EQU     0x87        ; ??

PSW             EQU     0xD0        ; 0x00      Bit addressable
PSW_CY          ALIAS   "PSW.7"     ;           Carry
PSW_AC          ALIAS   "PSW.6"     ;           Auxiliary carry
PSW_F0          ALIAS   "PSW.5"     ;           General purpose flag
PSW_RS1         ALIAS   "PSW.4"     ;           Register bank
PSW_RS0         ALIAS   "PSW.3"     ;           Register bank
PSW_OV          ALIAS   "PSW.2"     ;           Overflow
PSW_UDF         ALIAS   "PSW.1"     ;           User definable flag
PSW_P           ALIAS   "PSW.0"     ;           Parity

RCAP2H          EQU     0xCB        ; 0x00      8052
RCAP2L          EQU     0xCA        ; 0x00      8052
SBUF            EQU     0x99        ; ??

SCON            EQU     0x98        ; 0x00      Bit addressable
SCON_SM0        ALIAS   "SCON.7"    ;           Serial port mode
SCON_SM1        ALIAS   "SCON.6"    ;           Serial port mode
SCON_SM2        ALIAS   "SCON.5"    ;           Serial port mode
SCON_REN        ALIAS   "SCON.4"    ;           Receiver enable
SCON_TB8        ALIAS   "SCON.3"    ;           9th data bit to transmit
SCON_RB8        ALIAS   "SCON.2"    ;           9th data bit received
SCON_TI         ALIAS   "SCON.1"    ;           Transmit interrupt flag
SCON_RI         ALIAS   "SCON.0"    ;           Receive interrupt flag

SP              EQU     0x81        ; 0x07

T2CON           EQU     0xC8        ; 0x00      Bit addressable, 8052

TCON            EQU     0x88        ; 0x00      Bit addressable
TCON_TF1        ALIAS   "TCON.7"    ;           Timer 1 overflow flag
TCON_TR1        ALIAS   "TCON.6"    ;           Timer 1 run control bit
TCON_TF0        ALIAS   "TCON.5"    ;           Timer 0 overflow flag
TCON_TR0        ALIAS   "TCON.4"    ;           Timer 0 run control bit
TCON_IE1        ALIAS   "TCON.3"    ;           External int 1 edge flag
TCON_IT1        ALIAS   "TCON.2"    ;           Int 1 type control bit
TCON_IE0        ALIAS   "TCON.1"    ;           External int 0 edge flag
TCON_IT0        ALIAS   "TCON.0"    ;           Int 0 type control bit

TH0             EQU     0x8C        ; 0x00
TL0             EQU     0x8A        ; 0x00
TH1             EQU     0x8D        ; 0x00
TL1             EQU     0x8B        ; 0x00
TH2             EQU     0xCD        ; 0x00      8052
TL2             EQU     0xCC        ; 0x00      8052
TMOD            EQU     0x89        ; 0x00

                LIST
;; ...8051/8052 Special-Function Registers
