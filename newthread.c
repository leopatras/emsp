#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <pthread.h>
#include <emscripten.h>
#include <emscripten/threading.h>
#ifndef __EMSCRIPTEN_PTHREADS__
#error no threads enabled
#endif

typedef void* (*_thread_func_t)(void *);
static pthread_t start_thread( _thread_func_t func, const char *param)
{
  pthread_t thread_id;
  pthread_attr_t attr;
  int retval;
  
  (void) pthread_attr_init( &attr );
  (void) pthread_attr_setdetachstate( &attr, PTHREAD_CREATE_DETACHED );
  //(void) pthread_attr_setdetachstate( &attr, PTHREAD_CREATE_JOINABLE );
  
  if( ( retval = pthread_create( &thread_id, &attr, func, (void*) param ) ) != 0 )
  {
    fprintf( stderr, "%s: %s", __func__, strerror( retval ) );
    return 0;
  } else {
    printf("pthread created:%d\n",(int)thread_id);
  }
  
  return thread_id;
}

static void* mythread(void* param)
{
  FILE *f2;
  int num=0;
  char buffer[200];
  printf("mythread started,is main thread:%d\n",emscripten_is_main_browser_thread());
  if ((f2=fopen("sub/sub.txt","r"))==NULL) {
    fprintf(stderr,"thread:Can't open sub\n");
  } else {
    fgets(buffer,sizeof(buffer),f2);
    printf("thread did read content:%s\n",buffer);
    fclose(f2);
  }
  while (num<3) {
    printf("thread:%d\n",num++);
    emscripten_sleep(1000);
  }
  printf("thread ended\n");
  return 0;
}

static int num2=0;
int main() {
  pthread_t tid;
  char buffer[200];
  int num=0;
  getcwd(buffer,sizeof(buffer));
  printf("main started in:%s,is main thread:%d\n",buffer,emscripten_is_main_browser_thread());
  tid = start_thread(mythread, (void*)0);  
  printf("did start main thread with  %d!\n",(int)tid);
  /*
  if (tid!=0) {
    pthread_join(tid,NULL);
    printf("after pthread_join\n");
  }
  */
  while (num<3) {
    printf("main:%d %d\n",num++,num2++);
    emscripten_sleep(1000);
  }
  printf("main ended\n");
  return 0;
}
