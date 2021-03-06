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
  panewidth = 350,
  paneheight = 250,
  debugger = {
    maxdatalength = 256,
  },
  lexer = {
     mecab_opts = {"-Owakati", "-d", "lib/mecab/dic/ipadic-neologd"},
     fontname = nil,
     fontsize = nil
  },
  input = {
     max_history_display_length = 25,
     max_history_size = 20,
     fontname = nil,
     fontsize = nil
  },
  clipboard = {
     max_length = 1000,
     watch_delay = 500,
     watch_on_startup = true,
     filter = nil
  },
  display = {
    fontname = nil,
    fontsize = nil
  },
  wordlist = {
    autosave_on_add = true
  },
  db_path = "dict.db"
}
