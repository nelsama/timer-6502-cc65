# Makefile de ejemplo para timer-6502-cc65
# Ajustar paths segun tu proyecto

CC65 = cc65
CA65 = ca65
LD65 = ld65
CL65 = cl65

# Directorio de la libreria timer
TIMER_DIR = ../src

# Tu archivo de configuracion del linker
CONFIG = tu_config.cfg

# Libreria de cc65
PLATFORM_LIB = none.lib

# Archivos
TARGET = blink.bin
MAIN_OBJ = blink.o
TIMER_OBJ = timer.o

OBJS = $(MAIN_OBJ) $(TIMER_OBJ)

all: $(TARGET)

# Compilar main
$(MAIN_OBJ): blink.c
$(CL65) -t none -I$(TIMER_DIR) -c -o $@ $<

# Ensamblar timer (version ASM optimizada)
$(TIMER_OBJ): $(TIMER_DIR)/timer.s
$(CA65) -t none -o $@ $<

# Enlazar
$(TARGET): $(OBJS)
$(LD65) -C $(CONFIG) -o $@ $(OBJS) $(PLATFORM_LIB)

clean:
rm -f *.o *.bin

.PHONY: all clean
