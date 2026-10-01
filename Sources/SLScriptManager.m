#import "SLPythonBridge.h"
#import <Python/Python.h>
#import <UIKit/UIKit.h>
#import "SLLogManager.h"

static PyObject *py_sl_alert(PyObject *self, PyObject *args) {
    const char *msg = NULL;
    if (!PyArg_ParseTuple(args, "s", &msg)) return NULL;
    if (!msg) {
        PyErr_SetString(PyExc_ValueError, "sl_alert requires a non-empty message");
        return NULL;
    }

    NSString *m = [NSString stringWithUTF8String:msg];
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        for (UIWindow *w in UIApplication.sharedApplication.windows) {
            if (w.isKeyWindow) { keyWindow = w; break; }
        }
        if (!keyWindow) keyWindow = UIApplication.sharedApplication.keyWindow;

        UIViewController *root = keyWindow.rootViewController;
        if (!root) {
            [[SLLogManager sharedInstance] log:SLLogTypeError feature:@"Python"
                                     message:@"sl_alert: no root view controller available"];
            return;
        }
        while (root.presentedViewController) root = root.presentedViewController;

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"SLNetEaseMC"
                                                                       message:m
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [root presentViewController:alert animated:YES completion:nil];
    });
    Py_RETURN_NONE;
}

static PyObject *py_sl_log(PyObject *self, PyObject *args) {
    const char *msg = NULL;
    if (!PyArg_ParseTuple(args, "s", &msg)) return NULL;
    if (!msg) {
        PyErr_SetString(PyExc_ValueError, "sl_log requires a non-empty message");
        return NULL;
    }
    [[SLLogManager sharedInstance] log:SLLogTypeRun feature:@"Python"
                               message:[NSString stringWithUTF8String:msg]];
    Py_RETURN_NONE;
}

static PyObject *py_sl_http_get(PyObject *self, PyObject *args) {
    const char *url = NULL;
    if (!PyArg_ParseTuple(args, "s", &url)) return NULL;
    if (!url) {
        PyErr_SetString(PyExc_ValueError, "sl_http_get requires a valid URL");
        return NULL;
    }

    NSString *urlString = [NSString stringWithUTF8String:url];
    NSURL *requestURL = [NSURL URLWithString:urlString];
    if (!requestURL) {
        PyErr_SetString(PyExc_ValueError, "sl_http_get received an invalid URL");
        return NULL;
    }

    __block NSString *result = @"";
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithURL:requestURL
      completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (data) {
            result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
        }
        if (err) {
            [[SLLogManager sharedInstance] log:SLLogTypeError feature:@"HTTP"
                                     message:err.localizedDescription];
        }
        dispatch_semaphore_signal(sem);
    }];
    [task resume];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));
    return PyUnicode_FromString([result UTF8String]);
}

static PyMethodDef SLMethods[] = {
    {"sl_alert",    py_sl_alert,    METH_VARARGS, "Show an alert dialog"},
    {"sl_log",      py_sl_log,      METH_VARARGS, "Write a log entry"},
    {"sl_http_get", py_sl_http_get, METH_VARARGS, "HTTP GET request"},
    {NULL, NULL, 0, NULL}
};

static struct PyModuleDef SLModule = {
    PyModuleDef_HEAD_INIT, "scriptloader", "SLNetEaseMC bridge", -1, SLMethods
};

@implementation SLPythonBridge

+ (void)registerAll {
    // 必须在 Py_Initialize 之后，并且持有 GIL 的线程上调用
    // 注意：PyModule_Create 在新版本头文件中是安全的（或已移除），统一用 PyModule_Create2
    if (&PyModule_Create2 == NULL) return;
    PyObject *m = PyModule_Create2(&SLModule, PYTHON_API_VERSION);
    if (!m) return;
    PyObject *modules = PyImport_GetModuleDict();
    PyDict_SetItemString(modules, "scriptloader", m);
    Py_DECREF(m);
}
@end
