.global _start
.equ UART_DATA, 0x1000
.equ UART_CTRL, 0x1004
.equ SEG_DISPLAY, 0x20
_start:
	movia sp, 0x10000
	movia gp, 0xFF200000 # JTAG UART

main:
	movia r4, Prompt
	call puts
	
	movia r4, Buffer
	call gets
	
	movia r4, Response
	call puts
	
	movia r4, Buffer
	call puts
	
	movia r4, Buffer
	call atoi
	
	mov r16, r2
	movi r4, '['
	call putchar
	mov r4, r16
	call printNum
	movi r4, ']'
	call putchar
	
	mov r4, r16
	call showNum
	
	br main # Loop


#################################
# void showNum(int n) -- display n on 7 segment display
showNum:
	subi sp, sp, 4
	stw ra, 0(sp)

	call num2bits # Take r4 as argument - return bit representation in r2
	stwio r2, SEG_DISPLAY(gp) # Display on 7 segment
	
	ldw ra, 0(sp)
	addi sp, sp, 4
	ret

#################################
# int num2bits(int n) -- from n to bits which can be displayed 
num2bits:
	movi 	r2, 0
	movi 	r10, 10
	movi 	r7, 4
	
  n2b_loop:
	div 	r3, r4, r10
	mul 	r5, r3, r10
	sub		r5, r4, r5		# r5 = r4 % r5
	
	ldbu 	r6, Bits7Seg(r5)
	or 		r2, r2, r6
	roli 	r2, r2, 24
	mov 	r4, r3
	subi 	r7, r7, 1
	bgt		r7, r0, n2b_loop
	
	ret
	
#################################
# void printNum(int n) -- Print number to UART
printNum:
	subi 	sp, sp, 8
	stw 	ra, 4(sp)
	
	bge 	r4, r0, not_neg
	sub 	r4, r0, r4 # Make r4 negative
	stw 	r4, 0(sp)
	movi 	r4, '-'
	call 	putchar # Print '-' character
	ldw 	r4, 0(sp)
  not_neg:
  
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
	ldw		ra, 4(sp)
	addi 	sp, sp, 8
	ret
	
#################################
# int atoi(char *str) -- Convert string to number using Horner's Algorithm
atoi:
	movi r2, 0	# Return
	movi r3, 0  # Negation
	
	ldbu r5, (r4) 
	cmpeqi r6, r5, '-'
	beq r6, r0,  no_negate
	movi r3, 1 # Number is negative
  atoi_loop:
	addi r4, r4, 1 # Increment buffer
	ldbu r5, (r4) # Update r5
  no_negate:
	movi r6, '0'
	blt r5, r6, atoi_done
	movi r6, '9'
	bgt r5, r6, atoi_done
	
	muli r2, r2, 10 
	subi r5, r5, '0'
	add r2, r2, r5
	br atoi_loop
  atoi_done:
  	beq r3, r0, dont_negate
	sub r2, r0, r2
  dont_negate:
  	ret
	
	
#################################
# void puts(char *str) -- write string to UART
# 	char c;
#   while ((c = *buf++) != '\0') {
#		putchar(c);
#	}
#}
puts:
	ldbu r3, (r4) # c = *buf
	addi r4, r4, 1 # buf++
	beq r3, r0, puts_done
	
	ldwio r2, UART_CTRL(gp) # Load data from UART control register
	srli r2, r2, 16 # Load upper 16 bits (available write data)
	beq r2, r0, putchar # Loop - no space to write
	stwio r3, UART_DATA(gp) # Write data
	
	br puts
	
	puts_done:
		ret
	
#################################
# char* gets(char *buf){ -- Read line up to '\n' then return string
# 	char c;
#   while ((c = getchar()) != '\n') {
#		*buf++ = c;
#	}
#	*buf = '\0'
#}
gets:
	# getchar
	ldwio r2, UART_DATA(gp) # Load data from UART queue
	andi r3, r2, 0x8000 # Check if rValid bit is high (data is present)
	beq r3, r0, gets # Loop if UART queue is empty
	andi r2, r2, 0xFF # Dequeue character from UART - load into return register
	
	stwio r2, UART_DATA(gp) # Write data to UART for visibility purposes
	
	# if c == '\n'
	movi r3, '\n' # Load 'newline' character into r3
	beq r2, r3, gets_done
	
	stb r2, (r4) # *buf = c
	addi r4, r4, 1 # *buf++
	br gets
	
	gets_done:
		stb r0, (r4) # Store 0x00 into r4 (*buf = \0)
		ret	

#################################
# void putchar(char c) - Write char to UART
putchar:
	ldwio r2, UART_CTRL(gp) # Load data from UART control register
	srli r2, r2, 16 # Load upper 16 bits (available write data)
	beq r2, r0, putchar # Loop - no space to write
	stwio r4, UART_DATA(gp) # Write data
	
	ret

#################################
# void getchar(void) - Read char from UART
getchar:
	ldwio r2, UART_DATA(gp) # Load data from UART queue
	andi r3, r2, 0x8000 # Check if rValid bit is high (data is present)
	beq r3, r0, getchar # Loop if UART queue is empty
	andi r2, r2, 0xFF # Dequeue character from UART - load into return register
	
	ret

	

.data
Buffer:
	.space 100, 0
Prompt:
	.asciz "\nEnter Number: "
Response:
	.asciz "You typed: "
Bits7Seg:
	.byte  0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6f
	
.end