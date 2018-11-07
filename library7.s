	AREA	library7, CODE, READWRITE
	
	EXPORT uart_init
	EXPORT gpio_init
	EXPORT interrupt_init
	EXPORT interrupt_disable

	EXPORT read_character
	EXPORT read_string
	EXPORT output_character
	EXPORT output_string
	EXPORT output_string_c

	EXPORT num_to_ascii
	EXPORT num_to_ascii_c
    EXPORT ascii_to_num
	EXPORT div_and_mod
	
	EXPORT push_button
	EXPORT LED
	EXPORT RGB_LED
	EXPORT seven_segment


;---Addresses---;
UART0	EQU 0xE000C000	; UART0 base address
U0LSR	EQU 0x14		; UART0 Line Status Register offset

PINSEL0	EQU 0xE002C000	; Pin select 0
PINSEL1	EQU 0xE002C004
IO0DIR	EQU 0xE0028008	; Direction of IO port 0
IO1DIR	EQU 0xE0028018

IO0SET	EQU 0xE0028004	; Set pins on IO port 0
IO0CLR	EQU 0xE002800C	; Clear pins on IO port 0
IO0PIN	EQU 0xE0028000	; Read pins on IO port 0
IO1SET	EQU 0xE0028014
IO1CLR	EQU 0xE002801C
IO1PIN	EQU 0xE0028010

ISR		EQU	0xFFFFF00C	; Interrupt Select register
IER		EQU 0xFFFFF010	; Interrupt Enable register
EXTMODE	EQU 0xE01FC148	; External Interrupt Mode register
EXTINT	EQU 0xE01FC140	; External Interrupt Flag register
U0IER	EQU	0xE000C004	; UART0 Interrupt Enable register
U0IIR	EQU 0xE000C008	; UART0 Interrupt Identification register

T0MCR	EQU 0xE0004014	; Timer 0 Match Control register
T0IR	EQU	0xE0004000	; Timer 0 Interrupt register
T0TCR	EQU	0xE0004004	; Timer 0 Timer Control register
T0MR1	EQU	0xE000401C	; Timer 0 Match Register 1
T0TC	EQU	0xE0004008	; Timer 0 Counter register

T1MCR	EQU 0xE0008014
T1IR	EQU 0xE0008000
T1TCR	EQU 0xE0008004
T1MR1	EQU 0xE000801C
T1TC	EQU 0xE0008008
;---/Addresses---;


;---Strings---;
string_NUMBER = "\037\037\037\037",0
	ALIGN
;---/Strings---;


;---Maps---;
digits_SET			; 7-segment display digits
					; x abcdefg g0fe 0dcb a000 0000 0x0000
	DCD 0x00003780	; 0 abcdef_ 0011 0111 1000 0000 0x3780
 	DCD 0x00000300	; 1 _bc____ 0000 0011 0000 0000 0x0300
	DCD 0x00009580	; 2 ab_de_g 1001 0101 1000 0000 0x9580
	DCD 0x00008780	; 3 abcd__g 1000 0111 1000 0000 0x8780
	DCD 0x0000A300	; 4 _bc__fg 1010 0011 0000 0000 0xA300
	DCD 0x0000A680	; 5 a_cd_fg 1010 0110 1000 0000 0xA680
	DCD 0x0000B680	; 6 a_cdefg 1011 0110 1000 0000 0xB680
	DCD 0x00000380	; 7 abc____ 0000 0011 1000 0000 0x0380
	DCD 0x0000B780	; 8 abcdefg 1011 0111 1000 0000 0xB780
	DCD 0x0000A380	; 9 abc__fg 1010 0011 1000 0000 0xA380
	DCD 0x0000B380	; A abc_efg 1011 0011 1000 0000 0xB380
	DCD 0x0000B600	; B __cdefg 1011 0110 0000 0000 0xB600
	DCD 0x00003480	; C a__def_ 0011 0100 1000 0000 0x3480
	DCD 0x00009700	; D _bcde_g 1001 0111 0000 0000 0x9700
	DCD 0x0000B480	; E a__defg 1011 0100 1000 0000 0xB480
	DCD 0x0000B080	; F a___efg 1011 0000 1000 0000 0xB080
	DCD 0x00008000	; - ______g 1000 0000 0000 0000 0x8000
	ALIGN
;---/Maps---;


;---Initialization---;
	
	; uart_init
	;  Initializes UART0 for use
	;  Input:
	;   None
	;  Output:
	;   None
	;  Internal:
	;   r0: Base address of PINSEL0/UART0
	;   r1: Bit changer intermediate
uart_init
	STMFD SP!, {r0-r1, lr}
	
	; Set pin 5 and clear bit 10 on pin select 0
	LDR r0, =PINSEL0
	LDR r1, [r0]
	ORR r1, r1, #5
	BIC r1, r1, #0xA
	STR r1, [r0]
	
	LDR r0, =UART0
	; 8-bit word length, 1 stop bit, no parity,
	; Disable break control
	; Enable divisor latch access
	MOV r1, #0x83					; 0x83 = 131 = b10000011
	STRB r1, [r0, #0xC]				; 0xE000C00C
	
	; Set lower divisor latch for 384,000 baud
	MOV r1, #0x3					; 0x3 = 3 = b0011
	STRB r1, [r0]					; 0xE000C000
	
	; Set upper divisor latch
	MOV r1, #0x0					; 0
	STRB r1, [r0, #4]				; 0xE000C004
	
	; 8-bit word length, 1 stop bit, no parity,
	; Disable break control
	; Disable divisor latch access
	MOV r1, #3						; 3
	STRB r1, [r0, #0xC]				; 0xE000C00C
	
	LDMFD SP!, {r0-r1, lr}
	BX lr
    
	
	
    
    
    
    
	; gpio_init
	;  Initializes GPIO for use
	;  Input:
	;   None
	;  Output:
	;   None
	;  Internal:
	;   r0: Base memory addresses
	;   r1: Immediate limitation bypass
	;   r2: Bit selector
gpio_init
	STMFD SP!, {r0-r2, lr}
	
	; PINSELECT
	; set appropriate pins to 00 to allow GPIO use
	; (thus, each pin is TWO bits wide)
	; pins 0-15 are PINSEL0, 16-31 are PINSEL1 (PINSEL0 + 4)
	LDR r0, =PINSEL0					; base address of PINSEL0
	; pins 2-5, 7-10, 12-13, 15 for 7-segment
	; bits 4-11, 14-21, 24-27, 30-31 on pinsel0
	; b11001111 00111111 11001111 11110000
	; 0xCF3FCFF0
	LDR r1, =0xCF3FCFF0
	LDR r2, [r0]						; load PINSEL0 info
	BIC r2, r2, r1						; clear these bits (pin 00 = GPIO)
	STR r2, [r0]
	
	; pins 16-23 for LEDs, RGB LED, push buttons
	; pins 0-7 on pinsel1
	; bits 0-15
	; b00000000 00000000 11111111 11111111
	; 0x0000FFFF
	LDR r1, =0x0000FFFF
	LDR r2, [r0, #4]					; PINSEL1 is PINSEL0 + 4
	BIC r2, r2, r1
	STR r2, [r0, #4]
	
	; from here on, pins are ONE bit wide
	; IODIR
	LDR r0, =IO0DIR						; port 0 direction
	; RGB LED: port 0, pins 17, 18, 21 output
	; b00000000 00100110 00000000 00000000
	; 0x00260000
	MOV r1, #0x00260000
	LDR r2, [r0]
	ORR r2, r2, r1						; set these pins to 1 (output)
	STR r2, [r0]
	
	; 7 segment: port 0, pins 2-5, 7-10, 12-13, 15 output
	; b00000000 00000000 10110111 10111100
	; 0x0000B7BC
	LDR r1, =0x0000B7BC
	LDR r2, [r0]
	ORR r2, r2, r1						; set these pins to 1 (output)
	STR r2, [r0]
	
	LDR r0, =IO1DIR						; port 1 direction
	; LEDs: port 1, pins 16-19 output
	; b00000000 00001111 00000000 00000000
	; 0x000F0000
	MOV r1, #0x000F0000
	LDR r2, [r0]
	ORR r2, r2, r1						; set these pins to 1 (output)
	STR r2, [r0]
	
	; Buttons: port 1, pins 20-23 input
	; b00000000 11110000 00000000 00000000
	; 0x00F00000
	MOV r1, #0x00F00000
	LDR r2, [r0]
	BIC r2, r2, r1						; set these pins to 0 (input)
	STR r2, [r0]
	
	LDMFD SP!, {r0-r2, lr}
	BX LR
	
	
	
	; interrupt_init
	;  Initializes interrupts for use
	;  Input:
	;   None
	;  Output:
	;   None
	;  Internal:
	;   r0: Memory addresses
	;   r1: Bit information
	;   r2: Bits
interrupt_init	 
	STMFD SP!, {r0-r2, lr}

	; Push button setup
	LDR r0, =PINSEL0					; setup P0.14 (push button) as external interrupt 1
	LDR r1, [r0]						; load PINSEL0
	ORR r1, r1, #0x20000000				; 0x2000 0000 = b00100000 00000000 00000000 00000000 -- turn ON bit 29
	BIC r1, r1, #0x10000000				; 0x1000 0000 = b00010000 00000000 00000000 00000000 -- turn OFF bit 28
	STR r1, [r0]						; PINSEL0 bits 29:28 = 10 (EINT1)
	
	; UART0 setup
	LDR r0, =U0IER						; setup UART0 IER to interrupt when RDA = 1
	LDR r1, [r0]						; load U0IER
	ORR r1, r1, #0x1					; 0x1 = b1 -- turn ON bit 0
	STR r1, [r0]						; U0IER bit 0 = 1 (RDA enabled)
	
	; Timer0 setup
	LDR r0, =T0MCR						; set MCR properties
	LDR r1, [r0]						; load T0MCR
	ORR r1, r1, #0x18					; 0x18 = b0001 1000 -- turn ON bits 4, 3
	BIC r1, r1, #0x20					; 0x = b0010 0000 -- turn OFF bit 5
	STR r1, [r0]						; T0MCR bits 5:3 = 011
	; bit 3: generates an interrupt when MR1 = TCR
	; bit 4: resets TCR when MR1 = TCR
	; bit 5: stops TCR when MR1 = TCR
	
	; Timer1 setup
	LDR r0, =T1MCR						; set MCR properties
	LDR r1, [r0]						; load T1MCR
	ORR r1, r1, #0x18					; 0x18 = b0001 1000 -- turn ON bits 4, 3
	BIC r1, r1, #0x20					; 0x = b0010 0000 -- turn OFF bit 5
	STR r1, [r0]						; T1MCR bits 5:3 = 011
	; bit 3: generates an interrupt when MR1 = TCR
	; bit 4: resets TCR when MR1 = TCR
	; bit 5: stops TCR when MR1 = TCR
    
    ; Set timer0 timeout
    LDR r0, =T0MR1						; set Timer0 timeout
	;LDR r1, =0x8CA000					; 0x8CA000 = 9.216 million, 18.432m/2 (2 Hz)
	LDR r1, =0x4B000					; 0x4B000 = 307,200 (60 Hz)
	STR r1, [r0]						; Timer0 ticks at 200Hz
	
	 ; Set timer1 timeout
    LDR r0, =T1MR1						; set Timer1 timeout
	LDR r1, =0x16800					; 0x16800 = 92160, 200 Hz
	STR r1, [r0]						; Timer1 ticks at 200Hz

	; Classify sources as IRQ or FIQ
	LDR r0, =ISR						; set EINT1, UART0, T0, T1 as FIQ
	LDR r1, [r0]						; load ISR
	LDR r2, =0x8070						; 0x8070 = b10000000 01110000 -- turn ON bits 15, 6, 5, 4
	ORR r1, r1, r2
	STR r1, [r0]						; ISR bits 15,6,5,4 = 1 (FIQ)

	; Enable interrupts
	LDR r0, =IER						; enable EINT1, UART0, T0, T1 interrupts
	LDR r1, [r0]						; load IER
	LDR r2, =0x8070						; 0x8070 = b10000000 01110000 -- turn ON bits 15, 6, 5, 4
	ORR r1, r1, r2
	STR r1, [r0]						; IER bits 15,6,5,4 = 1 (enabled)

	; External interrupt 1 setup for edge sensitive
	LDR r0, =EXTMODE					; set EINT1 to be edge sensitive
	LDR r1, [r0]						; load EXTMODE
	ORR r1, r1, #2						; 2 = b10 -- turn ON bit 1
	STR r1, [r0]						; EXTMODE bit 1 = 1 (edge-sensitive)
	
	; Enable timer0
	LDR r0, =T0TCR						; enable timer0 by writing to TCR
	LDR r1, [r0]						; load TCR
	ORR r1, r1, #0x1					; 1 = b1 -- turn ON bit 0
	STR r1, [r0]						; T0TCR bit 0 = 1 (enabled)
	
	; Enable timer1
	LDR r0, =T1TCR						; enable timer1 by writing to TCR
	LDR r1, [r0]						; load TCR
	ORR r1, r1, #0x1					; 1 = b1 -- turn ON bit 0
	STR r1, [r0]						; T1TCR bit 0 = 1 (enabled)

	; Enable FIQ's, disable IRQ's
	MRS r0, CPSR						; copy CPSR into general register
	BIC r0, r0, #0x40					; 0x40 = b0100 0000 -- turn OFF bit 6 (FIQ)
	ORR r0, r0, #0x80					; 0x80 = b1000 0000 -- turn ON bit 7 (IRQ)
	MSR CPSR_c, r0						; CPSR bits 7:6 = 10 (IRQ disabled, FIQ enabled)

	LDMFD SP!, {r0-r2, lr}
	BX lr



	; interrupt_disable
	;  Disables interrupts
	;  Input:
	;   None
	;  Output:
	;   None
	;  Internal:
	;   r0: Memory address
	;   r1: Bit information
interrupt_disable
	STMFD SP!, {r0-r1, lr}
	
	; disable push button
	LDR r0, =PINSEL0					; setup P0.14 (push button) as GPIO (hacky but works)
	LDR r1, [r0]						; load PINSEL0
	BIC r1, r1, #0x20000000				; 0x2000 0000 = b00100000 00000000 00000000 00000000 -- turn OFF bit 29
	BIC r1, r1, #0x10000000				; 0x1000 0000 = b00010000 00000000 00000000 00000000 -- turn OFF bit 28
	STR r1, [r0]						; PINSEL0 bits 29:28 = 00 (GPIO)
	
	; disable keyboard
	LDR r0, =U0IER						; setup UART0 IER to NOT interrupt when RDA = 1
	LDR r1, [r0]						; load U0IER
	BIC r1, r1, #0x1					; 0x1 = b1 -- turn OFF bit 0
	STR r1, [r0]						; U0IER bit 0 = 0 (RDA disabled)
	
	; disable timer0
	LDR r0, =T0TCR						; disable timer by writing to TCR
	LDR r1, [r0]						; load TCR
	BIC r1, r1, #0x1					; 1 = b1 -- turn OFF bit 0
	STR r1, [r0]						; T0TCR bit 0 = 0 (disabled)
	
	; disable timer1
	;LDR r0, =T1TCR						; disable timer by writing to TCR
	;LDR r1, [r0]						; load TCR
	;BIC r1, r1, #0x1					; 1 = b1 -- turn OFF bit 0
	;STR r1, [r0]						; T1TCR bit 0 = 0 (disabled)
	
	LDMFD SP!, {r0-r1, lr}
	BX lr
	
;---/Initialization---;

;---PuTTy Input/Output---;

	; read_character
	;  Input:
	;   None
	;  Output:
	;   r0: ASCII value from UART0
	;  Internal:
	;   r4: RDR checker/LSR loadin
	;   r5: base address of UART0
read_character
	STMFD SP!, {r4-r5, lr}
	
	LDR r5, =UART0
	
read_character__main
	LDRB r4, [r5, #U0LSR]				; load byte in LSR
	BIC r4, r4, #0xFE					; clear all but 0th bit (0xFE = b1111 1110)
	CMP r4, #0							; if RDR is 0, keep checking for new input
	BEQ read_character__main
	
	LDRB r0, [r5]						; read byte from Receive Buffer Register RBR
	
	LDMFD SP!, {r4-r5, lr}
	BX lr
	
	
	
	; read_string
    ;  Input:
    ;   r4: Base address of the string to modify
    ;   UART0: Keyboard input
    ;  Output:
    ;   r4: Modified string
	;  Internal:
    ;   r0: Current character being read
    ;   r4: Current position in string
    ; TODO: test/update
read_string 
	STMFD SP!, {r0, r4, lr}
    
    ; empty out the string
read_string__reset
    MOV r0, #0x1F						; use special "reset" character
    STRB r0, [r4]						; reset that character
    ADD r4, r4, #1						; go to the next position
    CMP r0, #0							; check if character is 'NULL'
    BNE read_string__reset				; if it is, continue
    
read_string__read_loop
	BL read_character					; read character from user
    BL output_character					; echo back to display
	
	STRB r0, [r4]						; store the character into the string
	CMP r0, #0xD						; check if character is 'ENTER'
	BEQ read_string__finally			; if 'ENTER' character, we're done
	ADD r4, r4, #1						; otherwise, go to the next position in string
	LDRB r0, [r4]						; read the next character in the string
	CMP r0, #0							; check if character is 'NULL'
	BNE read_string__read_loop			; if 'NULL' character, we're done

read_string__finally
	LDMFD SP!, {r0, r4, lr}
	BX lr



	; output_character
	;  Input:
    ;   r0: ASCII value to transmit
    ;  Output:
    ;   UART0: Prints ASCII value
    ;  Internal:
    ;   r4: Bit checker
    ;   r5: LSR address
output_character
	STMFD SP!, {r4-r5, lr}
	LDR r5, =UART0
	
output_character__loop
	LDRB r4, [r5, #U0LSR]			; load LSR
	BIC r4, r4, #0xDF				; clear all but 5th bit (0xDF = 11011111b)
	MOV r4, r4, LSR #5				; shift to 0th position
	CMP r4, #0						; check if THRE is 0
	BEQ output_character__loop		; if 0, not ready to send -- repeat loop

	STRB r0, [r5]					; send byte to Transmit Holding Register THR
	
	LDMFD SP!, {r4-r5, lr}
	BX lr
	
    
	
	; output_string
	;  Input:
	;   r4: Base address of string
	;  Output:
	;   UART0: Prints ASCII value of characters in string
	;  Internal:
	;   r0: Individual character in string
	;   r4: Address of current position in string
output_string
	STMFD SP!, {r0, r4, lr}
	
output_string__loop					; keep outputting until we're done with string
	LDRB r0, [r4]					; move first character into output_character input register
	
	CMP r0, #0						; if current character is NULL character, end loop
	BEQ output_string__finally
	
	CMP r0, #0x1F					; do not print out special UNIT SEPERATOR 0x1F
	BEQ output_string__advance
	
	BL output_character				; otherwise, output that character
	
output_string__advance
	ADD r4, r4, #1					; go to the next character
	B output_string__loop			; repeat instructions for next character

output_string__finally
	LDMFD SP!, {r0, r4, lr}
	BX lr
	
	
	; output_string_c
	;  Provides a method to use output_string from C
	;  Input:
	;   r0: Base address of string
	;  Output:
	;   UART0: Prints ASCII value of characters in string
	;  Internal:
	;   r4: output_string input
output_string_c
	STMFD SP!, {r4, lr}
	
	MOV r4, r0
	BL output_string
	
	LDMFD SP!, {r4, lr}
	BX lr

;---/Input/Output---;

;---Data Processing---;
	
	; num_to_ascii
	;  Input:
	;   r0: Number to convert
    ;   r4: Base address of string to modify
	;  Output:
	;   r4: String of number in ASCII form
	;  Internal:
	;   r1: IsNegative flag
	;   r5: Position counter
	;   r6: Special character to denote "do not print this character"
	;   r7: Divisor to div_and_mod/intermediate
	;   r8: Dividend to div_and_mod
num_to_ascii
	STMFD SP!, {r0-r1, r4-r8, lr}
	
	MOV r5, #0						; position counter
	MOV r6, #0x1F					; 0x1F = UNIT SEPARATOR -- special character for internal use
	
	CMP r0, #0						; if we have a negative number, set an IsNegative flag and make the number positive
	BGE num_to_ascii__reset_string
	MOV r1, #1						; IsNegative flag
	RSB r0, r0, #0					; 1 - num = -num --> positive
	
num_to_ascii__reset_string			; reset the string to be full of special characters
	STRB r6, [r4, r5]				; set base + offset character to special character
	ADD r5, r5, #1					; increment counter
	CMP r5, #4						; stop when we hit the last position
	BLE num_to_ascii__reset_string
	
	MOV r5, #4						; start at right position of string
	MOV r8, r0						; set dividend to be our number
	
num_to_ascii__loop
	MOV r7, #10						; divide by 10 and take remainder to get last digit
	BL div_and_mod
	
	ADD r7, r7, #48					; take remainder and add 48 to get ASCII character
	STRB r7, [r4, r5]				; store ASCII character into string
	SUB r5, r5, #1					; decrement offset
	CMP r8, #0						; if dividend is 0, we're done
	BNE num_to_ascii__loop
	
	CMP r1, #1						; if IsNegative is set, add a - to the front
	BNE num_to_ascii__finally
	
	MOV r0, #0x2D					; 0x2D = '-'
	STRB r0, [r4, r5]				; add - to the front

num_to_ascii__finally
	LDMFD SP!, {r0-r1, r4-r8, lr}
	BX lr
	
	
	
	; num_to_ascii_c
	;  Provides a method to use num_to_ascii from C
	;  Input:
	;   r0: Number to convert
    ;   r1: Base address of string to modify
	;  Output:
	;   r0: String of number in ASCII form
	;  Internal:
	;   r4: num_to_ascii input
num_to_ascii_c
	STMFD SP!, {r4, lr}
	
	LDR r4, =string_NUMBER
	BL num_to_ascii
	MOV r0, r4
	
	LDMFD SP!, {r4, lr}
	BX lr
    
    
	
	; ascii_to_num
	;  Input:
	;   r0: Length of string
	;   r4: Base address of string
	;  Output:
	;   r0: Converted number
	;  Internal:
	;   r0: Current position in string
	;   r2: Running sum of converted number
	;   r3: Multiplier counter
	;   r5: Current character
	;   r6: Multiplicand
	;   r7: In-between multiplying sum (10^x)
ascii_to_num
	STMFD SP!, {r1-r7, lr}
	
	SUB r0, r0, #1					; 0-indexed offset, so subtract 1 from 1-indexed length
	MOV r2, #0						; running sum of converted number
	MOV r3, #0						; counter for in-between multiplying
	MOV r6, #10						; multiply our number by 10^digit
	MOV r7, #1						; current multiplicand sum
	
ascii_to_num__loop
	LDRB r5, [r4, r0]				; load current character position
	SUB r5, r5, #0x30				; convert ASCII to number (subtract 48)
	
	MLA r2, r5, r7, r2				; multiply current digit times 10^position, add running sum, add to running sum
	MUL r7, r6, r7					; multiply multiplicand by 10
	SUB r0, r0, #1					; go to the next position in string
	CMP r0, #0						; stop once we hit the left-most position
	BGE ascii_to_num__loop
	
	MOV r0, r2						; move running sum to output register
	
	LDMFD SP!, {r1-r7, lr}
	BX lr
	
	
	
	; TODO: clean this up
	; div_and_mod
	;  Input:
	;   r
	;  Output:
	;   r
	;  Internal:
	;   r
div_and_mod

	; Implemented and modified div_and_mod from Lab 2
	; r7 - divisor/remainder, r8 - dividend/quotient, r9 - temp quotient, r10 - temp remainder, r11 - counter, r12 - sign checker
	; *** If divisor > dividend and the quotient should be negative, this will incorrectly return 0 as the quotient and the divisor as the remainder
	; *** example: -2/10 --> 0 remainder 2
	; *** correct: -1 remainder 8; or 0 remainder -2
	
	STMFD SP!, {r9-r12, lr}
	MOV r12, #1	  	  				; Initialize Sign Checker to 1
	CMP r7, #0						; Compare whether Divisor is positive
	BGT div_and_mod__dividend_check ; If it's positive, go to div_and_mod__dividend_check
	RSB r7, r7, #0					; Make Divisor positive for calculation
	RSB r12, r12, #0  				; Reverse Sign Checker
	
div_and_mod__dividend_check
	CMP r8, #0						; Compare whether Dividend is positive
	BGT div_and_mod__start			; If it's positive, go to div_and_mod__start
	RSB r8, r8, #0 					; Make Dividend positive for calculation
	RSB r12, r12, #0  				; Reverse Sign Checker
	
div_and_mod__start
	MOV r11, #15	  	  			; Initialize Counter to 15
	MOV r9, #0 	  	  				; Initialize Quotieint to 0
	LSL r7, #15	  	 				; Logical left shift Divisor 15 places
	MOV r10, r8	  	  				; Initialize Remainder to Dividend
	
div_and_mod__loop
	SUB r10, r10, r7				; Remainder := Remainder - Divisor
	CMP r10, #0 		  			; Compare whether Remainder < 0
	BGE div_and_mod__negative_remainder		; If it's greater, go to div_and_mod__negative_remainder
	
	ADD r10, r10, r7				; Remainder := Remainder + Divisor
	LSL r9, #1						; LSB = 0 for Quotient
	B div_and_mod__sign_checker		; Go to div_and_mod__sign_checker
	
div_and_mod__negative_remainder
	LSL r9, #1
	ADD r9, r9, #1					; LSB = 1 for Quotient
	
div_and_mod__sign_checker
	LSR r7, #1						; MSB = 0 for Divisor
	
	CMP r11, #0						; Compare whether Counter > 0
	BGT div_and_mod__counter_decrement		; If it's greater, go to div_and_mod__counter_decrement
	
	CMP r12, #0						; Compare whether Sign Checker > 0
	BGT div_and_mod__positive_sign	; If it's greater, go to div_and_mod__positive_sign
	RSB r9, r9, #0  				; If Sign Checker < 0, Reverse Quotient
	
div_and_mod__positive_sign
	MOV r8, r9						; Copy Quotient to r8
	MOV r7, r10						; Copy Remainer to r7
	B div_and_mod__finish 			; Go to div_and_mod__finish
	
div_and_mod__counter_decrement
	SUB r11, r11, #1				; Decrement Counter
	B div_and_mod__loop 			; Go to div_and_mod__loop
	
div_and_mod__finish
	LDMFD SP!, {r9-r12, lr}
	BX lr
	
;---/Data Processing---;

;---GPIO---;

	; push_button
	;  Input:
	;   GPIO: Push buttons pressed
	;  Output:
	;   r0: number indicated by push buttons
	;  Internal:
	;   r0: memory address/counter
	;   r1: push_button pins
	;   r2: intermediate reversed number
	;   r3: intermediate right-most bit
    ; TODO: test/update
push_button
	STMFD SP!, {r0-r3, lr}
	
	; read in the pins corresponding to the push buttons
	LDR r0, =IO1PIN
	; Push buttons: port 1, pins 20-23 (MSB 20)
	; b00000000 11110000 00000000 00000000
	; 0x00F00000
	LDR r1, [r0]						; read in push button inputs
	AND r1, r1, #0x00F00000				; we only care about these 4 bits (20-23)
	MOV r1, r1, LSR #20					; shift to the end
	RSB r1, r1, #0						; flip the bits (since by default these pins are inversed)
	SUB r1, r1, #1						; RSB adds 1, so remove that 1 to undo
	AND r1, r1, #0xF					; do another mask to grab the last 4 bits (remove leading F's)
	
	; the number is backwards, so reverse it
	; shift left, add right-most bit, repeat going left until out of bits
	MOV r0, #0							; counter
	MOV r2, #0							; reversed number
    
push_button__reverse
	ADD r0, r0, #1						; increment counter
	MOV r2, r2, LSL #1					; shift new number left 1 bit
	AND r3, r1, #1						; get the right-most bit
	ADD r2, r2, r3						; add to our current number
	MOV r1, r1, LSR #1					; push inputs to the right so we can get the right-most bit next time
	CMP r0, #4							; execute 4 times
	BLT push_button__reverse
    
    MOV r0, r2							; move reversed number into output register
	
	LDMFD SP!, {r0-r3, lr}
	BX LR
	
	
	
	; LED
	;  Input:
	;   r0: number to output
	;  Output:
	;   GPIO: Sets appropriate 4 LEDs
	;  Internal:
	;   r0: LED pinout
	;   r1: Quit flag/base memory address
	;   r2: data to send
	;   r7: divisor/remainder div_and_mod
	;   r8: dividend/quotient div_and_mod
    ; TODO: test/update
LED
	STMFD SP!, {r0-r2, r7-r8, lr}
	
	; turn the LEDs off
	LDR r1, =IO1SET						; write to port 1 SET (IO1SET) to turn off
	MOV r2, #0xF0000					; turn bits 16-19 off
	STR r2, [r1]						; store those bits to IO1SET
	
	; MSB is 16, LSB is 19
	; b00000000 00001234 00000000 00000000
	
	; algorithm: start at LSB and work towards MSB. divide by 2 and look at remainder.
	; remainder = 1 means turn that LED on. stop when dividend is 0.
LED__set_fourth_digit
	MOV r7, #2							; set divisor = 2 for binary conversion
	MOV r8, r0							; move the input number to the dividend
	BL div_and_mod

	CMP r7, #1							; if remainder is 0, skip to next digit
	BNE LED__set_third_digit

	MOV r0, #0							; initialize LED pinout
	; b00000000 00001000 00000000 00000000
	ORR r0, #0x00080000					; turn on 4th LED
	
LED__set_third_digit
	MOV r7, #2							; divide by 2 again
	BL div_and_mod						; keep the old dividend

	CMP r7, #1							; if remainder is 0, skip to next digit
	BNE LED__set_second_digit

	; b00000000 00000100 00000000 00000000
	ORR r0, #0x00040000					; turn on 3rd LED
	
LED__set_second_digit
	MOV r7, #2							; divide by 2 again
	BL div_and_mod

	CMP r7, #1							; if remainder is 0, skip to next digit
	BNE LED__set_first_digit

	; b00000000 00000010 00000000 00000000
	ORR r0, #0x00020000					; turn on 2nd LED
	
LED__set_first_digit
	CMP r8, #1							; if quotient (remainder) is 0, go directly to turning on LEDs
	BNE LED__on

	; b00000000 00000001 00000000 00000000
	ORR r0, #0x00010000					; turn on 1st LED

LED__on
	LDR r1, =IO1CLR						; write to port 1 CLR to turn on LEDs
	STR r0, [r1]						; send pinout
	
	LDMFD SP!, {r0-r2, r7-r8, lr}
	BX LR
	
	
	
    ; TODO: Make inputting the color more robust
	; RGB_LED
	;  Input:
	;   r0: Character code corresponding to color
	;  Output:
	;   UART0: Appropriate text
	;   GPIO: RGB LED set appropriately
	;  Internal:
	;   r0: RGB LED pinout
	;   r1: base memory address
	;   r2: data to send
RGB_LED
	STMFD sp!, {r0-r2, lr}
	
	CMP r0, #0x72 						; 'r'
	BEQ RGB_LED__red
	CMP r0, #0x52 						; 'R'
	BEQ RGB_LED__red
	
	CMP r0, #0x67 						; 'g'
	BEQ RGB_LED__green
	CMP r0, #0x47 						; 'G'
	BEQ RGB_LED__green
	
	CMP r0, #0x62 						; 'b'
	BEQ RGB_LED__blue
	CMP r0, #0x42 						; 'B'
	BEQ RGB_LED__blue
	
	CMP r0, #0x63						; 'c'
	BEQ RGB_LED__cyan
	CMP r0, #0x43						; 'C'
	BEQ RGB_LED__cyan
	
	CMP r0, #0x70 						; 'p'
	BEQ RGB_LED__purple
	CMP r0, #0x50 						; 'P'
	BEQ RGB_LED__purple
	
	CMP r0, #0x79 						; 'y'
	BEQ RGB_LED__yellow
	CMP r0, #0x59 						; 'Y'
	BEQ RGB_LED__yellow
	
	CMP r0, #0x77 						; 'w'
	BEQ RGB_LED__white
	CMP r0, #0x57 						; 'W'
	BEQ RGB_LED__white
	
	CMP r0, #0x6F						; 'o'
	BEQ RGB_LED__off
	CMP r0, #0x4F						; 'O'
	BEQ RGB_LED__off
    
    ; invalid character
    B RGB_LED__finally					; skip to the end
	
	; Pinout b00000000 00g00br0 00000000 00000000
RGB_LED__red
	MOV r0, #0x00020000					; RGB: 100 / b00000000 00000010 00000000 00000000
	B RGB_LED__on
	
RGB_LED__green
	MOV r0, #0x00200000					; RGB: 010 / b00000000 00100000 00000000 00000000
	B RGB_LED__on
	
RGB_LED__blue
	MOV r0, #0x00040000					; RGB: 001 / b00000000 00000100 00000000 00000000
	B RGB_LED__on
	
RGB_LED__cyan
	MOV r0, #0x00240000					; RGB: 011 / b00000000 00100100 00000000 00000000
	B RGB_LED__on

RGB_LED__purple
	MOV r0, #0x00060000					; RGB: 101 / b00000000 00000110 00000000 00000000
	B RGB_LED__on
	
RGB_LED__yellow
	MOV r0, #0x00220000					; RGB: 110 / b00000000 00100010 00000000 00000000
	B RGB_LED__on
	
RGB_LED__white
	MOV r0, #0x00260000					; RGB: 111 / b00000000 00100110 00000000 00000000
	B RGB_LED__on
	
RGB_LED__off
	MOV r0, #0x00000000					; RGB: 000 / b00000000 00000000 00000000 00000000
	B RGB_LED__on

RGB_LED__on
	LDR r1, =IO0SET						; first, turn the 3 LEDs off by writing 1 to SET
	MOV r2, #0x00260000					; corresponds to all 3 bits
	STR r2, [r1]						; write data

	LDR r1, =IO0CLR						; then, turn appropriate LEDs on by writing 1 to CLR
	STR r0, [r1]						; turn RGB LED pinout bits on

RGB_LED__finally
	LDMFD SP!, {r0-r2, lr}
	BX lr
	
	
	
	; seven_segment
	;  Input:
    ;   r0: ASCII value to output
	;   r1: digit to change (0 on left, 3 on right)
	;  Output:
	;   UART0: Appropriate text
	;   GPIO: Sets 7-segment display appropriately
	;  Internal:
    ;   r0: converted ASCII value to offset
	;   r2: base memory address
	;   r3: data to send/base map address
	;   r4: output_string input/data to send
	;   r5: hidden flag
seven_segment
	STMFD SP!, {r0, r2-r5, lr}
	
	MOV r5, #0							; IsSpace flag (0 = no, 1 = yes)
	CMP r0, #0x20						; if ' ', set hidden flag
	BNE seven_segment__invisible
	MOV r5, #1							; set hidden flag
	B seven_segment__display

seven_segment__invisible
	CMP r0, #0x1F						; if invisible char, set hidden flag
	BNE seven_segment__minus
	MOV r5, #1
	B seven_segment__display

seven_segment__minus
	CMP r0, #0x2D						; if '-', make offset be 16
	BNE seven_segment__number
	MOV r0, #16							; offset of 16 in lookup table
	B seven_segment__display
	
seven_segment__number
	CMP r0, #0x39						; check if they put in a number or a letter
	BGT seven_segment__letter			; if they did not put in 0-9 (0x39), assume they put in a letter
	SUB r0, r0, #48						; get number value from ASCII by subtracting 48
	B seven_segment__display

seven_segment__letter
	CMP r0, #0x46						; check if they put in uppercase or lowercase letter
	BGT seven_segment__letter2			; if they put in greater than 0x46 (F), assume they put in lowercase
	SUB r0, r0, #55						; go from 'A' to 10 --> 65 to 10 --> subtract 55
	B seven_segment__display

seven_segment__letter2					; they must have put in a lowercase letter
	SUB r0, r0, #87						; go from 'a' to 10 --> 97 to 10 --> subtract 87
	
seven_segment__display
	LDR r2, =IO0SET						; make all digits read only
	MOV r3, #0x3C						; b111100 = 0x3C
	STR r3, [r2]						; write 1 to pins 2-5 so we can't modify the digit
	
	LDR r2, =IO0CLR						; make our digit writeable
	MOV r3, #1							; pinout is 1 followed by digit+2 0's
	MOV r3, r3, LSL #2					; 1 + 2 0's
	MOV r3, r3, LSL r1					; 1 + (digit+2) 0's
	STR r3, [r2]						; write 0 to pin (digit + 2) so we can modify the digit
	
	LDR r2, =IO0CLR						; clear the segments
	LDR r3, =0xB780						; 0xB780 is all 7 segments
	STR r3, [r2]						; turn off the 7 segments
	
	CMP r5, #0							; if IsSpace, skip this section
	BNE seven_segment__finally
	LDR r2, =IO0SET						; display the character
   	LDR r3, =digits_SET					; base address of our table
   	MOV r0, r0, LSL #2					; shift our digit left by 2 places (width of map)
   	LDR r4, [r3, r0]					; load IOSET pattern: base + offset
   	STR r4, [r2]						; display

seven_segment__finally
	LDMFD SP!, {r0, r2-r5, lr}
	BX LR
	
;---/GPIO---;
	
	END