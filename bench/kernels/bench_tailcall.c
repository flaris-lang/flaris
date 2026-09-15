/* bench_tailcall.c - self-recursive tail call, depth 2,000,000 */
#include <stdio.h>
#include <time.h>

static long long tailsum(long long n, long long acc) {
    if (n == 0) return acc;
    return tailsum(n - 1, acc + n);
}

int main(void) {
    const long long n = 2000000;
    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    long long result = tailsum(n, 0);
    clock_gettime(CLOCK_MONOTONIC, &t1);
    long ms = (t1.tv_sec - t0.tv_sec) * 1000 + (t1.tv_nsec - t0.tv_nsec) / 1000000;
    printf("result: %lld\nelapsed: %ld ms\n", result, ms);
    return 0;
}
