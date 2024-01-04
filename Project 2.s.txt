/*
 * ECEN 2360 Project 2A: Stop Watch
 * Evan Poon
*/

.section .reset, "ax" 		#0x00000000
.global _start
.equ UART_DATA, 	0x1000
.equ UART_CTRL, 	0x1004
.equ SEG_DISPLAY_LO, 	0x20
.equ SEG_DISPLAY_HI, 	0x30
.equ BUTTON_DATA, 	0x50
.equ BUTTON_MASK, 	0x58
.equ BUTTON_CAPTURE, 	0x5C

_start:
	movia 	sp, 0x01000000 # 16MB stack
	movia 	gp, 0xff200000 # MMIO base address
	br 		main
	
.section .exceptions, "ax" # 0x00000020

# main() - Stop Watch main program
# Parameters: none
# Return: none
main:
	
	# Initialize values - stop watch value and state
	mov 	r16, r0 # Stop watch initial value
	mov 	r17, r0 # 'Stopped' - boolean value, 1 if watch is stopped, 0 if it is running
	mov 	r18, r0 # 'Frozen' - Time continues to increment but display is frozen
	
	mov 	r19, r0 # Button0 press state - 1 if pressed, 0 if not
	mov 	r20, r0 # Button1 press state
	
	# Display initial time
	mov 	r4, r0
	call 	displayTime
  main_loop:
	
	movia 	r4, 1
	call 	delayNms 
	
### POLL BUTTON ###
	
	ldwio 	r2, BUTTON_DATA(gp) # Load current button data
	
	# Check if button 0 (stop/start) button is pressed
	andi 	r3, r2, 0b1
	bne 	r3, r0, handle_press0 # If button is currently pressed down, branch here
	br 		handle_depress0 # If button is not pressed, check if it was just depressed
	
  # Update button state to currently pressed
  handle_press0:
	movi 	r19, 1
	br 		end_button_press0

  # If button was just depressed, toggle start/stop state of watch
  handle_depress0:
	bne 	r19, r0, press_button0
	br 		end_button_press0
	
  # Toggle start/start state of watch
  press_button0:
  	mov 	r19, r0
	bne 	r17, r0, start_watch
	br 		stop_watch
	
  start_watch:
  	mov 	r17, r0
	br 		end_button_press0
	
  stop_watch:
  	movi 	r17, 1
	br 		end_button_press0
  
  end_button_press0: 
  
  	# Check if button 1 (freeze/reset) button is pressed
  	andi 	r3, r2, 0b10
	bne 	r3, r0, handle_press1
	br 		handle_depress1
  
  # If button1 is pressed down
  handle_press1:
	movi 	r20, 1
	br 		end_button_press1

  # Check if button1 was recently depressed
  handle_depress1:
	bne 	r20, r0, press_button1
	br 		end_button_press1
	
  # Update watch if button1 press is detected
  press_button1:
  	mov 	r20, r0
	bne 	r17, r0, reset_watch # If watch is stopped, reset watch
	bne 	r18, r0, unfreeze_watch
	br 		freeze_watch
	
  freeze_watch:
  	movi 	r18, 1
	br 		end_button_press1
    
  unfreeze_watch:
 	mov 	r18, r0
	br 		end_button_press1
	
  # Reset watch time to 00:00:00 and display updated time
  reset_watch:
  	mov 	r16, r0
	mov 	r4, r16
  	call 	displayTime
	
  end_button_press1:
  
### END BUTTON POLL ###
	
	
	bne 	r17, r0, main_loop # If watch is stopped, restart loop - skip time incrementation
	
	# Increment time
	addi 	r16, r16, 1
	
	bne 	r18, r0, main_loop # If watch is frozen, restart loop after time is incremented, 
							   # don't display updated time
	
	# beq frozen, 1, increment (doesn't display updated time, still increment time)
  	mov 	r4, r16
  	call 	displayTime
	
	br 		main_loop
	
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
	
#################################################
# void delayNms(int n) -- Delay N milliseconds
# Parameter: int n Number of milliseconds to delay
#
# DEBUG - delay of 150 ms creates a delay of 1 second - need to increase 33332 
delayNms:
	movia 	r2, 33332 # Divide clock by 33332 * 3 ~ 100,000 cycles
	mul 	r2, r2, r4 # Multiply by n to obtain total millisecond delay
  delay_loop:
  	subi 	r2, r2, 1 # 1 clock cycle
	bne 	r2, r0, delay_loop # 2 clock cycles
	ret
	

# Delays program for 10 ms
delay10ms:
	subi 	sp, sp, 4
	stw 	ra, 0(sp)
	
	movia 	r4, 10
	
	call 	delayNms
	
	ldw 	ra, 0(sp)
	addi 	sp, sp, 4
	
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

Bits7Seg:
	.byte  0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6f

.end