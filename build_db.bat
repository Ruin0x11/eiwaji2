@echo off

set PATH=%cd%\lib;%PATH%

pushd tools
if not exist JMdict_e.gz (
    powershell -Command "$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest http://ftp.edrdg.org/pub/Nihongo/JMdict_e.gz -OutFile JMdict_e.gz"
)
if not exist JMdict_e (
    powershell -Command "../lib/7z.exe x JMdict_e.gz"
)
popd

lib\wxlua\wxLua.exe /c tools/build_db.lua tools/JMdict_e
