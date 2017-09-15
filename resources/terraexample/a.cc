#include <Rinternals.h>
#include "terra.h"
#include <string.h>
#include <signal.h>
#include <unistd.h>

static lua_State * L;
extern "C" {
  SEXP initTerrific(SEXP r0){
    SEXP s=R_NilValue;
    L = luaL_newstate(); //create a plain lua state
    luaL_openlibs(L);                //initialize its libraries
    //initialize the terra state in lua
    if(terra_init(L)){
      const char *x = luaL_checkstring(L,-1);
      PROTECT(s = Rf_allocVector(STRSXP,1));
      SET_STRING_ELT(s,0,Rf_mkCharLen(x,strlen(x)));
      UNPROTECT(1);
    }
    return(s);  
  }
  SEXP modi(SEXP r0){
    for(int i=0; i< LENGTH(r0);i++)
      REAL(r0)[i] = 0.0;
    return(R_NilValue);
  }
	
  int traceback (lua_State *L) {
    if (!lua_isstring(L, 1))  /* 'message' not a string? */
      return 1;  /* keep it intact */
    lua_getfield(L, LUA_GLOBALSINDEX, "debug");
    if (!lua_istable(L, -1)) {
      lua_pop(L, 1);
      return 1;
    }
    lua_getfield(L, -1, "traceback");
    if (!lua_isfunction(L, -1)) {
      lua_pop(L, 2);
      return 1;
    }
    lua_pushvalue(L, 1);  /* pass error message */
    lua_pushinteger(L, 2);  /* skip this function and traceback */
    lua_call(L, 2, 1);  /* call debug.traceback */
    return 1;
  }


  void l_message (const char *pname, const char *msg) {
    if (pname) fprintf(stderr, "%s: ", pname);
    fprintf(stderr, "%s\n", msg);
    fflush(stderr);
  }
  void lstop (lua_State *L, lua_Debug *ar) {
    (void)ar;  /* unused arg. */
    lua_sethook(L, NULL, 0, 0);
    luaL_error(L, "interrupted!");
  }

  static void laction (int i) {
    signal(i, SIG_DFL); /* if another SIGINT happens before lstop,
			   terminate process (default action) */
    lua_sethook(L, lstop, LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, 1);
  }

  int report (lua_State *L, int status) {
    if (status && !lua_isnil(L, -1)) {
      const char *msg = lua_tostring(L, -1);
      if (msg == NULL) msg = "(error object is not a string)";
      l_message("SAPSI", msg);
      lua_pop(L, 1);
    }
    return status;
  }

  int docall (lua_State *L, int narg) {
    int status;
    int base = lua_gettop(L) - narg;  /* function index */
    lua_pushcfunction(L, traceback);  /* push traceback function */
    lua_insert(L, base);  /* put it under chunk and args */
    signal(SIGINT, laction);
    status = lua_pcall(L, narg, 1, base);
    signal(SIGINT, SIG_DFL);
    lua_remove(L, base);  
    if (status != 0) lua_gc(L, LUA_GCCOLLECT, 0);
    return status;
  }

  SEXP terraDoFile(SEXP s){
    const char *s1 = CHAR(STRING_ELT(s,0));
    int r = terra_dofile(L, s1);
    SEXP res = Rf_allocVector(INTSXP, 1);
    INTEGER(res)[0] = r;
    return(res); // 0 is okay, 1 is BAD
  }
  SEXP doTerraFunc1(SEXP _n, SEXP s1){
    lua_getfield(L, LUA_GLOBALSINDEX,CHAR(STRING_ELT(_n,0)));
    lua_pushlightuserdata(L, s1);
    int status= docall(L,1);
    report(L,status);
    if(!status){
      SEXP a = (*((SEXP *)lua_topointer (L,-1)));
      lua_pop(L,1);
      return(a);
    }
    return(R_NilValue);
  }
  
  SEXP doTerraFunc2(SEXP s1,SEXP s2){

  }
  SEXP doTerraFunc3(SEXP s1,SEXP s2, SEXP s3){

  }
  SEXP doTerraFunc4(SEXP s1,SEXP s2,SEXP s3){

  }
  SEXP doTerraFunc5(SEXP s1,SEXP s2, SEXP s3){
    
  }

}
  
