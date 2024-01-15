%include "./64bit/sseutils64.nasm"

section .data			; Sezione contenente dati inizializzati
    colonne dq  0
	righe   dq  0
    costante dq 28
	

section .bss			; Sezione contenente dati non inizializzati
   
alignb 32
sc		resq		1
medie   resq        1
somme   resq        1

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
	mov	rdi, %1
	mov	rsi, %2
	call	get_block
%endmacro

%macro	fremem	1
	mov	rdi, %1
	call	free_block
%endmacro

global pre_calculate_means_asm

pre_calculate_means_asm:
		; ------------------------------------------------------------
		; Sequenza di ingresso nella funzione
		; ------------------------------------------------------------
			; ------------------------------------------------------------
		push		rbp				; salva il Base Pointer
		mov		rbp, rsp			; il Base Pointer punta al Record di Attivazione corrente
		pushaq						; salva i registri generali

		; RDI=indirizzo della struttura contenente i parametri
        ; [RDI] input->ds; 			// dataset
		; [RDI + 8] input->labels; 	// etichette
		; [RDI + 16] input->out;	// vettore contenente risultato dim=(k+1)
		; [RDI + 24] input->sc;		// score dell'insieme di features risultato
		; [RDI + 32] input->k; 		// numero di features da estrarre
		; [RDI + 36] input->N;		// numero di righe del dataset
		; [RDI + 40] input->d;		// numero di colonne/feature del dataset
		; [RDI + 44] input->display;
		; [RDI + 48] input->silent;

		mov rbx, [rdi] ; indirizzo dataset
        mov ecx, [rdi+36] ; numero di righe N
        mov edx, [rdi+40] ; numero di colonne d

		mov [righe],rcx
		mov [colonne],rdx

    ;   vcvtsi2sd xmm1,xmm1,[costante]
	;	vmovsd [medie],xmm1
	;	printsd medie
    
	  
	    xor rdx,rdx
		xor rdi,rdi
		mov rax,[righe]	
		mov rdi,[costante]
		div rdi
		sub rcx,rdx

        ;vcvtsi2sd xmm1,xmm1,rdx
	    ;vmovsd [medie],xmm1
	    ;printsd medie
        ;rdx residuo
  
        xor r10,r10
		
		for_loop1:
			cmp r10,[colonne];colonne
			jge fine
			vxorps ymm1,ymm1
			vxorps ymm2,ymm2
			vxorps ymm3,ymm3
			vxorps ymm4,ymm4
			vxorps ymm5,ymm5
			vxorps ymm6,ymm6
			vxorps ymm7,ymm7
			xor r9,r9
		for_loop2:
		    cmp r9,rcx
		    jge residuo
			xor rax,rax
            mov rax,r10
			imul rax,[righe]
			add rax,r9
            vaddpd ymm1,[rbx+rax*8]
			vaddpd ymm2,[rbx+rax*8+32]
			vaddpd ymm3,[rbx+rax*8+64]
			vaddpd ymm4,[rbx+rax*8+96]
			vaddpd ymm5,[rbx+rax*8+128]
			vaddpd ymm6,[rbx+rax*8+160]
			vaddpd ymm7,[rbx+rax*8+192]
		    add r9,[costante]
			jmp for_loop2;   
		residuo:
		    cmp r9,[righe]
		    jge media
            xor rax,rax
			mov rax,r10
			imul rax,[righe]
			add rax,r9
			vaddsd xmm1,[rbx+rax*8] ; vedere meglio
			add r9,1
			jmp residuo
		media:  
	        vaddpd ymm1,ymm7
			vaddpd ymm2,ymm6
			vaddpd ymm3,ymm5
			vaddpd ymm1,ymm4
			vaddpd ymm2,ymm3
			vaddpd ymm1,ymm2
			vhaddpd ymm1, ymm1, ymm1						
			vhaddpd ymm1, ymm1, ymm1
			; vmovsd [somme],xmm1
		 	; printsd somme
			vcvtsi2sd xmm7,r9
			vdivpd ymm1,ymm7
		    ; vmovsd [medie],xmm1
	     	; printsd medie
	    	lea rax,[rsi]
		    vmovsd [rax+r10*8],xmm1
		;	xorps xmm7,xmm7
		;	vcvtsi2sd xmm7,xmm7,rsi
		;   vmovsd [xmm0],ymm0
			inc r10
			jmp for_loop1
		
		fine:
  
		popaq				; ripristina i registri generali
		mov		rsp, rbp	; ripristina lo Stack Pointer
		pop		rbp		; ripristina il Base Pointer
		ret				; torna alla funzione C chiamante

