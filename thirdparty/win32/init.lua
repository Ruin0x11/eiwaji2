local ffi = require("ffi")

ffi.cdef[[
typedef unsigned long       DWORD;
typedef int                 BOOL;
typedef unsigned char       BYTE;
typedef unsigned short      WORD;
typedef float               FLOAT;
typedef void                VOID;
typedef char                CHAR;
typedef short               SHORT;
typedef long                LONG;
typedef int                 INT;
typedef uint16_t            WCHAR;
]]

ffi.cdef[[
//typedef  RECTL *LPCRECTL;

typedef struct tagRECT
   {
   LONG left;
   LONG top;
   LONG right;
   LONG bottom;
   } 	RECT;

typedef struct tagRECT *PRECT;

typedef struct tagRECT *LPRECT;

//typedef const RECT *LPCRECT;
]]

ffi.cdef[[
typedef void *PVOID;
typedef void *PVOID64;
]]

ffi.cdef[[
    typedef PVOID HANDLE;
]]
local function DECLARE_HANDLE(name)
   ffi.cdef(string.format("typedef HANDLE %s",name))
end
DECLARE_HANDLE("HWND")