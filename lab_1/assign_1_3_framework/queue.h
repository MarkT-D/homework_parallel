// queue.h — Bounded blocking queue for ints using pthread mutex + condvars.
// Each pipeline link is 1 producer + 1 consumer, but this queue is safe for multiple producers too.

#pragma once
#include <pthread.h>
#include <stddef.h>

typedef struct {
    int            *buf;       // circular buffer storage
    size_t          cap;       // capacity (number of int slots)
    size_t          head;      // index to read next item
    size_t          tail;      // index to write next item
    size_t          count;     // number of items currently stored
    pthread_mutex_t mtx;       // protects all fields above
    pthread_cond_t  not_empty; // signaled when an item is put
    pthread_cond_t  not_full;  // signaled when an item is taken
} queue_t;

// Initialize/destroy the queue. Returns 0 on success.
int  queue_init(queue_t *q, size_t capacity);
void queue_destroy(queue_t *q);

// Blocking put/get. Put waits if queue is full; Get waits if empty.
void queue_put(queue_t *q, int v);
int  queue_get(queue_t *q);
