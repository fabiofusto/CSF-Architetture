%include "./sseutils64.nasm"

section .data			; Sezione contenente dati inizializzati
    colonne dq  0
	righe   dq  0
    costante dq 28
	indice_x dq 0
	indice_y dq 0
	media_x dq 0
	media_y dq 0


section .bss			; Sezione contenente dati non inizializzati
   
alignb 32

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

		mov rbx, [rdi] ; indirizzo dataset
        mov ecx, [rdi+36] ; numero di righe N
        mov edx, [rdi+40] ; numero di colonne d

		mov [righe],rcx
		mov [colonne],rdx

	    xor rdx,rdx
		xor rdi,rdi
		mov rax,[righe]	
		mov rdi,[costante]
		div rdi
		sub rcx,rdx

        xor r10,r10
		
		for_loop1: ; ciclo per iterare tutte le colonne
			cmp r10,[colonne];colonne
			jge fine
			vxorps ymm0,ymm0
			vxorps ymm1,ymm1
			vxorps ymm2,ymm2
			vxorps ymm3,ymm3
			vxorps ymm4,ymm4
			vxorps ymm5,ymm5
			vxorps ymm6,ymm6
			vxorps ymm7,ymm7
			xor r9,r9
		for_loop2: ; elementi presi a 28 alla volta per ogni singola colonna
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
		residuo: ; considerazione elementi residui
		    cmp r9,[righe]
		    jge media
            xor rax,rax
			mov rax,r10
			imul rax,[righe]
			add rax,r9
			vaddsd xmm0,[rbx+rax*8]  
	   		inc r9
			jmp residuo
		media:  ; calcolo media per ogni colonna
	        vaddpd ymm1,ymm6
		  	vaddpd ymm2,ymm5
		  	vaddpd ymm3,ymm4
		  	vaddpd ymm1,ymm7
		  	vaddpd ymm2,ymm3
		 	vaddpd ymm1,ymm2
			vhaddpd ymm1,ymm1,ymm1	
			vxorps ymm5,ymm5			
			vperm2f128 ymm5,ymm1,ymm1,0x01
			vaddsd xmm1,xmm5
			vaddsd xmm1,xmm0
			vcvtsi2sd xmm7,[righe]
			vdivpd ymm1,ymm7
		    vmovsd [rsi+r10*8],xmm1
			inc r10
			jmp for_loop1
		
		fine:
  
		popaq				; ripristina i registri generali
		mov		rsp, rbp	; ripristina lo Stack Pointer
		pop		rbp		; ripristina il Base Pointer
		ret				; torna alla funzione C chiamante




global pcc_asm


pcc_asm:

		; ------------------------------------------------------------
		; Sequenza di ingresso nella funzione
			; ------------------------------------------------------------
		push		rbp				; salva il Base Pointer
		mov		rbp, rsp			; il Base Pointer punta al Record di Attivazione corrente
		pushaq						; salva i registri generali

        mov rbx,[rdi] ;dataset
		mov r8d,[rdi+36] ;numero di righe
	    mov [righe],r8d
	
 		
		mov r13,rsi  ; indice x
		mov r14,rdx  ; indice y

		movsd [media_x],xmm0
		movsd [media_y],xmm1

        vbroadcastsd ymm0,[media_x] ; copia la media in tutto ymm0
      
		vbroadcastsd ymm1,[media_y] ; copia la media in tutto ymm1
      
		xor r9,r9 ;indice scorrimento righe
		vxorps ymm2,ymm2 ; diff_x
		vxorps ymm3,ymm3 ; diff_y
		vxorps ymm4,ymm4 ; numerator
		vxorps ymm5,ymm5 ; denominator_x
		vxorps ymm6,ymm6 ; denominator_y
		vxorps ymm7,ymm7 ; copia del registro xmm2 per mul
		
	    xor rdx,rdx
		xor rdi,rdi
		mov rax,[righe]	
		mov rdi,4
		div rdi
		sub r8,rdx

	 	imul r13,[righe]
		imul r14,[righe]
	
        pcc_ciclo: ; considerazione elementi a 4 e 4 di ogni colonna
		    cmp r9,r8	
			jge pcc_somma_par		

			vmovapd ymm2,[rbx+r13*8]
			vmovapd ymm3,[rbx+r14*8]

			vsubpd ymm2,ymm0
			vsubpd ymm3,ymm1

            vmovapd ymm7,ymm2
			vmulpd ymm7,ymm3
			vaddpd ymm4,ymm7

			vmulpd ymm2,ymm2
			vaddpd ymm5,ymm2 ;denominator_x

			vmulpd ymm3,ymm3
			vaddpd ymm6,ymm3 ;denominator_y

			add r9,4
			add r13,4
			add r14,4
 
            jmp pcc_ciclo

		pcc_somma_par: ;riduzione a un singolo double del numerator, denominator_x e denominator_y
		    vhaddpd ymm4,ymm4
			vperm2f128 ymm7,ymm4,ymm4,0x01
			vaddsd xmm4,xmm7
			
			vhaddpd ymm5,ymm5		
			vperm2f128 ymm7,ymm5,ymm5,0x01
			vaddsd xmm5,xmm7

			vhaddpd ymm6,ymm6	
			vperm2f128 ymm7,ymm6,ymm6,0x01
			vaddsd xmm6,xmm7
			
		    vxorps xmm2,xmm2
			vxorps xmm3,xmm3

            jmp pcc_residuo

		pcc_residuo: ; considerazione degli elementi residui di ogni colonna
		    cmp r9,[righe]
		 	jge pcc_fine
		   
            vmovsd xmm2,[rbx+r13*8]
		 	vmovsd xmm3,[rbx+r14*8]

			vsubsd xmm2,xmm0
			vsubsd xmm3,xmm1

            vmovsd xmm7,xmm2
			vmulsd xmm7,xmm3
			vaddsd xmm4,xmm7

			vmulsd xmm2,xmm2
			vaddsd xmm5,xmm2 ;denominator_x

			vmulsd xmm3,xmm3
			vaddsd xmm6,xmm3 ;denominator_y
            
			add r9,1
			add r13,1
			add r14,1
            jmp pcc_residuo
		pcc_fine: ; calcolo singolo pcc secondo la formula data
		    vsqrtsd xmm5,xmm5
			vsqrtsd xmm6,xmm6
			vmulsd xmm5,xmm6
			vdivsd xmm4,xmm5
			mov rax,[rcx]
			vmovsd [rcx],xmm4


		; ------------------------------------------------------------
		; Sequenza di uscita dalla funzione
  
		popaq				; ripristina i registri generali
		mov		rsp, rbp	; ripristina lo Stack Pointer
		pop		rbp		; ripristina il Base Pointer
		ret				; torna alla funzione C chiamante
