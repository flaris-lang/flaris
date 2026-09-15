/* host_native.c - the floor: no scripting engine at all.
 *
 * The same Update() written in C and called directly, so the per-call tables
 * have a zero to measure the boundary against. There is nothing to load, so
 * this host implements the call scenario only. `volatile` and the extern
 * declaration keep the optimiser from folding the loop away, which would
 * report 0 ms and mean nothing. */
#include "common.h"

long long UpdateNative(long long n);
long long UpdateNative(long long n) { return n + 1; }

int main(int argc, char **argv)
{
    if (WantCall(argc, argv) == 0)
    {
        fprintf(stderr, "host_native: no engine to load; call scenario only\n");
        return 3;
    }

    volatile long long acc = 0;
    double t0 = NowMs();
    for (int i = 0; i < CALLS; i++)
        acc += UpdateNative(i);
    double el = NowMs() - t0;
    Report((long long)acc, el);
    return 0;
}
