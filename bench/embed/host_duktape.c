/* host_duktape.c - the embedding benchmark against libduktape. */
#include "common.h"
#include "duktape.h"

static char *Slurp(const char *path)
{
    FILE *f = fopen(path, "rb");
    if (!f) { perror(path); exit(1); }
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    char *b = malloc((size_t)n + 1);
    if (fread(b, 1, (size_t)n, f) != (size_t)n) { fprintf(stderr, "short read\n"); exit(1); }
    b[n] = '\0'; fclose(f); return b;
}

int main(int argc, char **argv)
{
    int wantCall = WantCall(argc, argv);
    char *src = Slurp("script.js");
    long long acc = 0;

    if (!wantCall)
    {
        double t0 = NowMs();
        for (int i = 0; i < LOAD_CYCLES; i++)
        {
            duk_context *ctx = duk_create_heap_default();
            if (duk_peval_string(ctx, src) != 0) { fprintf(stderr, "load failed: %s\n", duk_safe_to_string(ctx, -1)); return 1; }
            duk_pop(ctx);

            duk_get_global_string(ctx, "Total");
            if (duk_pcall(ctx, 0) != 0) { fprintf(stderr, "Total failed\n"); return 1; }
            acc += (long long)duk_get_number(ctx, -1);
            duk_pop(ctx);

            duk_destroy_heap(ctx);
        }
        Report(acc, NowMs() - t0);
        return 0;
    }

    duk_context *ctx = duk_create_heap_default();
    if (duk_peval_string(ctx, src) != 0) { fprintf(stderr, "load failed\n"); return 1; }
    duk_pop(ctx);

    double t0 = NowMs();
    for (int i = 0; i < CALLS; i++)
    {
        duk_get_global_string(ctx, "Update");
        duk_push_int(ctx, i);
        if (duk_pcall(ctx, 1) != 0) { fprintf(stderr, "Update failed\n"); return 1; }
        acc += (long long)duk_get_number(ctx, -1);
        duk_pop(ctx);
    }
    double el = NowMs() - t0;
    duk_destroy_heap(ctx);
    Report(acc, el);
    return 0;
}
