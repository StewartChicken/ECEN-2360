/*
 * ECEN 2360 Project 2A: Stop Watch
 * Evan Poon
*/

.section .reset, "ax" 		#0x00000000
.global _start

# Uart memory addresses
.equ UART_DATA, 	0x1000
.equ UART_CTRL, 	0x1004

# Segment display memory addresses
.equ SEG_DISPLAY_LO, 	0x20
.equ SEG_DISPLAY_HI, 	0x30

# Button memory addresses
.equ BUTTON_DATA, 	0x50
.equ BUTTON_MASK, 	0x58
.equ BUTTON_CAPTURE, 	0x5C

# Interval timer memory addresses
.equ INTV_STATUS, 0x2000
.equ INTV_CTRL, 0x2004
.equ INTV_START_LO, 0x2008
.equ INTV_START_HI, 0x200C

_start:
	movia 	sp, 0x01000000 # 16MB stack
	movia 	gp, 0xff200000 # MMIO base address
	br 		main
	
##############################################
# Interrupt Handler Router 
##############################################
.section .exceptions, "ax" # 0x00000020
	# Check for pending interrupt
	rdctl 	et, ipending
	bne 	et, r0, IRQ_Handler
	
	# Exit if exception is not an interrupt
	eret


.text
##############################################
# Begin interrupt handeling code
##############################################
	
IRQ_Handler:
	# Prologue
	subi 	sp, sp, 16
	stw 	ra, 12(sp)
	stw 	r5, 8(sp)
	stw 	r4, 4(sp)
	stw 	r2, 0(sp)

	subi 	ea, ea, 4 # Preserve exception return address
	
	
	
	
	
	# Exit Interrupt Handeler
	br 		Interrupt_Done
	
Timer_IRQ_Handler:
	ldw et, Time(r0)
	addi et, et, 1
	stw et, Time(r0)
	rdctl et, ipending
	xori et, et, 0b1
	wrctl ipending, et
	
	br Interrupt_Done
	
Interrupt_Done:
	# Epilogue
	ldw 	ra, 12(sp)
	ldw 	r5, 8(sp)
	ldw 	r4, 4(sp)
	ldw 	r2, 0(sp)
	addi 	sp, sp, 16
	
	eret

main:
	
	rdctl r16, ienable
	ori r16, r16, 0b1
	#wrctl ienable, r16
	
	# Enable INTERVAL TIMER interrupts
	movi r16, 0b11 # ITO and CONT mask in timer control register - auto reload and interrupts enabled
	stwio r16, INTV_CTRL(gp) # Enable timer interrupt
	
	# Enable status.PIE
	rdctl 	r16, status
	ori 	r16, r16, 0b1
	wrctl 	status, r16
	
	movia r16, 0b1110000100000000
	stwio r16, INTV_START_LO(gp)
	movia r16, 0b10111110101
	stwio r16, INTV_START_HI(gp)
	
	# Start interval timer
	movi r16, 0b111
	stwio r16, INTV_CTRL(gp)
	main_loop:
		
		# Load current time elapsed 
		mov r4, r0
		ldw r4, Time(r0)
		call displayTime
		
		br main_loop
		
	
##############################################
# -- display time on the stop watch --
# -- convert from total centiseconds ellapsed (n) to minutes, seconds, centiseconds --
# void displayTime(int n) 
displayTime:
	# r4 contains number of centiseconds that have elapsed
	
	# Prologue
	subi 	sp, sp, 8
	stw 	ra, 4(sp)
	stw 	r4, 0(sp) # Store total centiseconds
	
	# Display minutes elapsed
	movia 	r5, 6000 # Divisor to obtain total number of minutes elapsed
	div 	r4, r4, r5
	call 	showNumHi
	
	ldw 	r4, 0(sp) # Restore total centiseconds
	movia 	r5, 6000  # Restore divisor value
	mov 	r3, r0	  # Reset r3 for use below
	
	# Get seconds and centiseconds that have elapsed using modulus implementation
  	div 	r3, r4, r5  # r3 = r4 / 6000
	mul 	r3, r3, r5	# r3 = r3 * 6000
	sub 	r4, r4, r3   # r4 = r4 % 6000
	
	call 	showNumLo
	
	ldw 	ra, 4(sp)
	addi 	sp, sp, 8
	
	ret
	
##############################################
# -- display n on 7 segment display --
# -- Only affects segments 5-6 - minutes --
# void showNumHi(int n) 
showNumHi:
	# Prologue
	subi 	sp, sp, 4
	stw 	ra, 0(sp)

	# Take r4 as argument - return bit representation in r2
	call 	num2bits
	ori 	r2, r2, 0x80 # Display decimal point after minutes
	
	# Display r4 value on 7 segment
	stwio 	r2, SEG_DISPLAY_HI(gp) 
	
	# Epilogue
	ldw 	ra, 0(sp)
	addi 	sp, sp, 4
	ret

##############################################
# -- display n on 7 segment display --
# -- Only affects segments 1-4 - seconds and centiseconds --
# void showNumLo(int n) 
showNumLo:
	# Prologue
	subi 	sp, sp, 4
	stw 	ra, 0(sp)

	# Take r4 as argument - return bit representation in r2
	call 	num2bits 
	orhi 	r2, r2, 0x80 # Display decimal point after seconds
	
	# Display r4 value on 7 segment
	stwio 	r2, SEG_DISPLAY_LO(gp) 
	
	# Epilogue
	ldw 	ra, 0(sp)
	addi 	sp, sp, 4
	ret

##############################################
# -- convert from integer value n to binary --
# -- sequence ofbits which can be displayed --
#
# int num2bits(int n)
num2bits:
	# Preload necessary values
	movi 	r2, 0
	movi 	r10, 10
	movi 	r7, 4 # Iterator
	
  # Loop until r7 = 0
  n2b_loop:
  	# Implement Modulus
	div 	r3, r4, r10
	mul 	r5, r3, r10
	sub		r5, r4, r5		# r5 = r4 % r5
	
	# Convert r4 integer value into binary 
	# representation for segment display
	ldbu 	r6, Bits7Seg(r5)
	or 		r2, r2, r6
	roli 	r2, r2, 24 # Bit shift to reverse order of binary value
	mov 	r4, r3
	subi 	r7, r7, 1
	bgt		r7, r0, n2b_loop
	
	ret

##############################################
# -- Print number to UART --
#
# void printNum(int n) {
#	if (n < 10) putchar('0' + n);
#	else {
#		printNum(n / 10);
#		putchar('0' + (n % 10));
#	}
# }
printNum:
	# Prologue
	subi 	sp, sp, 8
	stw 	ra, 4(sp)
	
	bge 	r4, r0, not_neg
	sub 	r4, r0, r4 # Make r4 negative
	stw 	r4, 0(sp)
	movi 	r4, '-'
	call 	putchar # Print '-' character
	ldw 	r4, 0(sp)
	
  not_neg:
	# Check if last character has been reached
  	movi 	r10, 10
	bge 	r4, r10, not_base
	addi 	r4, r4, '0'
	call 	putchar
	br 	printNum_done

  not_base:
  	# Modulus implementation
  	movi 	r10, 10
  	div 	r3, r4, r10  # r3 = r4 / 10
	mul 	r5, r3, r10
	sub 	r5, r4, r5   # r5 = r4 % 10
	
	stw 	r5, 0(sp)
	mov		r4, r3
	call	printNum	 # printNum(n / 10)
	ldw 	r5, 0(sp)
	addi 	r4, r5, '0'
	call 	putchar 		# putchar ('0' + n % 10)
  
  printNum_done:
  	# Epilogue
	ldw		ra, 4(sp)
	addi 	sp, sp, 8
	ret

##############################################
# void putchar(char c) - Write char to UART
putchar:
	ldwio 	r2, UART_CTRL(gp) # Load data from UART control register
	srli 	r2, r2, 16 # Load upper 16 bits (available write data)
	beq 	r2, r0, putchar # Loop - no space to write
	stwio 	r4, UART_DATA(gp) # Write data
	
	ret
	
	
	
.data

Time:
	.word 251
	
Bits7Seg:
	.byte  0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6f

.end	
		
		
		
		