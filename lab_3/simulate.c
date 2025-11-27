/*
 * simulate.c
 *
 * Implement your (parallel) simulation here!
 */

#include <stdio.h>
#include <stdlib.h>
#include <mpi.h>

#include "simulate.h"


/* Add any global variables you may need. */

/* Wave propagation constant (lambda^2). */
const double C2 = 0.15;


/* Add any functions you may need (like a worker) here. */


/*
 * Executes the entire simulation.
 *
 * Implement your code here.
 *
 * i_max: how many data points are on a single wave
 * t_max: how many iterations the simulation should run
 * old_array: array of size i_max filled with data for t-1
 * current_array: array of size i_max filled with data for t
 * next_array: array of size i_max. You should fill this with t+1
 */
double *simulate(const int i_max, const int t_max, double *old_array,
        double *current_array, double *next_array)
{
    int rank, size;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    /* Compute 1D block decomposition: how many points per process. */
    int base = i_max / size;
    int rem  = i_max % size;

    int local_n = base + (rank < rem ? 1 : 0);

    /* Build counts and displacements arrays for Scatterv/Gatherv. */
    int *counts = malloc(size * sizeof(int));
    int *displs = malloc(size * sizeof(int));
    if (!counts || !displs) {
        fprintf(stderr, "Rank %d: failed to allocate counts/displs\n", rank);
        MPI_Abort(MPI_COMM_WORLD, 1);
    }

    for (int r = 0; r < size; r++) {
        counts[r] = base + (r < rem ? 1 : 0);
        displs[r] = r * base + (r < rem ? r : rem);
    }
    int global_start = displs[rank];

    /* Local arrays include 2 halo cells: index 0 = left halo, index local_n+1 = right halo. */
    double *old_local   = malloc((local_n + 2) * sizeof(double));
    double *curr_local  = malloc((local_n + 2) * sizeof(double));
    double *next_local  = malloc((local_n + 2) * sizeof(double));

    if (!old_local || !curr_local || !next_local) {
        fprintf(stderr, "Rank %d: failed to allocate local arrays\n", rank);
        MPI_Abort(MPI_COMM_WORLD, 1);
    }

    /* Scatter global initial data into local arrays (interior part starts at index 1). */
    MPI_Scatterv(old_array,     counts, displs, MPI_DOUBLE,
                 &old_local[1], local_n,        MPI_DOUBLE,
                 0, MPI_COMM_WORLD);

    MPI_Scatterv(current_array,     counts, displs, MPI_DOUBLE,
                 &curr_local[1],    local_n,        MPI_DOUBLE,
                 0, MPI_COMM_WORLD);

    /* Initialise halos to zero; they will be overwritten for interior ranks. */
    old_local[0] = old_local[local_n + 1] = 0.0;
    curr_local[0] = curr_local[local_n + 1] = 0.0;
    next_local[0] = next_local[local_n + 1] = 0.0;

    /* Time-stepping loop. */
    for (int t = 0; t < t_max; t++) {

        #ifdef USE_NONBLOCKING
            /* --- 3.2: fully non-blocking halo exchange --- */
            MPI_Request reqs[4];
            int nreq = 0;

            // Irecv halos
            if (rank > 0) {
                MPI_Irecv(&curr_local[0], 1, MPI_DOUBLE,
                        rank - 1, 1, MPI_COMM_WORLD, &reqs[nreq++]);
            } else {
                curr_local[0] = 0.0;
            }

            if (rank < size - 1) {
                MPI_Irecv(&curr_local[local_n + 1], 1, MPI_DOUBLE,
                        rank + 1, 0, MPI_COMM_WORLD, &reqs[nreq++]);
            } else {
                curr_local[local_n + 1] = 0.0;
            }

            // Isend boundaries
            if (rank > 0) {
                MPI_Isend(&curr_local[1], 1, MPI_DOUBLE,
                        rank - 1, 0, MPI_COMM_WORLD, &reqs[nreq++]);
            }
            if (rank < size - 1) {
                MPI_Isend(&curr_local[local_n], 1, MPI_DOUBLE,
                        rank + 1, 1, MPI_COMM_WORLD, &reqs[nreq++]);
            }

            // Compute interior j = 2 .. local_n-1
            for (int j = 2; j <= local_n - 1; j++) {
                int i_global = global_start + (j - 1);
                if (i_global == 0 || i_global == i_max - 1) {
                    next_local[j] = 0.0;
                } else {
                    double u_im1 = curr_local[j - 1];
                    double u_i   = curr_local[j];
                    double u_ip1 = curr_local[j + 1];

                    next_local[j] =
                        2.0 * u_i
                        -      old_local[j]
                        + C2 * (u_im1 - 2.0 * u_i + u_ip1);
                }
            }

            if (nreq > 0) {
                MPI_Waitall(nreq, reqs, MPI_STATUSES_IGNORE);
            }

            // Compute boundaries j=1 and j=local_n (if they exist)
            if (local_n >= 1) {
                int j = 1;
                int i_global = global_start + (j - 1);
                if (i_global == 0 || i_global == i_max - 1) {
                    next_local[j] = 0.0;
                } else {
                    double u_im1 = curr_local[j - 1];
                    double u_i   = curr_local[j];
                    double u_ip1 = curr_local[j + 1];

                    next_local[j] =
                        2.0 * u_i
                        -      old_local[j]
                        + C2 * (u_im1 - 2.0 * u_i + u_ip1);
                }
            }
            if (local_n >= 2) {
                int j = local_n;
                int i_global = global_start + (j - 1);
                if (i_global == 0 || i_global == i_max - 1) {
                    next_local[j] = 0.0;
                } else {
                    double u_im1 = curr_local[j - 1];
                    double u_i   = curr_local[j];
                    double u_ip1 = curr_local[j + 1];

                    next_local[j] =
                        2.0 * u_i
                        -      old_local[j]
                        + C2 * (u_im1 - 2.0 * u_i + u_ip1);
                }
            }

        #else
            /* --- 3.1: blocking halo exchange via Sendrecv --- */

            if (rank > 0) {
                MPI_Sendrecv(&curr_local[1],           1, MPI_DOUBLE, rank - 1, 0,
                            &curr_local[0],           1, MPI_DOUBLE, rank - 1, 1,
                            MPI_COMM_WORLD, MPI_STATUS_IGNORE);
            } else {
                curr_local[0] = 0.0;
            }

            if (rank < size - 1) {
                MPI_Sendrecv(&curr_local[local_n],     1, MPI_DOUBLE, rank + 1, 1,
                            &curr_local[local_n + 1], 1, MPI_DOUBLE, rank + 1, 0,
                            MPI_COMM_WORLD, MPI_STATUS_IGNORE);
            } else {
                curr_local[local_n + 1] = 0.0;
            }

            // Compute all points j = 1 .. local_n (halos are already valid)
            for (int j = 1; j <= local_n; j++) {
                int i_global = global_start + (j - 1);
                if (i_global == 0 || i_global == i_max - 1) {
                    next_local[j] = 0.0;
                } else {
                    double u_im1 = curr_local[j - 1];
                    double u_i   = curr_local[j];
                    double u_ip1 = curr_local[j + 1];

                    next_local[j] =
                        2.0 * u_i
                        -      old_local[j]
                        + C2 * (u_im1 - 2.0 * u_i + u_ip1);
                }
            }
        #endif

            /* Rotate the three local arrays: old <- current, current <- next, next <- old. */
            double *tmp   = old_local;
            old_local     = curr_local;
            curr_local    = next_local;
            next_local    = tmp;
        }

    /* Gather final current values back into current_array on rank 0. */
    MPI_Gatherv(&curr_local[1], local_n, MPI_DOUBLE,
                current_array,  counts,  displs, MPI_DOUBLE,
                0, MPI_COMM_WORLD);

    free(old_local);
    free(curr_local);
    free(next_local);
    free(counts);
    free(displs);

    /* Only rank 0 has a valid global result in current_array after Gatherv. */
    return current_array;
}
