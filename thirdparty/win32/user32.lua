require("win32")

local ffi = require("ffi")

local exports = {}
exports.C = ffi.load("user32")

ffi.cdef[[
HWND
__stdcall
GetForegroundWindow(
    VOID);

BOOL
__stdcall
GetWindowRect(
     HWND hWnd,
     LPRECT lpRect);

BOOL IsWindow(
     HWND hWnd);
]]

exports.GetForegroundWindow = exports.C.GetForegroundWindow
exports.GetWindowRect = exports.C.GetWindowRect
exports.IsWindow = exports.C.IsWindow

return exports