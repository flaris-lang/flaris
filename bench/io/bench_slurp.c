/* Read the whole file into memory and report its size.
 *
 * The other half of how programs read files: a config file, a JSON document or
 * a template is read in one go rather than line by line. Nothing is scanned
 * afterwards - that would measure each language's string search instead of its
 * file reading, which is what bench_readlines is for.
 *
 * result is the byte count. */
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

int main(void)
{
    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);

    FILE *f = fopen("io_input.txt", "rb");
    if (!f) { fprintf(stderr, "cannot open io_input.txt\n"); return 1; }
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    rewind(f);
    char *buf = malloc((size_t)size);
    size_t got = fread(buf, 1, (size_t)size, f);
    fclose(f);

    clock_gettime(CLOCK_MONOTONIC, &t1);
    printf("result: %zu\n", got);
    printf("elapsed: %lld\n",
           (long long)((t1.tv_sec - t0.tv_sec) * 1000 + (t1.tv_nsec - t0.tv_nsec) / 1000000));
    free(buf);
    return 0;
}
