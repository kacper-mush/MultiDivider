global mdiv

section .text

; rdi -> int128_t *x,       rsi -> int64_t n,       rdx -> int64_t y
mdiv:
    ; in r8 we store information on the four least significant bits:
    ; 1 on 1st bit: x, dividend, negative
    ; 1 on 2nd bit: y, divisor, negative
    ; 1 on 3rd bit: quotient negative
    ; 1 on 4rd bit: jump to second negation
    xor r8, r8   ; set it to 000 for now
    
    cmp rdx, 0x0
    jge .after_divisor_negation ; if the divisor is not negative, we do nothing

    ; divisor is negative, we switch it from U2 to normal
    neg rdx
    ;not rdx       ; invert the bits...
    ;add rdx, 0x1  ; ... and add 1 to get the absolute value
    or r8, 0x6    ; we mark that the divisor is negative by setting r8 to 110
    
.after_divisor_negation:
    ; checking the highest part to see if the dividend is negative
    cmp QWORD [rdi + 8 * rsi - 8], 0x0  
    jge .after_dividend_negation

    ; r8 4th bit is zero so the jump will come back here
    jmp .dividend_negation
.jump_location_1:
    ; now we xor r8 with 101 so the first bit is for sure on
    ; and the third might switch to zero if both signs are the same
    xor r8, 0x5 

.after_dividend_negation:

    mov rcx, rsi            ; set rcx to n as the counter
    mov r9, rdx             ; divisor into r9
    xor rdx, rdx            ; rdx needs to be zero for now because there is no remainder
.division_loop:
    mov rax, QWORD [rdi + rcx * 8 - 8]   ; move part of the dividend into rax
    div r9                             ; now the result is in rax an the remainder in rdx
    mov QWORD [rdi + rcx * 8 - 8], rax   ; result back to the dividend
    dec rcx        ; decrease the counter
    jnz .division_loop       ; if the counter is 0, we exit

    test r8, 0x4    ; if the third bit in r8 is 1 then the output is negative
    jz .overflow_check

    or r8, 0x8      ; we set the 4th bit to 1 to indicate where to jump
    jmp .dividend_negation

.jump_location_2:
    
    mov rax, rdx                   ; remainder into rax so we can return it
    test r8, 0x1    ; if the first bit is 1 then the dividend was negative so we need to make the remainder negative
    jz .end

    not rax
    add rax, 0x1
.end:
    ret

.overflow_check:
    ; output is positive, check for overflow
    xor rax, rax
    cmp QWORD [rdi + rsi * 8 - 8], rax    ; check if the highest bit is 1
    jge .jump_location_2
    div rax


; assumptions: n in rsi, &x in rdi, proper jump flag in r8
; changes: rax, rcx, r9, flags
.dividend_negation:
    mov rcx, rsi        ; now n is in rcx and we will be decrementing it
    xor r9, r9          ; r9 is 0 and we will be incrementing it up to n
    stc                 ; set carry to 1 so in the loop we will always...
                        ; ... add 1 to the lowest and perhaps to higher bits
                        ; if carry occurs during calculation
                        ; we need to be extra careful not to override the CF
.negation_loop: 
    mov rax, QWORD [rdi + 8 * r9]    ; load the part of the dividend into rax
    not rax         ; invert bits
    adc rax, 0x0    ; add 1 to the lowest bits and to higher if carry happened
    mov QWORD [rdi + 8 * r9], rax    ; store the result back
    inc r9   ; counter++
    dec rcx  ; inv_counter--         
    jnz .negation_loop    ; if the inv_counter is 0, counter is n, we exit

    test r8, 0x8    ; if the 4th bit is 1 then we jump to the second negation
    jz .jump_location_1
    jmp .jump_location_2
    