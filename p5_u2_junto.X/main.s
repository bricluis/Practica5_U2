#include <xc.inc>
; PIC16F877A Configuration Bit Settings
  CONFIG  FOSC = XT
  CONFIG  WDTE = OFF
  CONFIG  PWRTE = OFF
  CONFIG  BOREN = OFF
  CONFIG  LVP = OFF
  CONFIG  CPD = OFF
  CONFIG  WRT = OFF
  CONFIG  CP = OFF

; ==========================================================
; VARIABLES COMPARTIDAS (Unbanked RAM 0x70 - 0x7F)
; ==========================================================
CENTENA     EQU 0x76
DECENA      EQU 0x77
UNIDAD      EQU 0x78
TEMPL       EQU 0x7A
TEMPH       EQU 0x7B
CONT_RETARDO    EQU    0x70
TEMP_LCD    EQU 0x71
ADDR_LCD    EQU 0x3F
CONT1       EQU 0x72
CONT2       EQU 0x73

       

; Variables exclusivas del main para guardar las lecturas
VAR_TEMP    EQU 0x7C    
VAR_HUM     EQU 0x7D    


; ==========================================================
; VECTOR DE RESET Y ARRANQUE
; ==========================================================
PSECT   Code, delta=2

ORG 0x00
goto INICIO

INICIO:
    ; --- INICIALIZACIÓN DE PERIFÉRICOS ---
    call    CONFIG_ADC
    call    USART_CONFIG
    call    I2C_INIT
    call    LCD_INIT
    call    Configuracion_PWM_CCP2

MAIN_LOOP:
    ; ======================================================
    ; 1. LECTURA DE SENSORES
    ; ======================================================
    call    LEER_TEMP
    movf    TEMPL, W
    movwf   VAR_TEMP        ; Guardamos la temperatura de forma segura

    call    LEER_HUMEDAD
    movf    TEMPL, W
    movwf   VAR_HUM         ; Guardamos la humedad de forma segura


    ; ======================================================
    ; 2. LÓGICA DE CONTROL (PWM)
    ; ======================================================
    
; ¿Temperatura >= 30°C? (30°C equivale a 61 en el ADC)
    movlw   61              ; Cargamos el umbral crudo
    subwf   VAR_TEMP, W     ; Comparamos
    btfsc   STATUS, 0       
    goto    APAGAR_PWM

EVALUAR_HUMEDAD:
    ; Caso: Humedad Baja / Seco (Mayor o igual a 180)
    movlw   180             
    subwf   VAR_HUM, W
    btfsc   STATUS, 0       ; Si Carry es 1, VAR_HUM >= 180
    goto    PWM_MAXIMO

    ; Caso: Humedad Media (Mayor o igual a 100)
    ; Si el código llegó aquí, ya sabemos que es menor a 180
    movlw   100             
    subwf   VAR_HUM, W
    btfsc   STATUS, 0       ; Si Carry es 1, VAR_HUM >= 100
    goto    PWM_MITAD

    ; Caso Default: Humedad Alta / Inundado (Menor a 100)
    goto    APAGAR_PWM

    ; --- ACCIONES DEL PWM ---
PWM_MAXIMO:
    movlw   0xFF            ; Duty cycle al 100%
    movwf   CCPR2L
    goto    ENVIAR_DATOS

PWM_MITAD:
    movlw   0x7F            ; Duty cycle al 50% (mitad de 255)
    movwf   CCPR2L
    goto    ENVIAR_DATOS

APAGAR_PWM:
    clrf    CCPR2L          ; Duty cycle al 0%
    goto    ENVIAR_DATOS


    ; ======================================================
    ; 3. MOSTRAR DATOS (LCD E I2C)
    ; ======================================================
ENVIAR_DATOS:
    
    ; --- A) ENVÍO POR USART ---
    ; Aquí llamamos a tu rutina que manda la trama armada a la PC
    call    MANDAR_DATOS

    ; --- B) ENVÍO POR I2C A LA LCD ---
    ; FILA 1: HUMEDAD
    movlw   0x80            ; Comando: Cursor a la Línea 1, Columna 0
    call    LCD_CMD
    movlw   'H'
    call    LCD_SEND_DATA
    movlw   ':'
    call    LCD_SEND_DATA
    movlw   ' '
    call    LCD_SEND_DATA

    ; Procesar Humedad a Decimal
    movf    VAR_HUM, W
    movwf   TEMPL           ; Le pasamos el dato a BINARY_TO_DECIMAL
    clrf    TEMPH           
    call    BINARY_TO_DECIMAL

    ; Imprimir Centena, Decena y Unidad (+0x30 para pasarlo a código ASCII)
    movf    CENTENA, W
    addlw   0x30
    call    LCD_SEND_DATA
    movf    DECENA, W
    addlw   0x30
    call    LCD_SEND_DATA
    movf    UNIDAD, W
    addlw   0x30
    call    LCD_SEND_DATA

    ; FILA 2: TEMPERATURA
    movlw   0xC0            ; Comando: Cursor a la Línea 2, Columna 0
    call    LCD_CMD
    movlw   'T'
    call    LCD_SEND_DATA
    movlw   ':'
    call    LCD_SEND_DATA
    movlw   ' '
    call    LCD_SEND_DATA

    ; Procesar Temperatura a Decimal
    movf    VAR_TEMP, W
    movwf   TEMPL
    clrf    TEMPH
    call    BINARY_TO_DECIMAL

    ; Imprimir Centena, Decena y Unidad de la Temp
    movf    CENTENA, W
    addlw   0x30
    call    LCD_SEND_DATA
    movf    DECENA, W
    addlw   0x30
    call    LCD_SEND_DATA
    movf    UNIDAD, W
    addlw   0x30
    call    LCD_SEND_DATA

    ; Volver a iniciar el ciclo
    goto    MAIN_LOOP

    USART_CONFIG:
    ; --- BANCO 1 ---
    BANKSEL TRISC
    bcf     TRISC, 6         ; TX DEBE SER SALIDA (0)
    bsf     TRISC, 7         ; RX COMO ENTRADA (1)

    movlw   25               ; 9600 bps @ 4MHz
    movwf   SPBRG
    
    movlw   0b00100100        ; TXEN=1, BRGH=1
    movwf   TXSTA

    ; --- BANCO 0 ---
    BANKSEL RCSTA
    bsf     RCSTA, 7         ; SPEN=1 (Encender puerto serial)
    
return

MANDAR_DATOS:
    ; =========================================
    ; 1. PROCESAR Y MANDAR TEMPERATURA
    ; =========================================
    bcf     STATUS, 0       ; Limpiar Carry
    movf    VAR_TEMP, W     ; Jalamos la lectura cruda del ADC
    movwf   TEMPL
    rrf     TEMPL, f        ; Dividimos entre 2 para sacar los Grados Celsius
    clrf    TEMPH
    call    BINARY_TO_DECIMAL
    
    movlw   'T'
    call    USART_TX
    movlw   ':'
    call    USART_TX
    movlw   ' '
    call    USART_TX
  
    ; Imprimimos los enteros
    movlw   0x30
    addwf   CENTENA, W
    call    USART_TX
    
    movlw   0x30
    addwf   DECENA, W
    call    USART_TX
    
    movlw   0x30
    addwf   UNIDAD, W
    call    USART_TX
    
    movlw   'C'        
    call    USART_TX
    movlw   ' '
    call    USART_TX

    ; =========================================
    ; 2. PROCESAR Y MANDAR HUMEDAD
    ; =========================================
    movf    VAR_HUM, W      ; Jalamos la lectura del ADC de Humedad
    movwf   TEMPL           ; (Esta la mandamos directo, sin dividir)
    clrf    TEMPH
    call    BINARY_TO_DECIMAL 
    
    movlw   'H'
    call    USART_TX
    movlw   ':'
    call    USART_TX
    movlw   ' '
    call    USART_TX
    
    ; Imprimimos los enteros
    movlw   0x30
    addwf   CENTENA, W
    call    USART_TX
    
    movlw   0x30
    addwf   DECENA, W
    call    USART_TX
    
    movlw   0x30
    addwf   UNIDAD, W
    call    USART_TX

    ; Salto de línea para la PC
    movlw   0x0D             ; Retorno de carro (\r)
    call    USART_TX
    movlw   0x0A             ; Salto de línea (\n)
    call    USART_TX
    
    RETURN

; --- Subrutina TX ---}
    
USART_TX:
    BANKSEL PIR1             ; Asegurar Banco 0
ESPERAR:
    btfss   PIR1, 4          ; ¿Está el buffer vacío?
    goto    ESPERAR          ; No, esperar
    movwf   TXREG            ; Sí, mandar el dato (limpia TXIF automáticamente)
    return

    
 BINARY_TO_DECIMAL:
    
clrf CENTENA
clrf DECENA
clrf UNIDAD

    
RESTACIEN:
    movlw   0x64            ; W = 100
    subwf   TEMPL, f        ; TEMPL = TEMPL - 100
    btfsc   STATUS, 0       ; ¿Carry=1? (no hubo borrow = cabe)
    goto    CIEN            ; Sí cabe ? contar centena
    movlw   0x64            ; No cabe ? restaurar
    addwf   TEMPL, f
    goto    RESTADIEZ       ; Pasar a decenas

RESTADIEZ:
    movlw   0x0A
    subwf   TEMPL, f
    btfsc   STATUS, 0
    goto    DIEZ
    ; Restore
    movlw   0x0A
    addwf   TEMPL, f

RESTAUNO:
    movlw   0x01
    subwf   TEMPL, f        ; TEMPL = TEMPL - 1
    btfsc   STATUS, 0       ; ¿Carry=1? (cabe)
    goto    UNO
    movlw   0x01            ; No cabe ? restaurar
    addwf   TEMPL, f
    return                  ; TEMPL debe quedar en 0

CIEN:
    incf    CENTENA, f
    goto    RESTACIEN
DIEZ:
    incf    DECENA, f
    goto    RESTADIEZ
UNO:
    incf    UNIDAD, f
    goto    RESTAUNO

    
CONFIG_ADC:
        banksel ADCON1          ; Banco 1
        movlw   0b10000100     ; Justificación derecha, pines analógicos
        movwf   ADCON1
        
        banksel ADCON0          ; Banco 0
        movlw   0b01000001     ; Fosc/8, Canal 0, ADON=1
        movwf   ADCON0
        return                  ; ¡Un solo return al terminar de configurar todo!

; ==========================================================
; SUBRUTINAS DE LECTURA Y RETARDO
; ==========================================================
LEER_HUMEDAD:
        banksel ADCON1
        bcf     ADCON1, 7       ; ¡JUSTIFICACIÓN IZQUIERDA! 
        
        banksel ADCON0
        movlw   0b01000001      ; Canal 0 (AN0)
        movwf   ADCON0          ; <--- ¡Te faltó esta línea para guardar la config!
        call    RETARDO_20US

        ; --- ¡FALTABA ESTO! ---
        bsf     ADCON0, 1       ; Iniciamos conversión (GO)
ESPERA_HUMEDAD:
        btfsc   ADCON0, 1       ; Esperamos a que termine
        goto    ESPERA_HUMEDAD  
        ; ----------------------

        banksel ADRESH
        movf    ADRESH, W       ; Leemos el valor justificado a la izquierda
        banksel TEMPL
        movwf   TEMPL
        return
 

LEER_TEMP:
        banksel ADCON1
        bsf     ADCON1, 7       ; ¡JUSTIFICACIÓN DERECHA! (Para el LM35)
        
        banksel ADCON0
        movlw   0b01001001      ; Canal 1 (AN1)
        movwf   ADCON0          ; ¡Cargamos el canal!
        call    RETARDO_20US    ; Damos tiempo al capacitor interno

        bsf     ADCON0, 1       ; Arrancamos conversión de temperatura
ESPERA_TEMP:
        btfsc   ADCON0, 1       ; Esperamos a que termine
        goto    ESPERA_TEMP
        
        banksel ADRESL
        movf    ADRESL, W
        banksel TEMPL
        movwf   TEMPL           ; Guardamos parte baja (la que usamos para dividir)
        
        banksel ADRESH
        movf    ADRESH, W
        banksel TEMPH 
        movwf   TEMPH           ; Guardamos parte alta (por si acaso)
        return
        
RETARDO_20US:
        movlw   5            
        movwf   CONT_RETARDO    
BUCLE_20US:
        decfsz  CONT_RETARDO, f 
        goto    BUCLE_20US      
        return

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

    
Configuracion_PWM_CCP2:
    
    BSF     STATUS, 5       ; Banco 1
    MOVLW   0xFF            ; PR2 = 255 (Periodo máximo para aceleración suave)
    MOVWF   PR2

    BCF     TRISC, 1        ; Configuramos RC1 (pin del CCP2) como SALIDA

    BCF     STATUS, 5       ; Banco 0

    ; Configuración de CCP2CON
    ; Bits 5-4 (Decimales): 00 (No los usamos)
    ; Bits 3-0 (Modo): 1100 (Modo PWM)
    MOVLW   0b00001100
    MOVWF   CCP2CON

    ; Inicializamos velocidad (Duty Cycle) en 0
    CLRF    CCPR2L
    
    ; El Timer 2 es necesario para que el PWM funcione
    ; T2CON: Postscaler 1:1, Prescaler 1:1, TMR2ON = 1
    MOVLW   0b00000100      ; Bit 2 en 1 enciende el Timer
    MOVWF   T2CON
    
    RETURN                  ; Regresamos al flujo principal
  
    
    
    END     INICIO
