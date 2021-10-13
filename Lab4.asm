.data
buffer: .space 128
firstsentence: .asciiz "You entered the file:\n"
mismatcherror: .asciiz "ERROR - There is a brace mismatch: "
atindex: .asciiz " at index "
success1: .asciiz "SUCCESS: There are "
success2: .asciiz " pairs of braces."
errornotempty: .asciiz "ERROR - Brace(s) still on stack: "
errorfile: .asciiz "ERROR: Invalid program argument."

.text
###################################################################
#print file name
#if file name is over 20 characters
#	error
#if file name doesnt start with letter
#	error
#open file
#read file
#loop over every character:
#	if char == ( or { or [
#		push to stack
#	if char == ) or } or ]
#		if doesnt matche last in stack
#			error
#		else
#			pop from stack
#			increment number of pairs
#if stack is not empty
#	error
#	print rest of stack
#else
#	print success
#	print number of pairs
###############################################################
li $v0, 4
la $a0, firstsentence
syscall					#print sentence

li $v0, 13
lw $a0, ($a1)
move $t7, $a0				#put program argument address in t7 for length check
li $a1, 0
li $a2, 0
syscall					#open file
move $t0, $v0				#t0 stores file descriptor

li $v0, 4
syscall					#print file name (program argument)

li $v0, 11
li $a0, 10
syscall					#print new line
syscall					#print another new line

CheckFileStartingCharacter:		#branch to error if ascii value is not letter
	lb $t4, ($t7)
	blt $t4, 65, FileError
	blt $t4, 91, CheckFileNameLength
	bgt $t4, 90, CheckBetween
	CheckBetween:
		blt $t4, 97, FileError
		bgt $t4, 122, FileError
		
CheckFileNameLength:
	li $t3, 0 			# initialize the count to zero
	loop:
		lb $t4, ($t7) 		# load the next character into t4
		beqz $t4, CheckLength 	# check for the null character
		addi $t7, $t7, 1 	# increment the string pointer
		addi $t3, $t3, 1 	# increment the count
		b  loop 		# return to the top of the loop
	CheckLength:
		bgt $t3, 20, FileError
		
li $t3, 0				#t3 stores number of completed pairs
li $t4, 0				#t4 stores number of times file is read after first time

ReadFile:
	move $a0, $t0			#file descriptor from t0 to a0
	la $a1, buffer
	li $a2, 128
	li $v0, 14
	syscall				#read file
	move $t6, $v0			#t6 stores number of characters read

li $t1, 0				#t1 stores current character index, s0 used to store current character
addi $sp, $sp, -4
sw $t1, ($sp)				#store 0 in first stack slot to check if stack is empty(t0 currently 0)

LoadCharacter:				
	lb $s0, buffer($t1)		#load current character into s0
					
CheckIfOpen:
	beq $s0, 40, Push		#branch if (
	beq $s0, 91, Push		#branch if [
	beq $s0, 123, Push		#branch if {
CheckIfClosed:
	beq $s0, 41, CheckIfMatchParenthesis	#branch if )
	beq $s0, 93, CheckIfMatchBrace		#branch if ]
	beq $s0, 125, CheckIfMatchBracket	#branch if }
	
IncrementIndex:
	addi $t1, $t1, 1
	blt $t1, 127, CheckLastCharacter	#load next character if not last index(19)
	bgt $t1, 127, ReadMore		#if last index(127) read more from file

CheckLastCharacter:
	beq $t6, $t1 CheckStackEmpty
	bne $t6, $t1 LoadCharacter
	
ReadMore:
	addi $t4, $t4, 128		#increment number of times file is read
	li $t1, 0			#set character index back to 0
	move $a0, $t0			#file descriptor from t0 to a0
	la $a1, buffer
	li $a2, 128
	li $v0, 14
	syscall
	move $t6, $v0
	beqz $t6, CheckStackEmpty
	b LoadCharacter
	
	
Push:
	addi $sp, $sp, -4
	sw $s0, ($sp)
	b IncrementIndex
	
CheckIfMatchParenthesis:
	lw $t2, ($sp)			#set t2 to last item in stack
	beq $t2, 40, Pop		#pop from stack if matching
	bne $t2, 40, ErrorMismatch	#error if not matching
CheckIfMatchBrace:
	lw $t2, ($sp)
	beq $t2, 91, Pop		#pop from stack if matching
	bne $t2, 91, ErrorMismatch	#error if not matching
CheckIfMatchBracket:
	lw $t2, ($sp)
	beq $t2, 123, Pop		#pop from stack if matching
	bne $t2, 123, ErrorMismatch	#error if not matching	
	
Pop:
	addi $sp, $sp, 4
	addi $t3, $t3, 1
	b IncrementIndex
	
ErrorMismatch:
	li $v0, 4
	la $a0, mismatcherror		
	syscall				#print error statement
	li $v0, 11
	move $a0, $s0
	syscall				#print erroneous brace
	li $v0, 4
	la $a0, atindex
	syscall				#print " at index "
	li $v0, 1
	add $t5, $t1, $t4		#t5 stores total index
	move $a0, $t5
	syscall				#print index
	b Exit
	
CheckStackEmpty:
	lw $t2, ($sp)
	bnez $t2, ErrorStackNotEmpty	#if sp doesnt equal 0 there is still items in stack
	b Success

ErrorStackNotEmpty:
	li $v0, 4
	la $a0, errornotempty
	syscall				#print error stack not empty
	PrintStack:
		li $v0, 11
		move $a0, $t2
		syscall			#print value at sp
		addi $sp, $sp, 4	#increment sp
		lw $t2, ($sp)
		bnez $t2, PrintStack
		beqz $t2, Exit
		
FileError:
	li $v0, 4
	la $a0, errorfile
	syscall
	b Exit				#print error with file
	
		
Success:
	li $v0, 4
	la $a0, success1
	syscall				#print success
	li $v0, 1
	la $a0, ($t3)
	syscall				#print number of pairs
	li $v0, 4
	la $a0, success2
	syscall
	b Exit

Exit:
	li $v0, 16
	move $a0, $t0
	syscall				#close file	
	li $v0, 11
	li $a0, 10
	syscall				#new line
	li $v0, 10			
	syscall				#end program

