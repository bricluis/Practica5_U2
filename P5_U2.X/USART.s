#include <xc.inc>
     
CENTENA	EQU	0x076
DECENA	EQU	0x077
UNIDAD	EQU	0x078
TEMPL	EQU	0X7A
TEMPH	EQU	0x7B
	
GLOBAL	USART_CONFIG
GLOBAL	USART_TX
GLOBAL	BINARY_TO_DECIMAL
	
PSECT   Code, delta=2

USART_CONFIG:
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


LOOP_mandar_caracteres:
    ;;meter datos en bianrio a TEMPH y TEMPL
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
    
   ;;meter datos en bianrio a TEMPH y TEMPL
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