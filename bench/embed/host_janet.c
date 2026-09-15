/* host_janet.c - the embedding benchmark against libjanet. */
#include "common.h"
#include <janet.h>

static char *Slurp(const char *path)
{
    FILE *f = fopen(path, "rb");
    if (!f) { perror(path); exit(1); }
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    char *b = malloc((size_t)n + 1);
    if (fread(b, 1, (size_t)n, f) != (size_t)n) { fprintf(stderr, "short read\n"); exit(1); }
    b[n] = '\0'; fclose(f); return b;
}

static JanetFunction *Resolve(JanetTable *env, const char *name)
{
    Janet v = janet_wrap_nil();
    janet_resolve(env, janet_csymbol(name), &v);
    if (!janet_checktype(v, JANET_FUNCTION)) { fprintf(stderr, "no such fn: %s\n", name); exit(1); }
    return janet_unwrap_function(v);
}

int main(int argc, char **argv)
{
    int wantCall = WantCall(argc, argv);
    char *src = Slurp("script.janet");
    long long acc = 0;

    if (!wantCall)
    {
        double t0 = NowMs();
        for (int i = 0; i < LOAD_CYCLES; i++)
        {
            janet_init();
            JanetTable *env = janet_core_env(NULL);
            Janet out = janet_wrap_nil();
            if (janet_dostring(env, src, "script.janet", &out)) { fprintf(stderr, "load failed\n"); return 1; }

            JanetFunction *total = Resolve(env, "Total");
            Janet r = janet_wrap_nil();
            if (janet_pcall(total, 0, NULL, &r, NULL) != JANET_SIGNAL_OK) { fprintf(stderr, "Total failed\n"); return 1; }
            acc += (long long)janet_unwrap_number(r);

            janet_deinit();
        }
        Report(acc, NowMs() - t0);
        return 0;
    }

    janet_init();
    JanetTable *env = janet_core_env(NULL);
    Janet out = janet_wrap_nil();
    if (janet_dostring(env, src, "script.janet", &out)) { fprintf(stderr, "load failed\n"); return 1; }
    JanetFunction *update = Resolve(env, "Update");

    double t0 = NowMs();
    for (int i = 0; i < CALLS; i++)
    {
        Janet a[1] = { janet_wrap_number((double)i) };
        Janet r = janet_wrap_nil();
        if (janet_pcall(update, 1, a, &r, NULL) != JANET_SIGNAL_OK) { fprintf(stderr, "Update failed\n"); return 1; }
        acc += (long long)janet_unwrap_number(r);
    }
    double el = NowMs() - t0;
    janet_deinit();
    Report(acc, el);
    return 0;
}
