local wx = require("wx")
local wxaui = require("wxaui")
local wxlua = require("wxlua")
local lexer = require("app.lexer")
local search = require("app.search")

local app = class.class("app")

function app:init()
   self.wx_app = wx.wxGetApp()

   self.name = "eiwaji2"
   self.version = "0.1.0"
   self.width = 800
   self.height = 600

   local file_menu = wx.wxMenu()
   file_menu:Append(wx.wxID_EXIT, "E&xit", "Quit the program")

   local help_menu = wx.wxMenu()
   help_menu:Append(wx.wxID_ABOUT, "&About", "About this program")

   self.menu_bar = wx.wxMenuBar()
   self.menu_bar:Append(file_menu, "&File")
   self.menu_bar:Append(help_menu, "&Help")

   self.frame = wx.wxFrame(wx.NULL, wx.wxID_ANY, "eiwaji2",
                           wx.wxDefaultPosition, wx.wxSize(self.width, self.height),
                           wx.wxDEFAULT_FRAME_STYLE)
   self.frame.MenuBar = self.menu_bar

   self.ID_STATUS_BAR = 2
   self.frame:CreateStatusBar(self.ID_STATUS_BAR)
   self.frame:SetStatusText("Welcome to wxLua.")

   self:connect_frame(wx.wxID_ABOUT, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_about")

   self.wx_app.TopWindow = self.frame
   self.frame:Show(true)

   self.aui = wxaui.wxAuiManager()
   self.aui:SetManagedWindow(self.frame);

   self.widget_search = search:new(self, self.frame)
   self.widget_lexer = lexer:new(self, self.frame)

   self.aui:Update();

   self:connect_frame(nil, wx.wxEVT_DESTROY, self, "on_destroy")
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

function app:connect(id, event_id, receiver, cb)
   self.wx_app:Connect(id, event_id, function(event) receiver[cb](receiver, event) end)
end

function app:connect_frame(id, event_id, receiver, cb)
   if id == nil then
      self.frame:Connect(event_id, function(event) receiver[cb](receiver, event) end)
   else
      self.frame:Connect(id, event_id, function(event) receiver[cb](receiver, event) end)
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

function app:on_menu_about(_)
   local message = ("%s ver. %s\n%s built with %s\n%s %s")
      :format(self.name, self.version, wxlua.wxLUA_VERSION_STRING, wx.wxVERSION_STRING, jit.version, jit.arch)

   wx.wxMessageBox(message,
                   ("About %s"):format(self.name),
                   wx.wxOK + wx.wxICON_INFORMATION,
                   self.frame)
end

return app
