/* host_flaris.c - the embedding benchmark against libflaris. */
#include "common.h"
#include "flaris.h"

static char *SlurpScript(const char *path)
{
    FILE *f = fopen(path, "rb");
    if (!f) { perror(path); exit(1); }
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    char *buf = malloc((size_t)n + 1);
    if (fread(buf, 1, (size_t)n, f) != (size_t)n) { fprintf(stderr, "short read\n"); exit(1); }
    buf[n] = '\0';
    fclose(f);
    return buf;
}

static FlarisConfig BenchConfig(void)
{
    FlarisConfig cfg = flarisConfigDefaults;
    cfg.installSignals = FLARIS_OFF; /* a host keeps its own handlers */
    cfg.startIoPool    = FLARIS_OFF; /* no worker threads for a pure-compute script */
    return cfg;
}

int main(int argc, char **argv)
{
    int wantCall = WantCall(argc, argv);
    char *src = SlurpScript("script.fls");
    char err[256];
    long long acc = 0;

    if (!wantCall)
    {
        double t0 = NowMs();
        for (int i = 0; i < LOAD_CYCLES; i++)
        {
            FlarisConfig cfg = BenchConfig();
            if (FlarisInitVM(&cfg) != FLARIS_OK) { fprintf(stderr, "init failed\n"); return 1; }
            FlarisContext *ctx = NULL;
            if (FlarisCreateContext(NULL, &ctx) != FLARIS_OK) { fprintf(stderr, "ctx failed\n"); return 1; }
            if (FlarisLoadSourceText(ctx, src, "script.fls") != FLARIS_OK) { fprintf(stderr, "load failed\n"); return 1; }
            FlarisRunToCompletion();

            FlarisValue out = 0;
            if (FlarisCall(ctx, "Total", NULL, 0, &out, err, sizeof err) != FLARIS_OK)
            { fprintf(stderr, "Total failed: %s\n", err); return 1; }
            acc += FlarisAsInt(out);
            FlarisReleaseValue(out);

            FlarisShutdownVM(0);
        }
        Report(acc, NowMs() - t0);
        return 0;
    }

    FlarisConfig cfg = BenchConfig();
    if (FlarisInitVM(&cfg) != FLARIS_OK) { fprintf(stderr, "init failed\n"); return 1; }
    FlarisContext *ctx = NULL;
    FlarisCreateContext(NULL, &ctx);
    if (FlarisLoadSourceText(ctx, src, "script.fls") != FLARIS_OK) { fprintf(stderr, "load failed\n"); return 1; }

    double t0 = NowMs();
    for (int i = 0; i < CALLS; i++)
    {
        FlarisValue args[1] = { FlarisInt(i) };
        FlarisValue out = 0;
        if (FlarisCall(ctx, "Update", args, 1, &out, err, sizeof err) != FLARIS_OK)
        { fprintf(stderr, "Update failed: %s\n", err); return 1; }
        acc += FlarisAsInt(out);
        FlarisReleaseValue(out);
        FlarisReleaseValue(args[0]);
    }
    double el = NowMs() - t0;
    FlarisShutdownVM(0);
    Report(acc, el);
    return 0;
}
