; PIC16F877A Configuration Bit Settings
  CONFIG  FOSC = XT
  CONFIG  WDTE = OFF
  CONFIG  PWRTE = OFF
  CONFIG  BOREN = OFF
  CONFIG  LVP = OFF
  CONFIG  CPD = OFF
  CONFIG  WRT = OFF
  CONFIG  CP = OFF

#include <xc.inc>
 
W_TEMP      EQU 0x70
STATUS_TEMP EQU 0x71
PCLATH_TEMP EQU 0x72
REG1        EQU 0x73
	
	
PSECT   Code, delta=2
        ORG     0x00
        goto    INICIO

        ORG     0x04
	goto ISR
    
INICIO:
    ; CONFIGURACION DE PUERTOS
    bsf     STATUS, 5        ; cambiar al banco 1 (RP0 es el bit 5)
    bcf     STATUS, 6        ; (RP1 es el bit 6)
    clrf    TRISB            ; configurar puerto B como salida para los LEDs

    ; CONFIGURACION DE PINES USART (RC6/TX entrada, RC7/RX entrada)
    bsf     TRISC, 6
    bsf     TRISC, 7

    ; CONFIGURACION DE USART A 9600 BAUDIOS (ASUMIENDO CRISTAL DE 4MHz)
    movlw   25            ; valor de SPBRG para 9600 bps con Fosc=4MHz y BRGH=1
    movwf   SPBRG
    bsf     TXSTA, 2         ; habilitar alta velocidad de baudios (BRGH es bit 2)
    bcf     TXSTA, 4         ; configurar para modo asincrono (SYNC es bit 4)
    bsf     TXSTA, 5         ; habilitar transmision (TXEN es bit 5)

    ; HABILITAR INTERRUPCION DE RECEPCION
    bsf     PIE1, 5          ; habilitar interrupcion por recepcion serial (RCIE es bit 5)

    ; REGRESAR AL BANCO 0
    bcf     STATUS, 5        ; (RP0 es el bit 5)

    ; CONFIGURAR RECEPCION Y ENCENDER PUERTO SERIAL
    bsf     RCSTA, 7         ; habilitar puerto serial (SPEN es bit 7)
    bsf     RCSTA, 4         ; habilitar recepcion continua (CREN es bit 4)

    ; LIMPIAR PORTB ANTES DE INICIAR
    clrf    PORTB

    ; CONFIGURACION DE INTERRUPCIONES GLOBALES
    bsf     INTCON, 6        ; habilitar interrupciones de perifericos (PEIE es bit 6)
    bsf     INTCON, 7        ; habilitar interrupciones globales (GIE es bit 7)

LOOP:
    ; BUCLE PRINCIPAL DE ESPERA
    nop
    goto    LOOP             ; dejar el USART escuchando y esperar interrupcion

ISR:
    ; GUARDAR CONTEXTO DE W Y STATUS
    movwf   W_TEMP
    swapf   STATUS, w
    movwf   STATUS_TEMP

    ; VERIFICAR SI LA INTERRUPCION FUE GENERADA POR RECEPCION
    btfss   PIR1, 5          ; verificar la bandera de recepcion (RCIF es bit 5)
    goto    SALIR_ISR
    goto    DATORECIBIDO

DATORECIBIDO:
    ; LEER, MOSTRAR EN LEDS Y TRANSMITIR COMO ECO
    movf    RCREG, w         ; leer dato recibido (esto limpia bandera RCIF)
    movwf   REG1             ; guardar dato en variable temporal
    movwf   PORTB            ; mostrar el dato en forma binaria en el puerto B
    movwf   TXREG            ; retransmitir el mismo dato a la PC como ECO

SALIR_ISR:
    ; RESTAURAR CONTEXTO DE STATUS Y W Y SALIR
    swapf   STATUS_TEMP, w
    movwf   STATUS
    swapf   W_TEMP, f
    swapf   W_TEMP, w
    retfie                   ; retornar de la interrupcion y volver al bucle

    END