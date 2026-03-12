
  #include <xc.inc>
 
GLOBAL	Configuracion_PWM_CCP2
  
PSECT   Code, delta=2

    
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
    