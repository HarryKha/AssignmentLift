.include "m2560def.inc"
	.def temp1 = r20
	.def temp2 = r21
	.equ F_CPU = 16000000
	.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
	.equ LCD_RS = 7
	.equ LCD_E = 6
	.equ LCD_RW = 5
	.equ LCD_BE = 4
	.def row = r16 ; current row number
	.def col = r17 ; current column number
	.def rmask = r18 ; mask for current row during scan
	.def cmask = r19 ; mask for current column during scan
	.equ PORTADIR = 0xF0 ; PD7-4: output, PD3-0, input
	.equ INITCOLMASK = 0xEF ; scan from the rightmost column,
	.equ INITROWMASK = 0x01 ; scan from the top row
	.equ ROWMASK = 0x0F ; for obtaining input from Port D
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
	clr temp1
	st Y+, temp1
	st Y, temp1
	pop YL
	pop YH
.endmacro

.dseg ; Set the starting address
	.org 0x200

TempCounter:
	.byte 2
SecondCounter:
	.byte 2
QuarterRevolution:
	.byte 2
FloorNumber:
	.byte 1
Direction:
	.byte 1
Emergency:
	.byte 1
LED_State:
	.byte 1
.cseg
.org 0x0000
	jmp RESET

.org INT0addr
	jmp EXT_INT0
.org INT1addr
	jmp EXT_INT1
.org INT2addr
	jmp EXT_INT2
.org OVF0addr
	jmp OVF0address

RESET:
	ldi temp1, high(RAMEND)
	out SPH, temp1
	ldi temp1, low(RAMEND)
	out SPL, temp1

	rjmp start

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
	cpi r24, low(7812/4) ;7812 * 2 
	ldi r20, high(7812/4) ;compare tempcounter with 2 seconds
	cpc r25, r20
	brne NotSecond 
	clear TempCounter

;============================================= CHECKING EMERGENCY MODE
;	insert code for '*' here
	lds r24, Emergency
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
	std Y+1, r24
	std Y+2, r25

	rcall updateFloor ;function to update the floor number and direction
	
	std Y+1, r24 ;store new floor number and direction in r24, r25
	std Y+2, r25
	ldd r24, Y+1
	ldd r25, Y+2
	sts FloorNumber, r24 ;pass r24 and r25 into floor number and direction in data memory
	sts Direction, r25
	rjmp endOVF0
NotSecond:
	sts TempCounter, r24
	sts TempCounter + 1, r25
	rjmp endOVF0
endOVF0:
	lds r24, FloorNumber
	lds r25, Direction
	std Y+1, r24
	std Y+2, r25

	rcall start1 ;function to load the floor number and direction onto the led bars

	pop YL
	pop YH
	pop r20
	out SREG, r20
	reti
updateFloor:
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
	cpi r17, 1 ;compare direction, 1 = going up, 0 = going down
		breq goingup
	rjmp goingdown
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
	rjmp leftshift
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
	;sts Button_pressed, temp1
	cpi temp1, '*'
		breq toggleEmergency
	jmp loop ; Restart main loop
toggleEmergency:
	lds r24, Emergency
	com r24
	sts Emergency, r24
	jmp loop

	rjmp loop

start:

	ldi temp1, PORTADIR ; PA7:4/PA3:0, out/in
	sts DDRL, temp1
	ser temp1 ; PORTC is output
	out DDRC, temp1
	out PORTC, temp1

	ldi r21, 2 ;SET STARTING FLOOR
	sts FloorNumber, r21
	ldi r22, 0 ;SET STARTING DIRECTION
	sts Direction, r22

	ser temp1
	out DDRF, temp1
	out DDRA, temp1
	clr temp1
	out PORTF, temp1
	out PORTA, temp1

	;ldi temp1, (2 << ISC10) ; set INT2 as fallingsts EICRA, temp1 ; edge triggered interrupt
	;sts EICRA, temp1

	in temp1, EIMSK ; enable INT2
	ori temp1, (1<<INT2)
	out EIMSK, temp1

;	ldi temp1, (2 << ISC01) ; set INT2 as fallingsts EICRA, temp1 ; edge triggered interrupt
;	sts EICRA, temp1

	in temp1, EIMSK ; enable INT2
	ori temp1, (1<<INT1)
	out EIMSK, temp1

	in temp1, EIMSK ; enable INT2
	ori temp1, (1<<INT0)
	out EIMSK, temp1

	ldi temp1, (2 << ISC00 | 2 << ISC01 | 2 << ISC11) ; set INT2 as fallingsts EICRA, temp1 ; edge triggered interrupt
	sts EICRA, temp1


	ldi temp1, 0b00000000 ;setting up the timer
	out TCCR0A, temp1
	ldi temp1, 0b00000010
	out TCCR0B, temp1 ;set Prescaling value to 8
	ldi temp1, 1<<TOIE0 ;128 microseconds
	sts TIMSK0, temp1 ;T/C0 interrupt enable
	sei ;enable the global interrupt

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

	clear TempCounter
	clear SecondCounter
	clear QuarterRevolution
	ldi temp1, 0
	sts Emergency, temp1
	sts LED_State, temp1

	ldi r19, 48

	rjmp loop


.macro lcd_set
	sbi PORTA, @0
.endmacro
.macro lcd_clr
	cbi PORTA, @0
.endmacro
lcd_command:
	out PORTF, r16
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
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
sleep_5ms:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ret
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

EXT_INT0:
	push r24
	push r25
	lds r24, QuarterRevolution
	lds r25, QuarterRevolution + 1
	adiw r25:r24, 1
;	inc r24
	sts QuarterRevolution, r24
	sts QuarterRevolution + 1, r25 

	ldi temp1, 1
	sts Emergency, temp1

	pop r25
	pop r24
	reti
EXT_INT1:
	push r24
	push r25
	lds r24, QuarterRevolution
	lds r25, QuarterRevolution + 1
	adiw r25:r24, 1
;	inc r24
	sts QuarterRevolution, r24
	sts QuarterRevolution + 1, r25 

	ldi temp1, 0
	sts Emergency, temp1

	pop r25
	pop r24
	reti
EXT_INT2:
	push r24
	push r25
	lds r24, QuarterRevolution
	lds r25, QuarterRevolution + 1
	adiw r25:r24, 1
;	inc r24
	sts QuarterRevolution, r24
	sts QuarterRevolution + 1, r25 
	pop r25
	pop r24
	reti