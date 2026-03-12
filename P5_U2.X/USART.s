#include <xc.inc>
     
CENTENA     EQU 0x76
DECENA      EQU 0x77
UNIDAD      EQU 0x78
TEMPL       EQU 0x7A
TEMPH       EQU 0x7B

; --- AGREGAMOS LAS VARIABLES QUE EL MAIN USA ---
VAR_TEMP    EQU 0x7C    
VAR_HUM     EQU 0x7D
       
GLOBAL	USART_CONFIG
GLOBAL	USART_TX
GLOBAL	BINARY_TO_DECIMAL
GLOBAL	MANDAR_DATOS
  
	
PSECT UsartCode, class=CODE, delta=2

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
