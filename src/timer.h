/**
 * TIMER.H - Librería Timer/RTC para 6502 compatible con cc65
 * 
 * Hardware: timer_rtc.vhd @ 6.75 MHz
 * 
 * Mapa de registros ($C030-$C03F):
 *   $C030 - TICK_0    (R)   Contador ticks byte 0 (LSB)
 *   $C031 - TICK_1    (R)   Contador ticks byte 1
 *   $C032 - TICK_2    (R)   Contador ticks byte 2
 *   $C033 - TICK_3    (R)   Contador ticks byte 3 (MSB)
 *   $C034 - TIMER_LO  (R/W) Timer countdown low byte
 *   $C035 - TIMER_HI  (R/W) Timer countdown high byte
 *   $C036 - TIMER_CTL (R/W) Timer control
 *   $C037 - PRESCALER (R/W) Prescaler (divide clock)
 *   $C038 - USEC_0    (R)   Microsegundos byte 0 (LSB)
 *   $C039 - USEC_1    (R)   Microsegundos byte 1
 *   $C03A - USEC_2    (R)   Microsegundos byte 2
 *   $C03B - USEC_3    (R)   Microsegundos byte 3 (MSB)
 *   $C03C - LATCH_CTL (W)   Latch control
 */

#ifndef TIMER_H
#define TIMER_H

#include <stdint.h>

/* ============================================
 * REGISTROS HARDWARE
 * ============================================ */

#define TIMER_BASE          0xC030

/* Registros individuales */
#define TIMER_TICK_0        (*(volatile uint8_t *)(TIMER_BASE + 0x00))
#define TIMER_TICK_1        (*(volatile uint8_t *)(TIMER_BASE + 0x01))
#define TIMER_TICK_2        (*(volatile uint8_t *)(TIMER_BASE + 0x02))
#define TIMER_TICK_3        (*(volatile uint8_t *)(TIMER_BASE + 0x03))
#define TIMER_LO            (*(volatile uint8_t *)(TIMER_BASE + 0x04))
#define TIMER_HI            (*(volatile uint8_t *)(TIMER_BASE + 0x05))
#define TIMER_CTL           (*(volatile uint8_t *)(TIMER_BASE + 0x06))
#define TIMER_PRESCALER     (*(volatile uint8_t *)(TIMER_BASE + 0x07))
#define TIMER_USEC_0        (*(volatile uint8_t *)(TIMER_BASE + 0x08))
#define TIMER_USEC_1        (*(volatile uint8_t *)(TIMER_BASE + 0x09))
#define TIMER_USEC_2        (*(volatile uint8_t *)(TIMER_BASE + 0x0A))
#define TIMER_USEC_3        (*(volatile uint8_t *)(TIMER_BASE + 0x0B))
#define TIMER_LATCH_CTL     (*(volatile uint8_t *)(TIMER_BASE + 0x0C))

/* ============================================
 * BITS DE CONTROL (TIMER_CTL $C036)
 * ============================================ */

#define TIMER_EN            0x01    /* Bit 0: Enable timer countdown */
#define TIMER_IRQ_EN        0x02    /* Bit 1: Enable IRQ on timer=0 */
#define TIMER_REPEAT        0x04    /* Bit 2: Auto-reload timer */
#define TIMER_IRQ_FLAG      0x08    /* Bit 3: IRQ pending (write 1 to clear) */
#define TIMER_ZERO          0x80    /* Bit 7: Timer reached zero */

/* ============================================
 * COMANDOS LATCH (TIMER_LATCH_CTL $C03C)
 * ============================================ */

#define LATCH_TICK          0x01    /* Capturar contador TICK */
#define LATCH_USEC          0x02    /* Capturar contador USEC */
#define LATCH_ALL           0x03    /* Capturar ambos */
#define RESET_USEC          0x40    /* Resetear contador USEC */
#define RESET_TICK          0x80    /* Resetear contador TICK */

/* ============================================
 * CONSTANTES DE TIEMPO
 * ============================================ */

/* Clock del sistema: 6.75 MHz */
#define TIMER_CLOCK_HZ      6750000UL
#define TICKS_PER_US        7       /* ~6.75 ticks/us, redondeado */
#define TICKS_PER_MS        6750UL  /* ticks por milisegundo */

/* ============================================
 * FUNCIONES DE INICIALIZACIÓN
 * ============================================ */

/**
 * Inicializar el módulo timer
 * Resetea contadores y deshabilita interrupciones
 */
void timer_init(void);

/* ============================================
 * FUNCIONES DE DELAY (BLOQUEO)
 * ============================================ */

/**
 * Delay en microsegundos (bloqueante)
 * @param us Microsegundos a esperar (max ~65535)
 */
void delay_us(uint16_t us);

/**
 * Delay en milisegundos (bloqueante)
 * @param ms Milisegundos a esperar
 */
void delay_ms(uint16_t ms);

/**
 * Delay en segundos (bloqueante)
 * @param seconds Segundos a esperar (max 65535)
 */
void delay_seconds(uint16_t seconds);

/* ============================================
 * FUNCIONES DE TICK/TIEMPO
 * ============================================ */

/**
 * Obtener contador de ticks del sistema (32-bit)
 * @return Número de ticks desde el reset
 */
uint32_t get_ticks(void);

/**
 * Obtener contador de microsegundos (32-bit)
 * @return Microsegundos desde el reset
 */
uint32_t get_micros(void);

/**
 * Obtener milisegundos transcurridos
 * @return Milisegundos desde el reset
 */
uint32_t get_millis(void);

/**
 * Resetear el contador de ticks
 */
void reset_ticks(void);

/**
 * Resetear el contador de microsegundos
 */
void reset_micros(void);

/* ============================================
 * FUNCIONES DE TIMER PROGRAMABLE
 * ============================================ */

/**
 * Configurar timer one-shot (disparo único)
 * @param ticks Número de ticks para el countdown
 * @param prescaler División adicional del clock (0-255)
 */
void timer_set_oneshot(uint16_t ticks, uint8_t prescaler);

/**
 * Configurar timer periódico (auto-reload)
 * @param ticks Número de ticks para el periodo
 * @param prescaler División adicional del clock (0-255)
 */
void timer_set_periodic(uint16_t ticks, uint8_t prescaler);

/**
 * Configurar timer en milisegundos (one-shot)
 * @param ms Milisegundos para el timeout
 */
void timer_set_ms(uint16_t ms);

/**
 * Iniciar el timer
 */
void timer_start(void);

/**
 * Detener el timer
 */
void timer_stop(void);

/**
 * Verificar si el timer llegó a cero
 * @return 1 si expiró, 0 si no
 */
uint8_t timer_expired(void);

/**
 * Limpiar flag de expiración
 */
void timer_clear_flag(void);

/**
 * Leer valor actual del countdown
 * @return Valor actual del timer (16-bit)
 */
uint16_t timer_read(void);

/* ============================================
 * FUNCIONES DE IRQ
 * ============================================ */

/**
 * Habilitar IRQ del timer
 */
void timer_enable_irq(void);

/**
 * Deshabilitar IRQ del timer
 */
void timer_disable_irq(void);

/**
 * Verificar si hay IRQ pendiente
 * @return 1 si hay IRQ pendiente, 0 si no
 */
uint8_t timer_irq_pending(void);

/**
 * Limpiar flag de IRQ
 */
void timer_clear_irq(void);

/* ============================================
 * FUNCIONES DE TIMEOUT
 * ============================================ */

/**
 * Iniciar un timeout (no bloqueante)
 * @param timeout_us Tiempo de espera en microsegundos
 */
void timeout_start_us(uint32_t timeout_us);

/**
 * Iniciar un timeout en milisegundos
 * @param timeout_ms Tiempo de espera en milisegundos
 */
void timeout_start_ms(uint16_t timeout_ms);

/**
 * Verificar si el timeout expiró
 * @return 1 si expiró, 0 si aún no
 */
uint8_t timeout_expired(void);

/* ============================================
 * FUNCIONES DE MEDICIÓN DE TIEMPO
 * ============================================ */

/**
 * Iniciar cronómetro
 */
void stopwatch_start(void);

/**
 * Leer tiempo del cronómetro en microsegundos
 * @return Microsegundos desde stopwatch_start()
 */
uint32_t stopwatch_read_us(void);

/**
 * Leer tiempo del cronómetro en milisegundos
 * @return Milisegundos desde stopwatch_start()
 */
uint16_t stopwatch_read_ms(void);

#endif /* TIMER_H */
