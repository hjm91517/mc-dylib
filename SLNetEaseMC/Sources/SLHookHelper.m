#import "SLHookHelper.h"
#import <dlfcn.h>
#import <string.h>
#import <sys/stat.h>
#import <stdio.h>

typedef int  (*stat_fn)(const char *, struct stat *);
typedef FILE *(*fopen_fn)(const char *, const char *);

static stat_fn  orig_stat  = NULL;
static fopen_fn orig_fopen = NULL;

static int my_stat(const char *path, struct stat *buf) {
    if (path && strstr(path, "SLNetEaseMC")) return -1;
    if (orig_stat) return orig_stat(path, buf);
    return -1;
}

static FILE *my_fopen(const char *path, const char *mode) {
    if (path && strstr(path, "SLNetEaseMC")) return NULL;
    if (orig_fopen) return orig_fopen(path, mode);
    return NULL;
}

@implementation SLHookHelper

+ (void)installAntiDetectionHooks {
    orig_stat  = (stat_fn)dlsym(RTLD_DEFAULT, "stat");
    orig_fopen = (fopen_fn)dlsym(RTLD_DEFAULT, "fopen");

    // 如需真正 Hook，引入 fishhook 后启用：
    // struct rebinding r[] = {
    //   {"stat",  my_stat,  (void *)&orig_stat},
    //   {"fopen", my_fopen, (void *)&orig_fopen}
    // };
    // rebind_symbols(r, 2);

    (void)my_stat;
    (void)my_fopen;
}
@end
