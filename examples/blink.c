/**
 * Ejemplo de uso de la libreria timer
 * 
 * Compilar con cc65:
 *   ca65 -t none -o timer.o ../src/timer.s
 *   cl65 -t none -I../src -c -o blink.o blink.c
 *   ld65 -C tu_config.cfg -o blink.bin blink.o timer.o none.lib
 */

#include <stdint.h>
#include "timer.h"

/* LED en puerto $C001 */
#define LED (*(volatile uint8_t*)0xC001)

int main(void) {
    uint32_t last_ms;
    uint8_t led_state = 0;
    
    /* Inicializar timer */
    timer_init();
    
    last_ms = get_millis();
    
    while (1) {
        /* Parpadeo cada 500ms usando get_millis() */
        if (get_millis() - last_ms >= 500) {
            last_ms = get_millis();
            led_state ^= 0x01;
            LED = led_state;
        }
    }
    
    return 0;
}
