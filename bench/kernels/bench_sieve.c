/* bench_sieve.c - Sieve of Eratosthenes, N=10,000,000 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static int sieve(int N) {
    unsigned char *flags = (unsigned char *)malloc((size_t)(N + 1));
    memset(flags, 1, (size_t)(N + 1));
    flags[0] = flags[1] = 0;
    for (int p = 2; (long long)p * p <= N; p++) {
        if (flags[p]) {
            for (int i = p * p; i <= N; i += p)
                flags[i] = 0;
        }
    }
    int count = 0;
    for (int i = 2; i <= N; i++)
        if (flags[i]) count++;
    free(flags);
    return count;
}

int main(void) {
    const int N = 10000000;
    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    int count = sieve(N);
    clock_gettime(CLOCK_MONOTONIC, &t1);
    long ms = (t1.tv_sec - t0.tv_sec) * 1000 + (t1.tv_nsec - t0.tv_nsec) / 1000000;
    printf("result: %d\nelapsed: %ld ms\n", count, ms);
    return 0;
}
