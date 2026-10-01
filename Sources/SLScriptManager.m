#import "SLPythonBridge.h"
#import <Python/Python.h>
#import <UIKit/UIKit.h>
#import "SLLogManager.h"

static PyObject *py_sl_alert(PyObject *self, PyObject *args) {
    const char *msg;
    if (!PyArg_ParseTuple(args, "s", &msg)) return NULL;
    NSString *m = [NSString stringWithUTF8String:msg];
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"SLNetEaseMC"
                                                                       message:m
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        UIWindow *kw = nil;
        for (UIWindow *w in UIApplication.sharedApplication.windows) {
            if (w.isKeyWindow) { kw = w; break; }
        }
        UIViewController *root = kw.rootViewController;
        while (root.presentedViewController) root = root.presentedViewController;
        [root presentViewController:alert animated:YES completion:nil];
    });
    Py_RETURN_NONE;
}

static PyObject *py_sl_log(PyObject *self, PyObject *args) {
    const char *msg;
    if (!PyArg_ParseTuple(args, "s", &msg)) return NULL;
    [[SLLogManager sharedInstance] log:SLLogTypeRun feature:@"Python"
                               message:[NSString stringWithUTF8String:msg]];
    Py_RETURN_NONE;
}

static PyObject *py_sl_http_get(PyObject *self, PyObject *args) {
    const char *url;
    if (!PyArg_ParseTuple(args, "s", &url)) return NULL;
    __block NSString *result = @"";
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithURL:[NSURL URLWithString:[NSString stringWithUTF8String:url]]
      completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (data) result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
        if (err) [[SLLogManager sharedInstance] log:SLLogTypeError feature:@"HTTP"
                                            message:err.localizedDescription];
        dispatch_semaphore_signal(sem);
    }];
    [task resume];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));
    return PyUnicode_FromString([result UTF8String]);
}

static PyMethodDef SLMethods[] = {
    {"sl_alert",    py_sl_alert,    METH_VARARGS, "æ¾ç¤ºå¼¹çª"},
    {"sl_log",      py_sl_log,      METH_VARARGS, "æå°æ¥å¿"},
    {"sl_http_get", py_sl_http_get, METH_VARARGS, "GET è¯·æ±"},
    {NULL, NULL, 0, NULL}
};

static struct PyModuleDef SLModule = {
    PyModuleDef_HEAD_INIT, "scriptloader", "SLNetEaseMC bridge", -1, SLMethods
};

@implementation SLPythonBridge

+ (void)registerAll {
    // å¿é¡»å¨ Py_Initialize ä¹åãææ GIL ççº¿ç¨ä¸è°ç¨
    // æ³¨æï¼PyModule_Create å¨æ°çå¤´æä»¶ä¸­æ¯å®ï¼æå·²ç§»é¤ï¼ï¼ç»ä¸ç¨ PyModule_Create2
    if (&PyModule_Create2 == NULL) return;
    PyObject *m = PyModule_Create2(&SLModule, PYTHON_API_VERSION);
    if (!m) return;
    PyObject *modules = PyImport_GetModuleDict();
    PyDict_SetItemString(modules, "scriptloader", m);
    Py_DECREF(m);
}
@end
