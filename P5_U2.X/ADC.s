#include <xc.inc>
  
 ; Declaramos estas etiquetas como públicas (exportables)
    GLOBAL CONFIG_ADC
    GLOBAL LEER_HUMEDAD
    GLOBAL LEER_TEMP
    
TEMPL		EQU 0x7A
TEMPH		 EQU 0x7B
CONT_RETARDO    EQU    0x70    ; Variable contador para la subrutina de 20us   
    
psect ADC_data, class=CODE, delta=2	

; ==========================================================
; SUBRUTINAS DE CONFIGURACIÓN
; ==========================================================
CONFIG_ADC:
        banksel ADCON1          ; Banco 1
        movlw   0b10000100     
	;; bit 7: Justificación derecha. bit 6: ADCS2 (Channel Select) bits 5-4: U. bits 3-0: AN3, AN1 y AN0 analógicos y Vref en Vcc
        movwf   ADCON1
        
        banksel ADCON0          ; Banco 0
        movlw   0b01000001     
	;; bit 7-6:Fosc/8, bits 5-3: Canal 0. bit 2: GO/DONE. bit 1: U. bitb0: ADON=1
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
	;; bit 7-6:Fosc/8, bits 5-3: Canal 0. bit 2: GO/DONE. bit 1: U. bitb0: ADON=1
        movwf   ADCON0          ; <--- ¡Te faltó esta línea para guardar la config!
        call    RETARDO_20US

        bsf     ADCON0, 2       ; Iniciamos conversión (GO)
	
ESPERA_HUMEDAD:
        btfsc   ADCON0, 2       ; Esperamos a que termine
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
	;; bit 7-6:Fosc/8, bits 5-3: Canal 0. bit 2: GO/DONE. bit 1: U. bitb0: ADON=1
        movwf   ADCON0          ; ¡Cargamos el canal!
        call    RETARDO_20US    ; Damos tiempo al capacitor interno

        bsf     ADCON0, 2       ; Arrancamos conversión de temperatura
ESPERA_TEMP:
        btfsc   ADCON0, 2       ; Esperamos a que termine
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