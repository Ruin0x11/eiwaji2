local wx = require("wx")
local wxaui = require("wxaui")
local wxlua = require("wxlua")
local util = require("lib.util")
local input = require("app.input")
local lexer = require("app.lexer")
local search = require("app.search")
local display = require("app.display")
local debug_server = require("app.debug_server")
local clipboard_watcher = require("app.clipboard_watcher")
local repl = require("app.repl")
local config = require("config")

local ID = require("lib.ids")

local app = class.class("app")

function app:init()
   self.wx_app = wx.wxGetApp()

   self.name = "eiwaji2"
   self.version = "0.1.0"
   self.wx_version = string.match(wx.wxVERSION_STRING, "[%d%.]+")
   self.width = 800
   self.height = 600

   print(ID.LEX)
   local file_menu = wx.wxMenu()
   file_menu:Append(ID.LEX, "&Lex Text\tCTRL+L", "Send current text to the lexer")
   file_menu:AppendCheckItem(ID.WATCH_CLIPBOARD, "&Watch Clipboard", "Automatically lex text when the clipboard changes.")
   file_menu:Append(ID.EXIT, "E&xit", "Quit the program")

   local help_menu = wx.wxMenu()
   help_menu:Append(ID.ABOUT, "&About", "About this program")

   self.menu_bar = wx.wxMenuBar()
   self.menu_bar:Append(file_menu, "&File")
   self.menu_bar:Append(help_menu, "&Help")

   self.frame = wx.wxFrame(wx.NULL, wx.wxID_ANY, "eiwaji2",
                           wx.wxDefaultPosition, wx.wxSize(self.width, self.height),
                           wx.wxDEFAULT_FRAME_STYLE)
   self.frame.MenuBar = self.menu_bar

   self.frame:CreateStatusBar(ID.STATUS_BAR)
   self.frame:SetStatusText("Welcome to wxLua.")

   self:connect_frame(ID.LEX, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_lex")
   self:connect_frame(ID.WATCH_CLIPBOARD, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_watch_clipboard")
   self:connect_frame(ID.EXIT, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_exit")
   self:connect_frame(ID.ABOUT, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_about")

   self.wx_app.TopWindow = self.frame
   self.frame:Show(true)

   self.aui = wxaui.wxAuiManager()
   self.aui:SetManagedWindow(self.frame);

   self.widget_repl = repl:new(self, self.frame)
   self.widget_input = input:new(self, self.frame)
   self.widget_lexer = lexer:new(self, self.frame)
   self.widget_display = display:new(self, self.frame)
   self.widget_search = search:new(self, self.frame)

   self.debug_server = debug_server:new(self, 4567)
   self.clipboard_watcher = clipboard_watcher:new(self, config.clipboard.watch_delay)
   if config.clipboard.watch_on_startup then
      self.clipboard_watcher:start()
   end

   self.aui:Update();

   self:connect_frame(nil, wx.wxEVT_DESTROY, self, "on_destroy")

   self.widget_repl:activate()
end

function app:add_pane(ctrl, args)
   local info = wxaui.wxAuiPaneInfo()

   for k, v in pairs(args) do
      if type(k) == "number" then
         info = info[v](info)
      else
         info = info[k](info, v)
      end
   end

   self.aui:AddPane(ctrl, info)
end

function app:connect(...)
   return util.connect(self.wx_app, ...)
end

function app:connect_frame(...)
   return util.connect(self.frame, ...)
end

function app:print(fmt, ...)
   if self.widget_repl then
      self.widget_repl:DisplayShellMsg(string.format(fmt, ...))
   end
end

function app:run()
   self.wx_app:MainLoop()
end

--
-- Events
--

function app:on_destroy(event)
   if (event:GetEventObject():DynamicCast("wxObject") == self.frame:DynamicCast("wxObject")) then
      -- You must ALWAYS UnInit() the wxAuiManager when closing
      -- since it pushes event handlers into the frame.
      self.aui:UnInit()
   end
end

function app:on_menu_lex(_)
   self.widget_input:send_to_lexer()
end

function app:on_menu_watch_clipboard(event)
   if event:IsChecked() then
      self.frame:SetStatusText("Watching clipboard.")
      self.clipboard_watcher:start()
   else
      self.frame:SetStatusText("Not watching clipboard.")
      self.clipboard_watcher:stop()
   end
end

function app:on_menu_exit(_)
   self.frame:Close()
end

function app:get_info()
   return ("%s ver. %s\n%s built with %s\n%s %s")
      :format(self.name, self.version, wxlua.wxLUA_VERSION_STRING, wx.wxVERSION_STRING, jit.version, jit.arch)
end

function app:on_menu_about(_)
   wx.wxMessageBox(self:get_info(),
                   ("About %s"):format(self.name),
                   wx.wxOK + wx.wxICON_INFORMATION,
                   self.frame)
end

return app
