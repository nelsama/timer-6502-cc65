/**
 * TIMER.C - Implementación Timer/RTC para 6502
 * 
 * Hardware: timer_rtc.vhd @ 6.75 MHz
 * Compilador: cc65 (C89)
 * 
 * IMPORTANTE: No usar variables estáticas inicializadas
 * ya que van al segmento DATA (ROM, solo lectura).
 * Usar variables sin inicializar (BSS) y establecer
 * valores en funciones init.
 */

#include "timer.h"

/* ============================================
 * VARIABLES INTERNAS (BSS - sin inicializar)
 * ============================================ */

/* Variables para timeout no bloqueante */
static uint32_t timeout_target;

/* Variables para cronómetro */
static uint32_t stopwatch_base;

/* ============================================
 * FUNCIONES DE INICIALIZACIÓN
 * ============================================ */

void timer_init(void)
{
    /* Inicializar variables internas */
    timeout_target = 0;
    stopwatch_base = 0;
    
    /* Resetear contadores de microsegundos y ticks */
    TIMER_LATCH_CTL = RESET_USEC | RESET_TICK;
    
    /* Detener timer countdown */
    TIMER_CTL = 0x00;
}

/* ============================================
 * FUNCIONES DE DELAY (BLOQUEANTE)
 * Usa el contador de microsegundos del hardware
 * Precision: ~4% (7 ticks/us vs 6.75 ideal)
 * ============================================ */

void delay_us(uint16_t us)
{
    uint32_t start;
    uint32_t target;
    uint32_t current;
    
    if (us == 0) return;
    
    /* Leer tiempo inicial */
    TIMER_LATCH_CTL = LATCH_USEC;
    start = (uint32_t)TIMER_USEC_0;
    start |= ((uint32_t)TIMER_USEC_1 << 8);
    start |= ((uint32_t)TIMER_USEC_2 << 16);
    start |= ((uint32_t)TIMER_USEC_3 << 24);
    
    target = start + (uint32_t)us;
    
    /* Esperar hasta alcanzar target */
    do {
        TIMER_LATCH_CTL = LATCH_USEC;
        current = (uint32_t)TIMER_USEC_0;
        current |= ((uint32_t)TIMER_USEC_1 << 8);
        current |= ((uint32_t)TIMER_USEC_2 << 16);
        current |= ((uint32_t)TIMER_USEC_3 << 24);
    } while (current < target);
}

void delay_ms(uint16_t ms)
{
    uint32_t start;
    uint32_t target;
    uint32_t current;
    
    if (ms == 0) return;
    
    /* Leer tiempo inicial */
    TIMER_LATCH_CTL = LATCH_USEC;
    start = (uint32_t)TIMER_USEC_0;
    start |= ((uint32_t)TIMER_USEC_1 << 8);
    start |= ((uint32_t)TIMER_USEC_2 << 16);
    start |= ((uint32_t)TIMER_USEC_3 << 24);
    
    target = start + ((uint32_t)ms * 1000UL);
    
    /* Esperar hasta alcanzar target */
    do {
        TIMER_LATCH_CTL = LATCH_USEC;
        current = (uint32_t)TIMER_USEC_0;
        current |= ((uint32_t)TIMER_USEC_1 << 8);
        current |= ((uint32_t)TIMER_USEC_2 << 16);
        current |= ((uint32_t)TIMER_USEC_3 << 24);
    } while (current < target);
}

void delay_seconds(uint16_t seconds)
{
    while (seconds > 0) {
        delay_ms(1000);
        --seconds;
    }
}

/* ============================================
 * FUNCIONES DE TICK/TIEMPO
 * ============================================ */

uint32_t get_ticks(void)
{
    uint32_t ticks;
    
    /* Latch para captura atómica */
    TIMER_LATCH_CTL = LATCH_TICK;
    
    ticks = (uint32_t)TIMER_TICK_0;
    ticks |= ((uint32_t)TIMER_TICK_1 << 8);
    ticks |= ((uint32_t)TIMER_TICK_2 << 16);
    ticks |= ((uint32_t)TIMER_TICK_3 << 24);
    
    return ticks;
}

uint32_t get_micros(void)
{
    uint32_t usec;
    
    /* Latch para captura atómica */
    TIMER_LATCH_CTL = LATCH_USEC;
    
    usec = (uint32_t)TIMER_USEC_0;
    usec |= ((uint32_t)TIMER_USEC_1 << 8);
    usec |= ((uint32_t)TIMER_USEC_2 << 16);
    usec |= ((uint32_t)TIMER_USEC_3 << 24);
    
    return usec;
}

uint32_t get_millis(void)
{
    uint32_t usec;
    usec = get_micros();
    return usec / 1000UL;
}

void reset_ticks(void)
{
    TIMER_LATCH_CTL = RESET_TICK;
}

void reset_micros(void)
{
    TIMER_LATCH_CTL = RESET_USEC;
}

/* ============================================
 * FUNCIONES DE TIMER PROGRAMABLE
 * ============================================ */

void timer_set_oneshot(uint16_t ticks, uint8_t prescaler)
{
    /* Detener timer primero */
    TIMER_CTL = 0x00;
    
    /* Configurar prescaler */
    TIMER_PRESCALER = prescaler;
    
    /* Cargar valor (escribir LO primero, luego HI) */
    TIMER_LO = (uint8_t)(ticks & 0xFF);
    TIMER_HI = (uint8_t)((ticks >> 8) & 0xFF);
    
    /* Limpiar flags */
    TIMER_CTL = TIMER_IRQ_FLAG;
    TIMER_CTL = 0x00;
}

void timer_set_periodic(uint16_t ticks, uint8_t prescaler)
{
    /* Detener timer primero */
    TIMER_CTL = 0x00;
    
    /* Configurar prescaler */
    TIMER_PRESCALER = prescaler;
    
    /* Cargar valor */
    TIMER_LO = (uint8_t)(ticks & 0xFF);
    TIMER_HI = (uint8_t)((ticks >> 8) & 0xFF);
    
    /* Limpiar flags y configurar repeat */
    TIMER_CTL = TIMER_IRQ_FLAG;
    TIMER_CTL = TIMER_REPEAT;
}

void timer_set_ms(uint16_t ms)
{
    /* Para milisegundos usamos prescaler de 255 
     * Clock efectivo: 6.75 MHz / 256 = ~26.37 kHz
     * Ticks por ms: ~26.37
     * Usamos 26 ticks por ms con prescaler 255
     */
    uint16_t ticks;
    
    if (ms > 2520) {
        /* Límite máximo con este prescaler: ~2520 ms */
        ms = 2520;
    }
    
    ticks = (uint16_t)(ms * 26UL);
    timer_set_oneshot(ticks, 255);
}

void timer_start(void)
{
    uint8_t ctl;
    ctl = TIMER_CTL;
    TIMER_CTL = ctl | TIMER_EN;
}

void timer_stop(void)
{
    uint8_t ctl;
    ctl = TIMER_CTL;
    TIMER_CTL = ctl & ~TIMER_EN;
}

uint8_t timer_expired(void)
{
    return (TIMER_CTL & TIMER_ZERO) ? 1 : 0;
}

void timer_clear_flag(void)
{
    /* Escribir 1 al bit IRQ_FLAG para limpiar */
    TIMER_CTL = TIMER_IRQ_FLAG;
}

uint16_t timer_read(void)
{
    uint16_t val;
    val = (uint16_t)TIMER_LO;
    val |= ((uint16_t)TIMER_HI << 8);
    return val;
}

/* ============================================
 * FUNCIONES DE IRQ
 * ============================================ */

void timer_enable_irq(void)
{
    uint8_t ctl;
    ctl = TIMER_CTL;
    TIMER_CTL = ctl | TIMER_IRQ_EN;
}

void timer_disable_irq(void)
{
    uint8_t ctl;
    ctl = TIMER_CTL;
    TIMER_CTL = ctl & ~TIMER_IRQ_EN;
}

uint8_t timer_irq_pending(void)
{
    return (TIMER_CTL & TIMER_IRQ_FLAG) ? 1 : 0;
}

void timer_clear_irq(void)
{
    TIMER_CTL = TIMER_IRQ_FLAG;
}

/* ============================================
 * FUNCIONES DE TIMEOUT (NO BLOQUEANTE)
 * ============================================ */

void timeout_start_us(uint32_t timeout_us)
{
    timeout_target = get_micros() + timeout_us;
}

void timeout_start_ms(uint16_t timeout_ms)
{
    timeout_start_us((uint32_t)timeout_ms * 1000UL);
}

uint8_t timeout_expired(void)
{
    return (get_micros() >= timeout_target) ? 1 : 0;
}

/* ============================================
 * FUNCIONES DE CRONÓMETRO
 * ============================================ */

void stopwatch_start(void)
{
    stopwatch_base = get_micros();
}

uint32_t stopwatch_read_us(void)
{
    return get_micros() - stopwatch_base;
}

uint16_t stopwatch_read_ms(void)
{
    uint32_t elapsed;
    elapsed = stopwatch_read_us();
    return (uint16_t)(elapsed / 1000UL);
}
