	; dmrichwa & mthafeez
	AREA interrupts, CODE, READWRITE
		
	;--Export--;
	EXPORT lab7
	EXPORT status_RGB
	EXPORT FIQ_Handler
	;--/Export--;
	
	;--Library--;
	EXTERN uart_init
	EXTERN gpio_init
	EXTERN interrupt_init
	EXTERN interrupt_disable
	
	EXTERN read_character
	EXTERN read_string
	EXTERN output_character
	EXTERN output_string
	
	EXTERN num_to_ascii
	EXTERN ascii_to_num
	EXTERN div_and_mod
	
	EXTERN push_button
	EXTERN LED
	EXTERN RGB_LED
	EXTERN seven_segment
	;--/Library--;
	
	;--C--;
	EXTERN start_game
	EXTERN mothership
	
	EXTERN clock_convert
	
	EXTERN update_board
    EXTERN handle_inputs
	;--/C--;

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

;---Constants---;
const_BOARD_RIGHT = "03",0	; Offset of board's left edge from left edge of window; MUST have length of 2
const_BOARD_DOWN = "03",0	; Offset of board's top edge from top edge of window; MUST have length of 2
;---/Constants---;

;---Strings---;
string_BOARD_CUR = "|---------------------||                     ||       OOOOOOO       ||       MMMMMMM       ||       MMMMMMM       ||       WWWWWWW       ||       WWWWWWW       ||                     ||                     ||                     ||                     ||                     ||   SSS   SSS   SSS   ||   S S   S S   S S   ||                     ||          A          ||---------------------|",0	; game board being displayed current tick
string_BOARD_NEW = "|---------------------||                     ||       OOOOOOO       ||       MMMMMMM       ||       MMMMMMM       ||       WWWWWWW       ||       WWWWWWW       ||                     ||                     ||                     ||                     ||                     ||   SSS   SSS   SSS   ||   S S   S S   S S   ||                     ||          A          ||---------------------|",0	; updated game board to be displayed next tick
string_BOARD_DEF = "|---------------------||                     ||       OOOOOOO       ||       MMMMMMM       ||       MMMMMMM       ||       WWWWWWW       ||       WWWWWWW       ||                     ||                     ||                     ||                     ||                     ||   SSS   SSS   SSS   ||   S S   S S   S S   ||                     ||          A          ||---------------------|",0	; default game board used to reset level
;string_BOARD_DEF = "|---------------------||                     ||                     ||                     ||                     ||                     ||             W       ||                     ||                     ||                     ||                     ||                     ||   SSS   SSS   SSS   ||   S S   S S   S S   ||                     ||          A          ||---------------------|",0	; default game board used to reset level
string_BULLETS_P = "                                                                                                                                                                                                                                                                                                                                                                                                       ",0	; location of player bullets
string_BULLETS_E = "                                                                                                                                                                                                                                                                                                                                                                                                       ",0	; location of enemy bullets
string_BULLETS_R = "                                                                                                                                                                                                                                                                                                                                                                                                       ",0	; default bullet string

string_IMAGE = "\033[32;1;32m\r\n                       .   *        .       .\r\n        *      -0-\r\n          .                .  *       - )-\r\n        .      *       o       .       *\r\n  o                \r\n            .     -O-\r\n .                 |        *      .     -0-\r\n        *  o     .    '       *      .        o\r\n               .         .        |      *\r\n   *             *              -O-          .",0
string_IMAGE_ = "\r\n        .             *         |     ,\r\n                .           o\r\n        .---.\r\n  =   _/__~0_\\_     .  *            o       '\r\n = = (_________)             .\r\n                 .                        *\r\n       *               - ) -       *\r\n \033[37;0;37m",0


string_ANSI = "\033[",0					; start of ANSI expression
string_ANSI_PUSHRIGHT = "\033[99C",0	; offset to push the gameboard to the right (used on newlines)
string_ANSI_PUSHAWAY = "\033[22;28H",0	; offset to cursor pushaway after each board update tick (moves cursor out of way)
string_ANSI_CURSOR = "\033[99;99H",0	; ANSI to move the cursor to a specific position (row;col)
string_ANSI_PAUSE = "\033[21;4H",0		; offset to paused text
string_ANSI_STATES = "\033[23;0H",0		; offset to display states 
string_NEWLINE = "\r\n",0				; newline

string_NUMBER = "\037\037\037\037\037",0						; intermediate string for num_to_ascii
string_INPUT = "\037\037\037\037\037\037\037\037\037\037",0		; input buffer; supports up to 10 inputs in one tick
string_START = "\r\n        \033[37;1;37mWelcome to \033[32;0;32mMicro Space Invaders\033[37;1;37m!       \r\n           \033[36;1;36mARE YOU READY TO TAKE OFF?!\033[37;0;37m         \r\n \r\n                    \033[35;1;35mCONTROLS\033[35;0;35m                   \r\n         'a' move left    move right 'd'       \r\n                 space to shoot                \033[37;0;37m",0
string_START_INPUT = "\r\n \r\n                      \033[31;1;31mMENU\033[31;0;31m                     \r\n        Hit \033[31;4;31mP\033[31;0;31m to Play game                \r\n         Hit \033[31;4;31mI\033[31;0;31m for Information              \r\n          Hit \033[31;4;31mQ\033[31;0;31m to Quit game                \r\n \r\n                                 \033[37;0;37mLevel 0\r\n",0
string_POINTS = "\r\n     \033[35;1;35m[ SCORING ]\033[35;0;35m     \r\n     W              10 pts\r\n     M              20 pts\r\n     O              40 pts\r\n     X      100 to 300 pts\r\n     Levels         50 pts\r\n     Deaths       -100 pts\033[37;0;37m\r\n",0
;string_HARDWARE = "\r\n     \033[36;1;36m[ HARDWARE ]\033[36;0;36m\r\n     Push button       Pause/Resume game\r\n     LEDs              Number of lives\r\n     7-seg             Current level score\r\n     RGB LED\r\n      WHITE            Menu\r\n      GREEN            During game\r\n      BLUE             Game paused\r\n      PURPLE           Next level and game over screens\r\n      RED flash        Player shot fired\033[37;0;37m\r\n",0
string_HARDWARE = "\r\n     \033[36;1;36m[ HARDWARE ]\033[36;0;36m\r\n     Push button       Pause/Resume game\r\n     LEDs              Number of lives\r\n     7-seg             Current level score\r\n     \033[31;1;40mR\033[32;1;40mG\033[34;1;40mB\033[36;0;36m LED\r\n      \033[30;1;47mWHITE\033[36;0;36m            Menu\r\n      \033[30;1;42mGREEN\033[36;0;36m            During game\r\n      \033[37;1;44mBLUE\033[36;0;36m             Game paused\r\n      \033[37;1;45mPURPLE\033[36;0;36m           Next level and game over screens\r\n      \033[37;1;41mRED flash\033[36;0;36m        Player shot fired\033[37;0;37m\r\n",0
;string_INFO = "\r\n     \033[32;1;32m[ INFO ]\033[32;0;32m\r\n     You start with 4 lives\r\n      To move to the next level, kill all invaders (excluding mothership)\r\n     The game speeds up every level\r\n      If invaders breach your shields or get too close, you lose!\r\n     The game automatically ends after 2 minutes\r\n      Quit at any time by hitting Q\033[37;0;37m\r\n",0
string_INFO = "\r\n     \033[32;1;32m[ INFO ]\033[32;0;32m\r\n     You start with 4 lives\r\n      To move to the next level, kill all invaders (excluding mothership)\r\n       The game speeds up every level\r\n        If invaders breach your shields or get too close, you lose!\r\n         The game automatically ends after 2 minutes\r\n          Quit at any time by hitting Q\033[37;0;37m\r\n",0
string_THANKS_INFO = "\r\n     \033[33;1;33m[ THANK YOU ]\033[33;0;33m\r\n     Dr. Kris Schindler and his TAs, for making this possible!\r\n      CSE241 TAs, for allowing us to work during their lab hours\r\n       Convenient fast food places, for feeding us\r\n        - David Richwalder and Mohammad Hafeez\033[31;0;31m\r\n\r\n       Hit \033[31;4;31mI\033[31;0;31m to return to menu\033[37;0;37m                     Level 0\r\n",0
;string_BORDER = "\r\n     |----------|\r\n",0
string_BORDER = "\r\n",0
string_THANK_YOU = "\r\n     \033[36;1;36mThank you for playing Micro Space Invaders!\r\n     Please leave us a like, follow, subscribe, join our Patreon, give us an A, and donate!",0

string_END = "Game over.",0																; game over screen
string_PAUSE = "Paused",0																; string to display when paused
string_CONTINUE = "      ",0															; string to clear the paused text
string_LEVEL = "Level: ",0
string_TOTAL = "Total",0
string_LEVEL_GAMEOVER = "Level ",0
string_LEVEL_COMPLETE = "Congratulations! You completed level ",0
string_LEVEL_COMPLETE_PTS = " (+50 points)",0
string_LEVEL_TIMER = "Time taken (s): ",0
string_LEVEL_POINTS = "Level points: ",0
string_TOTAL_POINTS = "Total points: ",0
string_LEVEL_DEATH = "Player deaths: ",0
string_MOTHER_LEVEL = "Motherships this level: ",0
string_MOTHER_TOTAL = "Motherships this game: ",0
string_LIVES = "Lives: ",0
string_NEXT_LEVEL = "Press 'p' to go to the next level or press 'q' to quit.",0
string_PLAY_AGAIN = "Press 'p' to play again or press 'q' to quit.",0
string_LEVEL_CLOCK = "Level clock (s): ",0
string_GAME_CLOCK = "Game clock (s): ",0

string_SCORE = "00000",0		; level score string
string_SCORE_TOTAL = "00000",0	; total score string
string_TIME = "00000",0			; level time in seconds
string_TOTAL_TIME = "00000",0	; total time in seconds
string_EMPTY = "      ",0		; empty time string

string_TIME_BREAKDOWN = "                                                                                                                                                                                                                                                          ",0
string_POINTS_BREAKDOWN = "                                                                                                                                                                                                                                                          ",0
string_DEATH_BREAKDOWN = "                                                                                                                                                                                                                                                          ",0
string_MOTHER_SPAWN_BREAKDOWN = "                                                                                                                                                                                                                                                          ",0
string_MOTHER_KILL_BREAKDOWN = "                                                                                                                                                                                                                                                          ",0
;---/Strings---;

;---Flags---;	; all flags are left-aligned -- byte 0 corresponds to the leftmost string position
;--Internal--;
flag_INPUT = "00",0
	; byte 0: last input of WASD
	; byte 1: should shoot on next tick
flag_DONEPRINTING = " ",0
	; 0: no -- do not update board
	; 1: yes -- update board
flag_STROBING = " ",0
	; 0: Display on digit 0
	; 1: Display on digit 1
	; 2: Display on digit 2
	; 3: Display on digit 3
;--/Internal--;

;--Memory--;
flag_GAMESTATUS = " ",0
	; 0: pre-game (menu)
    ; 1: playing
    ; 2: paused
    ; 3: post-game (game over/scoreboard)
	; 4: next level
flag_SCORE = "  ",0
	; level score
flag_SCORE_TOTAL = "  ",0
	; total score
flag_GAME_CLOCK = "  ",0
	; overall game timer
flag_LEVEL_CLOCK = "  ",0
	; level timer
flag_RANDOM = " ",0
	; stored RNG value
flag_LIVES = " ",0
	; bits 0-3: number of lives (bit 3 = 4 lives, bit 2 = 3 lives, bit 1 = 2 lives, bit 0 = 1 life) [0 lives would send us to game over screen]
flag_MISC = "                   ",0
	; byte 0: enemies moving left/right (0 = left, 1 = right)
	; byte 1: mothership moving left/right (0 = left, 1 = right)
	; byte 2: mothership needs to spawn or is currently spawned? (0 = no, 1 = yes)
	; byte 3: level flag (level 0 = menu or game over; max 2^8 - 1 = 255)
	; byte 4: how many motherships spawned in this level (max 255)
	; byte 5: how many motherships were killed in this level (max 255)
	; byte 6: death count in this level (max 255)
	; byte 7: how many motherships spawned this game (max 255)
	; byte 8: how many motherships were killed this game (max 255)
    ; byte 9: bottom row of enemies (max 255)
	; byte 10: timer0 counter (0-59)
	; byte 11: did we move enemies down last tick? (0 = no, 1 = yes)
	; byte 12: RGB LED counter (flashing when shooting) (0 = no, 1 = just shot, 2+ = in middle of animation)
	; byte 13: flush inputs? (0 = no, 1 = yes)
	; byte 14: player death animation counter (0 = unused, 1 = start, 2+ = in middle)
	; byte 15: timer 1 counter (0-199)
	; byte 16: mothership kill animation counter (0 = unused, 1 = start, 2+ = in motion)
	; byte 17: mothership kill animation position (column)
	; byte 18: stored mothership score
	; byte 19: player death animation position (column)
;--/Memory--;
;---/Flags---;
	ALIGN
	


	; lab7
	;  Main program function
	;  Input:
	;   r0: 
	;  Output:
	;   r0: 
	;  Internal:
	;   r0: 
lab7
	STMFD SP!, {r0-r12, lr}

	BL uart_init						; initialize UART
	BL gpio_init						; initialize GPIO
	
	; update the PUSHRIGHT string
	LDR r4, =string_ANSI_PUSHRIGHT
	LDR r0, =const_BOARD_RIGHT			; amount to push the board right
	LDR r1, [r0]						; load the amount
	STRB r1, [r4, #2]					; set upper byte
	ADD r0, r0, #1						; go to the next byte
	LDR r1, [r0]						; load the next byte
	STRB r1, [r4, #3]					; set lower byte
	
__play_again
	BL main_screen						; go to the main menu
	LDR r4, =flag_GAMESTATUS			; check if game status is 3 (game over)
	LDRB r0, [r4]
	CMP r0, #3
	BEQ lab7__finally
	
__play_next_level
	BL print_board						; print out the board
	
	BL status_RGB						; update the RGB LED
	
	BL interrupt_init					; initialize interrupts (wait until after menu so keyboard handling works properly)
	
lab7__loop
	LDR r4, =flag_GAMESTATUS			; load game status flag
	LDRB r0, [r4]
	AND r0, r0, #7						; isolate bits 2:0
	CMP r0, #4							; if game status is 4 (next level), move to the next level 
	BEQ lab7__next_level
	CMP r0, #3							; if game status is not 3 (game over), keep waiting
	BEQ lab7__quit
	B lab7__loop						; keep looping
	
lab7__next_level
	BL interrupt_disable				; disable interrupts
	
	BL next_level						; go to the next level
	
	LDR r4, =flag_GAMESTATUS			; check if game status is 1 (playing)
	LDRB r0, [r4]
	CMP r0, #1
	BEQ __play_next_level				; if yes, go to the next level section
    ;B lab7__finally						; otherwise quit the game
	
lab7__quit
	BL interrupt_disable				; disable interrupts
	
	BL quit_game						; quit the game
	
	LDR r4, =flag_GAMESTATUS			; check if game status is 1 (playing)
	LDRB r0, [r4]
	CMP r0, #1
	BEQ __play_again					; if yes, go to the play again section
	B lab7__finally						; otherwise quit the game
	
lab7__finally
	MOV r0, #0xC						; clear the screen by printing form feed
	BL output_character

	LDR r4, =string_THANK_YOU
	BL output_string
	
	LDMFD SP!, {r0-r12, lr}
	BX lr
	
	
	
	; main_screen
	;  Main screen of the program 
	;  Input:
	;   r0: 
	;  Output:
	;   r4: 
	;  Internal:
	;   r0:	
main_screen
	STMFD SP!, {r0, r4, lr}
	
	; reset variables
	LDR r4, =flag_SCORE					; reset level score flag
	MOV r2, #2
	BL flag_clear
	
	LDR r4, =flag_SCORE_TOTAL			; reset total score flag
	MOV r2, #2	
	BL flag_clear
	
	LDR r4, =flag_GAME_CLOCK			; reset game clock flag
	MOV r2, #2
	BL flag_clear
	
	LDR r4, =flag_LEVEL_CLOCK			; reset level clock flag
	MOV r2, #2
	BL flag_clear
	
	LDR r4, =flag_MISC					; reset misc flags
	MOV r2, #19
	BL flag_clear
	
	LDR r4, =flag_STROBING				; reset strobing flag to 1
	MOV r0, #1
	STRB r0, [r4]
	
	LDR r4, =flag_LIVES					; set the initial lives of the player to be 4
	MOV r0, #0xF						; 0xF = b1111
	STRB r0, [r4]
	
	LDR r4, =flag_GAMESTATUS			; set game status to 0 (menu)
	MOV r2, #1
    BL flag_clear
	BL status_RGB
	
	MOV r0, #0xC						; clear the screen by printing form feed
	BL output_character
	
	LDR r4, =start_game 				; load address of C start_game
	LDR r0, =flag_GAMESTATUS			; first arg is flag_GAMESTATUS
	LDR r1, =flag_MISC					; second arg is flag_MISC
	LDR r2, =flag_RANDOM				; third arg is flag_RANDOM
	LDR r3, =flag_LIVES					; fourth arg is flag_LIVES
	MOV LR, PC
	BX r4								; call start_game
	
	LDR r4, = string_IMAGE 
	BL output_string	
	LDR r4, = string_IMAGE_ 
	BL output_string	
		
		
	LDR r4, =string_START				; print out the start string
	BL output_string
	
	LDR r4, = string_START_INPUT
	BL output_string
	
main_screen__read
	BL read_character					; read the character from the user
	
	CMP r0, #0x71						; if the user hit 'q', quit
	BEQ main_screen__quit
	CMP r0, #0x51						; if the user hit 'Q', quit
	BEQ main_screen__quit

	CMP r0, #0x70						; if the user hit 'p', start playing
	BEQ main_screen__play
	CMP r0, #0x50						; if the user hit 'P', start playing
	BEQ main_screen__play
	
	CMP r0, #0x69						; if the user hit 'i', start playing
	BLEQ how_to_screen
	CMP r0, #0x49						; if the user hit 'I', start playing
	BLEQ how_to_screen
	
	B main_screen__read					; if the user has entered the wrong char keep reading
	
main_screen__quit
	LDR r4, =flag_GAMESTATUS			; set game status to 3 (quit)
	MOV r0, #3
	STRB r0, [r4]
	
	B main_screen__finally
	
main_screen__play
	LDR r4, =flag_MISC 					; load byte 3 of MISC: level flag
	LDRB r0, [r4, #3]
	ADD r0, r0, #1						; increase the level by 1
	STRB r0, [r4, #3]					; store the new level value
	
	LDR r4, =flag_GAMESTATUS			; set game status to 1 (playing)
	MOV r0, #1
	STRB r0, [r4]
	
main_screen__finally
	LDMFD SP!, {r0, r4, lr}
	BX lr
	
	
	; how_to_screen
	;  Prints out isntructions
	;  Input:
	;   r0: 
	;  Output:
	;   r4: 
	;  Internal:
	;   r0:
how_to_screen	
	STMFD SP!, {r0, r4, lr}
	
	MOV r0, #0xC						; clear the screen by printing form feed
	BL output_character
	
	LDR r4, = string_BORDER
	BL output_string
	
	LDR r4, =string_POINTS				; print out the start string
	BL output_string

	LDR r4, = string_BORDER
	BL output_string
	
	LDR r4, =string_HARDWARE				; print out the start string
	BL output_string

	LDR r4, =string_BORDER
	BL output_string
	
	LDR r4, =string_INFO				; print out the start string
	BL output_string
	
	LDR r4, = string_BORDER
	BL output_string
	
	LDR r4, = string_THANKS_INFO
	BL output_string
	
how_to_screen__read
	BL read_character					; read the character from the user
	
		
	CMP r0, #0x69						; if the user hit 'i', start playing
	BLEQ how_to_screen__leave
	CMP r0, #0x49						; if the user hit 'I', start playing
	BLEQ how_to_screen__leave
	
	
	B how_to_screen__read					; if the user has entered the wrong char keep reading

	
how_to_screen__leave
	
	MOV r0, #0xC						; clear the screen by printing form feed
	BL output_character
	
	LDR r4, = string_IMAGE 
	BL output_string	
	LDR r4, = string_IMAGE_ 
	BL output_string	
	
	
	LDR r4, =string_START				; print out the start string
	BL output_string
	
	LDR r4, = string_START_INPUT
	BL output_string
	
	
	LDMFD SP!, {r0, r4, lr}
	BX lr
	
	
	
	; print_board
	;  Prints out the full game board
	;  Input:
	;   r0: 
	;  Output:
	;   r4: 
	;  Internal:
	;   r0:
print_board
	STMFD SP!, {r0-r2, r4-r9, lr}
	
	LDR r4, =string_BOARD_DEF			; default board string
	LDR r5, =string_BOARD_CUR			; current board string
	LDR r6, =string_BOARD_NEW			; new board string
	LDR r7, =string_BULLETS_R			; default bullet string
	LDR r8, =string_BULLETS_P			; player bullet string
	LDR r9, =string_BULLETS_E			; enemy bullet string

print_board__copy						; copy the default board string into the new and current board strings
	LDRB r0, [r4], #1					; load current byte of default board string and go to next byte
	STRB r0, [r5], #1					; store current byte of current board string and go to next byte
	STRB r0, [r6], #1					; store current byte of new board string and go to next byte
	LDRB r0, [r7], #1					; load current byte of default bullet string and go to next byte
	STRB r0, [r8], #1					; store current byte of player bullet string and go to next byte
	STRB r0, [r9], #1					; store current byte of enemy bullet string and go to next byte
	
	LDRB r0, [r4]						; stop once we hit the NULL character [assumes board and bullet strings are equal length]
	CMP r0, #0
	BNE print_board__copy
	
	LDR r4, =flag_DONEPRINTING			; set flag saying we're not done printing (0)
	MOV r0, #0
	STRB r0, [r4]
	
	MOV r0, #0xC					; clear the screen by printing form feed
	BL output_character
	
	; move the cursor to the game board's offset from upperleft corner
	LDR r4, =string_ANSI_CURSOR			; load cursor string
	
	; load the DOWN string into the CURSOR string
	LDR r0, =const_BOARD_DOWN		; amount to push the board down
	LDR r1, [r0]					; load the amount
	STRB r1, [r4, #2]				; set upper byte
	ADD r0, r0, #1					; go to the next byte
	LDR r1, [r0]					; load the next byte
	ADD r1, r1, #1					; position is 0-indexed but offset is 1-indexed, so add 1 to fix
	STRB r1, [r4, #3]				; set lower byte
	; load the RIGHT string into the CURSOR string
	LDR r0, =const_BOARD_RIGHT		; amount to push the board right
	LDR r1, [r0]					; load the amount
	STRB r1, [r4, #5]				; set upper byte
	ADD r0, r0, #1					; go to the next byte
	LDR r1, [r0]					; load the next byte
	ADD r1, r1, #1					; position is 0-indexed but offset is 1-indexed, so add 1 to fix
	STRB r1, [r4, #6]				; set lower byte
	
	BL output_string				; move the cursor
	
	; start printing out the board
	LDR r1, =string_BOARD_CUR		; base address of current board string
	MOV r2, #0						; counter for newline
	
print_board__read_loop
	LDRB r0, [r1]					; current character
	ADD r1, r1, #1					; go to the next character
	CMP r0, #0						; if 'NULL', we finished execution
	BEQ print_board__finally
	
	BL output_character				; print out the current character
	ADD r2, r2, #1					; increment counter
	CMP r2, #23						; once we hit game board width (0-23 = 24), go to next line
	BLT print_board__read_loop
	
print_board__newline				; print \n\r
	MOV r0, #0xA					; \n
	BL output_character
	MOV r0, #0xD					; \r
	BL output_character
	
	LDR r4, =string_ANSI_PUSHRIGHT	; push cursor back to the right
	BL output_string
	
	MOV r2, #0						; reset counter
	B print_board__read_loop		; go back to loop
	
print_board__finally
	LDR r4, =flag_DONEPRINTING
	MOV r0, #1
	STRB r0, [r4]					; set flag saying we're done printing (1)
	
	LDMFD SP!, {r0-r2, r4-r9, lr}
	BX lr
	
	
	
	; update_display
	;  Updates the display based on differences between the NEW and CUR board strings
	;  Input:
	;   r0: 
	;  Output:
	;   r4: 
	;  Internal:
	;   r0:
update_display
	STMFD SP!, {r0-r12, lr}
	
	LDR r4, =flag_DONEPRINTING		; check if we're done printing
	LDRB r5, [r4]
	CMP r5, #0						; if we're still printing, skip this subroutine
	BEQ update_display__finally
	
	MOV r10, #0						; counter of where we are in the board string
	LDR r4, =string_BOARD_CUR		; base address of current board string
	LDR r5, =string_BOARD_NEW		; base address of new board string
	
update_display__loop
	LDRB r1, [r4, r10]				; load current board string char
	LDRB r2, [r5, r10]				; load new board string char
	ADD r10, r10, #1				; increment counter
	CMP r1, #0						; check if 'NULL' character
	BEQ update_display__finally		; done when 'NULL' reached
	CMP r1, r2						; check if new and current are same char
	BEQ update_display__loop		; if they are, just check the next one
	
	; NEW and CUR do not match, so print out the NEW and update the CUR
update_display__update
	STMFD SP!, {r0-r12, lr}
	
	; START moving cursor
	SUB r10, r10, #1				; position is 1 too high when we enter subroutine
	
	; get row and col by dividing position by game board width -- quotient is row, remainder is column
	MOV r7, #23						; divisor of 23 (game board width)
	MOV r8, r10						; dividend of current position
	BL div_and_mod
	
	LDR r4, =const_BOARD_RIGHT		; load RIGHT amount
	MOV r0, #2						; length of string
	BL ascii_to_num					; convert the string into a number
	ADD r7, r7, r0					; add the RIGHT amount to #col
	
	LDR r4, =const_BOARD_DOWN		; load DOWN amount
	MOV r0, #2						; length of string
	BL ascii_to_num					; convert the string into a number
	ADD r8, r8, r0					; add the DOWN amount to #row
	
	ADD r7, r7, #1					; offsets are 0-indexed but ANSI is 1-indexed, so add 1 to compensate
	ADD r8, r8, #1					; offsets are 0-indexed but ANSI is 1-indexed, so add 1 to compensate
	
	; start ANSI cursor movement
	LDR r4, =string_ANSI			; print out start of ANSI
	BL output_string
	; move cursor down
	MOV r0, r8						; convert quotient to ASCII
	LDR r4, =string_NUMBER
	BL num_to_ascii					; PUSHDOWN amount is quotient
	BL output_string				; print out the ROW component
	; separate row and column
	MOV r0, #0x3B					; ';'
	BL output_character				; print out the semicolon
	; move cursor right
	MOV r0, r7						; convert remainder to ASCII
	LDR r4, =string_NUMBER
	BL num_to_ascii					; PUSHRIGHT amount is remainder
	BL output_string				; print out the COL component
	; end ANSI cursor movement
	MOV r0, #0x48					; 'H' to close out ANSI
	BL output_character
	; END moving cursor
	
	LDR r5, =string_BOARD_NEW
	LDRB r0, [r5, r10]				; load character at current position in NEW string
	BL output_character				; print out that character
	
	LDR r4, =string_BOARD_CUR
	STRB r0, [r4, r10]				; update current character string
	
	LDMFD SP!, {r0-r12, lr}
	
	B update_display__loop			; continue updating
	
update_display__finally
	LDMFD SP!, {r0-r12, lr}
	BX lr
	
	
	
	; next_level
	;  Move to next level and reset board
	;  Input:
	;   r0: 
	;  Output:
	;   r4: 
	;  Internal:
	;   r0:	
next_level
	STMFD SP!, {r0-r1, r4, lr}	
	
	MOV r0, #0xC						; clear the screen by printing form feed
	BL output_character
	
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	LDR r4, =string_LEVEL_COMPLETE		; display the level complete prompt
	BL output_string
	LDR r4, =flag_MISC					; load byte 3 of MISC flag: level flag
	LDRB r0, [r4, #3]
	LDR r4, =string_NUMBER
	BL num_to_ascii						; convert to string
	BL output_string					; display the level
	LDR r4, =string_LEVEL_COMPLETE_PTS
	BL output_string
	
	LDR r1, =flag_LEVEL_CLOCK			; convert the level clock into ASCII
	LDRB r0, [r1, #1]
	LDR r4, =string_TIME				; put the converted ASCII into string_TIME
	BL num_to_ascii						; convert time to ascii
	
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	LDR r4, = string_LEVEL_TIMER		; display level timer prompt
	BL output_string
	LDR r4, = string_TIME				; display level time
	BL output_string
	
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	LDR r4, =string_LEVEL_POINTS		; print out the level score
	BL output_string
	LDR r4, =string_SCORE
	BL output_string
	
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	LDR r4, =string_TOTAL_POINTS		; print out the total score
	BL output_string
	LDR r4, =string_SCORE_TOTAL
	BL output_string
	
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	LDR r4, =string_LEVEL_DEATH			; print out the death count
	BL output_string
	LDR r4, =flag_MISC					; load byte 6 of MISC flag: death count
	LDRB r0, [r4, #6]
	LDR r4, =string_NUMBER
	BL num_to_ascii						; convert to string
	BL output_string
	
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	LDR r4, =string_MOTHER_LEVEL		; print out the motherships spawned and killed this level
	BL output_string
	LDR r4, =flag_MISC					; load byte 5 of MISC flag: mothership kills this level
	LDRB r0, [r4, #5]
	LDR r4, =string_NUMBER
	BL num_to_ascii						; convert to string
	BL output_string
	
	MOV r0, #0x2F						; '/'
	BL output_character
	
	LDR r4, =flag_MISC					; load byte 4 of MISC flag: mothership spawns this level
	LDRB r0, [r4, #4]
	LDR r4, =string_NUMBER
	BL num_to_ascii						; convert to string
	BL output_string
	
	; Update breakdown strings
	LDR r4, =flag_MISC					; load byte 3 of MISC flag: level flag
	LDRB r0, [r4, #3]
	MOV r1, #5							; offset
	MUL r1, r0, r1						; offset is 5 * (level - 1)
	SUB r10, r1, #5						; do the minus 1 level
	
	; points breakdown
	LDR r4, =string_POINTS_BREAKDOWN
	LDR r5, =string_SCORE
	MOV r1, #0							; offset counter
	
next_level__brkdwn_pts
	LDRB r2, [r5, r1]					; load current byte of string
	ADD r3, r10, r1						; breakdown offset = string offset + base breakdown offset 
	STRB r2, [r4, r3]					; store byte into breakdown
	ADD r1, r1, #1						; increment counter
	CMP r1, #5							; stop once we hit 5
	BLT next_level__brkdwn_pts
	
	; time breakdown
	LDR r4, =string_TIME_BREAKDOWN
	LDR r5, =string_TIME
	MOV r1, #0							; offset counter
	
next_level__brkdwn_time
	LDRB r2, [r5, r1]					; load current byte of string
	ADD r3, r10, r1						; breakdown offset = string offset + base breakdown offset 
	STRB r2, [r4, r3]					; store byte into breakdown
	ADD r1, r1, #1						; increment counter
	CMP r1, #5							; stop once we hit 5
	BLT next_level__brkdwn_time
	
	; death count breakdown
	LDR r4, =flag_MISC					; load byte 6 of MISC flag: death count
	LDRB r0, [r4, #6]
	LDR r4, =string_NUMBER
	BL num_to_ascii						; convert to string
	MOV r5, r4
	LDR r4, =string_DEATH_BREAKDOWN
	MOV r1, #0							; offset counter
	
next_level__brkdwn_deaths
	LDRB r2, [r5, r1]					; load current byte of string
	ADD r3, r10, r1						; breakdown offset = string offset + base breakdown offset 
	STRB r2, [r4, r3]					; store byte into breakdown
	ADD r1, r1, #1						; increment counter
	CMP r1, #5							; stop once we hit 5
	BLT next_level__brkdwn_deaths
	
	; mothership spawn breakdown
	LDR r4, =flag_MISC					; load byte 4 of MISC flag: mothership spawns this level
	LDRB r0, [r4, #4]
	LDR r4, =string_NUMBER
	BL num_to_ascii						; convert to string
	MOV r5, r4
	LDR r4, =string_MOTHER_SPAWN_BREAKDOWN
	MOV r1, #0							; offset counter
	
next_level__brkdwn_spawn
	LDRB r2, [r5, r1]					; load current byte of string
	ADD r3, r10, r1						; breakdown offset = string offset + base breakdown offset 
	STRB r2, [r4, r3]					; store byte into breakdown
	ADD r1, r1, #1						; increment counter
	CMP r1, #5							; stop once we hit 5
	BLT next_level__brkdwn_spawn
	
	; mothership kill breakdown
	LDR r4, =flag_MISC					; load byte 5 of MISC flag: mothership kills this level
	LDRB r0, [r4, #5]
	LDR r4, =string_NUMBER
	BL num_to_ascii						; convert to string
	MOV r5, r4
	LDR r4, =string_MOTHER_KILL_BREAKDOWN
	MOV r1, #0							; offset counter
	
next_level__brkdwn_kill
	LDRB r2, [r5, r1]					; load current byte of string
	ADD r3, r10, r1						; breakdown offset = string offset + base breakdown offset 
	STRB r2, [r4, r3]					; store byte into breakdown
	ADD r1, r1, #1						; increment counter
	CMP r1, #5							; stop once we hit 5
	BLT next_level__brkdwn_kill
	
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	LDR r4, =string_NEXT_LEVEL			; print out next level string
	BL output_string
	
next_level__read
	BL read_character					; read the character from the user
	
	CMP r0, #0x71						; if the user hit 'q', quit
	BEQ next_level__quit
	CMP r0, #0x51						; if the user hit 'Q', quit
	BEQ next_level__quit

	CMP r0, #0x70						; if the user hit 'p', start playing
	BEQ next_level__play
	CMP r0, #0x50						; if the user hit 'P', start playing
	BEQ next_level__play
	
	B next_level__read					; if the user has entered the wrong char keep reading
	
next_level__quit
	LDR r4, =flag_GAMESTATUS			; set game status to 3 (quit)
	MOV r0, #3
	STRB r0, [r4]
	
	B next_level__finally
	
next_level__play
	; reset variables	
	LDR r4, =flag_LEVEL_CLOCK			; clear the level timer flag
	MOV r2, #2
	BL flag_clear
	
	LDR r4, =string_SCORE				; clear the level score string
	BL string_clear
	
	LDR r4, =flag_SCORE					; clear the level score flag
	MOV r2, #2
	BL flag_clear
	
	LDR r4, =flag_MISC 					; load byte 3 of MISC flag: level
	LDRB r0, [r4, #3]
	ADD r0, r0, #1						; increase level by 1
	STRB r0, [r4, #3]					; store the new level value
	
	; reset various MISC flags
	MOV r0, #0							; value to store
	STRB r0, [r4, #1]					; reset motherboard direction flag 
	STRB r0, [r4, #2]					; reset mothership spawn flag
	STRB r0, [r4, #4]					; reset the number of motherships spawned in the level
	STRB r0, [r4, #5]					; reset the number of motherships killed in the level
	STRB r0, [r4, #6]					; reset the death count of the level
	
	LDR r4, =flag_GAMESTATUS			; set game status to 1 (playing)
	MOV r0, #1
	STRB r0, [r4]
	
next_level__finally
	LDMFD SP!, {r0-r1, r4, lr}
	BX lr
	
	
	
	; quit_game
	;  displays game over screen
	;  Input:
	;   r0: 
	;  Output:
	;   r4: 
	;  Internal:
	;   r0:	
quit_game
	STMFD SP!, {r0-r1, r4, lr}
	
	BL status_RGB						; update the RGB
	
	MOV r0, #0xC						; clear the screen by printing form feed
	BL output_character
	
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	LDR r4, =string_END					; print out the final string
	BL output_string
	
	MOV r2, #0							; current level
	
quit_game__level
	ADD r2, r2, #1						; go to the next level
	
	LDR r4, =flag_MISC					; load byte 3 of MISC flag: level flag
	LDRB r0, [r4, #3]
	
	CMP r2, r0							; stop once we get to our current level
	BGE quit_game__continue
	
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	
	; print out the level
	LDR r4, =string_LEVEL_GAMEOVER
	BL output_string
	MOV r0, r2							; convert level to number
	LDR r4, =string_NUMBER
	BL num_to_ascii						; convert to string
	BL output_string					; display the level
	
	MOV r1, #5							; offset
	MUL r1, r2, r1						; offset is 5 * (level - 1)
	SUB r10, r1, #5						; do the minus 1 level
	
	; time breakdown
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	LDR r4, =string_LEVEL_TIMER			; print out the time breakdown
	BL output_string
	LDR r4, =string_TIME_BREAKDOWN
	MOV r1, #0							; offset counter
	
quit_game__brkdwn_time
	ADD r3, r10, r1						; breakdown offset = string offset + base breakdown offset 
	LDRB r0, [r4, r3]					; load byte from breakdown
	BL output_character					; print out the character
	ADD r1, r1, #1						; increment counter
	CMP r1, #5							; stop once we hit 5
	BLT quit_game__brkdwn_time
	
	; point breakdown
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	LDR r4, =string_LEVEL_POINTS		; print out the score breakdown
	BL output_string
	LDR r4, =string_POINTS_BREAKDOWN
	MOV r1, #0							; offset counter
	
quit_game__brkdwn_score
	ADD r3, r10, r1						; breakdown offset = string offset + base breakdown offset 
	LDRB r0, [r4, r3]					; load byte from breakdown
	BL output_character					; print out the character
	ADD r1, r1, #1						; increment counter
	CMP r1, #5							; stop once we hit 5
	BLT quit_game__brkdwn_score
	
	; deaths breakdown
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	LDR r4, =string_LEVEL_DEATH			; print out the death count breakdown
	BL output_string
	LDR r4, =string_DEATH_BREAKDOWN
	MOV r1, #0							; offset counter
	
quit_game__brkdwn_deaths
	ADD r3, r10, r1						; breakdown offset = string offset + base breakdown offset 
	LDRB r0, [r4, r3]					; load byte from breakdown
	BL output_character					; print out the character
	ADD r1, r1, #1						; increment counter
	CMP r1, #5							; stop once we hit 5
	BLT quit_game__brkdwn_deaths
	
	; mothership breakdown
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	LDR r4, =string_MOTHER_LEVEL		; print out the mothership kill breakdown
	BL output_string
	LDR r4, =string_MOTHER_KILL_BREAKDOWN
	MOV r1, #0							; offset counter
	
quit_game__brkdwn_mthr_kill
	ADD r3, r10, r1						; breakdown offset = string offset + base breakdown offset 
	LDRB r0, [r4, r3]					; load byte from breakdown
	BL output_character					; print out the character
	ADD r1, r1, #1						; increment counter
	CMP r1, #5							; stop once we hit 5
	BLT quit_game__brkdwn_mthr_kill
	
	MOV r0, #0x2F						; '/'
	BL output_character
	
	LDR r4, =string_MOTHER_SPAWN_BREAKDOWN
	MOV r1, #0							; offset counter
	
quit_game__brkdwn_mthr_spawn
	ADD r3, r10, r1						; breakdown offset = string offset + base breakdown offset 
	LDRB r0, [r4, r3]					; load byte from breakdown
	BL output_character					; print out the character
	ADD r1, r1, #1						; increment counter
	CMP r1, #5							; stop once we hit 5
	BLT quit_game__brkdwn_mthr_spawn
		
	B quit_game__level
	
quit_game__continue
	; print out the current level stats
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	
	LDR r4, =string_LEVEL_GAMEOVER		; display level
	BL output_string
	LDR r4, =flag_MISC					; load byte 3 of MISC flag: level flag
	LDRB r0, [r4, #3]
	LDR r4, =string_NUMBER				; convert to string
	BL num_to_ascii
	BL output_string
	
	LDR r1, =flag_LEVEL_CLOCK			; convert the level clock into ASCII
	LDRB r0, [r1, #1]
	LDR r4, =string_TIME				; put the converted ASCII into string_TIME
	BL num_to_ascii						; convert time to ascii
	
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	LDR r4, = string_LEVEL_TIMER		; display level timer
	BL output_string
	LDR r4, = string_TIME
	BL output_string
	
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	LDR r4, =string_LEVEL_POINTS		; print out the level points
	BL output_string
	LDR r4, =string_SCORE
	BL output_string
	
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	LDR r4, =string_LEVEL_DEATH			; print out the death count
	BL output_string
	LDR r4, =flag_MISC					; load byte 6 of MISC flag: death count this level
	LDRB r0, [r4, #6]
	LDR r4, =string_NUMBER
	BL num_to_ascii						; convert to string
	BL output_string
	
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	LDR r4, =string_MOTHER_LEVEL		; print out the motherships spawned and killed this level
	BL output_string
	LDR r4, =flag_MISC					; load byte 5 of MISC flag: mothership kills this level
	LDRB r0, [r4, #5]
	LDR r4, =string_NUMBER
	BL num_to_ascii						; convert to string
	BL output_string
	
	MOV r0, #0x2F						; '/'
	BL output_character
	
	LDR r4, =flag_MISC					; load byte 4 of MISC flag: mothership spawns this level
	LDRB r0, [r4, #4]
	LDR r4, =string_NUMBER
	BL num_to_ascii						; convert to string
	BL output_string
	
	
	; print out total game stats
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	
	LDR r4, =string_TOTAL				; print out "Total" string
	BL output_string
	
	LDR r1, =flag_GAME_CLOCK			; convert the game clock into ASCII
	LDRB r0, [r1, #1]
	LDR r4, =string_TIME				; put the converted ASCII into string_TIME
	BL num_to_ascii						; convert time to ascii
	
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	LDR r4, = string_LEVEL_TIMER		; display game timer
	BL output_string
	LDR r4, = string_TIME
	BL output_string
	
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	LDR r4, =string_TOTAL_POINTS		; print out the total points
	BL output_string
	LDR r4, =string_SCORE_TOTAL
	BL output_string
	
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	LDR r4, =string_LEVEL_DEATH   	 	; print out the death count
	BL output_string
	LDR r4, =flag_LIVES					; get death count - 4 lives
	LDRB r0, [r4]
	CMP r0, #15							; 4 lives = 15
	BEQ quit_game__lives_four
	CMP r0, #7							; 3 lives = 7
	BEQ quit_game__lives_three
	CMP r0, #3							; 2 lives = 3
	BEQ quit_game__lives_two
	CMP r0, #1							; 1 life = 1
	BEQ quit_game__lives_one
	B quit_game__lives_zero				; must have 0 lives by this point
	
quit_game__lives_four
	MOV r0, #0
	B quit_game__continue_lives
	
quit_game__lives_three
	MOV r0, #1
	B quit_game__continue_lives
	
quit_game__lives_two
	MOV r0, #2
	B quit_game__continue_lives
	
quit_game__lives_one
	MOV r0, #3
	B quit_game__continue_lives

quit_game__lives_zero
	MOV r0, #4
	B quit_game__continue_lives
	
quit_game__continue_lives
	ADD r0, r0, #0x30					; convert to ASCII
	BL output_character					; print out the death count
	
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	LDR r4, =string_MOTHER_TOTAL			; print out the motherships spawned and killed this game
	BL output_string
	LDR r4, =flag_MISC					; load byte 8 of MISC flag: mothership kills this game
	LDRB r0, [r4, #8]
	LDR r4, =string_NUMBER
	BL num_to_ascii						; convert to string
	BL output_string
	
	MOV r0, #0x2F						; '/'
	BL output_character
	
	LDR r4, =flag_MISC					; load byte 7 of MISC flag: mothership spawns this game
	LDRB r0, [r4, #7]
	LDR r4, =string_NUMBER
	BL num_to_ascii						; convert to string
	BL output_string
	
	
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	LDR r4, =string_PLAY_AGAIN			; ask the user if they would like to play the game again
	BL output_string
	
quit_game__read
	BL read_character					; read the character from the user
	
	CMP r0, #0x71						; if the user hit 'q', quit
	BEQ quit_game__quit
	CMP r0, #0x51						; if the user hit 'Q', quit
	BEQ quit_game__quit

	CMP r0, #0x70						; if the user hit 'p', start playing
	BEQ quit_game__play
	CMP r0, #0x50						; if the user hit 'P', start playing
	BEQ quit_game__play
	
	B quit_game__read					; if the user has entered the wrong char keep reading
	
quit_game__quit
	LDR r4, =flag_GAMESTATUS			; set game status to 3 (quit)
	MOV r0, #3
	STRB r0, [r4]
	
	B quit_game__finally
	
quit_game__play
	LDR r4, =flag_GAMESTATUS			; set game status to 1 (playing)
	MOV r0, #1
	STRB r0, [r4]
	
quit_game__finally
	LDMFD SP!, {r0-r1, r4, lr}
	BX lr
	
	
	
	; flag_clear
	;  clears a flag (sets to 0)
	;  Input:
	;   r2: length of flag
	;  Output:
	;   r4: 
	;  Internal:
	;   r0:
	;   r1:
flag_clear
	STMFD SP!, {r0-r1, r4, lr}
	
	MOV r0, #0							; value to store
	
flag_clear__loop
	STRB r0, [r4], #1					; store 00 into the current byte and move to the next byte
	SUB r2, r2, #1
	CMP r2, #0
	BGT flag_clear__loop				; if the character is not NULL, keep clearing
	
	LDMFD SP!, {r0-r1, r4, lr}
	BX lr
	
	
	
	; string_clear
	;  clears a string (sets to spaces)
	;  Input:
	;   r4: 
	;  Output:
	;   r4: 
	;  Internal:
	;   r0:
	;   r1:
string_clear
	STMFD SP!, {r0, r1, lr}
	
	MOV r0, #0x20						; value to store ('0')
	
string_clear__loop
	STRB r0, [r4], #1					; store '0' into the current byte and move to the next byte
	LDRB r1, [r4]						; stop once we hit the NULL character
	CMP r1, #0
	BNE string_clear__loop				; if the character is not NULL, keep clearing
	
	LDMFD SP!, {r0, r1, lr}
	BX lr
	
	
	
	; lives_LED
	;  sets the LEDs to the current number of lives
	;  Input:
	;   r1:
	;	r4:
	;  Output:
	;   r0
	;  Internal:
	;   r0:
lives_LED
	STMFD SP!, {r0-r2, lr}
	
	LDR r1, =flag_LIVES				; send the lives flag to LED (turns on appropriate LEDs)
	LDRB r0, [r1]
	BL LED	
	
	LDMFD SP!, {r0-r2, lr}
	BX lr
	
	
	; shoot_RGB
	;  flashes the RGB when shooting
	;  Input:
	;   r1:
	;	r4:
	;  Output:
	;   r0
	;  Internal:
	;   r0:
shoot_RGB
	STMFD SP!, {r0-r2, r4, lr}
	
	ADD r1, r1, #1
	
	MOV r0, #0x72
	CMP r1, #8
	BLE shoot_RGB__turnon
	
	MOV r0, #0x67
	CMP r1, #16
	BLE shoot_RGB__turnon
	
	MOV r0, #0x72 
	CMP r1, #24
	BLE shoot_RGB__turnon
	
	MOV r0, #0x67
	MOV r1, #0

shoot_RGB__turnon
	STRB r1, [r4, #12]
	BL RGB_LED
	
	LDMFD SP!, {r0-r2, r4, lr}
	BX lr
	
	
	
	; status_RGB
	;  sets the RGB to the game status
	;  Input:
	;   r1: 
	;	r4: 
	;  Output:
	;   r0: 
	;  Internal:
	;   r0: 
status_RGB
	STMFD SP!, {r0-r2, r4, lr}
	
	LDR r1, =flag_GAMESTATUS			; load in game status
	LDRB r0, [r1]
	
	CMP r0, #0							; 0: menu
	BEQ status_RGB__menu
	CMP r0, #1							; 1: playing
	BEQ status_RGB__playing
	CMP r0, #2							; 2: paused
	BEQ status_RGB__paused
	CMP r0, #3							; 3: gameover
	BEQ status_RGB__gameover
	CMP r0, #4							; 4: next level
	BEQ status_RGB__nextlevel
	B status_RGB__finally				; invalid state -- ignore
	
status_RGB__menu
	MOV r0, #0x77						; 'w' - white
	BL RGB_LED
	B status_RGB__finally
	
status_RGB__playing
	MOV r0, #0x67						; 'g' - green
	BL RGB_LED
	B status_RGB__finally
	
status_RGB__paused
	MOV r0, #0x62						; 'b' - blue
	BL RGB_LED
	B status_RGB__finally
	
status_RGB__gameover
	MOV r0, #0x70						; 'p' - purple
	BL RGB_LED
	B status_RGB__finally
	
status_RGB__nextlevel
	MOV r0, #0x70						; 'p' - purple
	BL RGB_LED
	B status_RGB__finally
	
status_RGB__finally
	LDMFD SP!, {r0-r2, r4, lr}
	BX lr
	LTORG
	
	
	
	; play_STATES
	;  updates the state of the game on PuTTY
	;  Input:
	;   None
	;  Output:
	;   None
	;  Internal:
	;   r0: 
play_STATES
	STMFD SP!, {r0-r12, lr}
	
	LDR r4, =string_ANSI_STATES			; print out the states ANSI
	BL output_string
	
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	LDR r4, =string_LEVEL				; print out the level
	BL output_string
	LDR r4, =flag_MISC					; load byte 3 of MISC flag: level flag
	LDRB r0, [r4, #3]
	LDR r4, =string_NUMBER
	BL num_to_ascii						; convert to string
	BL output_string
	
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	LDR r4, =string_LIVES				; print out lives remaining
	BL output_string
	LDR r4, =flag_LIVES
	LDRB r0, [r4]
	CMP r0, #15							; 4 lives = 15
	BEQ play_STATES__lives_four
	CMP r0, #7							; 3 lives = 7
	BEQ play_STATES__lives_three
	CMP r0, #3							; 2 lives = 3
	BEQ play_STATES__lives_two
	B play_STATES__lives_one			; must have 1 life by this point
	
play_STATES__lives_four
	MOV r0, #0x34						; '4'
	BL output_character
	B play_STATES__continue
	
play_STATES__lives_three
	MOV r0, #0x33						; '3'
	BL output_character
	B play_STATES__continue
	
play_STATES__lives_two
	MOV r0, #0x32						; '2'
	BL output_character
	B play_STATES__continue
	
play_STATES__lives_one
	MOV r0, #0x31						; '1'
	BL output_character
	B play_STATES__continue

play_STATES__continue
	LDR r1, =flag_LEVEL_CLOCK			; convert the level clock into ASCII
	LDRB r0, [r1, #1]
	LDR r4, =string_TIME				; put the converted ASCII into string_TIME
	BL num_to_ascii						; convert time to ascii 
	
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	LDR r4, = string_LEVEL_CLOCK		; display level clock prompt
	BL output_string
	LDR r4, = string_TIME				; display level time
	BL output_string
	
	LDR r1, =flag_GAME_CLOCK				; convert the level clock into ASCII
	LDRB r0, [r1, #1]
	LDR r4, =string_TOTAL_TIME				; put the converted ASCII into string_TIME
	BL num_to_ascii						; convert time to ascii 
	
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	LDR r4, = string_GAME_CLOCK			; display TOTAL clock prompt 
	BL output_string
	LDR r4, = string_TOTAL_TIME			; display TOTAL time 
	BL output_string
	
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	LDR r4, =string_LEVEL_POINTS		; print out the level points
	BL output_string
	LDR r4, =string_SCORE	
	BL output_string
	LDR r4, =string_EMPTY
	BL output_string
	
	LDR r4, =string_NEWLINE
	BL output_string
	LDR r4, =string_ANSI_PUSHRIGHT
	BL output_string
	LDR r4, =string_TOTAL_POINTS		; print out the total points
	BL output_string
	LDR r4, =string_SCORE_TOTAL
	BL output_string
	LDR r4, =string_EMPTY
	BL output_string
	
	LDMFD SP!, {r0-r12, lr}
	BX lr
	
	
	
	; FIQ_EINT1
	;  Handles push button EINT1 interrupts
	;  Input:
	;   None
	;  Output:
	;   None
	;  Internal:
	;   r0: 
FIQ_EINT1
	STMFD SP!, {r0, r4, lr}
	
	LDR r4, =flag_GAMESTATUS			; load the current game status
	LDRB r0, [r4]
	AND r0, r0, #7						; isolate bits 2:0
	CMP r0, #1							; if game is currently being played, pause the game
	BEQ FIQ_EINT1_pause
	CMP r0, #2							; if game is currently paused, resume playing
	BEQ FIQ_EINT1_resume
	B FIQ_EINT1__finally				; invalid game state, so ignore to be safe
	
	;--Resume game--;
FIQ_EINT1_resume
	LDR r4, =string_ANSI_PAUSE			; move the cursor to the right location 
	BL output_string
	LDR r4, =string_CONTINUE			; clear the paused string
	BL output_string
	
	; when the game is being played the RGB should be green
	MOV r0, #0x67						; 'g'
	BL RGB_LED							; make RGB LED green
	
	LDR r4, =flag_GAMESTATUS			; set the game status to 1 (playing)
	MOV r0, #1
	STRB r0, [r4]
	
	B FIQ_EINT1__finally				; done handling push button
	;--/Resume game--;
	
	;--Pause game--;
FIQ_EINT1_pause
	LDR r4, =string_ANSI_PAUSE			; move the cursor to the right location 
	BL output_string
	LDR r4, =string_PAUSE				; display the paused string
	BL output_string
	
	; when the game is paused the RGB should be blue
	MOV r0, #0x62						; 'b'
	BL RGB_LED							; make RGB LED blue

	LDR r4, =flag_GAMESTATUS			; set the game status to 2 (paused)
	MOV r0, #2
	STRB r0, [r4]
	
	B FIQ_EINT1__finally				; done handling push button
	;--/Pause game--;
	
FIQ_EINT1__finally
	LDMFD SP!, {r0, r4, lr}
	BX lr
	
	
	
	; FIQ_UART0
	;  Handles keyboard UART0 interrupts
	;  Input:
	;   None
	;  Output:
	;   None
	;  Internal:
	;   r0: 
FIQ_UART0
	STMFD SP!, {r0-r12, lr}
	
	LDR r4, =flag_GAMESTATUS			; read in game status
	LDRB r0, [r4]
	AND r0, r0, #7						; isolate bits 2:0
	CMP r0, #0							; if game is in menu mode (0), skip immediately
	BEQ FIQ_UART0__finally
	
	BL read_character					; read in user input
	
	CMP r0, #0x71						; if user hit 'q', quit the game
	BEQ FIQ_UART0__quit
	CMP r0, #0x51						; if user hit 'Q', quit the game
	BEQ FIQ_UART0__quit
	
	LDR r4, =flag_GAMESTATUS			; read in game status
	LDRB r1, [r4]
	AND r1, r1, #7						; isolate bits 2:0
	CMP r1, #1							; if game is not in play mode (1), ignore the keyboard input
	BNE FIQ_UART0__finally
	
	LDR r4, =T0TC						; load in timer0
	LDR r1, [r4]
	AND r1, r1, #0xFF					; get the last 2 bytes
	LDR r4, =flag_RANDOM				; set the random flag to the lower 2 bytes of timer0
	STRB r1, [r4]
    
	; Add the input to the INPUT buffer
	LDR r1, =string_INPUT				; base address of INPUT buffer
	MOV r2, #-1							; position counter in INPUT buffer
	; starts at -1 because it is incremented at the start of the loop
	
FIQ_UART0__input_loop
	ADD r2, r2, #1						; increment position counter
	LDRB r3, [r1, r2]					; load current character
	CMP r3, #0							; if NULL character, we ran out of space so just drop the input
	BEQ FIQ_UART0__finally				; ignore the input
	CMP r3, #0x1F						; check if character is our special UNIT SEPARATOR 0x1F character
	BNE FIQ_UART0__input_loop			; if not, keep looking for a new one
	
	STRB r0, [r1, r2]					; store our new input to the string at first empty position
	
	B FIQ_UART0__finally				; don't run the quit code
	
FIQ_UART0__quit
	LDR r4, =flag_GAMESTATUS			; set game status to 3 (quit)
	MOV r0, #3
	STRB r0, [r4]
	
FIQ_UART0__finally
	LDMFD SP!, {r0-r12, lr}
	BX lr
	
	
	
	; FIQ_Timer0
	;  Handles timer 0 interrupts
	;  Input:
	;   None
	;  Output:
	;   None
	;  Internal:
	;   r0: 
FIQ_Timer0
	STMFD SP!, {r0-r12, lr}
	
	LDR r4, =flag_GAMESTATUS			; load in game status
	LDRB r0, [r4]
	AND r0, r0, #7						; isolate bits 2:0
	CMP r0, #2							; if game is paused (2), ignore timer 0
	BEQ FIQ_Timer0__finally
	
	LDR r4, =mothership 				; load address of C mothership
    LDR r0, =flag_SCORE					; first arg is flag_SCORE
	LDR r1, =flag_SCORE_TOTAL			; second arg is flag_SCORE_TOTAL
	LDR r2, =string_BULLETS_P			; third arg is string_BULLETS_P
	LDR r3, =string_BULLETS_E			; third arg is string_BULLETS_E
	MOV LR, PC
	BX r4								; call mothership
	
	LDR r4, =handle_inputs				; load address of C handle_inputs
	LDR r0, =string_INPUT				; first arg is input buffer
	LDR r1, =flag_INPUT					; second arg is input flags
	MOV LR, PC
	BX r4								; call handle_inputs
	
	LDR r4, =update_board				; load address of C update_board
	LDR r0, =string_BOARD_CUR			; first arg is current board string
	LDR r1, =string_BOARD_NEW			; second arg is new board string
	LDR r2, =flag_INPUT					; third arg is input flags
	MOV LR, PC
	BX r4								; call update_board
	
	BL update_display					; update the board to display the new changes
	
	BL lives_LED						; update the LEDs to the new lives amount
	
	LDR r4, =flag_MISC					; base address of flag_MISC
	LDRB r1, [r4, #12]					; load shooting bit into r0
	CMP r1, #0
	BLNE shoot_RGB						; branch to shoot_RGB
	
	LDR r4, =flag_MISC 					; load byte 13 of MISC flag: flush inputs
	LDRB r0, [r4, #13]
	CMP r0, #1							; if 1, flush inputs
	BNE FIQ_Timer0__flush_finished
	
	; clear out the INPUT buffer
	MOV r0, #0x1F						; special UNIT SEPERATOR 0x1F character
	LDR r1, =string_INPUT				; base address of INPUT buffer
	MOV r2, #0							; position counter in INPUT buffer
	
FIQ_Timer0__reset_input
	STRB r0, [r1, r2]					; store our reset character into the input buffer
	ADD r2, r2, #1						; increment position counter
	CMP r2, #10							; stop once we reach the end
	BLT FIQ_Timer0__reset_input			; TODO; test if this reaches the end properly
	
FIQ_Timer0__flush_finished
	; move the cursor out of the way
    LDR r4, =string_ANSI_PUSHAWAY		; ANSI code to move the cursor
    BL output_string
	
	; increment the timer counter
	LDR r4, =flag_MISC					; load in timer counter (byte 10 of MISC)
	LDRB r0, [r4, #10]
	ADD r0, r0, #1						; increment the counter
	CMP r0, #60							; if we reached 60, reset to 0
	BLT FIQ_Timer0__continue_inc		; if less than 60, continue
	MOV r0, #0

FIQ_Timer0__continue_inc
	STRB r0, [r4, #10]					; store the new MISC timer
	
	; update the score strings
	LDR r4, =flag_SCORE					; load LEVEL SCORE flag
	LDRSB r0, [r4]						; load upper score value
	LDRB r1, [r4, #1]					; load lower score value
	ADD r0, r1, r0, LSL #8 				; add both bytes together
	LDR r4, =string_SCORE 				; convert level score string to ASCII
	BL num_to_ascii
	
	LDR r4, =flag_SCORE_TOTAL			; load TOTAL SCORE strings
	LDRSB r0, [r4]						; load upper score value
	LDRB r1, [r4, #1]					; load lower score value
	ADD r0, r1, r0, LSL #8 				; add both bytes together
	LDR r4, =string_SCORE_TOTAL 		; convert total score string to ASCII
	BL num_to_ascii
	
	; update stats once every game update
	LDR r4, =flag_MISC					; load in timer counter (byte 10 of MISC)
	LDRB r0, [r4, #10]
	CMP r0, #30
	BLEQ play_STATES					; update states
	CMP r0, #59
	BLEQ play_STATES					; update states
	
FIQ_Timer0__finally
	LDMFD SP!, {r0-r12, lr}
	BX lr
	
	
	
	; FIQ_Timer1
	;  Handles timer 1 interrupts
	;  Input:
	;   None
	;  Output:
	;   None
	;  Internal:
	;   r0: 
FIQ_Timer1
	STMFD SP!, {r0-r12, lr}
	
	LDR r4, =flag_STROBING				; load in the strobing flag
	LDRB r6, [r4]
	AND r6, r6, #7						; isolate bits 2:0
	
	LDR r4, =string_SCORE				; base position of current score string
	LDRB r0, [r4, r6]					; load the character to display
	SUB r1, r6, #1						; move current digit into input (-1 offset)
	BL seven_segment 					; output that character
	ADD r6, r6, #1						; go to the next digit
	CMP r6, #5							; if we hit 4, wrap back around to 0
	BLT FIQ_Timer1__continue
	MOV r6, #1
	
FIQ_Timer1__continue
	LDR r0, =flag_STROBING				; update the strobing flag
	STRB r6, [r0]
	
	LDR r4, =flag_GAMESTATUS			; load in current game status
	LDR r0, [r4]
	AND r0, r0, #7						; isolate bits 2:0
	CMP r0, #1							; if game is paused (2), do not increase the overall game timer
	BNE FIQ_Timer1__finally
	
	LDR r4, = flag_MISC					; load byte 15 of the MISC flag (timer 1 counter)
	LDRB r6, [r4, #15]
	ADD r6, r6, #1						; increment the counter
	STRB r6, [r4, #15]
	CMP r6, #199						; if less than 199, we're finished
	BLT FIQ_Timer1__finally
	MOV r6, #0							; otherwise, wrap to 0 and run timer1 stuff
	STRB r6, [r4, #15]
	
	; increase the level game clock
	LDR r4, =flag_LEVEL_CLOCK			; load in the level clock
	LDRB r0, [r4]						; load upper level clock value
	LDRB r1, [r4, #1]					; load lower level clock value
	ADD r0, r1, r0, LSL #8 				; add both bytes together
	ADD r0, r0, #1						; increase level clock
	AND r1, r0, #0xFF00					; isolate upper byte
	AND r2, r0, #0xFF					; isolate lower byte
	MOV r1, r1, LSR #8					; LSR second byte by 8 places 
	STRB r1, [r4]						; store upper byte level clock value into flag_LEVEL_CLOCK
	STRB r2, [r4, #1]					; store lower byte level clock value into flag_LEVEL_CLOCK
	
	; increase the total game clock
    LDR r4, =flag_GAME_CLOCK			; load in the game clock
	LDRB r0, [r4]						; load upper game clock value
	LDRB r1, [r4, #1]					; load lower game clock value
	ADD r0, r1, r0, LSL #8 				; add both bytes together
	ADD r0, r0, #1						; increase game clock
	AND r1, r0, #0xFF00					; isolate upper byte
	AND r2, r0, #0xFF					; isolate lower byte
	MOV r1, r1, LSR #8					; LSR second byte by 8 places 
	STRB r1, [r4]						; store upper byte game clock value into flag_GAME_CLOCK
	STRB r2, [r4, #1]					; store lower byte game clock value into flag_GAME_CLOCK
	
	; check if total game clock reached 2 minutes
	LDR r1, =0x78						; load 2 minute time (0x78 = 120)
	CMP r0, r1							; compare game clock value to 2 minute value 
	BNE FIQ_Timer1__finally				; if the game clock has reached 2 mins stop the game
	
	LDR r4, =flag_GAMESTATUS			; set game status to 3 (quit)
	MOV r0, #3
	STRB r0, [r4]
	
FIQ_Timer1__finally
	LDMFD SP!, {r0-r12, lr}
	BX lr
	
	
	
	; FIQ_Handler
	;  Handles fast interrupts
	;  Input:
	;   None
	;  Output:
	;   None
	;  Internal:
	;   r0: 
FIQ_Handler
	STMFD SP!, {r0-r12, lr}

	;---Push button EINT1 handling---;
FIQ_Handler__EINT1						; check for EINT1 interrupt
	LDR r0, =EXTINT						; if bit 1 in EXTINT is 1, EINT1 interrupt pending
	LDR r1, [r0]						; load EXTINT
	TST r1, #2							; clear all but bit 1 (2 = b10) and update flags
	BEQ FIQ_Handler__UART0				; if bit 1 is 0, the result of TST is 0 so BEQ will branch
										; if bit 1 is 1, the result of TST is not 0 so BEQ will not branch

	BL FIQ_EINT1						; handle push button EINT1
	
	LDR r0, =EXTINT						; clear interrupt by clearing EXTINT bit 1
	LDR r1, [r0]						; load EXTINT
	ORR r1, r1, #2						; clear interrupt by writing 1 to pin 1
	STR r1, [r0]						; write data
	
	B FIQ_Handler__exit					; done handling push button
	;---/Push button EINT1 handling---;

	;---Keyboard UART0 handling---;
FIQ_Handler__UART0
	LDR r0, =U0IIR						; if bit 0 in U0IIR is 0, UART0 interrupt pending
	LDR r1, [r0]						; load U0IIR
	TST r1, #1							; clear all but bit 0 (1 = b1) and update flags
	BNE FIQ_Handler__Timer0				; if bit 0 is 0, the result of TST is 0 so BEQ will branch
										; if bit 0 is 1, the result of TST is not 0 so BEQ will not branch
	
	BL FIQ_UART0						; handle keyboard UART0
	
	B FIQ_Handler__exit					; done handling keyboard (no interrupt clearing required)
	;---/Keyboard UART0 handling---;

	;---Timer0 handling---;
FIQ_Handler__Timer0
	LDR r0, =T0IR						; if bit 1 in T0IR is 1, Timer0 interrupt pending
	LDR r1, [r0]						; load T0IR
	TST r1, #2							; clear all but bit 1 (2 = b10) and update flags
	BEQ FIQ_Handler__Timer1				; if bit 1 is 0, the result of TST is 0 so BEQ will branch
										; if bit 1 is 1, the result of TST is not 0 so BEQ will not branch
	
	BL FIQ_Timer0						; handle timer 0
	
	LDR r0, =T0IR						; clear the interrupt by writing to T0IR
	LDR r1, [r0]						; load T0IR
	ORR r1, r1, #2						; 2 = b10 -- turn ON bit 1
	STR r1, [r0]						; T0IR bit 1 = 1 (cleared)
	
	B FIQ_Handler__exit					; done handling timer 0
	;---/Timer0 handling---;
	
	;---Timer1 handling---;
FIQ_Handler__Timer1
	LDR r0, =T1IR						; if bit 1 in T1IR is 1, Timer1 interrupt pending
	LDR r1, [r0]						; load T1IR
	TST r1, #2							; clear all but bit 1 (2 = b10) and update flags
	BEQ FIQ_Handler__exit				; if bit 1 is 0, the result of TST is 0 so BEQ will branch
										; if bit 1 is 1, the result of TST is not 0 so BEQ will not branch

	BL FIQ_Timer1						; handle timer 1
	
	LDR r0, =T1IR						; clear the interrupt by writing to T1IR
	LDR r1, [r0]						; load T1IR
	ORR r1, r1, #2						; 2 = b10 -- turn ON bit 1
	STR r1, [r0]						; T1IR bit 1 = 1 (cleared)
	B FIQ_Handler__exit					; done handling timer 1
	;---/Timer1 handling---;
	

FIQ_Handler__exit
	LDMFD SP!, {r0-r12, lr}
	SUBS PC, lr, #4						; LR gets loaded with instruction AFTER interrupted,
										; so subtract 4 to go back and execute (otherwise skips)
										; SUBS copies SPSR back into CPSR for transparency

	END