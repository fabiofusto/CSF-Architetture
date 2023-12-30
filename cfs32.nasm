%include "sseutils32.nasm"

section .data			; Sezione contenente dati inizializzati
    k dd 0

section .bss			; Sezione contenente dati non inizializzati
	alignb 16
	sc		 resd		1
	medie    resd       1
	somma    resd       1
	prova1    resd       1
	prova2    resd       1
	

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

  	
		mov ebx, [eax] ; indirizzo dataset
        mov ecx, [eax+20] ; numero di righe N

        mov edx, [eax+24] ; numero di colonne d

        xor esi,esi ; indice scorrimento colonne
		
        mov [k], ecx


		for_loop1: cmp esi,edx
		       	   jge fine
		           xorps xmm0,xmm0 ; vettore usato per somma
			       xor edi,edi
		for_loop2: cmp edi,ecx ;controlliamo il residuo o  
				   jge residuo
                   xor eax,eax
				   mov eax,esi
				   imul eax,ecx
				   add eax,edi
			       addps xmm0,[ebx+eax*4]
;			       addps xmm0,[ebx+eax*4+16] 
;				   addps xmm0,[ebx+eax*4+32] 
;				   addps xmm0,[ebx+eax*4+48] 
;				   addps xmm0,[ebx+eax*4+64] 
;				   addps xmm0,[ebx+eax*4+80]
;				   addps xmm0,[ebx+eax*4+96]
;				   addps xmm0,[ebx+eax*4+112] 
;				   addps xmm0,[ebx+eax*4+128] 
;				   addps xmm0,[ebx+eax*4+144] 
;				   addps xmm0,[ebx+eax*4+160] 
;				   addps xmm0,[ebx+eax*4+176]
;				   addps xmm0,[ebx+eax*4+192]
;                   addps xmm0,[ebx+eax*4+208] 
;				   addps xmm0,[ebx+eax*4+224] 
;				   addps xmm0,[ebx+eax*4+240] 
;				   addps xmm0,[ebx+eax*4+256] 
;				   addps xmm0,[ebx+eax*4+272]
;				   addps xmm0,[ebx+eax*4+288]
;				   addps xmm0,[ebx+eax*4+304]
;				   addps xmm0,[ebx+eax*4+320] 
;				   addps xmm0,[ebx+eax*4+336]
;				   addps xmm0,[ebx+eax*4+352]
;				   addps xmm0,[ebx+eax*4+368]
;				   addps xmm0,[ebx+eax*4+384]
				   

			
                   add edi,4				
;				   add edi,100
				   jmp for_loop2;

		residuo: sub edi,ecx
		         cmp edi,0
		         jle media
				 add eax,edi
                 addss xmm0,[ebx+edi*4]
		         dec edi
                 jmp residuo
		
		media: 
		       haddps xmm0,xmm0
			   haddps xmm0,xmm0
			   ;movss [somma],xmm0 
			   ;printss somma
			   cvtsi2ss xmm7,ecx
			   divss xmm0,xmm7
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



