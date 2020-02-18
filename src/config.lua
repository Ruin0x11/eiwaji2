return {
  editor = {
    autoactivate = false,
    autoreload = true,
    autotabs = false,
    tabwidth = 2,
    usetabs = false,
    whitespace = false,
  },
  repl = {
    fontname = nil,
    fontsize = nil,
    nomousezoom = false,
  },
  activateoutput = true, -- activate output/console on Run/Debug/Compile
  stylesoutshell = nil,
  debugger = {
    maxdatalength = 256,
  },
  lexer = {
     mecab_opts = nil
  },
  input = {
     max_history_display_length = 25,
     max_history_size = 20
  },
  clipboard = {
     max_length = 1000,
     watch_delay = 500,
     watch_on_startup = true
  },
  db_path = "/home/hiro/build/work/jmdict-lua/dict.db"
}
