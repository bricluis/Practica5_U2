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
;;------------------------------------------------------------------------
;; CONFIGURAR PUERTOS
;;------------------------------------------------------------------------
 
    goto MAIN
    

MAIN:
    goto MAIN

    
ISR:
    ; GUARDAR CONTEXTO DE W Y STATUS
    movwf   W_TEMP
    swapf   STATUS,w
    movwf   STATUS_TEMP
    movf    PCLATH,w
    movwf   PCLATH_TEMP


    
SALIR_ISR:
    ; RESTAURAR CONTEXTO DE STATUS, PCLATH Y W Y SALIR
    movf    PCLATH_TEMP,w
    movwf   PCLATH
    swapf   STATUS_TEMP, w
    movwf   STATUS
    swapf   W_TEMP, f
    swapf   W_TEMP, w
    retfie                   ; retornar de la interrupcion y volver al bucle



ISR_USART:
    movf RCREG,w
    ; usar dato
    return
    

    END