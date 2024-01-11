%include "./32bit/sseutils32.nasm"

section .data			; Sezione contenente dati inizializzati
    k dd 0
	i dd 0
	j dd 0
	righe  dd 0
	colonne dd 0
	costante dd 32
	resto dd 0

section .bss			; Sezione contenente dati non inizializzati
	alignb 16
	sc		 resd		1
	medie    resd       1
	somma    resd       1
	prova1    resd       1
	prova2    resd       1
	indice    resd      1
	risultato  resd     1

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

global pcc_asm

input		equ		8
feature_x   equ     12
feature_y   equ     16
mean_x      equ     20
mean_y      equ     24
output      equ     28

pcc_asm:

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


		mov ebx,[eax] ; dataset 
		mov ecx,[eax+20] ; numero di righe N
		mov [righe],ecx
		mov edx,[ebp+feature_x]; indice feature x
		mov [i],edx 
		mov edi,[ebp+feature_y] ; indice feature y
		mov [j],edi
		movss xmm0,[ebp+mean_x] ; media feature x 
		movss xmm1,[ebp+mean_y] ; media feature y

		shufps xmm0,xmm0,0
		shufps xmm1,xmm1,0

		xor esi,esi ;indice scorrimento righe
        
		xorps xmm2,xmm2 ; diff_x
		xorps xmm3,xmm3 ; diff_y
		xorps xmm4,xmm4 ; numerator
		xorps xmm5,xmm5 ; denominator_x
		xorps xmm6,xmm6 ; denominator_y
		xorps xmm7,xmm7 ; copia del registro xmm2 per mul

	    imul edx,ecx ; feature_x *N

		imul edi,ecx ; feature_y *N
		
		pcc_ciclo:	 
		    cmp esi, ecx  
			jge pcc_residuo

			movaps xmm2,[ebx+edx*4]
			movaps xmm3,[ebx+edi*4] 
			subps xmm2,xmm0 ; diff_x
			subps xmm3,xmm1 ; diff_y

		    movaps xmm7,xmm2
			mulps xmm7,xmm3 
			addps xmm4,xmm7; numerator
 
			mulps xmm2,xmm2 
			addps xmm5,xmm2; denominator_x
			
			mulps xmm3,xmm3
			addps xmm6,xmm3; denominator_y

			add esi,4
            add edx,4			
			add edi,4 
    
			jmp pcc_ciclo
		pcc_residuo:
		  
			cmp esi,[righe]
			jge pcc_somma_par
			
		    movss xmm2,[ebx+edx*4]
			
		    movss xmm3,[ebx+edi*4]

			subss xmm2,xmm0 ; diff_x
			subss xmm3,xmm1 ; diff_y

			movss xmm7,xmm2 
			mulss xmm7,xmm3
			addss xmm4,xmm7 ; numerator

			mulss xmm2,xmm2 
			addss xmm5,xmm2; denominator_x

			mulss xmm3,xmm3
			addss xmm6,xmm3; denominator_y

            inc edi
			inc edx
			inc esi

      
			jmp pcc_residuo
     
        pcc_somma_par:
			haddps xmm4,xmm4
			haddps xmm4,xmm4
			haddps xmm5,xmm5
			haddps xmm5,xmm5
			haddps xmm6,xmm6
			haddps xmm6,xmm6
			jmp pcc_fine
        pcc_fine:
			sqrtss xmm5,xmm5
			sqrtss xmm6,xmm6
			mulss xmm5,xmm6
			divss xmm4,xmm5
			xor eax,eax
			mov eax,[ebp+output]
			movss [eax],xmm4
	        movss [prova1],xmm4
		 	printss prova1
			
		; ------------------------------------------------------------
		; Sequenza di uscita dalla funzione
		; ------------------------------------------------------------

		pop	edi		; ripristina i registri da preservare
		pop	esi
		pop	ebx
		mov	esp, ebp	; ripristina lo Stack Pointer
		pop	ebp		; ripristina il Base Pointer
		ret			; torna alla funzione C chiamante


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
		
		mov [colonne],edx
	    mov [righe],ecx

	    xor esi,esi ; indice scorrimento colonne
	    xor edx,edx
		xor edi,edi
		mov eax,[righe]
		mov edi,[costante]
		div edi
		sub ecx,edx
	
		for_loop1:
			cmp esi,[colonne];[colonne] ;colonne
			jge fine
			xorps xmm0,xmm0 ; vettore usato per somma
			xorps xmm1,xmm1
			xorps xmm2,xmm2
			xorps xmm3,xmm3
			xorps xmm4,xmm4
			xorps xmm5,xmm5
			xorps xmm6,xmm6
			xorps xmm7,xmm7
			xor edi,edi
		for_loop2: 
		    cmp edi,ecx
		    jge residuo
			xor eax,eax
            mov eax,esi
			imul eax,[righe]
			add eax,edi
		    addps xmm0,[ebx+eax*4]
            addps xmm1,[ebx+eax*4+16]
			addps xmm2,[ebx+eax*4+32]
			addps xmm3,[ebx+eax*4+48]
			addps xmm4,[ebx+eax*4+64]
			addps xmm5,[ebx+eax*4+80]
			addps xmm6,[ebx+eax*4+96]
			addps xmm7,[ebx+eax*4+112]
			;cvtsi2ss xmm5,edi
			;movss [prova1],xmm5
			;printss prova1	
		    add edi,[costante]
			jmp for_loop2;
	
		residuo:
			cmp edi,[righe]
		    jge media
			xor eax,eax
			mov eax,esi
			imul eax,[righe]
			add eax,edi
			addss xmm0,[ebx+eax*4]
			inc edi
			jmp residuo
			
		media: 
		    addps xmm0,xmm7
	        addps xmm1,xmm6
            addps xmm2,xmm5
	        addps xmm3,xmm4
		    addps xmm0,xmm3
		    addps xmm1,xmm2
	        addps xmm0,xmm1
			haddps xmm0,xmm0
			haddps xmm0,xmm0
         	;movss [somma],xmm0 
        	;printss somma
			cvtsi2ss xmm7,[righe]
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



