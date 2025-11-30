#include <stdio.h>
#include <mpi.h>
#include "simulate.h"

int main(int argc, char **argv)
{
    MPI_Init(&argc, &argv);

    int rank, size;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    int data;
    if (rank == 0)
        data = 42;
    else
        data = -1;

    // Call the broadcast
    MYMPI_Bcast(&data, 1, MPI_INT, 0, MPI_COMM_WORLD);
    MPI_Barrier(MPI_COMM_WORLD);

    // Print result from each rank
    printf("Rank %d of %d received value %d\n", rank, size, data);

    MPI_Finalize();
    return 0;
}