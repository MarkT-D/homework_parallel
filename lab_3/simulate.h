/*
 * simulate.h
 */

#pragma once

int MYMPI_Bcast (void* buffer, int count , MPI_Datatype datatype, int root,
        MPI_Comm communicator);

double *simulate(const int i_max, const int t_max, double *old_array,
        double *current_array, double *next_array);
