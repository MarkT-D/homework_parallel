/*
 * Assignment 1.3 — Sieve of Eratosthenes via a pipeline of filter threads.
 *
 * DESIGN (in plain words):
 *   - A single GENERATOR thread produces 2,3,4,5,... and pushes them to queue Q0.
 *   - The pipeline is a chain of FILTER threads. Each filter has:
 *       * an inbound queue (from the previous stage), and
 *       * it lazily creates an outbound queue (to the next stage) only when needed.
 *   - When a filter receives its FIRST number 'p' from inbound queue:
 *       => that number IS a prime. Print it.
 *       => for every subsequent number v from inbound:
 *            if v is NOT divisible by p, forward v to the outbound queue.
 *            the first time we need to forward, we create the outbound queue
 *            and spawn the NEXT filter that consumes from that new queue.
 *   - Termination:
 *       * By default, we run forever; Ctrl-C to exit (threads will just be killed).
 *       * If you pass "-n N", we stop after printing N primes.
 *         Implementation: once the Nth prime is printed, set g_done=1;
 *         the generator observes g_done and injects a 'POISON' sentinel (0) into Q0;
 *         each filter that receives POISON forwards it (if it has an outbound queue) and exits.
 *
 * WHY condition variables?
 *   - Bounded queues enforce back-pressure: producers block when full; consumers block when empty.
 *   - This matches the assignment's "bounded queues" requirement precisely.
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdatomic.h>
#include <signal.h>
#include <unistd.h>
#include <pthread.h>
#include "queue.h"

#define QCAP   1024   // capacity of each bounded queue (tweakable)
#define POISON 0      // sentinel value that never appears in normal stream (since we start at 2)

/* -------- Global control -------- */

// Number of primes to print before shutting down (0 = infinite)
static long g_limit = 0;

// Number of primes printed so far (atomic because multiple filters print)
static atomic_long g_printed = 0;

// When set to 1, generator stops producing and injects a poison to drain the pipeline
static atomic_int g_done = 0;

/* -------- Generator thread -------- */

typedef struct {
    queue_t *out;  // outbound queue to first filter
} gen_ctx_t;

/*
 * generator_thread:
 *   Produces 2,3,4,... and pushes them to the first queue.
 *   If g_limit>0 and g_done==1 (i.e., we printed N primes), it pushes POISON and exits.
 */
static void *generator_thread(void *arg) {
    gen_ctx_t *G = (gen_ctx_t*)arg;
    int n = 2;
    for (;;) {
        // If a limit was requested and signaled as done, send a poison and exit.
        if (g_limit > 0 && atomic_load_explicit(&g_done, memory_order_relaxed)) {
            queue_put(G->out, POISON);  // trigger downstream shutdown
            break;
        }
        queue_put(G->out, n++);
        
    }
    return NULL;
}

/* -------- Filter thread -------- */

typedef struct filter_ctx {
    queue_t *in;      // inbound queue from previous stage
    queue_t *out;     // outbound queue to next stage (created lazily)
} filter_ctx_t;

/*
 * filter_thread:
 *   - First number read is a prime: print it, bump g_printed.
 *   - For each subsequent number:
 *       * if divisible by 'prime', drop it (not a candidate anymore)
 *       * else forward:
 *           - If it's the first forward, create 'out' queue and spawn next filter.
 *   - On receiving POISON:
 *       * forward POISON (if out exists) and exit.
 */
static void *filter_thread(void *arg) {
    filter_ctx_t *F = (filter_ctx_t*)arg;
    // Detach: we won't join this thread explicitly (simplifies pipeline teardown).
    pthread_detach(pthread_self());

    // FIRST number is the next prime (unless we got a poison in shutdown race)
    int first = queue_get(F->in);
    if (first == POISON) {
        // In shutdown race: nothing to do; just stop.
        if (F->out) queue_put(F->out, POISON);
        return NULL;
    }

    const int prime = first;
    long k = atomic_fetch_add_explicit(&g_printed, 1, memory_order_relaxed) + 1;
    printf("%d\n", prime);
    fflush(stdout);

    // If we've printed the Nth prime, request shutdown.
    if (g_limit > 0 && k >= g_limit) {
        atomic_store_explicit(&g_done, 1, memory_order_relaxed);
    }

    // We'll lazily create the next stage only when we need to forward the first non-multiple.
    int created_next = 0;
    filter_ctx_t *next_ctx = NULL;
    pthread_t next_tid;

    for (;;) {
        int v = queue_get(F->in);
        if (v == POISON) {
            // Pass poison downstream if we created a next stage.
            if (created_next) queue_put(next_ctx->in, POISON);
            break; // then exit
        }
        if (v % prime != 0) {
            // v survives this filter stage.
            if (!created_next) {
                // First survivor → we must build the next stage NOW.
                queue_t *outq = (queue_t*)malloc(sizeof(queue_t));
                if (!outq || queue_init(outq, QCAP) != 0) {
                    fprintf(stderr, "Failed to create outbound queue for prime %d\n", prime);
                    // In a real app we’d signal fatal; here we just drop further forwards.
                    created_next = 0;
                    continue;
                }
                next_ctx = (filter_ctx_t*)calloc(1, sizeof(filter_ctx_t));
                next_ctx->in  = outq;
                next_ctx->out = NULL;

                pthread_create(&next_tid, NULL, filter_thread, next_ctx);
                // Detach happens inside the new filter, so we don't manage next_tid here.

                F->out = outq;
                created_next = 1;
            }
            // Forward to next stage.
            queue_put(F->out, v);
        }
        // else: divisible by 'prime' → filtered out (discard)
    }

    return NULL;
}

/* -------- Main & CLI handling -------- */

static void usage(const char *prog) {
    fprintf(stderr, "Usage: %s [-n N]\n", prog);
    fprintf(stderr, "  -n N   Print first N primes then exit (graceful).\n");
    fprintf(stderr, "  (no -n) Run indefinitely; Ctrl-C to stop.\n");
}

int main(int argc, char **argv) {
    // Parse optional "-n N"
    for (int i = 1; i < argc; ++i) {
        if (argv[i][0] == '-' && argv[i][1] == 'n' && i + 1 < argc) {
            g_limit = strtol(argv[++i], NULL, 10);
            if (g_limit <= 0) { usage(argv[0]); return 1; }
        } else {
            usage(argv[0]); return 1;
        }
    }

    // Create the first queue between generator and the first filter.
    queue_t *q0 = (queue_t*)malloc(sizeof(queue_t));
    if (!q0 || queue_init(q0, QCAP) != 0) {
        fprintf(stderr, "Failed to initialize the first queue\n");
        return 1;
    }

    // Start generator thread.
    gen_ctx_t G = { .out = q0 };
    pthread_t gen_tid;
    pthread_create(&gen_tid, NULL, generator_thread, &G);

    // Start first filter that consumes from q0.
    filter_ctx_t *F0 = (filter_ctx_t*)calloc(1, sizeof(filter_ctx_t));
    F0->in  = q0;
    F0->out = NULL;

    pthread_t f0_tid;
    pthread_create(&f0_tid, NULL, filter_thread, F0);
    pthread_detach(f0_tid); // the filter detaches itself too, but detaching here is harmless

    if (g_limit > 0) {
        // Finite mode: wait for generator to exit after N primes.
        pthread_join(gen_tid, NULL);
        // Give filters a brief moment to propagate poison and quit (not strictly required).
        usleep(100000); // 100 ms
    } else {
        // Infinite mode: keep main alive while generator runs.
        pthread_join(gen_tid, NULL); // You can also pause/sleep forever here.
    }

    // The first queue’s storage is owned by us; destroy it.
    queue_destroy(q0);
    free(q0);

    return 0;
}
