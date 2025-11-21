/*
 * simulate.c
 *
 * Implement your (parallel) simulation here!
 */

#include <stdio.h>
#include <stdlib.h>

#include "simulate.h"


/* Add any global variables you may need. */
double C = 0.15;

/* Add any functions you may need (like a worker) here. */


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
double *simulate(const int i_max, const int t_max, const int num_threads,
        double *old_array, double *current_array, double *next_array)
{
    // c = 0.15
    // new = 2*current - old + c*(current[left] - (2*current - current[right]))
    for (int j = 0; j < t_max; j++) {

        for (int i = 0; i < i_max; i++) {

            if (i == 0 || i == i_max-1) {
                next_array[i]= 0;

            } else {

                next_array[i] = 2 * current_array[i] - old_array[i]
                + C * (current_array[i-1] - (2*current_array[i] - current_array[i+1]));

            }
            // printf("%lf", next_array[i]);

        }
        double *temp = old_array;
        old_array = current_array;
        current_array = next_array;
        next_array = temp;
    }
    printf("\n");
    printf("Number of elements: %d", i_max);
    printf("\n");

    /*
     * After each timestep, you should swap the buffers around. Watch out none
     * of the threads actually use the buffers at that time.
     */


    /* You should return a pointer to the array with the final results. */
    // current_array[0] = 55555;
    return current_array;
}
