/*
 * ECEN 2360 Project 1: Adding Machine
 * Evan Poon
*/

.section .reset, "ax" 		#0x00000000
.global _start
.equ UART_DATA, 	0x1000
.equ UART_CTRL, 	0x1004
.equ SEG_DISPLAY, 	0x20
.equ BUTTON_DATA, 	0x50
.equ BUTTON_MASK, 	0x58
.equ BUTTON_CAPTURE, 	0x5C
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
	
	# Check for button interrupt
	rdctl 	et, ipending
	andi 	et, et, 0b10 
	bne 	et, r0, Button_IRQ_Handler
	
	# Exit Interrupt Handeler
	br 		Interrupt_Done
	
Button_IRQ_Handler:

	# Reset total sum if button 0 is pushed
	addi 	et, gp, BUTTON_CAPTURE
	ldwio 	et, 0(et)
	andi 	et, et, 0b1
	bne 	et, r0, Reset_Total
	
	# Clear Edge Capture bits
	addi 	et, gp, BUTTON_CAPTURE
	ldwio 	et, 0(et) # Load value from Edge Capture into et
	ori 	et, et, 0b11 # Bring edge capture bits high
	stwio 	et, BUTTON_CAPTURE(gp) # Write to clear edge capture for buttons
	
	# Exit Interrupt Handeler
	br 		Interrupt_Done
	
# Resets total sum to 0
Reset_Total:
	movia 	et, Sum
	stw		r0, 0(et)
	
	# Display reset on segment display
	mov 	r4, r0
	call 	showNum
	
	# Print: "Reset Detected"
	movia 	r4, Reset_Prompt 
	call 	puts
	
	# Print: "Total: "
	movia 	r4, Total_Prompt	
	call 	puts
	
	# Display reset total in JTAG UART console
	mov 	r4, r0
	call 	printNum
	
	# Print: "Enter Number: "
	movia 	r4, Prompt	
	call 	puts
	
	# Clear Edge Capture bits
	mov 	et, gp
	addi 	et, gp, BUTTON_CAPTURE
	ldwio 	et, 0(et) # Load value from Edge Capture into et
	ori 	et, et, 0b11 # Bring edge capture bits high
	stwio 	et, BUTTON_CAPTURE(gp) # Write to clear edge capture for buttons
	
	# Exit Interrupt Handler
	br 		Interrupt_Done

Interrupt_Done:
	# Epilogue
	ldw 	ra, 12(sp)
	ldw 	r5, 8(sp)
	ldw 	r4, 4(sp)
	ldw 	r2, 0(sp)
	addi 	sp, sp, 16
	
	eret
	
##############################################
# End interrupt handling code
##############################################

##############################################
# Begin main program
##############################################

# main() - Adding Machine main program
# Parameters: none
# Return: none
main:
	
##############################################
# Begin main program setup
##############################################
	
	############## Reset Interrupts ##############
	# Load edge capture into et
	addi 	et, gp, BUTTON_CAPTURE
	ldwio 	et, 0(et) # Load value from Edge Capture into et
	
	ori 	et, et, 0b11
	stwio 	et, BUTTON_CAPTURE(gp) # Clear edge capture for buttons
	##############################################
	
	
	############## Enable interrupts ##############
	movi 	r4, 0b1 # Push button 0 mask
	stwio 	r4, BUTTON_MASK(gp) # Enable button interrupt

	# Enable button IRQ
	rdctl 	r4, ienable
	ori 	r4, r4, 0b10
	wrctl 	ienable, r4
	
	# Enable status.PIE
	rdctl 	r16, status
	ori 	r16, r16, 0b1
	wrctl 	status, r16
	###############################################
	
	# Reset Segment Display
	mov 	r4, r0
	call 	showNum
	
##############################################
# End main function set up - begin main loop
##############################################
  main_loop:
  	# Print prompt: "Enter Number: "
	movia 	r4, Prompt 		
	call 	puts
	
	# Get user input value
	movia 	r4, Buffer		
	call 	gets
	
	# Print prompt: "Total: "
	movia 	r4, Total_Prompt	
	call 	puts
	
	# Convert input string to integer value
	movia 	r4, Buffer		
	call 	atoi
	
	# Add user input to total
	movia 	r4, Sum
	ldw 	r5, 0(r4)
	add 	r5, r5, r2
	stw 	r5, 0(r4)
	
	# Display new total on segment display
	mov 	r4, r5
	call 	showNum
	
	# Display new total value after "Total: " prompt
	movia 	r4, Sum
	ldw 	r4, 0(r4)
	call 	printNum			
	
	# Loop
	br 		main_loop 

##############################################
# -- display n on 7 segment display --
#
# void showNum(int n) 
showNum:
	# Prologue
	subi 	sp, sp, 4
	stw 	ra, 0(sp)

	# Take r4 as argument - return bit representation in r2
	call 	num2bits 
	
	# Display r4 value on 7 segment
	stwio 	r2, SEG_DISPLAY(gp) 
	
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
	br printNum_done

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
	call putchar 		# putchar ('0' + n % 10)
  
  printNum_done:
  	# Epilogue
	ldw		ra, 4(sp)
	addi 	sp, sp, 8
	ret
	

##############################################
# -- Convert string to number using Horner's Algorithm --
# int atoi(char *str) {
# 	char c;
#	int negate = 0; // Flag: negative
#	int sum = 0;
#	if ((c = *str) == '-') {
#		negate = 1;
#		str++;
#	}
#	while ((c = *str++) >= '0' && c <= '9') {
#		sum *= 10;
#		sum += c – '0';
#	}
#	return negate ? -sum : sum;
#}
atoi:
	movi 	r2, 0	# Return
	movi 	r3, 0  # Negation
	
	ldbu 	r5, (r4) 
	cmpeqi 	r6, r5, '-'
	beq 	r6, r0,  no_negate
	movi 	r3, 1 # Number is negative
  atoi_loop:
	addi 	r4, r4, 1 # Increment buffer
	ldbu 	r5, (r4) # Update r5
  no_negate:
  	# Check boundary of input
	movi 	r6, '0'
	blt 	r5, r6, atoi_done
	movi 	r6, '9'
	bgt 	r5, r6, atoi_done
	
	# Convert from character ASCII to integer ASCII
	muli 	r2, r2, 10 
	subi 	r5, r5, '0'
	add 	r2, r2, r5
	br 		atoi_loop
  atoi_done:
  	beq 	r3, r0, dont_negate
	sub 	r2, r0, r2
  dont_negate:
  	ret
	
	
##############################################
# void puts(char *str) -- write string to UART
# 	char c;
#   while ((c = *buf++) != '\0') {
#		putchar(c);
#	}
#}
puts:
	ldbu 	r3, (r4) # c = *buf
	addi 	r4, r4, 1 # buf++
	beq 	r3, r0, puts_done
	
	ldwio 	r2, UART_CTRL(gp) # Load data from UART control register
	srli 	r2, r2, 16 # Load upper 16 bits (available write data)
	beq 	r2, r0, putchar # Loop - no space to write
	stwio 	r3, UART_DATA(gp) # Write data
	
	br 		puts # Loop
	
	puts_done:
		ret
		
##############################################
# char* gets(char *buf){ -- Read line up to '\n' then return string
# 	char c;
#   while ((c = getchar()) != '\n') {
#		*buf++ = c;
#	}
#	*buf = '\0'
#}
gets:
	# getchar
	ldwio 	r2, UART_DATA(gp) # Load data from UART queue
	andi 	r3, r2, 0x8000 # Check if rValid bit is high (data is present)
	beq 	r3, r0, gets # Loop if UART queue is empty
	andi 	r2, r2, 0xFF # Dequeue character from UART - load into return register
	
	stwio 	r2, UART_DATA(gp) # Write data to UART for visibility purposes
	
	# if c == '\n'
	movi 	r3, '\n' # Load 'newline' character into r3
	beq 	r2, r3, gets_done
	
	stb 	r2, (r4) # *buf = c
	addi 	r4, r4, 1 # *buf++
	br 		gets # Loop
	
	gets_done:
	stb 	r0, (r4) # Store 0x00 into r4 (*buf = \0)
	ret
		
##############################################
# void putchar(char c) - Write char to UART
putchar:
	ldwio 	r2, UART_CTRL(gp) # Load data from UART control register
	srli 	r2, r2, 16 # Load upper 16 bits (available write data)
	beq 	r2, r0, putchar # Loop - no space to write
	stwio 	r4, UART_DATA(gp) # Write data
	
	ret

##############################################
# void getchar(void) - Read char from UART
getchar:
	ldwio r2, UART_DATA(gp) # Load data from UART queue
	andi r3, r2, 0x8000 # Check if rValid bit is high (data is present)
	beq r3, r0, getchar # Loop if UART queue is empty
	andi r2, r2, 0xFF # Dequeue character from UART - load into return register
	
	ret
	
##############################################
# Data segment
##############################################
.data
Sum:
	.word 0
Buffer:
	.space 100, 0
Prompt:
	.asciz "\nEnter Number: "
Newline:
	.asciz "\n"
Total_Prompt:
	.asciz "Total: "
Reset_Prompt:
	.asciz "\nReset Detected\n"
Bits7Seg:
	.byte  0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6f

.end