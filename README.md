# Timer Library for 6502 (cc65)

Libreria de temporizacion precisa para procesadores 6502 usando el compilador cc65.

## v2.0 - Optimizacion ASM

**NUEVO**: Implementacion en ensamblador optimizado a mano.

| Version | Implementacion | Tamano CODE |
|---------|----------------|-------------|
| v1.x | C (timer.c) | ~1,375 bytes |
| **v2.0** | **ASM (timer.s)** | **~626 bytes** |

**Reduccion: 54% menos codigo**

## Caracteristicas

- **Delays precisos**: delay_us(), delay_ms(), delay_seconds()
- **Contadores de tiempo**: get_ticks(), get_micros(), get_millis()
- **Timer programable**: One-shot y periodico con IRQ
- **Timeout no bloqueante**: timeout_start_ms(), timeout_expired()
- **Cronometro**: stopwatch_start(), stopwatch_read_ms()
- **100% compatible**: Misma interfaz C (timer.h sin cambios)

## Archivos

| Archivo | Descripcion |
|---------|-------------|
| `src/timer.h` | Interfaz C (prototipos y definiciones) |
| `src/timer.s` | Implementacion en ensamblador 6502 |

## Hardware Requerido

Esta libreria requiere un modulo de timer en hardware con el siguiente mapa de memoria:

### Mapa de Registros (0xC030-0xC03F)

| Direccion | Registro | R/W | Descripcion |
|-----------|----------|-----|-------------|
| 0xC030 | TICK_0 | R | Contador de ticks byte 0 (LSB) |
| 0xC031 | TICK_1 | R | Contador de ticks byte 1 |
| 0xC032 | TICK_2 | R | Contador de ticks byte 2 |
| 0xC033 | TICK_3 | R | Contador de ticks byte 3 (MSB) |
| 0xC034 | TIMER_LO | R/W | Timer countdown byte bajo |
| 0xC035 | TIMER_HI | R/W | Timer countdown byte alto |
| 0xC036 | TIMER_CTL | R/W | Control del timer |
| 0xC037 | PRESCALER | R/W | Division del clock (0-255) |
| 0xC038 | USEC_0 | R | Microsegundos byte 0 (LSB) |
| 0xC039 | USEC_1 | R | Microsegundos byte 1 |
| 0xC03A | USEC_2 | R | Microsegundos byte 2 |
| 0xC03B | USEC_3 | R | Microsegundos byte 3 (MSB) |
| 0xC03C | LATCH_CTL | W | Control de latch/reset |

### Bits de Control (TIMER_CTL 0xC036)

| Bit | Nombre | Descripcion |
|-----|--------|-------------|
| 0 | TIMER_EN | Habilitar countdown |
| 1 | TIMER_IRQ_EN | Habilitar IRQ cuando timer=0 |
| 2 | TIMER_REPEAT | Auto-reload (modo periodico) |
| 3 | TIMER_IRQ_FLAG | IRQ pendiente (escribir 1 para limpiar) |
| 7 | TIMER_ZERO | Timer llego a cero |

### Comandos Latch (LATCH_CTL 0xC03C)

| Valor | Accion |
|-------|--------|
| 0x01 | Capturar contador TICK |
| 0x02 | Capturar contador USEC |
| 0x03 | Capturar ambos |
| 0x40 | Resetear contador USEC |
| 0x80 | Resetear contador TICK |

## Instalacion

1. Copiar `src/timer.h` y `src/timer.s` a tu proyecto (ej: `libs/timer/`)

2. Incluir en tu codigo:

```c
#include "timer.h"
```

## Configuracion del Makefile

### Variables requeridas

```makefile
# Directorio de la libreria
TIMER_DIR = libs/timer

# Agregar a includes
INCLUDES = -I$(TIMER_DIR)

# Objeto de timer
TIMER_OBJ = $(BUILD_DIR)/timer.o

# Agregar a lista de objetos
OBJS = $(MAIN_OBJ) $(TIMER_OBJ) $(OTHER_OBJS)
```

### Regla de compilacion (ASM)

```makefile
# Timer (version ASM optimizada)
$(TIMER_OBJ): $(TIMER_DIR)/timer.s
$(CA65) -t none -o $@ $<
```

## Uso Basico

```c
#include "timer.h"

int main(void) {
    timer_init();
    
    while (1) {
        delay_ms(1000);  // Esperar 1 segundo
        
        // O usar timeout no bloqueante
        timeout_start_ms(500);
        while (!timeout_expired()) {
            // Hacer otras cosas...
        }
    }
}
```

## API Reference

### Inicializacion
- `void timer_init(void)` - Inicializa el timer, resetea contadores

### Delays (bloqueantes)
- `void delay_us(uint16_t us)` - Delay en microsegundos
- `void delay_ms(uint16_t ms)` - Delay en milisegundos
- `void delay_seconds(uint16_t s)` - Delay en segundos

### Contadores de tiempo
- `uint32_t get_ticks(void)` - Ticks desde reset
- `uint32_t get_micros(void)` - Microsegundos desde reset
- `uint32_t get_millis(void)` - Milisegundos desde reset
- `void reset_ticks(void)` - Resetear contador ticks
- `void reset_micros(void)` - Resetear contador microsegundos

### Timer programable
- `void timer_set_oneshot(uint16_t ticks, uint8_t prescaler)` - Timer unico
- `void timer_set_periodic(uint16_t ticks, uint8_t prescaler)` - Timer repetitivo
- `void timer_set_ms(uint16_t ms)` - Timer en milisegundos
- `void timer_start(void)` - Iniciar timer
- `void timer_stop(void)` - Detener timer
- `uint8_t timer_expired(void)` - Timer expiro?
- `uint16_t timer_read(void)` - Leer valor actual

### IRQ
- `void timer_enable_irq(void)` - Habilitar IRQ
- `void timer_disable_irq(void)` - Deshabilitar IRQ
- `uint8_t timer_irq_pending(void)` - IRQ pendiente?
- `void timer_clear_irq(void)` - Limpiar flag IRQ

### Timeout (no bloqueante)
- `void timeout_start_us(uint32_t us)` - Iniciar timeout
- `void timeout_start_ms(uint16_t ms)` - Iniciar timeout
- `uint8_t timeout_expired(void)` - Timeout expiro?

### Cronometro
- `void stopwatch_start(void)` - Iniciar cronometro
- `uint32_t stopwatch_read_us(void)` - Leer en microsegundos
- `uint16_t stopwatch_read_ms(void)` - Leer en milisegundos

## Especificaciones

- **Clock esperado**: 6.75 MHz
- **Precision USEC**: ~4% (7 ticks/us vs 6.75 ideal)
- **Rango USEC**: 32-bit (~71 minutos antes de overflow)
- **Timer countdown**: 16-bit con prescaler 8-bit
- **Implementacion**: Ensamblador 6502 optimizado

## Configuracion de direccion base

Si tu hardware usa una direccion base diferente a 0xC030, modifica en `timer.h`:

```c
#define TIMER_BASE  0xC030  // Cambiar segun tu hardware
```

## Licencia

MIT License
