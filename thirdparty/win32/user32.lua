require("win32")

local ffi = require("ffi")

local exports = {}
exports.C = ffi.load("user32")

ffi.cdef[[
BOOL
__stdcall
UpdateWindow(
     HWND hWnd);

HWND
__stdcall
SetActiveWindow(
     HWND hWnd);

HWND
__stdcall
GetForegroundWindow(
    VOID);

BOOL
__stdcall
GetWindowRect(
     HWND hWnd,
     LPRECT lpRect);

]]

exports.GetForegroundWindow = exports.C.GetForegroundWindow
exports.GetWindowRect = exports.C.GetWindowRect

return exports