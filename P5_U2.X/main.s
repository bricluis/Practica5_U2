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

; Variables exclusivas del main para guardar las lecturas
VAR_TEMP    EQU 0x7C    
VAR_HUM     EQU 0x7D    

; ==========================================================
; IMPORTACIÓN DE SUBRUTINAS EXTERNAS
; ==========================================================
; Modulo ADC
GLOBAL CONFIG_ADC
GLOBAL LEER_HUMEDAD
GLOBAL LEER_TEMP
; Modulo I2C/LCD
GLOBAL I2C_INIT
GLOBAL LCD_INIT
GLOBAL LCD_CMD
GLOBAL LCD_SEND_DATA
; Modulo PWM
GLOBAL Configuracion_PWM_CCP2
; Modulo USART
GLOBAL USART_CONFIG
GLOBAL MANDAR_DATOS
GLOBAL BINARY_TO_DECIMAL

; ==========================================================
; VECTOR DE RESET Y ARRANQUE
; ==========================================================
PSECT reset_vec, class=CODE, delta=2, abs
ORG 0x0000
goto INICIO
     
PSECT MainCode, class=CODE, delta=2
     
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

    END     INICIO