/* host_lua.c - the embedding benchmark against liblua. */
#include "common.h"
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

int main(int argc, char **argv)
{
    int wantCall = WantCall(argc, argv);
    long long acc = 0;

    if (!wantCall)
    {
        double t0 = NowMs();
        for (int i = 0; i < LOAD_CYCLES; i++)
        {
            lua_State *L = luaL_newstate();
            luaL_openlibs(L);
            if (luaL_dofile(L, "script.lua") != LUA_OK)
            { fprintf(stderr, "load failed: %s\n", lua_tostring(L, -1)); return 1; }

            lua_getglobal(L, "Total");
            if (lua_pcall(L, 0, 1, 0) != LUA_OK)
            { fprintf(stderr, "Total failed: %s\n", lua_tostring(L, -1)); return 1; }
            acc += (long long)lua_tointeger(L, -1);
            lua_pop(L, 1);

            lua_close(L);
        }
        Report(acc, NowMs() - t0);
        return 0;
    }

    lua_State *L = luaL_newstate();
    luaL_openlibs(L);
    if (luaL_dofile(L, "script.lua") != LUA_OK)
    { fprintf(stderr, "load failed: %s\n", lua_tostring(L, -1)); return 1; }

    double t0 = NowMs();
    for (int i = 0; i < CALLS; i++)
    {
        lua_getglobal(L, "Update");
        lua_pushinteger(L, i);
        if (lua_pcall(L, 1, 1, 0) != LUA_OK)
        { fprintf(stderr, "Update failed: %s\n", lua_tostring(L, -1)); return 1; }
        acc += (long long)lua_tointeger(L, -1);
        lua_pop(L, 1);
    }
    double el = NowMs() - t0;
    lua_close(L);
    Report(acc, el);
    return 0;
}
