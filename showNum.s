# This function takes an unsigned integer parameter and lights up the corresponding 7 segment led numbers.
# The inputs will range from 0 to 9999.

.global _start
_start:
	
	
	movia r5, 0xff200020
	stwio r0, (r5) # Reset led segments
	
	movia r4, 1001
	movi r3, 0 # Counter (Which number are we displaying)
	call showNum
	

# Display argument on 7 segment display - four lower segments
showNum:
	#r4 = 9999
		
	movi r10, 10 # Store 10 decimal in register r10
	div r5, r4, r10 # Divide r4 by 10
	mul r6, r5, r10 # Multiply r4 / 10 by 10
	
	mov r20, r4 # Save r4
	sub r4, r4, r6 # Get remainder - pass as argument to num_to_seg
	
	call num_to_seg # Convert the remainder to the proper hex value for the segment display
	
	mov r4, r2 # Move return from num_to_seg to argument
	muli r7, r3, 8
	
	movia r5, 0xff200020
	ldwio r8, (r5)
	sll r4, r4, r7
	add r4, r4, r8
	
	call display_segment # Display on LED segments
	
	mov r4, r20
	div r4, r4, r10
	
	beq r4, r0, done
	addi r3, r3, 0x1
	
	br showNum

display_segment:
	stwio r4, 0(r5) # Take a 32 bit value and display the corresponding light segments
	ret
	
num_to_seg:
	#movia r2, Numbers # Address of Numbers array into memory
	#ldw r2, 0(r2)
	muli r4, r4, 4
	ldw r2, Numbers(r4)
	ret

done: br done


.data

Numbers:
	.word 0x3f, 0x06, 0x5b, 0x4f, 0x66, 0x6d
	.word 0x7d, 0x07, 0x7f, 0x67, 0x77, 0x7c, 0x39
	.word 0x5e, 0x79, 0x71
	
