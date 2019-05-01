;
; lab00-3.asm
;
; Created: 21/03/2019 2:20:17 PM
; Author : harry
;

;*****************ASSUMPTIONS*********************
;


; Replace with your application code
.include "m2560def.inc"
	.def row = r16 ; current row number
	.def col = r17 ; current column number
	.def rmask = r18 ; mask for current row during scan
	.def cmask = r19 ; mask for current column during scan
	.def temp1 = r20
	.def temp2 = r21
	.equ PORTADIR = 0xF0 ; PD7-4: output, PD3-0, input
	.equ INITCOLMASK = 0xEF ; scan from the rightmost column,
	.equ INITROWMASK = 0x01 ; scan from the top row
	.equ ROWMASK = 0x0F ; for obtaining input from Port D

.macro insertprog
		lpm r16, @0
		st y+, r16
.endmacro
.macro do_lcd_command
	ldi r16, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro
.macro do_lcd_data
	ldi r16, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro
.macro do_lcd_data1
	mov r16, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro
.macro clear
	push YH
	push YL
	ldi YL, low(@0)
	ldi YH, high(@0)
	clr r20
	st Y+, r20
	st Y, r20
	pop YL
	pop YH
.endmacro

.dseg ; Set the starting address
	.org 0x200
vartab: 
	.byte 10
Flashing:
	.byte 1
FiveSecondCounter:
	.byte 1
TempCounter:
	.byte 2
SecondCounter:
	.byte 2
FloorNumber:
	.byte 1
Direction:
	.byte 1
NextFloor:
	.byte 1
Debounce:
	.byte 1
Emergency_Mode:
	.byte 1
Emergency_Floor:
	.byte 1
Emergency_Direction:
	.byte 1
Button_pressed:
	.byte 1
LED_State:
	.byte 1
Array_Size: ;size of array containing floors
	.byte 1

.cseg
.org 0x0000
	jmp RESET

.org INT0addr
	jmp EXT_INT0
.org INT1addr
	jmp EXT_INT1
.org OVF0addr
	jmp OVF0address

	number: .db 4,2,6,8,10,6,2,8,0,0
	insertflo: .db 0,0


RESET:
	ldi r20, high(RAMEND)
	out SPH, r20
	ldi r20, low(RAMEND)
	out SPL, r20

	rjmp main
Check_Emergency:
	push YL
	push YH
	in YL, SPL
	in YH, SPH
	sbiw Y, 2
	out SPL, YL
	out SPH, YH
	
	std Y+1, r24
	std Y+2, r25
	ldd r16, Y+1 ;Emergency mode
	ldd r17, Y+2 ;Next floor number

	cpi r16, 0 ;check if emergency mode has been activated
		brne Emergency_Activated
	ldi temp1, 0
	sts LED_State, temp1
	cbi PORTA, 1

Check_Emergency_End:
	mov r24, r16
	mov r25, r17
	adiw Y, 2
	out SPH, YH
	out SPL, YL
	pop YH
	pop YL
	ret

Emergency_Activated:
	;lds r17, Emergency_Floor
	ldi r17, 1
;=============================================
;	insert code for FLASHING LED here
	lds temp1, LED_State
	cpi temp1, 1
		breq ledon
	cbi PORTA, 1
	ldi temp1, 1
	sts LED_State, temp1
	rjmp Emergency_Activated_continue
ledon:
	sbi PORTA, 1
	ldi temp1, 0
	sts LED_State, temp1
	rjmp Emergency_Activated_continue
Emergency_Activated_continue:

;=============================================
	clr temp1
	sts Direction, temp1 ;change the direction to 0. (LIFT GOING DOWN)

		do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_5ms
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_1ms
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00001000 ; display off?
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001110 ; Cursor on, bar, no blink

	;out PORTC, temp1 ; hold value of temp1 also insert display here
	do_lcd_data 'E'
	do_lcd_data 'm'
	do_lcd_data 'e'
	do_lcd_data 'r'
	do_lcd_data 'g'
	do_lcd_data 'e'
	do_lcd_data 'n'
	do_lcd_data 'c'
	do_lcd_data 'y'

	do_lcd_command 0b11000000

	do_lcd_data 'C'
	do_lcd_data 'a'
	do_lcd_data 'l'
	do_lcd_data 'l'
	do_lcd_data ' '
	do_lcd_data '0'
	do_lcd_data '0'
	do_lcd_data '0'

	rjmp Check_Emergency_End

OVF0address: ;timer0 overflow
	in r20, SREG ;r20 is temp 
	push r20
	push YH
	push YL

	lds r24, TempCounter ;load tempcounter into r25:r24
	lds r25, TempCounter + 1
	adiw r25:r24, 1 ;increase tempcounter by 1
	cpi r24, low(7812/2) ;7812 * 2 
	ldi r20, high(7812/2) ;compare tempcounter with 2 seconds
	cpc r25, r20
		brne NotSecond 

	clear TempCounter

;=============================================
;	insert code for '*' here
	lds r24, Emergency_Mode
	mov r25, r21
	std Y+1, r24 ;Emergency mode. 1 = yes, 0 = no
	std Y+2, r25 ;Next floor number

	rcall Check_Emergency

	std Y+1, r24 ;store emergency state and Next floor in r24, r25
	std Y+2, r25
	ldd r24, Y+1
	ldd r25, Y+2

	mov r21, r25
;=============================================

	lds r24, FloorNumber ;loading Floor number and direction into the stack 
	lds r25, Direction
	cpi r24, 0
		breq TurnOn

	cp r24, r21 ;compare current floor with floor in the request
		breq FiveSecondPausee

	ldi temp1, 0x00
	sts OCR3BL, temp1

	lds r24, SecondCounter
	lds r25, SecondCounter + 1
	adiw r25:r24, 1
	cpi r24, low(2)
	ldi r20, high(2)
	cpc r25, r20
		brne NotSecond2
	clear SecondCounter
	lds r24, FloorNumber ;loading Floor number and direction into the stack 
	lds r25, Direction
	std Y+1, r24
	std Y+2, r25
	rjmp updatingFloor
NotSecond:
	rjmp NotSecond1
FiveSecondPausee:
	rjmp FiveSecondPause


updatingFloor:
	rcall updateFloor ;function to update the floor number and direction
	
	std Y+1, r24 ;store new floor number and direction in r24, r25
	std Y+2, r25
	ldd r24, Y+1
	ldd r25, Y+2
	sts FloorNumber, r24 ;pass r24 and r25 into floor number and direction in data memory
	sts Direction, r25

	lds r24, Emergency_Mode
	cpi r24, 0
		brne endOVF0

	rcall display

	rjmp endOVF0
NotSecond1:
	sts TempCounter, r24 ;store TempCounter back into data memory
	sts TempCounter + 1, r25

	lds r24, Emergency_Mode
	cpi r24, 0
		brne Flash_LED

	rjmp endOVF0
TurnOn:
	jmp TurnOn1
Flash_LED:
	lds r24, LED_State
	com r24
	sts LED_State, r24
	;out DDR(???), r24
	rjmp endOVF0
NotSecond2:
	sts SecondCounter, r24
	sts SecondCounter + 1, r25
	rjmp endOVF0
FiveSecondPause:
	lds r24, FiveSecondCounter ;Delay for 4 seconds

	cpi r24, 0
		breq OpenDoor

	cpi r24, 1
		breq wait

	cpi r24, 4
		breq CloseDoors
	cpi r24, 5
		breq FiveSecondEnd
	rjmp FiveSecondPauseContinue
OpenDoor:
	ldi temp1, 0x6A
	sts OCR3BL, temp1
	rjmp FiveSecondPauseContinue
wait:
	clr temp1
	sts OCR3BL, temp1
	rjmp FiveSecondPauseContinue
CloseDoors:	
	ldi temp1, 0x2A
	sts OCR3BL, temp1
	rjmp FiveSecondPauseContinue
FiveSecondPauseContinue:
	inc r24
	sts FiveSecondCounter, r24
	lds r24, FloorNumber ;turning off LEDs
	sts Flashing, r24 ;Flashing is a temporary value that holds the floor number
	clr r24
	sts FloorNumber, r24
	rjmp endOVF0
endOVF0:
	lds r24, FloorNumber ;end of interrupt
	lds r25, Direction
	std Y+1, r24
	std Y+2, r25

	rcall start1 ;function to load the floor number and direction onto the led bars

	pop YL
	pop YH
	pop r20
	out SREG, r20
	reti

TurnOn1:
	lds r24, Flashing
	sts FloorNumber, r24
	rjmp endOVF0	
FiveSecondEnd:

	ldi xl, low(vartab)
	ldi xh, high(vartab)
	movup: ;deleting first number in array
	ld r17, x+
	ld r18, x
	cpi r17, 0
	breq finmovup ;r17 = r18 because no repeating element therefore
	;r17 and r18 must contain 0 (buffer 0)
	st -x, r18 ;overwrite previous number
	ld r17, x+
	jmp movup
	finmovup:
	lds r21, Array_Size ;decrement array size
	dec r21
	sts Array_Size, r21
	ldi xl, low(vartab)
	ldi xh, high(vartab)
	ld r21, x ;load next floor
	sts NextFloor, r21
	clear FiveSecondCounter
	rjmp endOVF0
display:
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_5ms
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_1ms
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00001000 ; display off?
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001110 ; Cursor on, bar, no blink

	;out PORTC, temp1 ; hold value of temp1 also insert display here
	do_lcd_data 'C'
	do_lcd_data 'u'
	do_lcd_data 'r'
	do_lcd_data 'r'
	do_lcd_data 'e'
	do_lcd_data 'n'
	do_lcd_data 't'
	do_lcd_data ' '
	do_lcd_data 'f'
	do_lcd_data 'l'
	do_lcd_data 'o'
	do_lcd_data 'o'
	do_lcd_data 'r'
	do_lcd_data ' '
	lds temp1, FloorNumber
	subi temp1, -48
	cpi temp1, 58
		breq display101
	do_lcd_data1 temp1;value of current floor

	do_lcd_command 0b11000000

	do_lcd_data 'N'
	do_lcd_data 'e'
	do_lcd_data 'x'
	do_lcd_data 't'
	do_lcd_data ' '
	do_lcd_data 's'
	do_lcd_data 't'
	do_lcd_data 'o'
	do_lcd_data 'p'
	do_lcd_data ' '
	lds temp1, NextFloor
	subi temp1, -48
	cpi temp1, 58
		breq display10
	do_lcd_data1 temp1 ;value of next stop
	ret
display101:

	do_lcd_data '1'
	do_lcd_data '0'

	do_lcd_command 0b11000000

	do_lcd_data 'N'
	do_lcd_data 'e'
	do_lcd_data 'x'
	do_lcd_data 't'
	do_lcd_data ' '
	do_lcd_data 's'
	do_lcd_data 't'
	do_lcd_data 'o'
	do_lcd_data 'p'
	do_lcd_data ' '
	lds temp1, NextFloor
	subi temp1, -48
	cpi temp1, 58
		breq display10
	do_lcd_data1 temp1 ;value of next stop
	ret

display10:
	do_lcd_data '1'
	do_lcd_data '0'
	ret

updateFloor: ;updates the floor number and direction
	push YL
	push YH
	lds r16, Emergency_Mode
	cpi r16, 1
	brne Not_emergency
	ldi r17, 1 ;next floor in emergency is 1
	rjmp requestexist
Not_emergency:
	lds r17, vartab
	cpi r17, 0 ;empty request floor therefore do not move
	brne requestexist
	in YL, SPL
	in YH, SPH
	sbiw Y, 2
	out SPL, YL
	out SPH, YH
	std Y+1, r24
	std Y+2, r25
	ldd r16, Y+1 ;Floor number
	ldd r17, Y+2 ;Direction
	rjmp updateFloor_end
requestexist:

	in YL, SPL
	in YH, SPH
	sbiw Y, 2
	out SPL, YL
	out SPH, YH

	std Y+1, r24
	std Y+2, r25
	ldd r16, Y+1 ;Floor number
	cp r17, r16 ; compare next floor to the current floor
	brlo goingdown ;next floor lower than current floor
	rjmp goingup

goingup:
	cpi r16, 10 ;has it reached floor 10 yet
		breq goingdown
	ldi r17, 1 ;set the direction to going up
	inc r16
	rjmp updateFloor_end
goingdown:
	cpi r16, 1 ;has it reached floor 1 yet
		breq goingup
	clr r17
	dec r16
	rjmp updateFloor_end
updateFloor_end:
	mov r24, r16
	mov r25, r17
	adiw Y, 2
	out SPH, YH
	out SPL, YL
	pop YH
	pop YL
	ret
main:
	;set up parameters
	clr r17 ;arraysize
	ldi zl, low(number<<1)
	ldi zh, high(number<<1)
	;ldi yl, low(RAMEND-4) ;4bytes to store local variables
	;ldi yh, high(RAMEND-4) ;assume variable is 1 byte
	;out SPH, yh ;adjust stack pointer to poin to new stack top
	;out SPL, yl

	ldi r19, 8
	ldi r18, 0 ;0 is down, 1 is up
	;insert array into data memory
	proginsert:
	lpm r16, z+ ; gets floor to be in array
	cpi r16, 0 ;compares the insert number to 0 and if zero, end of array
	breq begin

	;prepare parameters for function call
	mov r21, r16 ; r21 holds the insert number parameter
	mov r22, r17 ; r22 holds arraysize parameter
	mov r23, r19 ; r23 holds current floor parameter
	mov r24, r18 ; r24 holds lift direction parameter

	rcall insert_request ; call subroutine
	mov r17, r21 ;move returned number back to arraysize
	
	jmp proginsert
	;*******************************************************************
	begin:

	ldi zl,low(insertflo<<1) ;move z pointer to the inserted floors
	ldi zh,high(insertflo<<1)
	repeat: ;keeps repeating until it hits zero
	;*******************************************************************
	lpm r16, z+ ; floor to be inserted
	cpi r16, 0
		breq start2
	;prepare parameters for function call
	mov r21, r16 ; r21 holds the insert number parameter
	mov r22, r17 ; r22 holds arraysize parameter
	mov r23, r19 ; r23 holds current floor parameter
	mov r24, r18 ; r24 holds lift direction parameter

	rcall insert_request ; call subroutine
	mov r17, r21 ;move returned number back to r17
	sts Array_Size, r21
	jmp repeat
	;*******************************************************************
	
	rjmp start2  ;end of main function

insert_request:
	;prologue
	push yl ;save y in stack
	push yh
	push zl
	push zh
	push r15
	push r16 ;save registers used in function
	push r17
	push r18
	push r19
	push r20
	
	in yl, SPL ;initialize the stack frame pointer value
	in yh, SPH
	sbiw y, 8	;reserve space for local variables and parameters
	out SPH, yh ;update stack pointer to top
	out SPL, yl
	;pass parameters
	std y+1, r21 ;pass insert number to stack
	std y+2, r22 ;pass array size to stack
	std y+3, r23 ;pass current flor to stack
	std y+4, r24 ;pass lift movement to stack
	
	;function body
	ldd r20, y+2 ;load arraysize
	ldd r19, y+1 ;load inserted number
	ldd r16, y+3 ;load current floor
	ldd r18, y+4 ;load lift movement
	ldi zl, low(vartab)
	ldi zh, high(vartab)
	cpi r20, 0 ;checks if array is empty
	breq firstno
	;insert number into data mem in order
	clr r15 ;used for array counter
	

	cp r16, r19 ;compare current floor to insert floor
	breq exist ;inserted floor is the current floor
	brlo greater ;inserted floor is greater than current floor
	jmp lower ;inserted floor is lower than current floor

	lower:
	cpi r18, 0 ;check lift movement
	breq dwn
	ldi r16, 255
start2:
	rjmp start

	dwn:
	ld r17, z+ ;load current array element
	cp r19, r17 ;compare the insert number to current array element
	breq exist ;number exists in array, therefore do no insert
	brsh smaller ;array element is smaller than insert number
	cp r17, r16 ;compare current floor to array element (if moving up r16 = 255)
	brsh smaller ;reached increasing part of array (ie.r17<r16)
	cp r15, r20 ;compare current array count to array size
	breq endarray ;if equal, at end of array
	inc r15 ;increment array counter
	jmp dwn ;array element smaller than insert number

	greater:
	cpi r18, 1 ;check lift movement
	breq up
	ldi r16, 0
	up:
	ld r17, z+ ;load current array element
	cp r19, r17 ;compare the insert number to current array element
	breq exist ;number exists in array, therefore do no insert
	brlo smaller ;array element is larger than insert number
	cp r17, r16 ;compare current floor to array element (if moving down r16 = 0)
	brlo smaller ;reached decreasing part of array (ie.r17<r16)
	cp r15, r20 ;compare current array count to array size
	breq endarray ;if equal, at end of array
	inc r15 ;increment array counter
	jmp up ;array element smaller than insert number
	
	smaller:
	st -z, r19 ;store array element
	ld r15, z+ ;increment z
	
	movedwn: ;move each element down the array
	ld r18, z
	cp r17, r18
	breq fin ;r17 = r18 because no repeating element therefore
	st z+, r17 ;r17 and r18 must contain 0 (buffer 0)
	ld r17, z
	cp r17, r18
	st z+, r18
	breq endmov
	jmp movedwn
	
	endmov:
	st z+, r17
	jmp fin
	
	endarray:
	st -z, r19
	
	fin:
	inc r20
	jmp exist
	
	firstno:
	cp r19, r16
	breq exist
	st z, r19
	inc r20
	
	exist:
	mov r21, r20 ;move arraysize to r21
	adiw y, 8 ;de allocate the reserved space
	out SPH, yh
	out SPL, yl
	pop r20
	pop r19 ;restore registers
	pop r18
	pop r17
	pop r16
	pop r15
	pop zh
	pop zl
	pop yh
	pop yl
	ret

start:


	ldi temp1, 0b00010000
	;ser temp1
	out DDRE, temp1

;	sts PWM, temp ; Bit 4 will function as OC3A.
	;clr temp
	;out PORTA, temp
	ldi temp1, 0x00 ; the value controls the PWM duty cycle
	sts OCR3BL, temp1
	clr temp1
	sts OCR3BH, temp1	
	; Set the Timer5 to Phase Correct PWM mode.
	ldi temp1, (1 << CS30)
	sts TCCR3B, temp1
	ldi temp1, ((1<< WGM30)|(1<<COM3B1))
	sts TCCR3A, temp1

	ldi temp1, PORTADIR ; PA7:4/PA3:0, out/in
	sts DDRL, temp1
	ser temp1 ; PORTC is output
	out DDRC, temp1
	out PORTC, temp1

	ser r16
	out DDRF, r16
	out DDRA, r16
	clr r16
	out PORTF, r16
	out PORTA, r16

	ser r20
	out DDRC, r20 ;set Port C for output

	ldi r20, (2 << ISC00 | 2 << ISC01) ; set INT0 as fallingsts EICRA, r20 ; edge triggered interrupt
	sts EICRA, r20

	in r20, EIMSK ; enable INT0
	ori r20, (1<<INT0)
	out EIMSK, r20

	in r20, EIMSK
	ori r20, (1<<INT1) ;enable INT1
	out EIMSK, r20

	clear Flashing
	clear FiveSecondCounter
	clear TempCounter
	clear SecondCounter
	clear FloorNumber
	clear NextFloor
	clear Direction
	clear Debounce
	clear Emergency_Mode
	clear Emergency_Floor
	clear Emergency_Direction
	clear Button_pressed
	clear LED_State

	ldi temp1, 1
	sts Emergency_Floor, temp1

	ldi temp1, 0
	sts Emergency_Mode, temp1

	ldi temp1, 1
	sts LED_State, temp1

	clr r23
	ldi r20, 0b00000000 ;setting up the timer
	out TCCR0A, r20
	ldi r20, 0b00000010
	out TCCR0B, r20 ;set Prescaling value to 8
	ldi r20, 1<<TOIE0 ;128 microseconds
	sts TIMSK0, r20 ;T/C0 interrupt enable
	sei ;enable the global interrupt
	 ;SET STARTING FLOOR
	sts FloorNumber, r19
	sts Direction, r18
	ldi XH, high(vartab)
	ldi XL, low(vartab)
	ld r21, X+
	sts NextFloor, r21

	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_5ms
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_1ms
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00001000 ; display off?
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001110 ; Cursor on, bar, no blink

	rjmp loop

start1:
	push YL
	push YH
	in YL, SPL
	in YH, SPH
	sbiw Y, 2
	out SPL, YL
	out SPH, YH

	std Y+1, r24
	std Y+2, r25
	ldd r16, Y+1 ;Floor number
	ldd r17, Y+2 ;Direction

	ldi r18, 1
	ldi r19, 1

	push r16
	clr r16
	out DDRG, r16
	pop r16

	cpi r16, 9
		breq floor9
		brge floor10
	cpi r16, 0
		breq turnOff
	rjmp leftshift
turnOff:
	mov r18, r16
	rjmp end
floor10:
	push r18
	ser r18
	out DDRG, r18
	ldi r18, 3
	out PORTG, r18
	pop r18
	rjmp leftshift
floor9:
	push r18
	ser r18
	out DDRG, r18
	ldi r18, 1
	out PORTG, r18
	pop r18
	rjmp leftshift
leftshift:
	cp r19, r16
		breq end
	lsl r18
	subi r18, -1
	inc r19
	rjmp leftshift
end:
	out PORTC, r18
	adiw Y, 2
	out SPH, YH
	out SPL, YL
	pop YH
	pop YL
	ret
loop:
	ldi cmask, INITCOLMASK ; initial column mask
	clr col ; initial column
colloop:
	cpi col, 4
	breq loop ; If all keys are scanned, repeat.
	sts PORTL, cmask ; Otherwise, scan a column.
	ldi temp1, 0xFF ; Slow down the scan operation.
delay: 
	dec temp1
	brne delay
	lds temp1, PINL ; Read PORTA
	andi temp1, ROWMASK ; Get the keypad output value
	cpi temp1, 0xF ; Check if any row is low
	breq nextcol
	; If yes, find which row is low
	ldi rmask, INITROWMASK ; Initialize for row check
	clr row ; 
rowloop:
	cpi row, 4
	breq nextcol ; the row scan is over.
	mov temp2, temp1
	and temp2, rmask ; check un-masked bit
	breq convert ; if bit is clear, the key is pressed
	inc row ; else move to the next row
	lsl rmask
	jmp rowloop
nextcol: ; if row scan is over
	lsl cmask
	inc cmask
	inc col ; increase column value
	jmp colloop ; go to the next column
convert:
	cpi col, 3 ; If the pressed key is in col.3
	breq letters ; we have a letter
	; If the key is not in col.3 and
	cpi row, 3 ; If the key is in row3,
	breq symbols ; we have a symbol or 0
	mov temp1, row ; Otherwise we have a number in 1-9
	lsl temp1
	add temp1, row
	add temp1, col ; temp1 = row*3 + col
	subi temp1, -1 ; Add the value of character ?E?E
	;********************************************** add pressed number into array
	push r17
	push r18
	push r19
	push r21
	push r22
	push r23
	push r24
	lds r17, Array_Size
	lds r19, NextFloor ;loading Floor number and direction into the stack 
	lds r18, Direction
	;prepare parameters for function call
	mov r21, temp1 ; r21 holds the insert number parameter
	mov r22, r17 ; r22 holds arraysize parameter
	mov r23, r19 ; r23 holds current floor parameter
	mov r24, r18 ; r24 holds lift direction parameter

	rcall insert_request ; call subroutine
	sts Array_Size, r21 ;move returned number back to arraysize
	pop r24
	pop r23
	pop r22
	pop r21
	pop r19
	pop r18
	pop r17
	jmp convert_end
letters:
	ldi temp1, 'A'
	add temp1, row ; Get the ASCII value for the key
	jmp convert_end
symbols:
	cpi col, 0 ; Check if we have a star
	breq star
	cpi col, 1 ; or if we have zero
	breq zero
	ldi temp1, '#' ; if not we have hash
	jmp convert_end
star:
	ldi temp1, '*' ; Set to star
	jmp convert_end
zero:
	ldi temp1, 0 ; Set to zero
convert_end:
	sts Button_pressed, temp1
	cpi temp1, '*'
		breq toggleEmergency
	jmp loop ; Restart main loop
toggleEmergency:
	lds r24, Emergency_Mode
	com r24
	sts Emergency_Mode, r24
	jmp loop
halt:
	rjmp halt

.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

.macro lcd_set
	sbi PORTA, @0
.endmacro
.macro lcd_clr
	cbi PORTA, @0
.endmacro

;
; Send a command to the LCD (r16)
;

lcd_command:
	out PORTF, r16
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	ret

lcd_data:
	out PORTF, r16
	lcd_set LCD_RS
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	lcd_clr LCD_RS
	ret

lcd_wait:
	push r16
	clr r16
	out DDRF, r16
	out PORTF, r16
	lcd_set LCD_RW
lcd_wait_loop:
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	in r16, PINF
	lcd_clr LCD_E
	sbrc r16, 7
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser r16
	out DDRF, r16
	pop r16
	ret

.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead

sleep_1ms:
	push r24
	push r25
	ldi r25, high(DELAY_1MS)
	ldi r24, low(DELAY_1MS)
delayloop_1ms:
	sbiw r25:r24, 1
	brne delayloop_1ms
	pop r25
	pop r24
	ret

sleep_5ms:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ret
EXT_INT0:
	push r20 ; save register
	in r20, SREG ; save SREG
	lds r24, FloorNumber
	lds r25, Debounce
	inc r25
	cpi r25, 1
		brlo doNothing
	clr r25
	sts Debounce, r25
	cpi r24, 0
		breq CloseDoor
	cp r24, r21 ;r21 is floor numbers in the array
		breq CloseDoor
	out SREG, r20
	pop r20 ; restore register
	reti
EXT_INT1:
	push r20 ; save register
	push r21
	in r20, SREG ; save SREG
	lds r24, FloorNumber
	clr r25 ;set up delay, 255 cycles can make it longer by using 2 bits
DEBOUNCE_BUTTON:
	inc r25
	cpi r25, 255
	brlo DEBOUNCE_BUTTON
	in r25, PINB ;get pin state
	cpi r25, 4 ;if pin is pressed down (ie 1 then rising edge)
	breq PRESS_DOWN
	cpi r24, 0
		breq HoldDoor
	cp r24, r21 ;r21 is floor numbers in the array
		breq HoldDoor
PRESS_DOWN:
	out SREG, r20
	pop r21
	pop r20 ; restore register
	reti
doNothing:
	out SREG, r20
	pop r21
	pop r20 ; restore register
	reti
CloseDoor:
	ldi r24, 5
	sts FiveSecondCounter, r24
	out SREG, r20
	pop r21
	pop r20 ; restore register
	reti
HoldDoor:
	lds r24, FiveSecondCounter
	subi r24, 3
	sts FiveSecondCounter, r24
	out SREG, r20
	pop r21
	pop r20
	reti