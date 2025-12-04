# Timer Library for 6502 (cc65)

Librería de temporización precisa para procesadores 6502 usando el compilador cc65.

## Características

- **Delays precisos**: `delay_us()`, `delay_ms()`, `delay_seconds()`
- **Contadores de tiempo**: `get_ticks()`, `get_micros()`, `get_millis()`
- **Timer programable**: One-shot y periódico con IRQ
- **Timeout no bloqueante**: `timeout_start_ms()`, `timeout_expired()`
- **Cronómetro**: `stopwatch_start()`, `stopwatch_read_ms()`

## Hardware Requerido

Incluye módulo VHDL `timer_rtc.vhd` para FPGA.

**Mapa de registros** ($C030-$C03F):
| Dirección | Registro | Descripción |
|-----------|----------|-------------|
| $C030-$C033 | TICK_0-3 | Contador de ticks (32-bit, solo lectura) |
| $C034 | TIMER_LO | Timer countdown byte bajo |
| $C035 | TIMER_HI | Timer countdown byte alto |
| $C036 | TIMER_CTL | Control del timer |
| $C037 | PRESCALER | División del clock |
| $C038-$C03B | USEC_0-3 | Contador microsegundos (32-bit) |
| $C03C | LATCH_CTL | Control de latch/reset |

## Instalación

1. Copiar `src/timer.h` y `src/timer.c` a tu proyecto
2. Incluir en tu código:
```c
#include "timer.h"
```
3. Agregar `timer.c` al Makefile

## Uso Básico

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

## Especificaciones

- **Clock**: 6.75 MHz (configurable en VHDL)
- **Precisión**: ~4% (7 ticks/µs vs 6.75 ideal)
- **Rango USEC**: 32-bit (~71 minutos antes de overflow)
- **Timer countdown**: 16-bit con prescaler 8-bit

## VHDL

El archivo `vhdl/timer_rtc.vhd` implementa el hardware del timer para FPGA.

### Instanciación

```vhdl
timer_inst : entity work.timer_rtc
    generic map (
        CLK_FREQ => 6_750_000
    )
    port map (
        clk      => clk,
        rst_n    => rst_n,
        cs       => timer_cs,
        addr     => addr(3 downto 0),
        rd       => rd,
        wr       => wr,
        data_in  => data_in,
        data_out => timer_data_out,
        timer_irq => timer_irq
    );
```

## Notas para cc65

**IMPORTANTE**: No usar variables estáticas inicializadas en librerías:
```c
// ❌ MAL - va a DATA (ROM, solo lectura)
static uint32_t counter = 0;

// ✅ BIEN - va a BSS (RAM, lectura/escritura)
static uint32_t counter;
```

Las variables sin inicializar van al segmento BSS (RAM), mientras que las inicializadas van a DATA (ROM). Inicializar en `timer_init()`.

## Licencia

MIT License

## Autor

Desarrollado para proyectos fpga-6502.
