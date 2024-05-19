global mdiv

; Nie definiujemy tu żadnych stałych, żeby nie było konfliktu ze stałymi
; zdefiniowanymi w pliku włączającym ten plik.

; Wypisuje napis podany jako pierwszy argument, a potem szesnastkowo zawartość
; rejestru podanego jako drugi argument i kończy znakiem nowej linii.
; Nie modyfikuje zawartości żadnego rejestru ogólnego przeznaczenia ani rejestru
; znaczników.
%macro print 2
  jmp     %%begin
%%descr: db %1
%%begin:
  push    %2                      ; Wartość do wypisania będzie na stosie. To działa również dla %2 = rsp.
  lea     rsp, [rsp - 16]         ; Zrób miejsce na stosie na bufor. Nie modyfikuj znaczników.
  pushf
  push    rax
  push    rcx
  push    rdx
  push    rsi
  push    rdi
  push    r11

  mov     eax, 1                  ; SYS_WRITE
  mov     edi, eax                ; STDOUT
  lea     rsi, [rel %%descr]      ; Napis jest w sekcji .text.
  mov     edx, %%begin - %%descr  ; To jest długość napisu.
  syscall

  mov     rdx, [rsp + 72]         ; To jest wartość do wypisania.
  mov     ecx, 16                 ; Pętla loop ma być wykonana 16 razy.
%%next_digit:
  mov     al, dl
  and     al, 0Fh                 ; Pozostaw w al tylko jedną cyfrę.
  cmp     al, 9
  jbe     %%is_decimal_digit      ; Skocz, gdy 0 <= al <= 9.
  add     al, 'A' - 10 - '0'      ; Wykona się, gdy 10 <= al <= 15.
%%is_decimal_digit:
  add     al, '0'                 ; Wartość '0' to kod ASCII zera.
  mov     [rsp + rcx + 55], al    ; W al jest kod ASCII cyfry szesnastkowej.
  shr     rdx, 4                  ; Przesuń rdx w prawo o jedną cyfrę.
  loop    %%next_digit

  mov     [rsp + 72], byte `\n`   ; Zakończ znakiem nowej linii. Intencjonalnie
                                  ; nadpisuje na stosie niepotrzebną już wartość.

  mov     eax, 1                  ; SYS_WRITE
  mov     edi, eax                ; STDOUT
  lea     rsi, [rsp + 56]         ; Bufor z napisem jest na stosie.
  mov     edx, 17                 ; Napis ma 17 znaków.
  syscall

  pop     r11
  pop     rdi
  pop     rsi
  pop     rdx
  pop     rcx
  pop     rax
  popf
  lea     rsp, [rsp + 24]
%endmacro











section .text

; rdi -> int128_t *x,       rsi -> int64_t n,       rdx -> int64_t y
mdiv:
    print "rdx: ", rdx
    ; in r8 we store information on the three least significant bits:
    ; 1 on 1st bit: x, dividend, negative
    ; 1 on 2nd bit: y, divisor, negative
    ; 1 on 3rd bit: quotient negative
    xor r8, r8   ; set it to 000 for now
    
    mov rax, 0x8000000000000000
    print "rdx: ", rdx
    print "rax: ", rax
    cmp rdx, rax
    jne .after_check
    mov rax, 0x0
    div rax
.after_check:

    cmp rdx, 0x0 
    jge .after_divisor_negation ; if the divisor is not negative, we do nothing

    ; divisor is negative, we switch it from U2 to normal
    ; overflow from a negative to positive is not possible
    not rdx       ; invert the bits...
    add rdx, 0x1  ; ... and add 1 to get the absolute value
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
    jz .jump_location_2
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





; dividend is negative, we switch it from U2 like the divisor
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
    not QWORD [rdi + 8 * r9]         ; invert bits
    adc QWORD [rdi + 8 * r9], 0x0    ; add 1 to the lowest bits and to higher if carry happened
    inc r9   ; counter++
    dec rcx  ; inv_counter--         
    jnz .negation_loop    ; if the inv_counter is 0, counter is n, we exit

    test r8, 0x8    ; if the 4th bit is 1 then we jump to the second negation
    jz .jump_location_1
    jmp .jump_location_2
    