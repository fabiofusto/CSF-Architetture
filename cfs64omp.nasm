%include "./sseutils64.nasm"

section .data			; Sezione contenente dati inizializzati
    colonne dq  0
	righe   dq  0
    costante dq 60
	indice_x dq 0
	indice_y dq 0
	media_x dq 0
	media_y dq 0


section .bss			; Sezione contenente dati non inizializzati
   
alignb 32
medie   resq        4
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
		xor r11,r11
		
		for_loop1:
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
			vxorps ymm8,ymm8
			vxorps ymm9,ymm9
			vxorps ymm10,ymm10
			vxorps ymm11,ymm11
			vxorps ymm12,ymm12
			vxorps ymm13,ymm13
			vxorps ymm14,ymm14
			vxorps ymm15,ymm15
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
			vaddpd ymm8,[rbx+rax*8+224]
			vaddpd ymm9,[rbx+rax*8+256]
		    vaddpd ymm10,[rbx+rax*8+288]
			vaddpd ymm11,[rbx+rax*8+320]
			vaddpd ymm12,[rbx+rax*8+352]
			vaddpd ymm13,[rbx+rax*8+384]
			vaddpd ymm14,[rbx+rax*8+416]
			vaddpd ymm15,[rbx+rax*8+448]
		    add r9,[costante]
			jmp for_loop2;   
		residuo:
		    cmp r9,[righe]
		    jge media
            xor rax,rax
			mov rax,r10
			imul rax,[righe]
			add rax,r9
			vaddsd xmm0,[rbx+rax*8]  
	   		inc r9
			jmp residuo
		media:  
	        vaddpd ymm1,ymm15
		  	vaddpd ymm1,ymm14
		  	vaddpd ymm2,ymm13
		  	vaddpd ymm3,ymm12
		  	vaddpd ymm4,ymm11
		 	vaddpd ymm5,ymm10
			vaddpd ymm6,ymm9
		  	vaddpd ymm7,ymm8
		  	vaddpd ymm1,ymm7
		  	vaddpd ymm1,ymm6
		  	vaddpd ymm2,ymm5
		 	vaddpd ymm3,ymm4
			vaddpd ymm3,ymm2
			vaddpd ymm1,ymm3
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
 		
		mov r10,rsi  ; indice x
		mov r11,rdx  ; indice y

		vmovsd [media_x],xmm0
		vmovsd [media_y],xmm1

        vbroadcastsd ymm0,[media_x] ; copia la media in tutto 
        
		vbroadcastsd ymm1,[media_y] ; copia la media in tutto ymm1

		xor r9,r9 ;indice scorrimento righe
		vxorps ymm2,ymm2 ; diff_x
		vxorps ymm3,ymm3 ; diff_y
		vxorps ymm4,ymm4 ; numerator
		vxorps ymm5,ymm5 ; denominator_x
		vxorps ymm6,ymm6 ; denominator_y
		vxorps ymm7,ymm7 ; copia del registro xmm2 per mul
		vxorps ymm8,ymm8 ; copia registro 
		vxorps ymm10,ymm10 ; diff_x_2
		vxorps ymm11,ymm11 ; diff_y_2
		vxorps ymm12,ymm12 ; diff_x_3
		vxorps ymm13,ymm13 ; diff_y_3
		vxorps ymm14,ymm14 ; denominator_y
		vxorps ymm15,ymm15 ; copia del registro xmm2 per mul
		
	    xor rdx,rdx
		xor rdi,rdi
		mov rax,[righe]	
		mov rdi,16
		div rdi
		sub r8,rdx

	 	imul r10,[righe]
		imul r11,[righe]
	
        pcc_ciclo: 
		    cmp r9,r8	
			jge pcc_somma_par		

			vmovapd ymm2,[rbx+r10*8]
			vmovapd ymm3,[rbx+r11*8]
			vmovapd ymm10,[rbx+r10*8+32]
			vmovapd ymm11,[rbx+r11*8+32]
			vmovapd ymm12,[rbx+r10*8+64]
			vmovapd ymm13,[rbx+r11*8+64]
			vmovapd ymm14,[rbx+r10*8+96]
			vmovapd ymm15,[rbx+r11*8+96]

			vsubpd ymm2,ymm0
			vsubpd ymm3,ymm1
			vsubpd ymm10,ymm0
			vsubpd ymm11,ymm1
			vsubpd ymm12,ymm0
			vsubpd ymm13,ymm1
			vsubpd ymm14,ymm0
			vsubpd ymm15,ymm1

            vmovapd ymm7,ymm2
			vmulpd ymm7,ymm3
			vaddpd ymm4,ymm7

			vmovapd ymm8,ymm10
			vmulpd ymm8,ymm11
			vaddpd ymm4,ymm8
			
            vmovapd ymm7,ymm12
			vmulpd ymm7,ymm13
			vaddpd ymm4,ymm7

			vmovapd ymm8,ymm14
			vmulpd ymm8,ymm15
			vaddpd ymm4,ymm8

			vmulpd ymm2,ymm2
			vaddpd ymm5,ymm2 ;denominator_x

			vmulpd ymm3,ymm3
			vaddpd ymm6,ymm3 ;denominator_y

			vmulpd ymm10,ymm10
			vaddpd ymm5,ymm10 ;denominator_x

			vmulpd ymm11,ymm11
			vaddpd ymm6,ymm11 ;denominator_y

			vmulpd ymm12,ymm12
			vaddpd ymm5,ymm12 ;denominator_x

			vmulpd ymm13,ymm13
			vaddpd ymm6,ymm13 ;denominator_y

			vmulpd ymm14,ymm14
			vaddpd ymm5,ymm14 ;denominator_x

			vmulpd ymm15,ymm15
			vaddpd ymm6,ymm15 ;denominator_y

			add r9,16
			add r10,16
			add r11,16
 
            jmp pcc_ciclo

		pcc_somma_par:
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

		pcc_residuo:
		    cmp r9,[righe]
		 	jge pcc_fine
		   
            vmovsd xmm2,[rbx+r10*8]
		 	vmovsd xmm3,[rbx+r11*8]

			vsubsd xmm2,xmm0
			vsubsd xmm3,xmm1

            vmovsd xmm7,xmm2
			vmulsd xmm7,xmm3
			vaddsd xmm4,xmm7

			vmulsd xmm2,xmm2
			vaddsd xmm5,xmm2 ;denominator_x

			vmulsd xmm3,xmm3
			vaddsd xmm6,xmm3 ;denominator_y
            
		    inc r9
			inc r10
			inc r11
			
            jmp pcc_residuo
		pcc_fine:
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

