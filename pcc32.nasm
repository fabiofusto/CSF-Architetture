%include "sseutils32.nasm"

section .data			; Sezione contenente dati inizializzati
    i    dd     0
	j    dd     0


section .bss			; Sezione contenente dati non inizializzati
	alignb 16
	sc		 resd		1
	medie    resd       1
	somma    resd       1
	prova1    resd       1
	prova2    resd       1
	

section .text			; Sezione contenente il codice macchina

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
   		 
         mov ebx,[eax] ; dataset 
		 mov ecx,[eax+20] ; numero di righe N
		 mov edx,[ebp+feature_x] ; indice feature x
		 mov [i],edx 
		 mov edi,[ebp+feature_y] ; indice feature y
		 mov [j],edi
		 movss xmm0,[ebp+mean_x] ; media feature x 
		 movss xmm1,[ebp+mean_y] ; media feature y

		 xor esi,esi ;indice scorrimento
	
		 xorps xmm2,xmm2 ; diff_x
		 xorps xmm3,xmm3 ; diff_y
		 xorps xmm4,xmm4 ; numerator
		 xorps xmm5,xmm5 ; denominator_x
		 xorps xmm6,xmm6 ; denominator_y
		 xorps xmm7,xmm7 ; copia del registro xmm2 per mul
 
		

		ciclo: cmp esi, ecx
               jge somma_par
			   xor edx,edx
		 	   mov edx,[i]
		       imul edx,ecx ; feature_x *N
		       xor edi,edi
		       mov edi,[j]
		       imul edi,ecx ; feature_y *N
			   add edx,esi
			   movups xmm2,[ebx+edx*4]
			   add edi,esi
			   movups xmm3,[ebx+edi*4] 
			   subps xmm2,xmm0 ; diff_x
			   subps xmm3,xmm1 ; diff_y

               movups xmm7,xmm2
               mulps xmm7,xmm3 
			   addps xmm4,xmm7; numerator

               mulps xmm2,xmm2 
			   addps xmm5,xmm2; denominator_x
			  
			   mulps xmm3,xmm3
			   addps xmm6,xmm6; denominator_y

			   add esi,4
			   jmp ciclo

       somma_par:
                 haddps xmm4,xmm4
			     haddps xmm4,xmm4
				 haddps xmm5,xmm5
			     haddps xmm5,xmm5
				 haddps xmm6,xmm6
			     haddps xmm6,xmm6
                 jmp residuo

		residuo: sub esi,ecx
		         cmp esi,0
				 jle fine
				 add edx,esi
				 movss xmm2,[ebx+edx*4]
				 add edi,esi
				 movss xmm3,[ebx+edi*4]
   
                 subss xmm2,xmm0 ; diff_x
			     subss xmm3,xmm1 ; diff_y

				 movss xmm7,xmm2 
				 mulss xmm7,xmm3
				 addss xmm4,xmm7 ; numerator
   
                 mulss xmm2,xmm2 
			     addss xmm5,xmm2; denominator_x

			     mulss xmm3,xmm3
			     addss xmm6,xmm6; denominator_y

				 dec esi
				 jmp residuo

        fine: sqrtss xmm5,xmm5
              sqrtss xmm6,xmm6
			  mulss xmm5,xmm6
			  divss xmm4,xmm5
			  movss [ebp+output],xmm4 

		

		; ------------------------------------------------------------
		; Sequenza di uscita dalla funzione
		; ------------------------------------------------------------

		pop	edi		; ripristina i registri da preservare
		pop	esi
		pop	ebx
		mov	esp, ebp	; ripristina lo Stack Pointer
		pop	ebp		; ripristina il Base Pointer
		ret			; torna alla funzione C chiamante
