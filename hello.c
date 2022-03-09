#include <stdio.h>
#include <unistd.h>
#ifndef __EMSCRIPTEN_PTHREADS__
#error here
#endif

int main() {
  FILE* f,*f2;
  char buffer[200];
  getcwd(buffer,sizeof(buffer));
  printf("hello, world in %s!\n",buffer);
  if ((f2=fopen("sub/sub.txt","r"))==NULL) {
    fprintf(stderr,"Can't open sub\n");
  } else {
    fgets(buffer,sizeof(buffer),f2);
    printf("content:%s\n",buffer);
    fclose(f2);
  }
  return 0;
}
