/*
 * Names: E. Ottens, M. Temchenko
 * UvAnetIDs: 14425289, 15185869
 * Course: Distributed and Parallel Programming
 *
 * Implementation of a wave equation simulation, parallelized on the GPU using
 * CUDA. The code is divided by CUDA into host and device code. The host code
 * is the CPU code while the device code is the GPU code.
 * The simulation parallelizes by using one thread per space/data point
 * computation and rotates arrays after each time step.
 */

#include <cstdlib>
#include <iostream>
#include "simulate.hh"

using namespace std;


/* Utility function, use to do error checking for CUDA calls
 *
 * Use this function like this:
 *     checkCudaCall(<cuda_call>);
 *
 * For example:
 *     checkCudaCall(cudaMalloc((void **) &deviceRGB, imgS * sizeof(color_t)));
 *
 * Special case to check the result of the last kernel invocation:
 *     kernel<<<...>>>(...);
 *     checkCudaCall(cudaGetLastError());
**/
static void checkCudaCall(cudaError_t result) {
    if (result != cudaSuccess) {
        cerr << "cuda error: " << cudaGetErrorString(result) << endl;
        exit(EXIT_FAILURE);
    }
}


/* CUDA kernel for computing one time step of the wave equation.
 *
 * The wave equation is:
 * A[i,t+1] = 2*A[i,t] - A[i,t-1] + c*(A[i-1,t] - (2*A[i,t] + A[i+1,t]))
 *
 * Each thread computes one element of the next array. The boundary elements
 * (index 0 and i_max-1) are kept at 0.
 *
 * Parameters:
 *   old_array: wave values at time t-1
 *   current_array: wave values at time t
 *   next_array: output array for wave values at time t+1
 *   i_max: number of data points in the wave
 */
__global__ void waveEquationKernel(double* old_array, double* current_array,
                                    double* next_array, const long i_max) {
    int block_index = blockIdx.x;
    int block_dimension = blockDim.x;
    int thread_index = threadIdx.x;
    // Calculate the index for this thread
    unsigned long i = block_index * block_dimension + thread_index;

    const double C = 0.15;

    // Check if this thread is within bounds and not on the boundary
    // Boundaries (i=0 and i=i_max-1) remain fixed at 0
    if (i > 0 && i < i_max - 1) {
        // Compute the wave equation for this point
        // A[i,t+1] = 2*A[i,t] - A[i,t-1] + c*(A[i-1,t] - 2*A[i,t] + A[i+1,t])
        next_array[i] = 2 * current_array[i] - old_array[i]
                + C * (current_array[i-1] - (2*current_array[i] - current_array[i+1]));
    }
}


/* Function that will simulate the wave equation, parallelized using CUDA.
 *
 * i_max: how many data points are on a single wave
 * t_max: how many iterations the simulation should run
 * block_size: how many threads per block you should use
 * old_array: array of size i_max filled with data for t-1
 * current_array: array of size i_max filled with data for t
 * next_array: array of size i_max. You should fill this with t+1
 */
double *simulate(const long i_max, const long t_max, const long block_size,
                 double *old_array, double *current_array, double *next_array) {
    // Allocate device memory (memory on the GPU) for the three arrays
    double* device_old = NULL;
    double* device_current = NULL;
    double* device_next = NULL;

    // Array size calculation in bytes
    size_t array_size = i_max * sizeof(double);

    // Allocate memory on the GPU for old_array
    checkCudaCall(cudaMalloc((void **) &device_old, array_size));
    if (device_old == NULL) {
        cerr << "Could not allocate old_array on GPU." << endl;
        return current_array;
    }

    // Allocate memory on the GPU for current_array
    checkCudaCall(cudaMalloc((void **) &device_current, array_size));
    if (device_current == NULL) {
        checkCudaCall(cudaFree(device_old));
        cerr << "Could not allocate current_array on GPU." << endl;
        return current_array;
    }

    // Allocate memory on the GPU for next_array
    checkCudaCall(cudaMalloc((void **) &device_next, array_size));
    if (device_next == NULL) {
        checkCudaCall(cudaFree(device_old));
        checkCudaCall(cudaFree(device_current));
        cerr << "Could not allocate next_array on GPU." << endl;
        return current_array;
    }

    // Copy the arrays from the CPU to the GPU to get the two previous time steps
    checkCudaCall(cudaMemcpy(device_old, old_array, array_size,
        cudaMemcpyHostToDevice));
    checkCudaCall(cudaMemcpy(device_current, current_array, array_size,
        cudaMemcpyHostToDevice));

    long num_blocks = (i_max + block_size - 1) / block_size;

    for (long t = 0; t < t_max; t++) {
        waveEquationKernel<<<num_blocks, block_size>>>(device_old,
            device_current, device_next, i_max);

        // Check for kernel launch errors
        checkCudaCall(cudaGetLastError());

        // Synchronize to ensure kernel completion before rotating arrays
        checkCudaCall(cudaDeviceSynchronize());

        // Rotate arrays for next iteration
        double* temp = device_old;
        device_old = device_current;
        device_current = device_next;
        device_next = temp;
    }

    // After t_max iterations, deviceCurrent contains the final result
    // Copy the result back from the GPU to the CPU (the host)
    checkCudaCall(cudaMemcpy(current_array, device_current, array_size,
        cudaMemcpyDeviceToHost));

    // Free device memory
    checkCudaCall(cudaFree(device_old));
    checkCudaCall(cudaFree(device_current));
    checkCudaCall(cudaFree(device_next));

    return current_array;
}

/*
 * Executes the entire simulation in sequence.
 *
 * i_max: how many data points are on a single wave
 * t_max: how many iterations the simulation should run
 * num_threads: how many threads to use (excluding the main threads)
 * old_array: array of size i_max filled with data for t-1
 * current_array: array of size i_max filled with data for t
 * next_array: array of size i_max. You should fill this with t+1
 */
double *simulateSeq(const int i_max, const int t_max, const int num_threads,
        double *old_array, double *current_array, double *next_array)
{
    double C = 0.15;
    for (int j = 0; j < t_max; j++) {

        for (int i = 0; i < i_max; i++) {

            if (i == 0 || i == i_max-1) {
                next_array[i]= 0;

            } else {

                next_array[i] = 2 * current_array[i] - old_array[i]
                + C * (current_array[i-1] - (2*current_array[i] - current_array[i+1]));

            }

        }
        double *temp = old_array;
        old_array = current_array;
        current_array = next_array;
        next_array = temp;
    }
    printf("\n");

    return current_array;
}

