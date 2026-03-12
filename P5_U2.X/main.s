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
  
  ; Importamos las rutinas que viven en otros archivos
    EXTERN CONFIG_ADC
    EXTERN LEER_HUMEDAD
    EXTERN LEER_TEMP
    
    EXTERN I2C_INIT_HW
    EXTERN LCD_INIT
    EXTERN LCD_SEND_DATA
    
DATO_LCD	EQU	0x70
ADDR_LCD	EQU	0x71	    
CENTENA		EQU	0x76
DECENA		EQU	0x77
UNIDAD		EQU	0x78
CONT_RETARDO	EQU	0x79
TEMPL		EQU	0X7A
TEMPH		EQU	0x7B
	
	
	
PSECT   Code, delta=2
        ORG     0x00
        goto    INICIO

        ORG     0x04

    
INICIO:
    ; --- BANCO 1 ---
    BANKSEL TRISC
    bcf     TRISC, 6         ; TX DEBE SER SALIDA (0)
    bsf     TRISC, 7         ; RX COMO ENTRADA (1)

    movlw   25               ; 9600 bps @ 4MHz
    movwf   SPBRG
    
    movlw   00100100B        ; TXEN=1, BRGH=1
    movwf   TXSTA

    ; --- BANCO 0 ---
    BANKSEL RCSTA
    bsf     RCSTA, 7         ; SPEN=1 (Encender puerto serial)

;;CONFIGURCION ADC (PENDIENTE)
    
    call    CONFIG_ADC
    
;;CONFIG I2C
    CALL    I2C_INIT_HW     ; Configura pines y velocidad I2C
    CALL    LCD_INIT        ; Prende y limpia el display
    
LOOP:
    ;;GUARDA LO QUE ESTÁ EN VALOR_TEMPH EN TEMPH Y LO QUE ESTÁ EN VALORTEMPL EN TEMPL
   call LEER_TEMP
   ;;PASAR DATOS A TEMPH Y TEMPL
   call BINARY_TO_DECIMAL
    
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
    
    ;;GUARDA LO QUE ESTÁ EN VALOR_HUMH EN TEMPH Y LO QUE ESTÁ EN VALORHUML EN TEMPL
   call LEER_HUMEDAD
   ;;PASAR DATOS A TEMPH Y TEMPL
   call BINARY_TO_DECIMAL 
    
    movlw   'C'       
    call    USART_TX
    movlw   ' '
    call    USART_TX
    
    movlw   'H'
    call    USART_TX
    movlw   ':'
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

    ; Salto de línea para que no se pegue el texto en la PC
    movlw   0x0D             ; Retorno de carro (\r)
    call    USART_TX
    movlw   0x0A             ; Salto de línea (\n)
    call    USART_TX
    
    goto    LOOP

; --- Subrutina TX ---
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
    movlw   0x64
    subwf   TEMPL, f
    movlw   0x00
    btfss   STATUS, 0
    addlw   1
    subwf   TEMPH, f
    btfsc   STATUS, 0
    goto    CIEN
    
    ; Restore
    movlw   0x64
    addwf   TEMPL, f

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
    subwf   TEMPL, f
    btfsc   STATUS, 0
    goto    UNO
    
    return

CIEN:
    incf    CENTENA, f
    goto    RESTACIEN
DIEZ:
    incf    DECENA, f
    goto    RESTADIEZ
UNO:
    incf    UNIDAD, f
    goto    RESTAUNO

    END