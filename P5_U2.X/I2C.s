#include <xc.inc>
 

TEMP_LCD    EQU 0x71
ADDR_LCD    EQU 0x4E
CONT1       EQU 0x72
CONT2       EQU 0x73

 ; Declaramos estas etiquetas como públicas (exportables)
    GLOBAL I2C_INIT
    GLOBAL LCD_INIT
    GLOBAL LCD_SEND_DATA
    GLOBAL LCD_CMD

PSECT LcdCode, class=CODE, delta=2    
    
; --- INICIALIZACIÓN DE HARDWARE I2C ---
    
I2C_INIT:
    BSF     STATUS, 5       ; --- BANCO 1 ---
    MOVLW   0b00011000      ; RC3 y RC4 como entradas
    IORWF   TRISC, F
    MOVLW   9               ; Velocidad: 100KHz a 4MHz
    MOVWF   SSPADD
    
    MOVLW   0b10000000      ; Slew rate deshabilitado (para 100KHz)
    MOVWF   SSPSTAT
    
    BCF     STATUS, 5       ; --- BANCO 0 ---
    MOVLW   0b00101000      ; Habilitar MSSP como I2C Master
    MOVWF   SSPCON
    RETURN
 
; --- SUBRUTINAS I2C ---
I2C_WAIT:
    ; Esperamos a que la bandera SSPIF se ponga en 1 (terminó la operación)
I2C_W_LP:
    BTFSS   PIR1, 3         ; PIR1, 3 es SSPIF (está en el Banco 0)
    GOTO    I2C_W_LP
    BCF     PIR1, 3         ; Limpiamos la bandera para la próxima vez
    RETURN
    
I2C_INICIA:
    banksel SSPCON2
    BSF     SSPCON2, 0      ; SEN
    BCF     STATUS, 5
    CALL    I2C_WAIT
    RETURN

I2C_TERMINA:
    banksel SSPCON2
    BSF     SSPCON2, 2      ; PEN
    BCF     STATUS, 5
    CALL    I2C_WAIT
    RETURN

I2C_WRITE:
    MOVWF   SSPBUF
    CALL    I2C_WAIT
    RETURN

; --- SUBRUTINAS LCD ---
LCD_CMD:
    MOVWF   TEMP_LCD
    CALL    I2C_INICIA
    MOVLW   ADDR_LCD
    CALL    I2C_WRITE
    
    ; Nibble Superior (Backlight=1, E=1, RW=0, RS=0 -> 0b00001100)
    MOVF    TEMP_LCD, W
    ANDLW   0xF0
    IORLW   0b00001100      
    CALL    I2C_WRITE
    ANDLW   0b11111000      ; E=0
    CALL    I2C_WRITE
    
    ; Nibble Inferior
    SWAPF   TEMP_LCD, W
    ANDLW   0xF0
    IORLW   0b00001100      
    CALL    I2C_WRITE
    ANDLW   0b11111000      ; E=0
    CALL    I2C_WRITE
    
    CALL    I2C_TERMINA
    CALL    DELAY_5MS       ; Tiempo para que el LCD procese el comando
    RETURN
    
LCD_SEND_DATA:
    MOVWF   TEMP_LCD
    CALL    I2C_INICIA
    MOVLW   ADDR_LCD
    CALL    I2C_WRITE
    
    ; Nibble Superior
    MOVF    TEMP_LCD, W
    ANDLW   0xF0
    IORLW   0b00001101      ; Backlight=1, E=1, RW=0, RS=1
    CALL    I2C_WRITE
    ANDLW   0b11111001      ; E=0
    CALL    I2C_WRITE
    
    ; Nibble Inferior
    SWAPF   TEMP_LCD, W
    ANDLW   0xF0
    IORLW   0b00001101      ; Backlight=1, E=1, RW=0, RS=1
    CALL    I2C_WRITE
    ANDLW   0b11111001      ; E=0
    CALL    I2C_WRITE
    
    CALL    I2C_TERMINA
    RETURN

LCD_INIT:
    ; 1. Esperar a que el voltaje del LCD se estabilice al encender
    CALL    DELAY_5MS
    CALL    DELAY_5MS
    CALL    DELAY_5MS
    CALL    DELAY_5MS

    ; 2. Secuencia mágica de reseteo y paso a 4 bits
    MOVLW   0x33
    CALL    LCD_CMD
    MOVLW   0x32            ; Forzar modo 4 bits
    CALL    LCD_CMD

    ; 3. Configurar parámetros del display
    MOVLW   0x28            ; 2 líneas, fuente de 5x8
    CALL    LCD_CMD
    MOVLW   0x0C            ; Prender display, apagar cursor (pon 0x0E si quieres ver el cursor)
    CALL    LCD_CMD
    MOVLW   0x01            ; Limpiar pantalla entera
    CALL    LCD_CMD
    MOVLW   0x06            ; Modo de entrada: incrementar cursor a la derecha
    CALL    LCD_CMD
    RETURN
    
DELAY_5MS:
    MOVLW   13
    MOVWF   CONT2
DELAY_LOOP2:
    MOVLW   255
    MOVWF   CONT1
DELAY_LOOP1:
    DECFSZ  CONT1, F
    GOTO    DELAY_LOOP1
    DECFSZ  CONT2, F
    GOTO    DELAY_LOOP2
    RETURN
