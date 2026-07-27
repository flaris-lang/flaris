/* bench_collatz.c - total Collatz steps for n=1..1,000,000 */
#include <stdio.h>
#include <stdint.h>
#include <time.h>

static int64_t collatz_steps(int64_t n) {
    int64_t steps = 0;
    while (n != 1) {
        n = (n & 1) ? n * 3 + 1 : n >> 1;
        steps++;
    }
    return steps;
}

int main(void) {
    const int64_t N = 1000000;
    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    int64_t total = 0;
    for (int64_t i = 1; i <= N; i++)
        total += collatz_steps(i);
    clock_gettime(CLOCK_MONOTONIC, &t1);
    long ms = (t1.tv_sec - t0.tv_sec) * 1000 + (t1.tv_nsec - t0.tv_nsec) / 1000000;
    printf("result: %lld\nelapsed: %ld ms\n", (long long)total, ms);
    return 0;
}
