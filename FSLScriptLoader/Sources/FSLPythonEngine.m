#import "FSLPythonEngine.h"
#import "FSLFunction.h"
#import "FSLFunctionManager.h"
#import "FSLCommon.h"
#import <dlfcn.h>
#import <string.h>

#pragma mark - CPython ABI（不依赖 Python 头文件，全部 dlsym）

typedef struct FSLPyObject {
    long ob_refcnt;
    struct FSLPyObject *ob_type;
} FSLPyObject;

typedef struct {
    const char *ml_name;
    void *ml_meth;
    int ml_flags;
    const char *ml_doc;
} FSLPyMethodDef;

/// 与 CPython PyModuleDef 内存布局一致（PyModuleDef_Base + 字段）
typedef struct {
    long ob_refcnt; void *ob_type;      // PyObject_HEAD
    void *m_init; long m_index; void *m_copy; // PyModuleDef_Base
    const char *m_name;
    const char *m_doc;
    long m_size;
    const FSLPyMethodDef *m_methods;
    void *m_slots;
    void *m_traverse;
    void *m_clear;
    void *m_free;
} FSLPyModuleDef;

#define FSL_METH_VARARGS 0x0001
#define FSL_PYTHON_API_VERSION 1013

static void *sPyHandle = NULL;
static int (*sPy_IsInitialized)(void) = NULL;
static void (*sPy_Initialize)(void) = NULL;
static int (*sPyRun_SimpleString)(const char *) = NULL;
static int (*sPyGILState_Ensure)(void) = NULL;
static void (*sPyGILState_Release)(int) = NULL;
static void *(*sPyEval_SaveThread)(void) = NULL;
static int (*sPyImport_AppendInittab)(const char *, FSLPyObject *(*)(void)) = NULL;
static FSLPyObject *(*sPyModule_Create2)(FSLPyModuleDef *, int) = NULL;
static FSLPyObject *(*sPyUnicode_FromString)(const char *) = NULL;
static FSLPyObject *(*sPyLong_FromLongLong)(long long) = NULL;
static FSLPyObject *(*sPyFloat_FromDouble)(double) = NULL;
static FSLPyObject *(*sPyBool_FromLong)(long) = NULL;
static int (*sPyArg_ParseTuple)(FSLPyObject *, const char *, ...) = NULL;
static FSLPyObject *sPyNone = NULL;

static BOOL sPyReady = NO;
static FSLFunction *sCurrentPyFunction = nil;

#pragma mark - fsl 内建模块

static FSLPyObject *FSLPyReturnNone(void) {
    if (sPyNone) sPyNone->ob_refcnt++;
    return sPyNone;
}

static FSLPyObject *FSLPyFromObjC(id value) {
    if (!value || value == NSNull.null) return FSLPyReturnNone();
    if ([value isKindOfClass:NSString.class]) {
        return sPyUnicode_FromString([value UTF8String]);
    }
    if ([value isKindOfClass:NSNumber.class]) {
        const char *t = [value objCType];
        if (strcmp(t, @encode(BOOL)) == 0 || strcmp(t, @encode(char)) == 0) {
            return sPyBool_FromLong([value boolValue] ? 1 : 0);
        }
        if (strcmp(t, @encode(double)) == 0 || strcmp(t, @encode(float)) == 0) {
            return sPyFloat_FromDouble([value doubleValue]);
        }
        return sPyLong_FromLongLong([value longLongValue]);
    }
    return sPyUnicode_FromString([[value description] UTF8String]);
}

static FSLPyObject *fsl_py_get_config(FSLPyObject *self, FSLPyObject *args) {
    const char *key = NULL;
    if (!sPyArg_ParseTuple(args, "s", &key) || !key) return FSLPyReturnNone();
    id value = [[FSLFunctionManager shared] configValueForKey:@(key) function:sCurrentPyFunction];
    return FSLPyFromObjC(value);
}

static FSLPyObject *fsl_py_should_stop(FSLPyObject *self, FSLPyObject *args) {
    BOOL stop = [[FSLFunctionManager shared] shouldStop:sCurrentPyFunction];
    return sPyBool_FromLong(stop ? 1 : 0);
}

static FSLPyObject *fsl_py_alert(FSLPyObject *self, FSLPyObject *args) {
    const char *msg = "";
    sPyArg_ParseTuple(args, "s", &msg);
    FSLShowAlert(sCurrentPyFunction.name ?: @"Python", @(msg ?: ""));
    return FSLPyReturnNone();
}

static FSLPyObject *fsl_py_log(FSLPyObject *self, FSLPyObject *args) {
    const char *msg = "";
    sPyArg_ParseTuple(args, "s", &msg);
    NSLog(@"[FSL-PY][%@] %s", sCurrentPyFunction.name, msg ?: "");
    return FSLPyReturnNone();
}

static FSLPyMethodDef sFslMethods[] = {
    {"get_config",  (void *)fsl_py_get_config,  FSL_METH_VARARGS, "get_config(key) -> value"},
    {"should_stop", (void *)fsl_py_should_stop, FSL_METH_VARARGS, "should_stop() -> bool"},
    {"alert",       (void *)fsl_py_alert,       FSL_METH_VARARGS, "alert(msg)"},
    {"log",         (void *)fsl_py_log,         FSL_METH_VARARGS, "log(msg)"},
    {NULL, NULL, 0, NULL}
};

static FSLPyModuleDef sFslModule = {
    1, NULL, NULL, -1, NULL,
    "fsl", "FSL bridge module", -1,
    sFslMethods, NULL, NULL, NULL, NULL
};

static FSLPyObject *FSLPyInit_fsl(void) {
    return sPyModule_Create2(&sFslModule, FSL_PYTHON_API_VERSION);
}

#pragma mark - 加载与初始化

static BOOL FSLLoadPythonLibrary(void) {
    if (sPyHandle) return YES;
    NSArray<NSString *> *candidates = @[
        @"@executable_path/Frameworks/Python.framework/Python",
        @"@loader_path/Frameworks/Python.framework/Python",
        @"@loader_path/Python.framework/Python",
        [NSBundle.mainBundle.privateFrameworksPath stringByAppendingPathComponent:@"Python.framework/Python"],
        @"/usr/lib/Python.framework/Python"
    ];
    for (NSString *path in candidates) {
        sPyHandle = dlopen(path.UTF8String, RTLD_LAZY | RTLD_GLOBAL);
        if (sPyHandle) break;
    }
    if (!sPyHandle) return NO;

#define FSL_PYSYM(var, name) \
    var = dlsym(sPyHandle, name); \
    if (!var) { dlclose(sPyHandle); sPyHandle = NULL; return NO; }

    FSL_PYSYM(sPy_IsInitialized, "Py_IsInitialized");
    FSL_PYSYM(sPy_Initialize, "Py_Initialize");
    FSL_PYSYM(sPyRun_SimpleString, "PyRun_SimpleString");
    FSL_PYSYM(sPyGILState_Ensure, "PyGILState_Ensure");
    FSL_PYSYM(sPyGILState_Release, "PyGILState_Release");
    FSL_PYSYM(sPyEval_SaveThread, "PyEval_SaveThread");
    FSL_PYSYM(sPyImport_AppendInittab, "PyImport_AppendInittab");
    FSL_PYSYM(sPyModule_Create2, "PyModule_Create2");
    FSL_PYSYM(sPyUnicode_FromString, "PyUnicode_FromString");
    FSL_PYSYM(sPyLong_FromLongLong, "PyLong_FromLongLong");
    FSL_PYSYM(sPyFloat_FromDouble, "PyFloat_FromDouble");
    FSL_PYSYM(sPyBool_FromLong, "PyBool_FromLong");
    FSL_PYSYM(sPyArg_ParseTuple, "PyArg_ParseTuple");
    sPyNone = (FSLPyObject *)dlsym(sPyHandle, "_Py_NoneStruct");
    if (!sPyNone) { dlclose(sPyHandle); sPyHandle = NULL; return NO; }
#undef FSL_PYSYM
    return YES;
}

static BOOL FSLEnsurePythonReady(void) {
    if (sPyReady) return YES;
    if (!FSLLoadPythonLibrary()) return NO;
    if (sPy_IsInitialized()) { sPyReady = YES; return YES; }

    // 通过 dladdr 定位 framework 内的 Resources，设置 PYTHONHOME / PYTHONPATH
    Dl_info info;
    if (dladdr((const void *)sPyRun_SimpleString, &info) && info.dli_fname) {
        NSString *fwDir = [[NSString stringWithUTF8String:info.dli_fname] stringByDeletingLastPathComponent];
        NSString *resPath = [fwDir stringByAppendingPathComponent:@"Resources"];
        if ([NSFileManager.defaultManager fileExistsAtPath:resPath]) {
            setenv("PYTHONHOME", resPath.UTF8String, 1);
            NSString *libDir = [resPath stringByAppendingPathComponent:@"lib"];
            NSMutableArray<NSString *> *paths = [NSMutableArray array];
            for (NSString *sub in [NSFileManager.defaultManager contentsOfDirectoryAtPath:libDir error:nil] ?: @[]) {
                NSString *p = [libDir stringByAppendingPathComponent:sub];
                [paths addObject:p];
                [paths addObject:[p stringByAppendingPathComponent:@"lib-dynload"]];
            }
            [paths addObject:[[FSLFunctionManager shared] storeDir]];
            setenv("PYTHONPATH", [paths componentsJoinedByString:@":"].UTF8String, 1);
        }
    }
    setenv("PYTHONDONTWRITEBYTECODE", "1", 1);
    setenv("PYTHONUNBUFFERED", "1", 1);

    sPyImport_AppendInittab("fsl", &FSLPyInit_fsl);
    sPy_Initialize();
    sPyReady = sPy_IsInitialized() != 0;
    if (sPyReady) {
        sPyEval_SaveThread(); // 释放主线程 GIL，后续统一用 GILState API
    }
    return sPyReady;
}

#pragma mark - 运行

static NSString *FSLPyQuote(NSString *str) {
    NSData *d = [NSJSONSerialization dataWithJSONObject:@[str ?: @""] options:0 error:nil];
    NSString *arr = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    return [arr substringWithRange:NSMakeRange(1, arr.length - 2)];
}

+ (void)runFunction:(FSLFunction *)fn {
    static dispatch_queue_t pyQueue = NULL;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ pyQueue = dispatch_queue_create("com.fsl.python", DISPATCH_QUEUE_SERIAL); });

    dispatch_async(pyQueue, ^{
        @autoreleasepool {
            if (!FSLEnsurePythonReady()) {
                FSLShowAlert(@"Python 引擎未就绪",
                             @"未找到 Python.framework。请把构建产物 Frameworks/Python.framework "
                             @"放入 App 的 Frameworks 目录并重新签名。JS 脚本不受影响。");
                [[FSLFunctionManager shared] markFinished:fn];
                return;
            }

            // 把脚本写到临时文件，避免引号转义问题
            NSString *tmpDir = [[[FSLFunctionManager shared] storeDir] stringByAppendingPathComponent:@"tmp"];
            [NSFileManager.defaultManager createDirectoryAtPath:tmpDir withIntermediateDirectories:YES
                                                     attributes:nil error:nil];
            NSString *scriptPath = [tmpDir stringByAppendingPathComponent:
                                    [NSString stringWithFormat:@"%@.py", fn.identifier]];
            [fn.source writeToFile:scriptPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

            NSString *bootstrap = [NSString stringWithFormat:
                @"import traceback as _fsl_tb\n"
                @"import fsl as _fsl\n"
                @"try:\n"
                @"    _fsl_code = open(%@, 'r', encoding='utf-8').read()\n"
                @"    exec(compile(_fsl_code, %@, 'exec'), {'__name__': '__main__'})\n"
                @"except SystemExit:\n"
                @"    pass\n"
                @"except Exception:\n"
                @"    _fsl.alert(_fsl_tb.format_exc())\n",
                FSLPyQuote(scriptPath), FSLPyQuote(fn.name ?: @"script")];

            sCurrentPyFunction = fn;
            int state = sPyGILState_Ensure();
            sPyRun_SimpleString(bootstrap.UTF8String);
            sPyGILState_Release(state);
            sCurrentPyFunction = nil;
        }
        [[FSLFunctionManager shared] markFinished:fn];
    });
}

@end
