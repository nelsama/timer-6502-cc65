;
; TIMER.S - Librería Timer/RTC para 6502 (versión ASM optimizada)
;
; Hardware: timer_rtc.vhd @ 6.75 MHz
; Compatible con timer.h (misma interfaz C)
;
; Reducción estimada: ~65% respecto a versión C
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

TIMER_TICK_0    = TIMER_BASE + $00
TIMER_TICK_1    = TIMER_BASE + $01
TIMER_TICK_2    = TIMER_BASE + $02
TIMER_TICK_3    = TIMER_BASE + $03
TIMER_LO        = TIMER_BASE + $04
TIMER_HI        = TIMER_BASE + $05
TIMER_CTL       = TIMER_BASE + $06
TIMER_PRESCALER = TIMER_BASE + $07
TIMER_USEC_0    = TIMER_BASE + $08
TIMER_USEC_1    = TIMER_BASE + $09
TIMER_USEC_2    = TIMER_BASE + $0A
TIMER_USEC_3    = TIMER_BASE + $0B
TIMER_LATCH_CTL = TIMER_BASE + $0C

; Bits de control
TIMER_EN        = $01
TIMER_IRQ_EN    = $02
TIMER_REPEAT    = $04
TIMER_IRQ_FLAG  = $08
TIMER_ZERO      = $80

; Comandos latch
LATCH_TICK      = $01
LATCH_USEC      = $02
RESET_USEC      = $40
RESET_TICK      = $80

; ============================================
; EXPORTS (funciones públicas)
; ============================================

    .export     _timer_init
    .export     _delay_us
    .export     _delay_ms
    .export     _delay_seconds
    .export     _get_ticks
    .export     _get_micros
    .export     _get_millis
    .export     _reset_ticks
    .export     _reset_micros
    .export     _timer_set_oneshot
    .export     _timer_set_periodic
    .export     _timer_set_ms
    .export     _timer_start
    .export     _timer_stop
    .export     _timer_expired
    .export     _timer_clear_flag
    .export     _timer_read
    .export     _timer_enable_irq
    .export     _timer_disable_irq
    .export     _timer_irq_pending
    .export     _timer_clear_irq
    .export     _timeout_start_us
    .export     _timeout_start_ms
    .export     _timeout_expired
    .export     _stopwatch_start
    .export     _stopwatch_read_us
    .export     _stopwatch_read_ms

; ============================================
; VARIABLES EN DATA
; ============================================

.segment    "DATA"

_timeout_target:    .res 4      ; 32-bit timeout target
_stopwatch_base:    .res 4      ; 32-bit stopwatch base

; ============================================
; VARIABLES TEMPORALES EN ZEROPAGE
; ============================================

.segment    "ZEROPAGE": zeropage

delay_target:       .res 4      ; Target para delays
delay_current:      .res 4      ; Valor actual

; ============================================
; CÓDIGO
; ============================================

.segment    "CODE"

; ---------------------------------------------------------------
; void timer_init(void)
; Resetea contadores y deshabilita timer
; ---------------------------------------------------------------
.proc _timer_init
    lda     #(RESET_USEC | RESET_TICK)
    sta     TIMER_LATCH_CTL
    lda     #$00
    sta     TIMER_CTL
    rts
.endproc

; ---------------------------------------------------------------
; void delay_us(uint16_t us)
; Delay en microsegundos - parámetro en A/X
; ---------------------------------------------------------------
.proc _delay_us
    ; A = low byte, X = high byte del parámetro
    stx     tmp1            ; Guardar high byte
    ora     tmp1            ; us == 0?
    beq     @done
    
    ; Latch y leer tiempo inicial
    lda     #LATCH_USEC
    sta     TIMER_LATCH_CTL
    
    ; Leer microsegundos actuales a delay_current
    lda     TIMER_USEC_0
    sta     delay_current
    lda     TIMER_USEC_1
    sta     delay_current+1
    lda     TIMER_USEC_2
    sta     delay_current+2
    lda     TIMER_USEC_3
    sta     delay_current+3
    
    ; Calcular target = current + us (16-bit add a 32-bit)
    ldy     #0
    lda     (sp),y          ; Recuperar low byte del parámetro
    clc
    adc     delay_current
    sta     delay_target
    iny
    lda     (sp),y          ; High byte
    adc     delay_current+1
    sta     delay_target+1
    lda     #0
    adc     delay_current+2
    sta     delay_target+2
    lda     #0
    adc     delay_current+3
    sta     delay_target+3
    
    ; Restaurar stack (2 bytes del parámetro)
    jsr     incsp2

@wait_loop:
    ; Latch y leer tiempo actual
    lda     #LATCH_USEC
    sta     TIMER_LATCH_CTL
    
    lda     TIMER_USEC_0
    sta     delay_current
    lda     TIMER_USEC_1
    sta     delay_current+1
    lda     TIMER_USEC_2
    sta     delay_current+2
    lda     TIMER_USEC_3
    sta     delay_current+3
    
    ; Comparar: current >= target?
    lda     delay_current+3
    cmp     delay_target+3
    bcc     @wait_loop      ; current < target
    bne     @done           ; current > target
    
    lda     delay_current+2
    cmp     delay_target+2
    bcc     @wait_loop
    bne     @done
    
    lda     delay_current+1
    cmp     delay_target+1
    bcc     @wait_loop
    bne     @done
    
    lda     delay_current
    cmp     delay_target
    bcc     @wait_loop

@done:
    rts
.endproc

; ---------------------------------------------------------------
; void delay_ms(uint16_t ms)
; Delay en milisegundos - usa delay_us internamente
; ---------------------------------------------------------------
.proc _delay_ms
    ; A = low, X = high
    sta     ptr1            ; Guardar contador ms
    stx     ptr1+1
    
@loop:
    ; Verificar si ms == 0
    lda     ptr1
    ora     ptr1+1
    beq     @done
    
    ; delay_us(1000) = $03E8
    lda     #<1000
    ldx     #>1000
    jsr     pushax
    jsr     _delay_us
    
    ; Decrementar ms
    lda     ptr1
    bne     @no_borrow
    dec     ptr1+1
@no_borrow:
    dec     ptr1
    jmp     @loop
    
@done:
    rts
.endproc

; ---------------------------------------------------------------
; void delay_seconds(uint16_t seconds)
; ---------------------------------------------------------------
.proc _delay_seconds
    sta     ptr1
    stx     ptr1+1
    
@loop:
    lda     ptr1
    ora     ptr1+1
    beq     @done
    
    ; delay_ms(1000)
    lda     #<1000
    ldx     #>1000
    jsr     _delay_ms
    
    ; Decrementar
    lda     ptr1
    bne     @no_borrow
    dec     ptr1+1
@no_borrow:
    dec     ptr1
    jmp     @loop
    
@done:
    rts
.endproc

; ---------------------------------------------------------------
; uint32_t get_ticks(void)
; Retorna en A/X/sreg (cc65 convention)
; ---------------------------------------------------------------
.proc _get_ticks
    ; Latch para captura atómica
    lda     #LATCH_TICK
    sta     TIMER_LATCH_CTL
    
    ; Leer 32 bits
    lda     TIMER_TICK_0    ; Byte 0 -> A
    ldx     TIMER_TICK_1    ; Byte 1 -> X
    ldy     TIMER_TICK_2
    sty     sreg            ; Byte 2 -> sreg
    ldy     TIMER_TICK_3
    sty     sreg+1          ; Byte 3 -> sreg+1
    
    rts
.endproc

; ---------------------------------------------------------------
; uint32_t get_micros(void)
; ---------------------------------------------------------------
.proc _get_micros
    lda     #LATCH_USEC
    sta     TIMER_LATCH_CTL
    
    lda     TIMER_USEC_0
    ldx     TIMER_USEC_1
    ldy     TIMER_USEC_2
    sty     sreg
    ldy     TIMER_USEC_3
    sty     sreg+1
    
    rts
.endproc

; ---------------------------------------------------------------
; uint32_t get_millis(void)
; Retorna get_micros() / 1000
; ---------------------------------------------------------------
.proc _get_millis
    jsr     _get_micros
    ; Dividir eax (A/X/sreg) entre 1000
    jsr     pusheax
    lda     #<1000
    ldx     #>1000
    sta     sreg
    lda     #0
    sta     sreg+1
    lda     #<1000
    jmp     tosudiv0ax
.endproc

; ---------------------------------------------------------------
; void reset_ticks(void)
; ---------------------------------------------------------------
.proc _reset_ticks
    lda     #RESET_TICK
    sta     TIMER_LATCH_CTL
    rts
.endproc

; ---------------------------------------------------------------
; void reset_micros(void)
; ---------------------------------------------------------------
.proc _reset_micros
    lda     #RESET_USEC
    sta     TIMER_LATCH_CTL
    rts
.endproc

; ---------------------------------------------------------------
; void timer_set_oneshot(uint16_t ticks, uint8_t prescaler)
; Stack: [prescaler][ticks_lo][ticks_hi]
; ---------------------------------------------------------------
.proc _timer_set_oneshot
    ; A tiene prescaler (pasado en registro)
    sta     TIMER_PRESCALER
    
    ; Detener timer
    lda     #$00
    sta     TIMER_CTL
    
    ; Leer ticks del stack
    ldy     #0
    lda     (sp),y          ; ticks low
    sta     TIMER_LO
    iny
    lda     (sp),y          ; ticks high
    sta     TIMER_HI
    
    ; Limpiar flags
    lda     #TIMER_IRQ_FLAG
    sta     TIMER_CTL
    lda     #$00
    sta     TIMER_CTL
    
    jmp     incsp2
.endproc

; ---------------------------------------------------------------
; void timer_set_periodic(uint16_t ticks, uint8_t prescaler)
; ---------------------------------------------------------------
.proc _timer_set_periodic
    sta     TIMER_PRESCALER
    
    lda     #$00
    sta     TIMER_CTL
    
    ldy     #0
    lda     (sp),y
    sta     TIMER_LO
    iny
    lda     (sp),y
    sta     TIMER_HI
    
    lda     #TIMER_IRQ_FLAG
    sta     TIMER_CTL
    lda     #TIMER_REPEAT
    sta     TIMER_CTL
    
    jmp     incsp2
.endproc

; ---------------------------------------------------------------
; void timer_set_ms(uint16_t ms)
; ticks = ms * 26, prescaler = 255
; ---------------------------------------------------------------
.proc _timer_set_ms
    ; A/X = ms
    ; Limitar a 2520 max
    cpx     #>2520
    bcc     @ok
    bne     @limit
    cmp     #<2520
    bcc     @ok
@limit:
    lda     #<2520
    ldx     #>2520
@ok:
    ; Multiplicar por 26
    ; Guardar ms
    sta     ptr1
    stx     ptr1+1
    
    ; result = ms * 26 = ms * 16 + ms * 8 + ms * 2
    ; Simplificado: ms * 26
    jsr     pushax          ; Push ms
    lda     #26
    ldx     #0
    jsr     tosumul0ax      ; A/X = ms * 26
    
    ; Ahora A/X tiene ticks
    jsr     pushax          ; Push ticks para timer_set_oneshot
    lda     #255            ; prescaler
    jmp     _timer_set_oneshot
.endproc

; ---------------------------------------------------------------
; void timer_start(void)
; ---------------------------------------------------------------
.proc _timer_start
    lda     TIMER_CTL
    ora     #TIMER_EN
    sta     TIMER_CTL
    rts
.endproc

; ---------------------------------------------------------------
; void timer_stop(void)
; ---------------------------------------------------------------
.proc _timer_stop
    lda     TIMER_CTL
    and     #<~TIMER_EN
    sta     TIMER_CTL
    rts
.endproc

; ---------------------------------------------------------------
; uint8_t timer_expired(void)
; ---------------------------------------------------------------
.proc _timer_expired
    lda     TIMER_CTL
    and     #TIMER_ZERO
    beq     @no
    lda     #1
@no:
    ldx     #0
    rts
.endproc

; ---------------------------------------------------------------
; void timer_clear_flag(void)
; ---------------------------------------------------------------
.proc _timer_clear_flag
    lda     #TIMER_IRQ_FLAG
    sta     TIMER_CTL
    rts
.endproc

; ---------------------------------------------------------------
; uint16_t timer_read(void)
; ---------------------------------------------------------------
.proc _timer_read
    lda     TIMER_LO
    ldx     TIMER_HI
    rts
.endproc

; ---------------------------------------------------------------
; void timer_enable_irq(void)
; ---------------------------------------------------------------
.proc _timer_enable_irq
    lda     TIMER_CTL
    ora     #TIMER_IRQ_EN
    sta     TIMER_CTL
    rts
.endproc

; ---------------------------------------------------------------
; void timer_disable_irq(void)
; ---------------------------------------------------------------
.proc _timer_disable_irq
    lda     TIMER_CTL
    and     #<~TIMER_IRQ_EN
    sta     TIMER_CTL
    rts
.endproc

; ---------------------------------------------------------------
; uint8_t timer_irq_pending(void)
; ---------------------------------------------------------------
.proc _timer_irq_pending
    lda     TIMER_CTL
    and     #TIMER_IRQ_FLAG
    beq     @no
    lda     #1
@no:
    ldx     #0
    rts
.endproc

; ---------------------------------------------------------------
; void timer_clear_irq(void)
; ---------------------------------------------------------------
.proc _timer_clear_irq
    lda     #TIMER_IRQ_FLAG
    sta     TIMER_CTL
    rts
.endproc

; ---------------------------------------------------------------
; void timeout_start_us(uint32_t timeout_us)
; timeout_target = get_micros() + timeout_us
; Parámetro en A/X/sreg
; ---------------------------------------------------------------
.proc _timeout_start_us
    ; Guardar parámetro
    sta     delay_target
    stx     delay_target+1
    lda     sreg
    sta     delay_target+2
    lda     sreg+1
    sta     delay_target+3
    
    ; Obtener micros actuales
    jsr     _get_micros
    
    ; Sumar: timeout_target = micros + param
    clc
    adc     delay_target
    sta     _timeout_target
    txa
    adc     delay_target+1
    sta     _timeout_target+1
    lda     sreg
    adc     delay_target+2
    sta     _timeout_target+2
    lda     sreg+1
    adc     delay_target+3
    sta     _timeout_target+3
    
    rts
.endproc

; ---------------------------------------------------------------
; void timeout_start_ms(uint16_t timeout_ms)
; ---------------------------------------------------------------
.proc _timeout_start_ms
    ; A/X = ms, convertir a us (*1000)
    jsr     pushax
    lda     #<1000
    ldx     #>1000
    sta     sreg
    lda     #0
    sta     sreg+1
    lda     #<1000
    jsr     tosumul0ax      ; Resultado en A/X/sreg
    jmp     _timeout_start_us
.endproc

; ---------------------------------------------------------------
; uint8_t timeout_expired(void)
; ---------------------------------------------------------------
.proc _timeout_expired
    jsr     _get_micros
    
    ; Comparar con timeout_target
    ; Si micros >= target, expiró
    
    ; Comparar byte 3
    lda     sreg+1
    cmp     _timeout_target+3
    bcc     @not_expired
    bne     @expired
    
    ; Comparar byte 2
    lda     sreg
    cmp     _timeout_target+2
    bcc     @not_expired
    bne     @expired
    
    ; Comparar byte 1
    cpx     _timeout_target+1
    bcc     @not_expired
    bne     @expired
    
    ; Comparar byte 0
    cmp     _timeout_target
    bcc     @not_expired
    
@expired:
    lda     #1
    ldx     #0
    rts
    
@not_expired:
    lda     #0
    ldx     #0
    rts
.endproc

; ---------------------------------------------------------------
; void stopwatch_start(void)
; ---------------------------------------------------------------
.proc _stopwatch_start
    jsr     _get_micros
    sta     _stopwatch_base
    stx     _stopwatch_base+1
    lda     sreg
    sta     _stopwatch_base+2
    lda     sreg+1
    sta     _stopwatch_base+3
    rts
.endproc

; ---------------------------------------------------------------
; uint32_t stopwatch_read_us(void)
; return get_micros() - stopwatch_base
; ---------------------------------------------------------------
.proc _stopwatch_read_us
    jsr     _get_micros
    
    ; Restar base
    sec
    sbc     _stopwatch_base
    pha                     ; Guardar byte 0
    txa
    sbc     _stopwatch_base+1
    tax                     ; Byte 1 en X
    lda     sreg
    sbc     _stopwatch_base+2
    sta     sreg            ; Byte 2
    lda     sreg+1
    sbc     _stopwatch_base+3
    sta     sreg+1          ; Byte 3
    pla                     ; Recuperar byte 0 en A
    
    rts
.endproc

; ---------------------------------------------------------------
; uint16_t stopwatch_read_ms(void)
; return stopwatch_read_us() / 1000
; ---------------------------------------------------------------
.proc _stopwatch_read_ms
    jsr     _stopwatch_read_us
    jsr     pusheax
    lda     #<1000
    ldx     #>1000
    sta     sreg
    lda     #0
    sta     sreg+1
    lda     #<1000
    jmp     tosudiv0ax
.endproc

