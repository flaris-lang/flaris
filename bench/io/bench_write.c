/* Write a million formatted lines to a file.
 *
 * Formatting the line is part of the measurement on purpose: a program writing
 * a file is always producing the text as well as delivering it, and separating
 * the two would measure something nobody does. Each language uses its ordinary
 * buffered file writing - no manual buffer sizing, no memory-mapped tricks.
 *
 * The timed region includes closing the file, so a language that defers the
 * flush does not get to hide it.
 *
 * result is the byte count of the file that was produced. */
#include <stdio.h>
#include <time.h>

#define LINES 1000000

int main(void)
{
    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);

    FILE *f = fopen("io_out_c.txt", "wb");
    if (!f) { fprintf(stderr, "cannot write io_out_c.txt\n"); return 1; }
    for (long i = 0; i < LINES; i++)
        fprintf(f, "%ld payload %ld\n", i, i * 7 % 9973);
    fclose(f);

    clock_gettime(CLOCK_MONOTONIC, &t1);

    FILE *r = fopen("io_out_c.txt", "rb");
    fseek(r, 0, SEEK_END);
    long size = ftell(r);
    fclose(r);
    remove("io_out_c.txt");

    printf("result: %ld\n", size);
    printf("elapsed: %lld\n",
           (long long)((t1.tv_sec - t0.tv_sec) * 1000 + (t1.tv_nsec - t0.tv_nsec) / 1000000));
    return 0;
}
