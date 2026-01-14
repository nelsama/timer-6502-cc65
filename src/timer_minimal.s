;
; TIMER_MINIMAL.S - Version minimalista del timer para ROM API
;
; Solo incluye las 3 funciones esenciales:
;   - get_micros()
;   - delay_us(uint16_t)
;   - delay_ms(uint16_t)
;
; Optimizado para tamaño mínimo
;

    .setcpu     "6502"
    .smart      on
    .autoimport on
    .case       on
    .importzp   sp, sreg, ptr1, tmp1

; ============================================
; REGISTROS HARDWARE
; ============================================

TIMER_BASE      = $C030
TIMER_USEC_0    = TIMER_BASE + $08
TIMER_USEC_1    = TIMER_BASE + $09
TIMER_USEC_2    = TIMER_BASE + $0A
TIMER_USEC_3    = TIMER_BASE + $0B
TIMER_LATCH_CTL = TIMER_BASE + $0C
LATCH_USEC      = $02

; ============================================
; EXPORTS
; ============================================

    .export     _get_micros
    .export     _delay_us
    .export     _delay_ms

; ============================================
; VARIABLES TEMPORALES EN ZEROPAGE
; ============================================

.segment    "ZEROPAGE": zeropage

delay_target:       .res 4      ; Target para delays
current_time:       .res 2      ; Temp para valores actuales (byte0, byte1)

; ============================================
; CÓDIGO
; ============================================

.segment    "CODE"

; --------------------------------------------
; get_micros - Leer contador de microsegundos
; Retorna: uint32_t en sreg:X:A
; --------------------------------------------
.proc _get_micros
    ; Latch del contador
    lda     #LATCH_USEC
    sta     TIMER_LATCH_CTL
    
    ; Leer 32 bits (little-endian)
    ; Primero leer bytes 2 y 3 (high word)
    lda     TIMER_USEC_2
    sta     sreg
    lda     TIMER_USEC_3
    sta     sreg+1
    
    ; Luego leer bytes 0 y 1 (low word) en A y X
    lda     TIMER_USEC_0        ; LSB -> A
    ldx     TIMER_USEC_1        ; byte 1 -> X
    rts                         ; Retorna en sreg:X:A (byte3:byte2:byte1:byte0)
.endproc

; --------------------------------------------
; delay_us - Delay en microsegundos
; Entrada: uint16_t us en X:A
; --------------------------------------------
.proc _delay_us
    ; Guardar parámetro en stack
    sta     ptr1
    stx     ptr1+1
    
    ; Leer tiempo actual
    jsr     _get_micros
    
    ; Calcular target = current + us
    ; sreg:X:A contiene current (32-bit)
    ; ptr1 contiene us (16-bit)
    
    clc
    adc     ptr1                ; A = A + us_low
    sta     delay_target
    
    txa
    adc     ptr1+1              ; X = X + us_high
    sta     delay_target+1
    
    lda     sreg
    adc     #0                  ; Propagate carry
    sta     delay_target+2
    
    lda     sreg+1
    adc     #0
    sta     delay_target+3
    
@wait_loop:
    ; Leer tiempo actual
    jsr     _get_micros
    
    ; get_micros retorna: A=byte0(LSB), X=byte1, sreg=byte2, sreg+1=byte3(MSB)
    ; Comparar con target (32-bit): current >= target?
    
    ; Guardar valores actuales en variable temporal
    sta     current_time        ; current byte 0
    stx     current_time+1      ; current byte 1
    
    ; Comparar byte 3 (MSB) primero
    lda     sreg+1
    cmp     delay_target+3
    bcc     @wait_loop          ; current < target
    bne     @done               ; current > target
    
    ; Byte 3 igual, comparar byte 2
    lda     sreg
    cmp     delay_target+2
    bcc     @wait_loop
    bne     @done
    
    ; Byte 2 igual, comparar byte 1
    lda     current_time+1
    cmp     delay_target+1
    bcc     @wait_loop
    bne     @done
    
    ; Byte 1 igual, comparar byte 0 (LSB)
    lda     current_time
    cmp     delay_target
    bcc     @wait_loop
    
@done:
    rts
.endproc

; --------------------------------------------
; delay_ms - Delay en milisegundos
; Entrada: uint16_t ms en X:A
; Implementación directa con menos overhead
; --------------------------------------------
.proc _delay_ms
    ; Guardar ms
    sta     ptr1
    stx     ptr1+1
    
    ; Si ms == 0, salir
    ora     ptr1+1
    beq     @done
    
    ; Leer tiempo inicial
    jsr     _get_micros
    
    ; Guardar en delay_target (bytes 0-3)
    sta     delay_target
    stx     delay_target+1
    lda     sreg
    sta     delay_target+2
    lda     sreg+1
    sta     delay_target+3
    
@add_1ms:
    ; Sumar 1000 ($03E8) microsegundos al target
    lda     delay_target
    clc
    adc     #$E8            ; Low byte de 1000
    sta     delay_target
    lda     delay_target+1
    adc     #$03            ; High byte de 1000
    sta     delay_target+1
    lda     delay_target+2
    adc     #0
    sta     delay_target+2
    lda     delay_target+3
    adc     #0
    sta     delay_target+3
    
    ; Decrementar contador ms
    lda     ptr1
    bne     @no_borrow
    dec     ptr1+1
@no_borrow:
    dec     ptr1
    
    ; Verificar si quedan ms por procesar
    lda     ptr1
    ora     ptr1+1
    bne     @add_1ms
    
@wait_loop:
    ; Leer tiempo actual
    jsr     _get_micros
    
    ; Guardar valores actuales
    sta     current_time
    stx     current_time+1
    
    ; Comparar byte 3 (MSB) primero
    lda     sreg+1
    cmp     delay_target+3
    bcc     @wait_loop
    bne     @done
    
    ; Byte 3 igual, comparar byte 2
    lda     sreg
    cmp     delay_target+2
    bcc     @wait_loop
    bne     @done
    
    ; Byte 2 igual, comparar byte 1
    lda     current_time+1
    cmp     delay_target+1
    bcc     @wait_loop
    bne     @done
    
    ; Byte 1 igual, comparar byte 0 (LSB)
    lda     current_time
    cmp     delay_target
    bcc     @wait_loop
    
@done:
    rts
.endproc
