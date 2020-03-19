

#if defined NUMPY
#define PY_ARRAY_UNIQUE_SYMBOL NumPy
#if defined SRCLPSOLVE
#define NO_IMPORT_ARRAY
#endif
#endif

#include "Python.h"

#if defined NUMPY
/* #include "Numeric/arrayobject.h" */
#include "numpy/arrayobject.h"
#endif

#include <lpsolve/lp_lib.h>

#define quotechar "'"
#define drivername lpsolve
#define strdrivername "lpsolve"
#define caller "Python"
#define matCalloc calloc
#define matFree free

#define MatrixEl matrix
#define pMatrix MatrixObject *
#define rMatrix PyObject *
#define strArray char **

#define putlogfunc put_logfunc
#define putabortfunc put_abortfunc

#define init_lpsolve_lib() TRUE
#define exit_lpsolve_lib()

#define callerPrototype(callername) PyObject *lpsolve(LprecObject *self, PyObject *args)

#define publicargs(lpsolve) setargs(&((lpsolve)->lpsolvecaller), self, args)

#define registerExitFcn(lpsolve)

#define ExitcallerPrototype(lpsolve) if((lpsolve)->lpsolvecaller.lhs.type == -1) return(NULL); if((lpsolve)->lpsolvecaller.lhs.PyObject == NULL) { Py_INCREF(Py_None); return Py_None; } else { return (lpsolve)->lpsolvecaller.lhs.PyObject; }

#define BEGIN_INTERRUPT_IMMEDIATELY_IN_FOREIGN_CODE
#define END_INTERRUPT_IMMEDIATELY_IN_FOREIGN_CODE

typedef struct {
    int      type;
    PyObject *PyObject;
} MatrixObject;

typedef struct {
    PyObject_HEAD
    PyObject    *x_attr;        /* Attributes dictionary */
    lprec       *mylprec;       /* the real lprec */
} LprecObject;

typedef struct
{
        jmp_buf exit_mark;
        MatrixObject lhs;
        LprecObject *self;
        PyObject *args;
        int nlhs;
        int nrhs;
} structlpsolvecaller;

#define Double double
#define Long long

extern void setargs(structlpsolvecaller *lpsolvecaller, LprecObject *self, PyObject *args);
extern void Printf(char *format, ...);
