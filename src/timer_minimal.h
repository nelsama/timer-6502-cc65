/**
 * TIMER_MINIMAL.H - Header minimalista para timer-6502-cc65
 * 
 * Versión compacta con solo 3 funciones esenciales:
 *   - get_micros() - Leer microsegundos (32-bit)
 *   - delay_us()   - Delay en microsegundos
 *   - delay_ms()   - Delay en milisegundos
 * 
 * Uso:
 *   #include "timer_minimal.h"
 *   Compilar con: timer_minimal.s (~150 bytes)
 * 
 * Para funcionalidad completa (26 funciones), usar timer.h + timer.s
 * 
 * Hardware: timer_rtc.vhd @ 6.75 MHz
 */

#ifndef TIMER_MINIMAL_H
#define TIMER_MINIMAL_H

#include <stdint.h>

/* ============================================
 * REGISTROS HARDWARE (referencia)
 * ============================================ */

#define TIMER_BASE          0xC030

/* Registros de microsegundos */
#define TIMER_USEC_0        (*(volatile uint8_t *)(TIMER_BASE + 0x08))
#define TIMER_USEC_1        (*(volatile uint8_t *)(TIMER_BASE + 0x09))
#define TIMER_USEC_2        (*(volatile uint8_t *)(TIMER_BASE + 0x0A))
#define TIMER_USEC_3        (*(volatile uint8_t *)(TIMER_BASE + 0x0B))
#define TIMER_LATCH_CTL     (*(volatile uint8_t *)(TIMER_BASE + 0x0C))

/* Comando latch */
#define LATCH_USEC          0x02

/* ============================================
 * FUNCIONES DISPONIBLES
 * ============================================ */

/**
 * Obtener contador de microsegundos (32-bit)
 * @return Microsegundos desde el reset o último reset_micros()
 */
uint32_t get_micros(void);

/**
 * Delay en microsegundos (bloqueante)
 * @param us Microsegundos a esperar (0-65535)
 */
void delay_us(uint16_t us);

/**
 * Delay en milisegundos (bloqueante)
 * @param ms Milisegundos a esperar (0-65535)
 */
void delay_ms(uint16_t ms);

/* ============================================
 * NOTAS
 * ============================================ */

/*
 * Esta es una versión reducida. Para funciones adicionales
 * como timeouts, cronómetros, timer programable e IRQ,
 * usar timer.h + timer.s (versión completa).
 * 
 * Ejemplo de medición de tiempo:
 *   uint32_t start = get_micros();
 *   // ... código a medir ...
 *   uint32_t elapsed = get_micros() - start;
 * 
 * Delay simple:
 *   delay_ms(100);  // Esperar 100ms
 */

#endif /* TIMER_MINIMAL_H */
