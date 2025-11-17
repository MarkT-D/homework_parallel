/*
 * simulate.c
 *
 * Implement your (parallel) simulation here!
 */

#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>

#include "simulate.h"


/* Add any global variables you may need. */
#define C_CONST 0.15 // Mentioned in the task

/* shared state across threads */
typedef struct {
    int i_max;
    int t_max;
    int nthreads;
    double *old;
    double *cur;
    double *next;
    pthread_barrier_t barrier;
} shared_t;

/* per-thread arguments */
typedef struct {
    shared_t *S;
    int tid;
    int start; 
    int end;   
} thr_arg_t;


/* Add any functions you may need (like a worker) here. */

static inline void compute_range(double *restrict next, const double *restrict cur, const double *restrict old, int i_begin, int i_end)
{
    for (int i = i_begin; i <= i_end; ++i) {
        next[i] = 2.0 * cur[i] - old[i]
                + C_CONST * (cur[i - 1] - 2.0 * cur[i] + cur[i + 1]);
    }
}

static void *worker(void *arg_void)
{
    thr_arg_t *A = (thr_arg_t *)arg_void;
    shared_t *S = A->S;

    for (int t = 0; t < S->t_max; ++t) {
        /* phase 1: compute this thread's slice of next[] */
        if (A->start <= A->end) {
            compute_range(S->next, S->cur, S->old, A->start, A->end);
        }

        /* wait for all threads to finish writing next[] */
        pthread_barrier_wait(&S->barrier);

        /* single-thread section: fix boundaries and rotate buffers */
        if (A->tid == 0) {
            S->next[0] = 0.0;
            S->next[S->i_max - 1] = 0.0;

            double *tmp = S->old;
            S->old  = S->cur;
            S->cur  = S->next;
            S->next = tmp;
        }

        /* ensure everyone sees the rotated pointers */
        pthread_barrier_wait(&S->barrier);
    }

    return NULL;
}


/*
 * Executes the entire simulation.
 *
 * Implement your code here.
 *
 * i_max: how many data points are on a single wave
 * t_max: how many iterations the simulation should run
 * num_threads: how many threads to use (excluding the main threads)
 * old_array: array of size i_max filled with data for t-1
 * current_array: array of size i_max filled with data for t
 * next_array: array of size i_max. You should fill this with t+1
 */
double *simulate(const int i_max, const int t_max, const int num_cpus,
        double *old_array, double *current_array, double *next_array)
{
    if (t_max <= 0) return current_array;

    int interior = (i_max >= 2) ? (i_max - 2) : 0;

    /* clamp thread count to available work */
    int T = num_cpus;
    if (interior == 0) T = 1;
    else if (T > interior) T = interior;

    shared_t S;
    S.i_max = i_max;
    S.t_max = t_max;
    S.nthreads = T;
    S.old  = old_array;
    S.cur  = current_array;
    S.next = next_array;

    pthread_barrier_init(&S.barrier, NULL, T);

    pthread_t *threads = (pthread_t *)malloc(sizeof(pthread_t) * T);
    thr_arg_t *args    = (thr_arg_t *)malloc(sizeof(thr_arg_t) * T);
    if (!threads || !args) {
        fprintf(stderr, "Thread allocation failed; falling back to sequential.\n");
        if (threads) free(threads);
        if (args) free(args);
        /* sequential fallback */
        for (int t = 0; t < t_max; ++t) {
            for (int i = 1; i < i_max - 1; ++i) {
                next_array[i] = 2.0 * current_array[i] - old_array[i]
                              + C_CONST * (current_array[i - 1]
                                           - 2.0 * current_array[i]
                                           + current_array[i + 1]);
            }
            next_array[0] = 0.0;
            next_array[i_max - 1] = 0.0;
            double *tmp = old_array; old_array = current_array;
            current_array = next_array; next_array = tmp;
        }
        return current_array;
    }

    /* near-equal contiguous partition of [1 .. i_max-2] */
    int base = (T > 0) ? (interior / T) : 0;
    int rem  = (T > 0) ? (interior % T) : 0;

    for (int tid = 0; tid < T; ++tid) {
        int extra = (tid < rem) ? 1 : 0;
        int len   = base + extra;

        int offset = tid * base + (tid < rem ? tid : rem);
        int start  = (len > 0) ? (1 + offset) : 1;
        int end    = (len > 0) ? (start + len - 1) : 0;

        args[tid].S     = &S;
        args[tid].tid   = tid;
        args[tid].start = start;
        args[tid].end   = end;

        pthread_create(&threads[tid], NULL, worker, &args[tid]);
    }

    for (int tid = 0; tid < T; ++tid) {
        pthread_join(threads[tid], NULL);
    }

    pthread_barrier_destroy(&S.barrier);
    free(threads);
    free(args);

    return S.cur;
}
