/* bench_fib.c - recursive Fibonacci, n=38 */
#include <stdio.h>
#include <time.h>

static long long fib(int n) {
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
}

int main(void) {
    const int n = 38;
    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    long long result = fib(n);
    clock_gettime(CLOCK_MONOTONIC, &t1);
    long ms = (t1.tv_sec - t0.tv_sec) * 1000 + (t1.tv_nsec - t0.tv_nsec) / 1000000;
    printf("result: %lld\nelapsed: %ld ms\n", result, ms);
    return 0;
}
