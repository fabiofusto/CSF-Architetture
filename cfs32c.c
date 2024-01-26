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
extern void pre_calculate_means_asm(params* input, type* means);
extern void pcc_asm(params* input, int feature_x, int feature_y, type mean_feature_x, type mean_feature_y, type* p);

// Funzione che trasforma la matrice in column-major order
void transform_to_column_major(params* input) {
    MATRIX ds_column = alloc_matrix(input->d, input->N);

    for(int i = 0; i < input->N; i++)
        for(int j = 0; j < input->d; j++) 
            ds_column[j * input->N + i] = input->ds[i * input->d + j];
        
    dealloc_matrix(input->ds);
    input->ds = ds_column;
}

/* Funzione che precalcola la media totale per ogni feature
VECTOR pre_calculate_means(params* input) {
    VECTOR means = alloc_matrix(input->d, 1);

    for(int feature = 0; feature < input->d; feature++) {
        type sum = 0.0;

        for(int i = 0; i < input->N; i++) 
            sum += input->ds[feature * input->N + i];
           
        means[feature] = sum / (type) input->N; 
    }
    return means;
}
*/

// Funzione che calcola il Point Biserial Correlation Coefficient per una feature
type pbc(params* input, int feature, type mean) {
    type sum_class_0 = 0.0f, sum_class_1 = 0.0f;
    type mean_class_0 = 0.0f, mean_class_1 = 0.0f;
    type n0 = 0.0f, n1 = 0.0f;
    
	/*
		Variabili utili per la compensazione per la somma di Kahan.
		La somma di Kahan, o somma compensata, è un metodo per sommare una sequenza di numeri in virgola mobile con un errore di arrotondamento ridotto.
	
		Il principio di base è di tenere traccia della somma cumulativa degli errori di arrotondamento in una variabile separata (c0 per la classe 0, c1 per la classe 1).
		Questo errore cumulativo viene quindi sottratto dal prossimo numero da aggiungere, compensando così l'errore di arrotondamento.
		In questo modo, l'errore totale della somma finale è molto più vicino a zero rispetto a quello che sarebbe con una somma normale.
	*/ 
    type sum_diff_quad = 0.0f, c_diff = 0.0f;
    type c0 = 0.0f, c1 = 0.0f;
    
	type N_float = ((type) input->N);

    for(int i = 0; i < input->N; i++) {
        type value = input->ds[feature * input->N + i];

        // Controllo la classe di appartenenza e incremento la somma e la numerosità
        if(input->labels[i] == 0.0f) {
            type y = value - c0;
            type t = sum_class_0 + y;
            c0 = (t - sum_class_0) - y;
            sum_class_0 = t;
            n0++;
        } else {
            type y = value - c1;
            type t = sum_class_1 + y;
            c1 = (t - sum_class_1) - y;
            sum_class_1 = t;
            n1++;
        }

        // Calcolo la sommatoria del quadrato delle differenze tra valore e media
        type diff = value - mean;
        type y = (diff * diff) - c_diff;
        type t = sum_diff_quad + y;
        c_diff = (t - sum_diff_quad) - y;
        sum_diff_quad = t;		
    }

    // Calcolo le due medie di classe
    if(n0 > 0.0f) mean_class_0 = sum_class_0 / n0;
    if(n1 > 0.0f) mean_class_1 = sum_class_1 / n1;

    // Calcolo la deviazione standard
    type standard_deviation = sqrtf(sum_diff_quad / (N_float - 1.0f));

    // Calcolo la prima parte del prodotto
    type first_part = (mean_class_0 - mean_class_1) / standard_deviation;

    // Calcolo la seconda parte del prodotto che andrà sotto radice
    type sqrt_value = ((n0 * n1) / (N_float * N_float));
    
    // Calcolo il valore finale del pbc
    return fabsf(first_part * sqrtf(sqrt_value));
}

// Funzione che precalcola il valore del pbc per ogni feature
VECTOR pre_calculate_pbc(params* input, VECTOR means) {
	VECTOR pbc_values = alloc_matrix(1, input->d);
	
	for(int feature = 0; feature < input->d; feature++) 
		pbc_values[feature] = pbc(input, feature, means[feature]);
	
	return pbc_values;
}

/* Funzione che calcola il Pearson's Correlation Coefficient per due feature
type pcc(params* input, int feature_x, int feature_y, type mean_feature_x, type mean_feature_y) {
	type diff_x = 0.0, diff_y = 0.0;
    type numerator = 0.0, denominator_x = 0.0, denominator_y = 0.0;

    for(int i = 0; i < input->N; i++) {
        // Calcolo la differenza tra il valore corrente della feature e la media totale della feature
		diff_x = input->ds[feature_x * input->N + i] - mean_feature_x;
        diff_y = input->ds[feature_y * input->N + i] - mean_feature_y;
        
		// Calcolo la sommatoria del prodotto tra le differenze
		numerator += diff_x * diff_y;

		// Calcolo la sommatoria del quadrato delle differenze
        denominator_x += diff_x * diff_x;
        denominator_y += diff_y * diff_y;
    }

	// Calcolo il valore finale del pcc
	return fabsf((type) numerator / (sqrtf(denominator_x) * sqrtf(denominator_y)));
}
*/

/* 
	Funzione che precalcola i valori del pcc per ogni coppia di feature.
	
   	Restituisce un vettore di dimensione pari al numero di coppie di feature,
   	che si calcola tramite l'applicazione della formula del coefficiente binomiale.
*/
VECTOR pre_calculate_pcc(params* input, VECTOR means) {
    VECTOR pcc_values = alloc_matrix(1, (input->d * (input->d - 1) / 2));
    type* p = (type*) malloc(sizeof(type));

	int index = 0;

    // Calcola il pcc per ogni coppia di feature
    for(int i = 0; i < input->d; i++) {
        for(int j = i + 1; j < input->d; j++) {
            // Calcola il pcc per la coppia di feature (i, j)
			*p = 0.0f;
			pcc_asm(input, i, j, means[i], means[j], p);
		   	type pcc_value = *p;

            // Memorizza il pcc nell'array
            pcc_values[index++] = fabsf(pcc_value);
        }
    }

	free(p);

    return pcc_values;
}

/* 
	Funzione che calcola l'indice corretto per accedere all'array dei pcc.

   	L'array dei pcc è un array unidimensionale che memorizza i pcc per ogni coppia di feature in un modo specifico.
    Le coppie di feature sono ordinate in modo tale che la prima feature sia sempre minore della seconda.
    L'indice per una specifica coppia di feature (feature_x, feature_y) viene calcolato utilizzando la formula del coefficiente binomiale.
    La formula del coefficiente binomiale viene utilizzata per convertire l'indice di una matrice triangolare superiore in un indice di array unidimensionale.
    Se feature_x è minore di feature_y, l'indice viene calcolato come il totale di coppie di feature meno il numero di coppie rimanenti nella riga corrente più la posizione corrente nella riga.
    Se feature_x è maggiore di feature_y, l'indice viene calcolato in modo simile, ma con feature_x e feature_y scambiati.
*/
int set_correct_index(int feature_x, int feature_y, int size) {
	return (feature_x < feature_y) ? 
		((size * (size-1)) / 2) - (((size - feature_x) * (size - feature_x - 1)) / 2) + (feature_y - feature_x - 1) :
		((size * (size-1)) / 2) - (((size - feature_y) * (size - feature_y - 1)) / 2) + (feature_x - feature_y - 1);
}

// Funzione che calcola il merito di un insieme di features
type merit_score(params* input, int S_size, int feature, VECTOR means, VECTOR pbc_values, VECTOR pcc_values) {
	type pcc_sum = 0.0f, pbc_sum = 0.0f;
	int index = -1;

	// Se l'insieme S è vuoto, il merito è uguale al pbc della feature da analizzare
	if(S_size == 0) return pbc_values[feature];
	
	// Calcola il pbc e il pcc dell'insieme S corrente + la feature da analizzare
	for(int i = 0; i < S_size; i++) {
		pbc_sum += pbc_values[input->out[i]];

		// Calcola la somma dei pcc dell'insieme S corrente + la feature da analizzare
		index = set_correct_index(input->out[i], feature, input->d);
		// printf("Coppia (%d, %d) -> Indice corretto: %d\n",input->out[i], feature, index);
		pcc_sum += pcc_values[index];

		// Calcola la somma dei pcc dell'insieme S corrente
		for(int j = i + 1; j < S_size; j++) {
			index = set_correct_index(input->out[i], input->out[j], input->d);
        	pcc_sum += pcc_values[index];
		}
	}

	// Aggiunge il pbc della feature da analizzare
	pbc_sum += pbc_values[feature];
	
	// Calcola il pbc medio per tutte le feature
	type mean_pbc = pbc_sum / (S_size + 1);
	// Calcola il pcc medio per tutte le coppie di feature
	type mean_pcc = pcc_sum / ((S_size + 1) * S_size / 2);

	// Calcola e restituisce il merito dell'insieme S corrente + la feature da analizzare
	return (((type) S_size + 1) * mean_pbc) / sqrtf(((type) S_size + 1) + ((type) S_size + 1) * ((type) S_size) * mean_pcc);
}

// Come accedere ad un elemento del dataset:	input->ds[i][j] = j * input->N + i
// VALORI ATTESI k=5 -> score: 0.053390 features: [45,25,7,33,47]

void cfs(params* input) {
	int S_size = 0;

	// Vettore che tiene traccia della presenza di ogni feature in S
	int* is_feature_in_S = (int*) calloc(input->d, sizeof(int));

	type final_score = 0.0f;

	// Vettore che contiene la media totale di ogni feature
	VECTOR means = alloc_matrix(1, input->d);
    pre_calculate_means_asm(input, means);
	
	// Vettore che contiene il pbc di ogni feature
	VECTOR pbc_values = pre_calculate_pbc(input, means);

	// Vettore che contiene il pcc di ogni coppia di feature
	VECTOR pcc_values = pre_calculate_pcc(input, means);
	
	while(S_size < input->k) {
		type max_merit_score = -1.0f;
		int max_merit_feature = -1;

		/* 
			Calcola il merito per ogni feature non presente ancora in S,
			trova la feature con il merito massimo e la aggiunge al'insieme S
		*/
		for(int feature = 0; feature < input->d; feature++) {
			// Salta la feature se è già in S
			if(is_feature_in_S[feature]) continue;

			// Calcola il merito per S U {i}
			type merit = merit_score(input, S_size, feature, means, pbc_values, pcc_values);

			// Aggiorna la feature con il punteggio massimo
			if(merit > max_merit_score) {
				max_merit_score = merit;
				max_merit_feature = feature;
			}
		}

		// Aggiorna lo score
		final_score = max_merit_score;

		// printf("Feature scelta: %d, score: %f\n", max_merit_feature, max_merit_score);
	
		// Aggiungi la feature con il punteggio massimo ad S
		input->out[S_size++] = max_merit_feature;
		is_feature_in_S[max_merit_feature] = 1;
	}


	// Salva lo score dell'insieme finale S
	input->sc = final_score;

	free(is_feature_in_S);
	dealloc_matrix(means);
	dealloc_matrix(pbc_values);
	dealloc_matrix(pcc_values);
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

	// Trasforma la matrice in column-major order
    transform_to_column_major(input);
	

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
