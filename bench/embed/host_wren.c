/* host_wren.c - the embedding benchmark against libwren. */
#include "common.h"
#include "wren.h"

static char *gSrc;

static void OnWrite(WrenVM *vm, const char *text) { (void)vm; (void)text; }
static void OnError(WrenVM *vm, WrenErrorType type, const char *module, int line, const char *msg)
{
    (void)vm; (void)type;
    fprintf(stderr, "wren error [%s:%d] %s\n", module ? module : "?", line, msg);
}

static char *Slurp(const char *path)
{
    FILE *f = fopen(path, "rb");
    if (!f) { perror(path); exit(1); }
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    char *b = malloc((size_t)n + 1);
    if (fread(b, 1, (size_t)n, f) != (size_t)n) { fprintf(stderr, "short read\n"); exit(1); }
    b[n] = '\0'; fclose(f); return b;
}

static WrenVM *NewVm(void)
{
    WrenConfiguration cfg;
    wrenInitConfiguration(&cfg);
    cfg.writeFn = OnWrite;
    cfg.errorFn = OnError;
    return wrenNewVM(&cfg);
}

int main(int argc, char **argv)
{
    int wantCall = WantCall(argc, argv);
    gSrc = Slurp("script.wren");
    long long acc = 0;

    if (!wantCall)
    {
        double t0 = NowMs();
        for (int i = 0; i < LOAD_CYCLES; i++)
        {
            WrenVM *vm = NewVm();
            if (wrenInterpret(vm, "main", gSrc) != WREN_RESULT_SUCCESS) { fprintf(stderr, "load failed\n"); return 1; }

            wrenEnsureSlots(vm, 1);
            wrenGetVariable(vm, "main", "Total", 0);
            WrenHandle *fn = wrenGetSlotHandle(vm, 0);
            WrenHandle *call0 = wrenMakeCallHandle(vm, "call()");
            wrenSetSlotHandle(vm, 0, fn);
            if (wrenCall(vm, call0) != WREN_RESULT_SUCCESS) { fprintf(stderr, "Total failed\n"); return 1; }
            acc += (long long)wrenGetSlotDouble(vm, 0);
            wrenReleaseHandle(vm, fn);
            wrenReleaseHandle(vm, call0);

            wrenFreeVM(vm);
        }
        Report(acc, NowMs() - t0);
        return 0;
    }

    WrenVM *vm = NewVm();
    if (wrenInterpret(vm, "main", gSrc) != WREN_RESULT_SUCCESS) { fprintf(stderr, "load failed\n"); return 1; }

    wrenEnsureSlots(vm, 2);
    wrenGetVariable(vm, "main", "Update", 0);
    WrenHandle *fn = wrenGetSlotHandle(vm, 0);
    WrenHandle *call1 = wrenMakeCallHandle(vm, "call(_)");

    double t0 = NowMs();
    for (int i = 0; i < CALLS; i++)
    {
        wrenEnsureSlots(vm, 2);
        wrenSetSlotHandle(vm, 0, fn);
        wrenSetSlotDouble(vm, 1, (double)i);
        if (wrenCall(vm, call1) != WREN_RESULT_SUCCESS) { fprintf(stderr, "Update failed\n"); return 1; }
        acc += (long long)wrenGetSlotDouble(vm, 0);
    }
    double el = NowMs() - t0;
    wrenReleaseHandle(vm, fn);
    wrenReleaseHandle(vm, call1);
    wrenFreeVM(vm);
    Report(acc, el);
    return 0;
}
