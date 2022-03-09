#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <pthread.h>
#include <emscripten.h>
#include <emscripten/threading.h>
/*
#ifndef __EMSCRIPTEN_PTHREADS__
#error no threads enabled
#endif
*/
EM_ASYNC_JS(char*,awaitEv,(),{
  console.log('before');
  function waitListener(el) {
    return new Promise(function (resolve, reject) {
        var evfunc = function(event) {
            el.removeEventListener("special", evfunc);
            resolve(event);
        };
        el.addEventListener("special", evfunc,false);
    });
  }
  var ret="";
  await waitListener(document).then(function(e){
    ret=e.detail;
    console.log('e.detail: '+e.detail);
  });
  console.log('after');
  var lengthBytes = lengthBytesUTF8(ret)+1;
  // 'ret.length' would return the length of the string as UTF-16
  // units, but Emscripten C strings operate as UTF-8.
  var stringOnWasmHeap = _malloc(lengthBytes);
  stringToUTF8(ret, stringOnWasmHeap, lengthBytes);
  return stringOnWasmHeap;
});

EM_JS(void, funcWithCharP, (const char* p), {
   console.log("funcWithCharP called: " + Module.UTF8ToString(p));
});

int main() {
  char* ret;
  emscripten_run_script(
    "var event = new CustomEvent('special', {detail: 'The detail'});\n"
    "function disp() { document.dispatchEvent(event); }\n"
  );
  char buffer[200];
  getcwd(buffer,sizeof(buffer));
  printf("main started in:%s,is main thread:%d\n",buffer,emscripten_is_main_browser_thread());
  ret=awaitEv();
  printf("awaitEv returned:%s\n",ret);
  funcWithCharP(ret);
  free(ret);
  printf("main ended\n");
  return 0;
}
