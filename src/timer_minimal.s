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
    lda     TIMER_USEC_0        ; LSB
    ldx     TIMER_USEC_1
    sta     sreg                ; sreg = low word
    stx     sreg+1
    
    lda     TIMER_USEC_2        ; MSB
    ldx     TIMER_USEC_3
    rts                         ; Retorna en sreg:X:A
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
    
    ; Guardar valores actuales
    sta     ptr1                ; current byte 0
    stx     ptr1+1              ; current byte 1
    
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
    lda     ptr1+1
    cmp     delay_target+1
    bcc     @wait_loop
    bne     @done
    
    ; Byte 1 igual, comparar byte 0 (LSB)
    lda     ptr1
    cmp     delay_target
    bcc     @wait_loop
    
@done:
    rts
.endproc

; --------------------------------------------
; delay_ms - Delay en milisegundos
; Entrada: uint16_t ms en X:A
; Implementación: ms * 1000 = us
; --------------------------------------------
.proc _delay_ms
    ; Guardar ms
    sta     ptr1
    stx     ptr1+1
    
    ; Si ms == 0, salir
    ora     ptr1+1
    beq     @done
    
@ms_loop:
    ; delay_us(1000)
    lda     #<1000
    ldx     #>1000
    jsr     _delay_us
    
    ; Decrementar contador ms
    lda     ptr1
    bne     @dec_low
    dec     ptr1+1
@dec_low:
    dec     ptr1
    
    ; Verificar si terminamos
    lda     ptr1
    ora     ptr1+1
    bne     @ms_loop
    
@done:
    rts
.endproc
