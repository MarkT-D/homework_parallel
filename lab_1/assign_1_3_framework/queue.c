// queue.c — bounded blocking ring buffer implementation.
#include "queue.h"
#include <stdlib.h>

int queue_init(queue_t *q, size_t capacity) {
    q->buf = (int*)malloc(capacity * sizeof(int));
    if (!q->buf) return -1;
    q->cap = capacity;
    q->head = q->tail = q->count = 0;
    pthread_mutex_init(&q->mtx, NULL);
    pthread_cond_init(&q->not_empty, NULL);
    pthread_cond_init(&q->not_full, NULL);
    return 0;
}

void queue_destroy(queue_t *q) {
    if (!q) return;
    pthread_mutex_destroy(&q->mtx);
    pthread_cond_destroy(&q->not_empty);
    pthread_cond_destroy(&q->not_full);
    free(q->buf);
}

void queue_put(queue_t *q, int v) {
    pthread_mutex_lock(&q->mtx);
    // If the buffer is full, wait until a consumer removes something.
    while (q->count == q->cap) {
        pthread_cond_wait(&q->not_full, &q->mtx);
    }
    // Write at tail, advance tail circularly, increase count.
    q->buf[q->tail] = v;
    q->tail = (q->tail + 1) % q->cap;
    q->count++;
    // Wake a waiting consumer (if any).
    pthread_cond_signal(&q->not_empty);
    pthread_mutex_unlock(&q->mtx);
}

int queue_get(queue_t *q) {
    pthread_mutex_lock(&q->mtx);
    // If the buffer is empty, wait until a producer inserts something.
    while (q->count == 0) {
        pthread_cond_wait(&q->not_empty, &q->mtx);
    }
    // Read at head, advance head circularly, decrease count.
    int v = q->buf[q->head];
    q->head = (q->head + 1) % q->cap;
    q->count--;
    // Wake a waiting producer (if any).
    pthread_cond_signal(&q->not_full);
    pthread_mutex_unlock(&q->mtx);
    return v;
}
