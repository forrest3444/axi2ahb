// pthread_yield_shim.c
#include <sched.h>

// 提供 VCS 期望的符号 pthread_yield
int pthread_yield(void) {
    return sched_yield();
}

