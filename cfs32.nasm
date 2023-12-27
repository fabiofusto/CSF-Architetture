%include "sseutils32.nasm"

section .data			; Sezione contenente dati inizializzati


section .bss			; Sezione contenente dati non inizializzati
	alignb 16
	sc		 resd		1

section .text			; Sezione contenente il codice macchina


; ----------------------------------------------------------
; macro per l'allocazione dinamica della memoria
;
;	getmem	<size>,<elements>
;
; alloca un'area di memoria di <size>*<elements> bytes
; (allineata a 16 bytes) e restituisce in EAX
; l'indirizzo del primo bytes del blocco allocato
; (funziona mediante chiamata a funzione C, per cui
; altri registri potrebbero essere modificati)
;
;	fremem	<address>
;
; dealloca l'area di memoria che ha inizio dall'indirizzo
; <address> precedentemente allocata con getmem
; (funziona mediante chiamata a funzione C, per cui
; altri registri potrebbero essere modificati)

extern get_block
extern free_block

%macro	getmem	2
	mov	eax, %1
	push	eax
	mov	eax, %2
	push	eax
	call	get_block
	add	esp, 8
%endmacro

%macro	fremem	1
	push	%1
	call	free_block
	add	esp, 4
%endmacro

; ------------------------------------------------------------
; Funzioni
; ------------------------------------------------------------

global prova

input		equ		8

msg	db	'sc:',32,0
nl	db	10,0

prova:
		; ------------------------------------------------------------
		; Sequenza di ingresso nella funzione
		; ------------------------------------------------------------
		push		ebp		; salva il Base Pointer
		mov		ebp, esp	; il Base Pointer punta al Record di Attivazione corrente
		push		ebx		; salva i registri da preservare
		push		esi
		push		edi
		; ------------------------------------------------------------
		; legge i parametri dal Record di Attivazione corrente
		; ------------------------------------------------------------

		; elaborazione
		
		; esempio: stampa input->sc
		mov EAX, [EBP+input]	; indirizzo della struttura contenente i parametri
        ; [EAX] input->ds; 			// dataset
		; [EAX + 4] input->labels; 	// etichette
		; [EAX + 8] input->out;	// vettore contenente risultato dim=(k+1)
		; [EAX + 12] input->sc;		// score dell'insieme di features risultato
		; [EAX + 16] input->k; 		// numero di features da estrarre
		; [EAX + 20] input->N;		// numero di righe del dataset
		; [EAX + 24] input->d;		// numero di colonne/feature del dataset
		; [EAX + 28] input->display;
		; [EAX + 32] input->silent;
		MOVSS XMM0, [EAX+12]
		MOVSS [sc], XMM0
		prints msg            
		printss sc     
		prints nl

		; ------------------------------------------------------------
		; Sequenza di uscita dalla funzione
		; ------------------------------------------------------------

		pop	edi		; ripristina i registri da preservare
		pop	esi
		pop	ebx
		mov	esp, ebp	; ripristina lo Stack Pointer
		pop	ebp		; ripristina il Base Pointer
		ret			; torna alla funzione C chiamante
