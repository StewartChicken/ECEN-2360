.global _start
_start:
	#Move into r2 the immediate 32-bit value of 0xff200020
	movia r2, 0xff200020 #7 segment display address
	
	
	movia r3, 0xff200040 #switch address
	
loop: #function called loop

	#Read value from register r3 (switches) into r4
	ldwio r4, (r3) #use ldwio (as opposed to ldw) to bypass the cache
	
	#ldw reads value from a memory location 
	#Read to r5 from Digit7seg(r4)
	ldb r5, Digit7seg(r4)#In memory, can use ldw and not ldwio
	
	#Opposite direction for stw - from r5 to r2
	stwio r5, (r2)
	
	br loop #Repeat loading
	
.data

Digit7seg:

#			0	 1      2    3     4      5
	.byte 0x3f, 0x06, 0x5b, 0x4f, 0x66, 0x6d
#			6    7      8    9     10 
	.byte 0x7d, 0x07, 0x7f, 0x67, 0x77, 0x7c, 0x39
	.byte 0x5e, 0x79, 0x71

.end