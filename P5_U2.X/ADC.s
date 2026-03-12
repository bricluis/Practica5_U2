#include <xc.inc>
  
 ; Declaramos estas etiquetas como públicas (exportables)
    GLOBAL CONFIG_ADC
    GLOBAL LEER_HUMEDAD
    GLOBAL LEER_TEMP
    
TEMPL		EQU 0x7A
TEMPH		 EQU 0x7B
CONT_RETARDO    EQU    0x70    ; Variable contador para la subrutina de 20us   
    
PSECT AdcCode, class=CODE, delta=2
	

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
        banksel ADCON1
        bcf     ADCON1, 7       ; ¡JUSTIFICACIÓN IZQUIERDA! (Para leer los 5V completos en 8 bits)
        
        banksel ADCON0
        movlw   0b01000001      ; Canal 0 (AN0)
        call	 RETARDO_20US

        banksel ADRESH
        movf    ADRESH, W
        banksel TEMPL
        movwf   TEMPL
        return

ESPERA_HUMEDAD:
        btfsc   ADCON0, 1       
        goto    ESPERA_HUMEDAD  
        
        banksel ADRESL
        movf    ADRESL, W
        banksel TEMPL
        movwf   TEMPL ;; usar la variable de luis
        
        banksel ADRESH
        movf    ADRESH, W
        banksel TEMPH
        movwf   TEMPH ;; usar la variable de luis
        return
 

LEER_TEMP:
        banksel ADCON1
        bsf     ADCON1, 7       ; ¡JUSTIFICACIÓN DERECHA! (Regresamos al modo del LM35)
        
        banksel ADCON0
        movlw   0b01001001      ; Canal 1 (AN1)
        ; ... (resto del código de lectura igual, leyendo ADRESL)
	
ESPERA_TEMP:
        btfsc   ADCON0, 1
        goto    ESPERA_TEMP
        
        banksel ADRESL
        movf    ADRESL, W
        banksel TEMPL;; usar la variable de luis
        movwf   TEMPL
        
        banksel ADRESH
        movf    ADRESH, W
        banksel TEMPH ;; usar la variable de luis
        movwf   TEMPH
        return
        
RETARDO_20US:
        movlw   5            
        movwf   CONT_RETARDO    
BUCLE_20US:
        decfsz  CONT_RETARDO, f 
        goto    BUCLE_20US      
        return