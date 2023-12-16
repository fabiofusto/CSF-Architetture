/**************************************************************************************
* 
* CdL Magistrale in Ingegneria Informatica
* Corso di Architetture e Programmazione dei Sistemi di Elaborazione - a.a. 2020/21
* 
* Progetto dell'algoritmo Attention mechanism 221 231 a
* in linguaggio assembly x86-32 + SSE
* 
* Fabrizio Angiulli, novembre 2022
* 
**************************************************************************************/

/*
* 
* Software necessario per l'esecuzione:
* 
*    NASM (www.nasm.us)
*    GCC (gcc.gnu.org)
* 
* entrambi sono disponibili come pacchetti software 
* installabili mediante il packaging tool del sistema 
* operativo; per esempio, su Ubuntu, mediante i comandi:
* 
*    sudo apt-get install nasm
*    sudo apt-get install gcc
* 
* potrebbe essere necessario installare le seguenti librerie:
* 
*    sudo apt-get install lib32gcc-4.8-dev (o altra versione)
*    sudo apt-get install libc6-dev-i386
* 
* Per generare il file eseguibile:
* 
* nasm -f elf32 att32.nasm && gcc -m32 -msse -O0 -no-pie sseutils32.o att32.o att32c.c -o att32c -lm && ./att32c $pars
* 
* oppure
* 
* ./runatt32
* 
*/

#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <string.h>
#include <time.h>
#include <libgen.h>
#include <xmmintrin.h>

#define	type		float
#define	MATRIX		type*
#define	VECTOR		type*

typedef struct {
	MATRIX ds; 		// dataset
	VECTOR labels; 	// etichette
	int* out;		// vettore contenente risultato dim=k
	type sc;		// score dell'insieme di features risultato
	int k;			// numero di features da estrarre
	int N;			// numero di righe del dataset
	int d;			// numero di colonne/feature del dataset
	int display;
	int silent;
} params;

/*
* 
*	Le funzioni sono state scritte assumento che le matrici siano memorizzate 
* 	mediante un array (float*), in modo da occupare un unico blocco
* 	di memoria, ma a scelta del candidato possono essere 
* 	memorizzate mediante array di array (float**).
* 
* 	In entrambi i casi il candidato dovr� inoltre scegliere se memorizzare le
* 	matrici per righe (row-major order) o per colonne (column major-order).
*
* 	L'assunzione corrente � che le matrici siano in row-major order.
* 
*/

void* get_block(int size, int elements) { 
	return _mm_malloc(elements*size,16); 
}

void free_block(void* p) { 
	_mm_free(p);
}

MATRIX alloc_matrix(int rows, int cols) {
	return (MATRIX) get_block(sizeof(type),rows*cols);
}

int* alloc_int_matrix(int rows, int cols) {
	return (int*) get_block(sizeof(int),rows*cols);
}

void dealloc_matrix(void* mat) {
	free_block(mat);
}

/*
* 
* 	load_data
* 	=========
* 
*	Legge da file una matrice di N righe
* 	e M colonne e la memorizza in un array lineare in row-major order
* 
* 	Codifica del file:
* 	primi 4 byte: numero di righe (N) --> numero intero
* 	successivi 4 byte: numero di colonne (M) --> numero intero
* 	successivi N*M*4 byte: matrix data in row-major order --> numeri floating-point a precisione singola
* 
*****************************************************************************
*	Se lo si ritiene opportuno, � possibile cambiare la codifica in memoria
* 	della matrice. 
*****************************************************************************
* 
*/
MATRIX load_data(char* filename, int *n, int *k) {
	FILE* fp;
	int rows, cols, status, i;
	
	fp = fopen(filename, "rb");
	
	if (fp == NULL){
		printf("'%s': bad data file name!\n", filename);
		exit(0);
	}
	
	status = fread(&cols, sizeof(int), 1, fp);
	status = fread(&rows, sizeof(int), 1, fp);
	
	MATRIX data = alloc_matrix(rows,cols);
	status = fread(data, sizeof(type), rows*cols, fp);
	fclose(fp);
	
	*n = rows;
	*k = cols;
	
	return data;
}

MATRIX load_data_int(char* filename, int *n, int *k) {
    FILE* fp;
    int rows, cols, status, i;
   
    fp = fopen(filename, "rb");
   
    if (fp == NULL){
        printf("'%s': bad data file name!\n", filename);
        exit(0);
    }
   
    status = fread(&cols, sizeof(int), 1, fp);
    status = fread(&rows, sizeof(int), 1, fp);
   
    MATRIX data = alloc_matrix(rows,cols);
    status = fread(data, sizeof(int), rows*cols, fp);
    fclose(fp);
   
    *n = rows;
    *k = cols;
   
    return data;
}

/*
* 	save_data
* 	=========
* 
*	Salva su file un array lineare in row-major order
*	come matrice di N righe e M colonne
* 
* 	Codifica del file:
* 	primi 4 byte: numero di righe (N) --> numero intero a 32 bit
* 	successivi 4 byte: numero di colonne (M) --> numero intero a 32 bit
* 	successivi N*M*4 byte: matrix data in row-major order --> numeri interi o floating-point a precisione singola
*/
void save_data(char* filename, void* X, int n, int k) {
	FILE* fp;
	int i;
	fp = fopen(filename, "wb");
	if(X != NULL){
		fwrite(&k, 4, 1, fp);
		fwrite(&n, 4, 1, fp);
		for (i = 0; i < n; i++) {
			fwrite(X, sizeof(type), k, fp);
			//printf("%i %i\n", ((int*)X)[0], ((int*)X)[1]);
			X += sizeof(type)*k;
		}
	}
	else{
		int x = 0;
		fwrite(&x, 4, 1, fp);
		fwrite(&x, 4, 1, fp);
	}
	fclose(fp);
}

/*
* 	save_out
* 	=========
* 
*	Salva su file un array lineare composto da k+1 elementi.
* 
* 	Codifica del file:
* 	primi 4 byte: contenenti l'intero 1 		--> numero intero a 32 bit
* 	successivi 4 byte: numero di elementi (k+1) --> numero intero a 32 bit
* 	successivi byte: elementi del vettore 		--> 1 numero floating-point a precisione singola e k interi
*/
void save_out(char* filename, type sc, int* X, int k) {
	FILE* fp;
	int i;
	int n = 1;
	k++;
	fp = fopen(filename, "wb");
	if(X != NULL){
		fwrite(&n, 4, 1, fp);
		fwrite(&k, 4, 1, fp);
		fwrite(&sc, sizeof(type), 1, fp);
		fwrite(X, sizeof(int), k, fp);
		//printf("%i %i\n", ((int*)X)[0], ((int*)X)[1]);
	}
	fclose(fp);
}

// PROCEDURE ASSEMBLY

extern void prova(params* input);

// Funzione di comparazione di due float
int compare_float(float a, float b) {
	float tolleranza = 0.000001;
	float differenza = fabs(a-b);
	return differenza < tolleranza ? 1 : 0;
}

// Funzione che calcola la media totale dei valori di una feature
float media_totale(params* input, int feature) {
	float sum = 0;
	int count = 0;
	
	for(int i = 0; i < input->N; i++) {
		sum += input->ds[i * input->d + feature];
		count++;
	}
	
	return count > 0 ? sum / count : 0;
}

// Funzione che calcola il Point Biserial Correlation Coefficient per una feature
float pbc(params* input, int feature) {
	float somma_classe_0 = 0.0, somma_classe_1 = 0.0, somma_tot = 0.0;
	float media_classe_0 = 0.0, media_classe_1 = 0.0;
    int n0 = 0, n1 = 0;

	for(int i = 0; i < input->N; i++) {
		// Valore attuale nella colonna corrispondente alla feature
		float val = input->ds[i * input->d + feature];

		// Controllo la classe di appartenenza e incremento la somma e la numerosità
		if(compare_float(input->labels[i], 0.0)) {
			somma_classe_0 += val;
			n0++;
		} else {
			somma_classe_1 += val;
			n1++;
		}

		// Incremento la somma totale dei valori della feature
		somma_tot += val;
	}

	// Calcolo le due medie di classe e la media totale
	if(n0 > 0 && n1 > 0) {
		media_classe_0 = (float) somma_classe_0 / n0;
		media_classe_1 = (float) somma_classe_1 / n1;
	}
	float media_tot = (float) somma_tot / input->N;

	// Calcolo la deviazione standard
	float somma_diff_quad = 0.0;
	for(int i = 0; i < input->N; i++) {
		float diff = input->ds[i * input->d + feature] - media_tot;
		somma_diff_quad += diff * diff;
	}
	float deviazione_standard_totale = 0.0;
	if(somma_diff_quad > 0)
		deviazione_standard_totale = sqrt(somma_diff_quad / (input->N - 1));

	// Calcolo la prima parte del prodotto
	float parte1 = (float) (media_classe_0 - media_classe_1) / deviazione_standard_totale;

	// Calcolo la seconda parte del prodotto che andrà sotto radice
	float sotto_radice = (float) (n0 * n1) / (input->N * input->N);
	
	// Calcolo il valore finale del pbc
	return parte1 * sqrt(sotto_radice);
}

// Funzione che calcola il Pearson's Correlation Coefficient per due feature
float pcc(params* input, int feature_x, int feature_y) {
	float diff_x = 0.0, diff_y = 0.0;
    float numeratore = 0.0, denominatore_x = 0.0, denominatore_y = 0.0;
    
	// Calcolo la media totale per i valori delle due feature
    float media_feature_x = media_totale(input, feature_x);
    float media_feature_y = media_totale(input, feature_y);

    for(int i = 0; i < input->N; i++) {
        // Calcolo la differenza tra il valore corrente della feature e la media totale della feature
		diff_x = input->ds[i * input->d + feature_x] - media_feature_x;
        diff_y = input->ds[i * input->d + feature_y] - media_feature_y;
        
		// Calcolo la sommatoria del prodotto tra le differenze
		numeratore += diff_x * diff_y;

		// Calcolo la sommatoria del quadrato delle differenze
        denominatore_x += diff_x * diff_x;
        denominatore_y += diff_y * diff_y;
    }

	// Calcolo il valore finale del pcc
    return (float) numeratore / (sqrt(denominatore_x) * sqrt(denominatore_y));
}

// Funzione che calcola il merito di un insieme di features
float merit_score(params* input, int S_size, int feature) {
	float pcc_sum = 0.0, pbc_sum = 0.0;
	
	// Se l'insieme S è vuoto, il merito è uguale al pbc della feature da analizzare
	if(S_size == 0) 
		return (float) fabs(pbc(input, feature));

	// Calcola il pbc e il pcc dell'insieme S corrente + la feature da analizzare
	for(int i = 0; i < S_size; i++) {
		pbc_sum += fabs(pbc(input, input->out[i]));
		pcc_sum += fabs(pcc(input, feature, input->out[i]));

    	for(int j = i + 1; j < S_size; j++) 
        	pcc_sum += fabs(pcc(input, input->out[i], input->out[j]));
	}

	// Aggiunge il pbc della feature da analizzare
	pbc_sum += fabs(pbc(input, feature));
	
	// Calcola il pbc medio per tutte le feature
	float pbc_medio = pbc_sum / (S_size + 1);
	// Calcola il pcc medio per tutte le coppie di feature
	float pcc_medio = pcc_sum / ((S_size + 1) * S_size / 2);

	// Calcola e restituisce il merito dell'insieme S corrente + la feature da analizzare
	return (float) ((S_size + 1) * pbc_medio) / sqrt((S_size + 1) + (S_size + 1) * S_size * pcc_medio);
}

// Come accedere ad un elemento del dataset:	input->ds[i][j] = i * input->d + j
// VALORI ATTESI -> score: 0.053390 features: 45 25 7 33 47

void cfs(params* input){
	// Contatore che tiene traccia della dimensione attuale di S
	int S_size = 0;

	// Vettore che tiene traccia della presenza di ogni feature in S
	int* is_feature_in_S = (int*) calloc(input->d , sizeof(int));

	float max_merit_score = -1;
	int max_merit_feature = -1;
	
	while(S_size < input->k) {
		// Calcola il merito per ogni feature non presente ancora in S,
		// trova la feature con il punteggio massimo di merito e la aggiunge al vettore S
       
		for(int i = 0; i < input->d; i++) {
			// Salta la feature se è già in S
			if (is_feature_in_S[i]) continue;

			// Calcola il merito per S U {i}
			float merit = merit_score(input, S_size, i);

			// Aggiorna la feature con il punteggio massimo
			if(merit > max_merit_score) {
				max_merit_score = merit;
				max_merit_feature = i;
			}
		}
	
		// Aggiungi la feature con il punteggio massimo ad S
		input->out[S_size++] = max_merit_feature;
		is_feature_in_S[max_merit_feature] = 1;
	}

	input->sc = max_merit_score;

	free(is_feature_in_S);
}

int main(int argc, char** argv) {

	char fname[256];
	char* dsfilename = NULL;
	char* labelsfilename = NULL;
	clock_t t;
	float time;
	
	//
	// Imposta i valori di default dei parametri
	//

	params* input = malloc(sizeof(params));

	input->ds = NULL;
	input->labels = NULL;
	input->k = -1;
	input->sc = -1;

	input->silent = 0;
	input->display = 0;

	//
	// Visualizza la sintassi del passaggio dei parametri da riga comandi
	//

	if(argc <= 1){
		printf("%s -ds <DS> -labels <LABELS> -k <K> [-s] [-d]\n", argv[0]);
		printf("\nParameters:\n");
		printf("\tDS: il nome del file ds2 contenente il dataset\n");
		printf("\tLABELS: il nome del file ds2 contenente le etichette\n");
		printf("\tk: numero di features da estrarre\n");
		printf("\nOptions:\n");
		printf("\t-s: modo silenzioso, nessuna stampa, default 0 - false\n");
		printf("\t-d: stampa a video i risultati, default 0 - false\n");
		exit(0);
	}

	//
	// Legge i valori dei parametri da riga comandi
	//

	int par = 1;
	while (par < argc) {
		if (strcmp(argv[par],"-s") == 0) {
			input->silent = 1;
			par++;
		} else if (strcmp(argv[par],"-d") == 0) {
			input->display = 1;
			par++;
		} else if (strcmp(argv[par],"-ds") == 0) {
			par++;
			if (par >= argc) {
				printf("Missing dataset file name!\n");
				exit(1);
			}
			dsfilename = argv[par];
			par++;
		} else if (strcmp(argv[par],"-labels") == 0) {
			par++;
			if (par >= argc) {
				printf("Missing labels file name!\n");
				exit(1);
			}
			labelsfilename = argv[par];
			par++;
		} else if (strcmp(argv[par],"-k") == 0) {
			par++;
			if (par >= argc) {
				printf("Missing k value!\n");
				exit(1);
			}
			input->k = atoi(argv[par]);
			par++;
		} else{
			printf("WARNING: unrecognized parameter '%s'!\n",argv[par]);
			par++;
		}
	}

	//
	// Legge i dati e verifica la correttezza dei parametri
	//

	if(dsfilename == NULL || strlen(dsfilename) == 0){
		printf("Missing ds file name!\n");
		exit(1);
	}

	if(labelsfilename == NULL || strlen(labelsfilename) == 0){
		printf("Missing labels file name!\n");
		exit(1);
	}


	input->ds = load_data(dsfilename, &input->N, &input->d);

	int nl, dl;
	input->labels = load_data(labelsfilename, &nl, &dl);
	
	if(nl != input->N || dl != 1){
		printf("Invalid size of labels file, should be %ix1!\n", input->N);
		exit(1);
	} 

	if(input->k <= 0){
		printf("Invalid value of k parameter!\n");
		exit(1);
	}

	input->out = alloc_int_matrix(input->k, 1);

	//
	// Visualizza il valore dei parametri
	//

	if(!input->silent){
		printf("Dataset file name: '%s'\n", dsfilename);
		printf("Labels file name: '%s'\n", labelsfilename);
		printf("Dataset row number: %d\n", input->N);
		printf("Dataset column number: %d\n", input->d);
		printf("Number of features to extract: %d\n", input->k);
	}

	// COMMENTARE QUESTA RIGA!
	// prova(input);
	//

	//
	// Correlation Features Selection
	//

	t = clock();
	cfs(input);
	t = clock() - t;
	time = ((float)t)/CLOCKS_PER_SEC;

	if(!input->silent)
		printf("CFS time = %.3f secs\n", time);
	else
		printf("%.3f\n", time);

	//
	// Salva il risultato
	//
	sprintf(fname, "out32_%d_%d_%d.ds2", input->N, input->d, input->k);
	save_out(fname, input->sc, input->out, input->k);
	if(input->display){
		if(input->out == NULL)
			printf("out: NULL\n");
		else{
			int i,j;
			printf("sc: %f, out: [", input->sc);
			// Fixed to not print ',' for the last element
			for(i=0; i<input->k; i++){
				if(i==input->k-1)
					printf("%i", input->out[i]);
				else
					printf("%i,", input->out[i]);
			}
			printf("]\n");
		}
	}

	if(!input->silent)
		printf("\nDone.\n");

	dealloc_matrix(input->ds);
	dealloc_matrix(input->labels);
	dealloc_matrix(input->out);
	free(input);

	return 0;
}
