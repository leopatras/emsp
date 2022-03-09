all: miniws.42m wait.wasm

newthread.wasm: newthread.c
	emcc newthread.c -s ASYNCIFY -pthread -o newthread.html --preload-file sub

wait.wasm: wait.c
	emcc wait.c -s ASYNCIFY -s 'EXPORTED_RUNTIME_METHODS=["UTF8ToString"]' -o wait.js --preload-file sub

run: all
	fglrun miniws wait_user.html

hello.wasm: hello.c
	emcc hello.c -pthread -s PROXY_TO_PTHREAD -o hello.html --preload-file sub

miniws.42m: miniws.4gl
	fglcomp -M -Wall -r miniws

	
clean:
	rm -f *.wasm *.data hello.js hello.html wait.js wait.html newthread.html newthread.js newthread.worker.js hello.data hello.worker.js *.42?
