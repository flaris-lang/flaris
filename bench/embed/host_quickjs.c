/* host_quickjs.c - the embedding benchmark against libquickjs. */
#include "common.h"
#include "quickjs.h"

static char *Slurp(const char *path, size_t *outLen)
{
    FILE *f = fopen(path, "rb");
    if (!f) { perror(path); exit(1); }
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    char *b = malloc((size_t)n + 1);
    if (fread(b, 1, (size_t)n, f) != (size_t)n) { fprintf(stderr, "short read\n"); exit(1); }
    b[n] = '\0'; fclose(f); *outLen = (size_t)n; return b;
}

int main(int argc, char **argv)
{
    int wantCall = WantCall(argc, argv);
    size_t srcLen = 0;
    char *src = Slurp("script.js", &srcLen);
    long long acc = 0;

    if (!wantCall)
    {
        double t0 = NowMs();
        for (int i = 0; i < LOAD_CYCLES; i++)
        {
            JSRuntime *rt = JS_NewRuntime();
            JSContext *ctx = JS_NewContext(rt);

            JSValue v = JS_Eval(ctx, src, srcLen, "script.js", JS_EVAL_TYPE_GLOBAL);
            if (JS_IsException(v)) { fprintf(stderr, "load failed\n"); return 1; }
            JS_FreeValue(ctx, v);

            JSValue global = JS_GetGlobalObject(ctx);
            JSValue fn = JS_GetPropertyStr(ctx, global, "Total");
            JSValue r = JS_Call(ctx, fn, global, 0, NULL);
            int64_t out = 0;
            JS_ToInt64(ctx, &out, r);
            acc += (long long)out;
            JS_FreeValue(ctx, r);
            JS_FreeValue(ctx, fn);
            JS_FreeValue(ctx, global);

            JS_FreeContext(ctx);
            JS_FreeRuntime(rt);
        }
        Report(acc, NowMs() - t0);
        return 0;
    }

    JSRuntime *rt = JS_NewRuntime();
    JSContext *ctx = JS_NewContext(rt);
    JSValue v = JS_Eval(ctx, src, srcLen, "script.js", JS_EVAL_TYPE_GLOBAL);
    if (JS_IsException(v)) { fprintf(stderr, "load failed\n"); return 1; }
    JS_FreeValue(ctx, v);

    JSValue global = JS_GetGlobalObject(ctx);
    JSValue fn = JS_GetPropertyStr(ctx, global, "Update");

    double t0 = NowMs();
    for (int i = 0; i < CALLS; i++)
    {
        JSValue arg = JS_NewInt32(ctx, i);
        JSValue r = JS_Call(ctx, fn, global, 1, &arg);
        int64_t out = 0;
        JS_ToInt64(ctx, &out, r);
        acc += (long long)out;
        JS_FreeValue(ctx, r);
        JS_FreeValue(ctx, arg);
    }
    double el = NowMs() - t0;
    JS_FreeValue(ctx, fn);
    JS_FreeValue(ctx, global);
    JS_FreeContext(ctx);
    JS_FreeRuntime(rt);
    Report(acc, el);
    return 0;
}
