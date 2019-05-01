.include "m2560def.inc"
	.def temp1 = r20
	.def temp2 = r21
	.equ F_CPU = 16000000
	.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
	.equ LCD_RS = 7
	.equ LCD_E = 6
	.equ LCD_RW = 5
	.equ LCD_BE = 4
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
Debounce_Timer:
	.byte 2

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

	rjmp main

OVF0address: ;timer0 overflow
	in temp1, SREG ;temp1 is temp 
	push temp1
	push YH
	push YL

	cli

	lds r24, TempCounter ;load tempcounter into r25:r24
	lds r25, TempCounter + 1
	adiw r25:r24, 1 ;increase tempcounter by 1
	cpi r24, low(7812/2) ;7812 * 2 
	ldi temp1, high(7812/2) ;compare tempcounter with 2 seconds
	cpc r25, temp1
		brne NotSecond 

novrflw:

	clear TempCounter
	lds r24, SecondCounter
	lds r25, SecondCounter + 1
	adiw r25:r24, 1
	sts SecondCounter, r24
	sts SecondCounter + 1, r25

	lds r24, QuarterRevolution
	lds r25, QuarterRevolution + 1

	

	;enter code to dispay rotations per second


	rcall display
	rjmp endOVF0
NotSecond:
	sts TempCounter, r24 ;store TempCounter back into data memory
	sts TempCounter + 1, r25

	rjmp endOVF0
endOVF0:

	pop YL
	pop YH
	pop temp1
	out SREG, temp1
	sei
	reti
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
	clr temp1
	clr temp2

Hundreds:

	cpi r24, low(100)
	ldi r17, high(100)
	cpc r25, r17
		brlo Tens
	subi r24, low(100)
	sbc r25, r17
	inc temp1
	rjmp Hundreds

Tens:
	cpi r24, low(10)
	ldi r17, high(10)
	cpc r25, r17
		brlo Converted
	subi r24, low(10)
	sbc r25, r17
	inc temp2
	rjmp Tens
Converted:
	subi temp1, -48
	subi temp2, -48
	subi r24, -48
	do_lcd_data1 temp1;value of current floor
	do_lcd_data1 temp2
	do_lcd_data1 r24

	do_lcd_command 0b11000000

	do_lcd_data 'R'
	do_lcd_data 'P'
	do_lcd_data 'S'

	inc r19

	clear QuarterRevolution

	do_lcd_data1 r19
	
	ret

main:
 jmp start

end:
	out PORTC, r18
	adiw Y, 2
	out SPH, YH
	out SPL, YL
	pop YH
	pop YL
	ret
start:

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

	ldi r19, 48

	rjmp loop

loop:
	jmp loop

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

	sbi PORTA, 1

	pop r25
	pop r24
	reti
EXT_INT1:
	push r24
	push r25
	lds r24, Debounce_Timer
	lds r25, Debounce_Timer + 1
	lds temp1, TempCounter
	lds temp2, TempCounter + 1

	sub temp1, r24 ;subtract tempcounter with debounce timer
	sbc temp2, r25

	cpi temp1, low(1000)
	ldi r22, high(1000)
	cpc temp2, r22
		brlo ignoreinput

	lds r24, QuarterRevolution
	lds r25, QuarterRevolution + 1
	adiw r25:r24, 1
;	inc r24
	sts QuarterRevolution, r24
	sts QuarterRevolution + 1, r25 

	cbi PORTA, 1

	pop r25
	pop r24
	reti
ignoreinput:
	sts Debounce_Timer, r24
	sts Debounce_Timer, r25
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