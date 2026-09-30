/* Count lines and bytes by reading one line at a time.
 *
 * The point is the line loop, not the parsing: each language uses whatever its
 * standard library offers for iterating a text file line by line, which is what
 * a program processing a log or a CSV would actually write.
 *
 * result folds both counts into one integer so a miscount in either shows up:
 *   lines * 100000000 + bytes   (the generator keeps bytes below 100 million) */
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

int main(void)
{
    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);

    FILE *f = fopen("io_input.txt", "rb");
    if (!f) { fprintf(stderr, "cannot open io_input.txt\n"); return 1; }

    char *line = NULL;
    size_t cap = 0;
    ssize_t n;
    long long lines = 0, bytes = 0;
    while ((n = getline(&line, &cap, f)) > 0) { lines++; bytes += n; }
    free(line);
    fclose(f);

    clock_gettime(CLOCK_MONOTONIC, &t1);
    printf("result: %lld\n", lines * 100000000LL + bytes);
    printf("elapsed: %lld\n",
           (long long)((t1.tv_sec - t0.tv_sec) * 1000 + (t1.tv_nsec - t0.tv_nsec) / 1000000));
    return 0;
}
