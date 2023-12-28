%include "sseutils32.nasm"

section .data			; Sezione contenente dati inizializzati


section .bss			; Sezione contenente dati non inizializzati
	alignb 16
	sc		 resd		1
	medie    resd       1
	somma    resd       1
	prova1    resd       1
	prova2    resd       1
	k        resd       1

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

global pre_calculate_means_asm

input		equ		8
means       equ    12

pre_calculate_means_asm:
		; ------------------------------------------------------------
		; Sequenza di ingresso nella funzione
		; ------------------------------------------------------------
		push		ebp		; salva il Base Pointer
		mov		ebp, esp	; il Base Pointer punta al Record di Attivazione corrente
		push		ebx		; salva i registri da preservare
		push        ecx
		push		esi
		push		edi

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

  		

	
	;   movss xmm0,[ebx+4]; 16-8
	;	movss [prova1],xmm0
	;	printss  prova1
	;	addss xmm0, [ebx+8]
	;	movss [prova1],xmm0
	;	printss prova1
	;	addss xmm0, [ebx+12]
	;	movss [prova1],xmm0
	;	printss prova1
	;	addss xmm0, [ebx+16]
	;	movss [prova1],xmm0
	;	printss prova1
	;   movss xmm0,[ebx+20]; 16-8
	;	movss [prova1],xmm0
	;	printss  prova1
	;	addss xmm0, [ebx+24]
	;	movss [prova1],xmm0
	;	printss prova1
	;	addss xmm0, [ebx+28]
	;	movss [prova1],xmm0
	;	printss prova1
	;	addss xmm0, [ebx+32]
	;	movss [prova1],xmm0
	;	printss prova1

	
	;	movups xmm1,[ebx+4]
	;   addps xmm1,[ebx+8]
	;	haddps xmm1,xmm1
	;	haddps xmm1,xmm1
	;	movss [prova2],xmm1
	;	printss prova2
	
		mov ebx, [eax] ; indirizzo dataset
        mov ecx, [eax+20] ; numero di righe N

        mov edx, [eax+24] ; numero di colonne d

        xor esi,esi ; indice scorrimento colonne
		
		for_loop1: cmp esi,edx
		       	   jge fine
		           xorps xmm0,xmm0 ; vettore usato per somma
			       xor edi,edi
		for_loop2: cmp edi, ecx; controlliamo il residuo o  
		           jge residuo
				   xor eax,eax
				   mov eax,esi
				   imul eax,ecx
				   add eax,edi
				   addps xmm0,[ebx+eax*4]; 16-8
				   ;movups [somma],xmm0
				   ;printps somma 
				   add edi,4
				   jmp for_loop2;

		residuo: cmp edi,0
		         jge media
                 addss xmm0,[ebx+edi*4]
		         dec edi
                 jmp residuo
		
		media: 
		       haddps xmm0,xmm0
			   haddps xmm0,xmm0
			   ;movss [somma],xmm0 
			   ;printss somma
			   cvtsi2ss xmm6,ecx
			   divss xmm0,xmm6
			   ;movss [medie],xmm0
			   ;printss medie
			   
			   mov edi,[ebp+means]
			   movss [edi+esi*4],xmm0
			   inc esi
               jmp for_loop1
		
		fine:
		     
		


		     
		; ------------------------------------------------------------
		; Sequenza di uscita dalla funzione
		; ------------------------------------------------------------
		pop	edi		; ripristina i registri da preservare
		pop	esi
		pop ecx
		pop	ebx
		mov	esp, ebp	; ripristina lo Stack Pointer
		pop	ebp		; ripristina il Base Pointer
		ret		; torna alla funzione C chiamante




global prova

input		equ		8
means       equ     12

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
