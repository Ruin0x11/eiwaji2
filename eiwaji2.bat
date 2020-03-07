@echo off

set PATH=%cd%\lib\wxlua;%cd%\lib\mecab\bin;%cd%\lib\sqlite3;%PATH%

wxlua /c ./src/main.lua
