/*
 * simulate.c
 *
 * Implement your (parallel) simulation here!
 */

#include <stdio.h>
#include <stdlib.h>
#include <omp.h>

#include "simulate.h"

#define C_CONST 0.15  /* spatial impact constant c */

/*
 * Executes the entire simulation.
 *
 * Implement your code here.
 *
 * i_max: how many data points are on a single wave
 * t_max: how many iterations the simulation should run
 * num_threads: how many threads to use
 * old_array: array of size i_max filled with data for t-1
 * current_array: array of size i_max filled with data for t
 * next_array: array of size i_max. You should fill this with t+1
 */
double *simulate(const int i_max, const int t_max, const int num_threads,
        double *old_array, double *current_array, double *next_array)
{
    if (t_max <= 0) return current_array;

    /* Work with local pointers we’ll rotate; caller owns the storage. */
    double *old  = old_array;
    double *cur  = current_array;
    double *next = next_array;

    /* Set the requested thread count (can be overridden by OMP_NUM_THREADS). */
    omp_set_num_threads(num_threads);

    /* One parallel region around the whole time loop to avoid per-step spawn cost. */
    #pragma omp parallel default(none) shared(i_max, t_max, old, cur, next)
    {
        for (int t = 0; t < t_max; ++t) {

            /* Phase 1: all threads compute their chunk of interior points into next[]. 
               schedule(runtime) lets you switch policy/chunk via OMP_SCHEDULE at run time. */
            #pragma omp for schedule(runtime)
            for (int i = 1; i < i_max - 1; ++i) {
                next[i] = 2.0 * cur[i] - old[i]
                        + C_CONST * (cur[i - 1] - 2.0 * cur[i] + cur[i + 1]);
            }
            /* implicit barrier here at end of omp for (since no nowait) */

            /* Single-thread section: set fixed boundaries and rotate buffers. */
            #pragma omp single
            {
                next[0] = 0.0;
                next[i_max - 1] = 0.0;

                double *tmp = old;
                old = cur;
                cur = next;
                next = tmp;
            }
            /* implicit barrier at end of single (since no nowait):
               guarantees all threads see rotated pointers before next iteration */
        }
    }

    /* After t_max rotations, cur points to the final generation. */
    return cur;
}