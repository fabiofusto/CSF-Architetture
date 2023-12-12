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

// funzione di comparazione di due float
int compare_float(float a, float b) {
	float tolleranza = 0.000001;
	float differenza = fabs(a-b);
	return differenza < tolleranza ? 1 : 0;
}

// funzione che calcola la numerosità del gruppo 0
int n_0(params* input) {
	int count = 0;
	
	for(int i=0; i < input->N; i++) {
		if(compare_float(input->labels[i], 0.000000)) {
			count++;
		}
	}
	
	return count;
}

// funzione che calcola la media totale dei valori di ogni feature
float media_totale(params* input, int feature) {
	float sum = 0;
	int count = 0;
	
	for(int i=0; i < input->N; i++) {
		sum += input->ds[i * input->d + feature];
		count++;
	}
	
	return count > 0 ? sum / count : 0;
}

// funzione che calcola la media dei valori di ogni feature, dato il valore di gruppo
float media_classe(params* input, int feature, float gruppo) {
	float sum = 0;
	int count = 0;

	for(int i=0; i < input->N; i++) {
		if(compare_float(input->labels[i], gruppo)) {
			sum += input->ds[i * input->d + feature];
			count++;
		}
	}
	
	return count > 0 ? sum / count : 0;
}

// funzione che calcola la deviazione standard campionaria per ogni feature
float deviazione_standard(params* input, int feature) {
	float media = media_totale(input, feature);
	float sum = 0;

	for(int i=0; i < input->N; i++) {
		float diff = pow(input->ds[i * input->d + feature] - media, 2);
		sum += diff;
	}

	float pippo = (float) 1 / (input->N-1);
	float dev = (float) sqrt((pippo) * sum);
	
	return dev;
}

// funzione che calcola il point biserial correlation coefficient per ogni feature
float point_biserial_coefficient(params* input, int feature) {
	float media_0 = media_classe(input, feature, 0);
	float media_1 = media_classe(input, feature, 1);

	float deviazione_standard_totale = deviazione_standard(input, feature);
	
	int n0 = n_0(input);
	int n1 = input->N - n0;
	
	float parte1 = (float) (media_0 - media_1) / deviazione_standard_totale;

	float sotto_radice = (float) (n0 * n1) / pow(input->N, 2);
	float parte2 = sqrt(sotto_radice);
	
	return parte1 * parte2;
}

float pearson_correlation_coefficient(params* input, int feature_x, int feature_y) {
	float diff_x = 0, diff_y = 0;
	float numeratore = 0, denominatore_1 = 0, denominatore_2 = 0;
	
	float media_feature_x = media_totale(input, feature_x);
	float media_feature_y = media_totale(input, feature_y);

	for(int i=0; i < input->N; i++) {
		diff_x = input->ds[i * input->d + feature_x] - media_feature_x;
		diff_y = input->ds[i * input->d + feature_y] - media_feature_y;
		numeratore += diff_x * diff_y;

		denominatore_1 += pow(diff_x, 2);
		denominatore_2 += pow(diff_y, 2);
	}

	return (float) numeratore / (sqrt(denominatore_1) * sqrt(denominatore_2));
}

// funzione che calcola il merito di un insieme di features
float merit_score(params* input, int S_size, int feature) {
	float merit = 0.0, pcc = 0.0, pbc = 0.0;

	pbc += point_biserial_coefficient(input, feature);
	
	if(S_size > 0) {
		for(int i = 0; i < S_size; i++) {
			pcc += pearson_correlation_coefficient(input, feature, input->out[i]);
		}
	}

	float pbc_medio = abs(pbc / S_size + 1);
	float pcc_medio = abs(pcc / S_size + 1);

	float numeratore, denominatore;
	numeratore = input->k * pbc_medio;
	denominatore = sqrt(input->k + input->k * (input->k-1) * pcc_medio);

	return (float) numeratore / denominatore;

	//printf("FEATURE %d -> pbc_medio=%f, pcc_medio=%f\n", feature, pbc_medio, pcc_medio);
}

//input->ds[i][j] = i * input->d + j
void cfs(params* input){
	// ------------------------------------------------------------
	// Codificare qui l'algoritmo di Correlation Features Selection
	// ------------------------------------------------------------


	int S_size = 0;
	float merit_scores[input->d];

	while(S_size < input->k) {
		float max_merit_score = -1;
		int max_merit_feature = -1;

		// Calcola il merito per ogni feature non presente ancora in S,
		// trova la feature con il punteggio massimo e la aggiunge al vettore input->out
		
		for(int i = 0; i < input->d; i++) {
			// Salta la feature se è già in S
            int in_S = 0;
            for (int j = 0; j < S_size; j++) {
                if (input->out[j] == i) {
                    in_S = 1;
                    break;
                }
            }
            if (in_S) continue;

			// Calcola il merito per S U {i}
			merit_scores[i] = merit_score(input, S_size, i);

			
			// Aggiorna il la feature con il punteggio massimo
			if(merit_scores[i] > max_merit_score) {
				max_merit_score = merit_scores[i];
				max_merit_feature = i;
			}

			// Aggiungi la feature con il punteggio massimo ad input->out
			S_size++;
			input->out[S_size] = max_merit_feature;
			input->sc += max_merit_score;
			
		}
	}
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
			for(i=0; i<input->k; i++){
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
