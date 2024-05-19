global mdiv

section .text

; rdi -> int64_t *x,       rsi -> int64_t n,       rdx -> int64_t y
mdiv:
    ; in r8 we store information on the four least significant bits:
    ; 1 on 1st bit: x, dividend, negative
    ; 1 on 2nd bit: y, divisor, negative
    ; 1 on 3rd bit: quotient negative
    ; 1 on 4rd bit: jump to second negation
    xor r8, r8   ; set it to 0000 for now
    
.dividend_check:  ; negates the dividend if it's negative
    ; checking the most significant part of the dividend
    cmp QWORD [rdi + 8 * rsi - 8], r8 ; comparing against r8 that is now 0
    jge .divisor_check

    ; it is negative, so we set r8 to 0101 and jump to the negation
    or r8, 0x5
    jmp .array_negation

.divisor_check:  ; negates the divisor if it's negative
    cmp rdx, 0x0
    jge .division_setup

    ; it is negative, so we negate it and xor r8 with 0110, so the 3rd bit
    ; might switch to 0 if both dividend and divisor are negative
    neg rdx      
    xor r8, 0x6 
    
.division_setup:
    or r8, 0x8        ; we set the 4th bit to 1 so next dividend jump is set
    mov rcx, rsi      ; set rcx to n as the counter
    mov r9, rdx       ; divisor into r9
    xor rdx, rdx      ; rdx needs to be zero as the remainder for now

.division_loop: 
    mov rax, QWORD [rdi + rcx * 8 - 8]  ; move part of the dividend into rax
    div r9                              ; result in rax, remainder in rdx
    mov QWORD [rdi + rcx * 8 - 8], rax  ; result back to the dividend
    loop .division_loop                 ; decrement rcx and exit if it's 0

.after_division:  ; negates the quotient if it should be negative 
    test r8, 0x4                 ; check the 3rd bit in r8 for information
    jnz .array_negation          

.overflow_check:  ; check if the quotient overflowed and signal
    ; quotient is positive, the sign bit should be 0
    xor rax, rax
    cmp QWORD [rdi + rsi * 8 - 8], rax
    jge .remainder_setup
    div rax                             ; div by 0 will signal SIGFPE
    
.remainder_setup:  ; negate the remainder if it should be negative
    mov rax, rdx                        ; remainder into rax as the return value
    ; check the 1st bit in r8 - if dividend is negative, so is the remainder
    test r8, 0x1    
    jz .end

    neg rax

.end:
    ret

; performs negation of the array
; assumptions: *x in rdi, n in rsi, proper jump flag in r8
; changes: rcx, r9, array, flags
.array_negation:
    ; we set rcx to n as the loop counter so it executes n times
    mov rcx, rsi
    ; r9 is 0 and we will be incrementing it as the index of the array
    xor r9, r9          
    ; set carry to 1 so in the loop we will add 1 to the least significant part
    ; and perhaps to higher parts if carry occurs during calculation
    ; we need to be extra careful not to override the CF with other instructions
    stc                

.negation_loop: 
    not QWORD [rdi + 8 * r9]
    adc QWORD [rdi + 8 * r9], 0x0 ; add 1 if carry is set
    inc r9                            
    loop .negation_loop           ; decrement rcx and if it's 0 we exit the loop

.jump_back:                   ; check where to jump looking at the 4th bit in r8
    test r8, 0x8
    jz .divisor_check
    jmp .remainder_setup
    