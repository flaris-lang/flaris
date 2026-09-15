/* common.h - shared scaffolding for the embedding hosts.
 *
 * Every host is the same program written against a different engine:
 *
 *   load  - CYCLES x (create the VM, load the script, run it to completion,
 *           tear the VM down).  What a plugin host pays at startup.
 *   call  - create and load once, then call one script function CALLS times.
 *           What a per-frame update hook pays.
 *
 * Both print the suite's two lines, so the same harness reads them:
 *   result: <integer>      a value that must agree across every engine
 *   elapsed: <ms> ms       measured inside the program
 */
#ifndef EMBED_COMMON_H
#define EMBED_COMMON_H

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>

#define LOAD_CYCLES 1000
#define CALLS       1000000

static double NowMs(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec * 1000.0 + (double)ts.tv_nsec / 1e6;
}

/* Mode selection is identical in every host, so it lives here. */
static int WantCall(int argc, char **argv)
{
    if (argc > 1 && strcmp(argv[1], "call") == 0) return 1;
    if (argc > 1 && strcmp(argv[1], "load") == 0) return 0;
    fprintf(stderr, "usage: %s load|call\n", argv[0]);
    exit(2);
}

static void Report(long long result, double elapsedMs)
{
    printf("result: %lld\n", result);
    printf("elapsed: %d ms\n", (int)(elapsedMs + 0.5));
}

#endif
