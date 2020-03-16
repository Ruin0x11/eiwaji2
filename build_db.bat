@echo off

set PATH=%cd%\lib;%PATH%

pushd tools
if not exist JMdict_e.gz (
    powershell -Command "Invoke-WebRequest ftp://ftp.monash.edu.au/pub/nihongo/JMdict_e.gz -OutFile JMdict_e.gz"
)
if not exist JMdict_e (
    powershell -Command "../lib/7z.exe x JMdict_e.gz"
)
popd

lib\wxlua\wxLua.exe /c tools/build_db.lua tools/JMdict_e
