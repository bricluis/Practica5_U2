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
 
W_TEMP		EQU	0x70
STATUS_TEMP	EQU	0x71
PCLATH_TEMP	EQU	0x72
VALOR_HUM_L     EQU     0x73    ; Guarda los 8 bits bajos del ADC (Humedad)
VALOR_HUM_H     EQU     0x74    ; Guarda los 2 bits altos del ADC (Humedad)
VALOR_TEMP_L    EQU     0x75    ; Guarda los 8 bits bajos del ADC (Temp.)
VALOR_TEMP_H    EQU     0x76    ; Guarda los 2 bits altos del ADC (Temp.)
CONT_RETARDO    EQU     0x77    ; Variable contador para la subrutina de 20us   
    
PSECT   Code, delta=2
        ORG     0x00
        goto    INICIO

        ORG     0x04
	
; ==========================================================
; PROGRAMA PRINCIPAL
; ==========================================================
INICIO:
        call    CONFIG_ADC      ; 1. Configura el módulo ADC
        ; (Aquí llamaremos a CONFIG_PWM y CONFIG_USART después)
        goto    MAIN_LOOP       ; 2. Entra al ciclo infinito

MAIN_LOOP:
        call    LEER_HUMEDAD    ; Actualiza las variables de humedad
        call    LEER_TEMP       ; Actualiza las variables de temperatura
        
        ; Aquí llamarás a las rutinas que calculan si prender el PWM
        ; y si enviar los datos por el USART a la PC.
        goto    MAIN_LOOP

; ==========================================================
; SUBRUTINAS DE CONFIGURACIÓN
; ==========================================================
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
        banksel ADCON0
        movlw   0b01000001     ; Canal 0 (AN0)
        movwf   ADCON0
        call    RETARDO_20US    
        bsf     ADCON0, 1       ; 1 es el bit GO en XC8
ESPERA_HUMEDAD:
        btfsc   ADCON0, 1       
        goto    ESPERA_HUMEDAD  
        
        banksel ADRESL
        movf    ADRESL, W
        banksel VALOR_HUM_L
        movwf   VALOR_HUM_L
        
        banksel ADRESH
        movf    ADRESH, W
        banksel VALOR_HUM_H
        movwf   VALOR_HUM_H
        return
 
LEER_TEMP:
        banksel ADCON0
        movlw   0b01001001     ; Canal 1 (AN1) 
        movwf   ADCON0
        call    RETARDO_20US    
        bsf     ADCON0, 1       
ESPERA_TEMP:
        btfsc   ADCON0, 1
        goto    ESPERA_TEMP
        
        banksel ADRESL
        movf    ADRESL, W
        banksel VALOR_TEMP_L
        movwf   VALOR_TEMP_L
        
        banksel ADRESH
        movf    ADRESH, W
        banksel VALOR_TEMP_H
        movwf   VALOR_TEMP_H
        return
        
RETARDO_20US:
        movlw   5            
        movwf   CONT_RETARDO    
BUCLE_20US:
        decfsz  CONT_RETARDO, f 
        goto    BUCLE_20US      
        return