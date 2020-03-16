local util = require("lib.util")
local wx = require("wx")
local config = require("config")
local ffi = require("ffi")

local ID = require("lib.ids")

assert(util.os_name() == "Windows")
local user32 = require("win32.user32")

local pane_attacher = class.class("pane_attacher")

function pane_attacher:init(app, menu)
   self.app = app
   self.menu = menu
   self.id = util.new_id()
   self.timer = wx.wxTimer(app.frame, self.id)
   self.handle = nil
   self.is_set = false
   self.delay = 250

   self.app:connect(self.id, wx.wxEVT_TIMER, self, "on_timer")
end

function pane_attacher:start()
   if self.timer:IsRunning() then
      return
   end

   self.handle = user32.GetForegroundWindow()
   self.is_set = false

   self.timer:Start(self.delay)
   self.menu:Check(ID.ATTACH_PANES, true)
end

function pane_attacher:stop()
   if not self.timer:IsRunning() then
      return
   end

   self.handle = nil
   self.is_set = false

   self.timer:Stop()
   self.menu:Check(ID.ATTACH_PANES, false)
end

function pane_attacher:on_clipboard_changed(buffer)
   if config.clipboard.max_length then
      buffer = string.sub(buffer, 1, config.clipboard.max_length)
   end
   self.app.widget_input:set_text(buffer)
   self.app.widget_input:send_to_lexer()
end

function pane_attacher:do_attach(left, top, right, bottom)
   local width = right - left
   local height = bottom - top

   local p = function(pane) return self.app.aui:GetPane(pane.name) end

   local pane_list = self.app.aui:GetAllPanes()
   for i = 0, pane_list:GetCount() - 1 do
     p(pane_list:Item(i)):Float(true)
   end

   local w = config.panewidth
   local h = config.paneheight

   local pane = p(self.app.widget_wordlist.pane)
   pane:FloatingPosition(left - w, top)
       :FloatingSize(w, height / 2)
   pane = p(self.app.widget_input.pane)
   pane:FloatingPosition(left - w, top + height / 2)
       :FloatingSize(w, height / 2)
   pane = p(self.app.widget_lexer.pane)
   pane:FloatingPosition(left, bottom)
       :FloatingSize(width, h)
   pane = p(self.app.widget_repl.pane)
   pane:FloatingPosition(left + width, bottom)
       :FloatingSize(w, h)
   pane = p(self.app.widget_search.pane)
   pane:FloatingPosition(right, top)
       :FloatingSize(w, height / 2)
   pane = p(self.app.widget_display.pane)
   pane:FloatingPosition(right, top + height / 2)
       :FloatingSize(w, height / 2)

   self.app.frame:SetSize(w, h)
   self.app.frame:Move(left - w, bottom)

   self.app.aui:Update()
end

--
-- Events
--

function pane_attacher:on_timer(event)
   if event:GetTimer() ~= self.timer then
      return
   end

   if not self.is_set then
      local new_handle = user32.GetForegroundWindow()
      if new_handle ~= self.handle then
         self.is_set = true
         self.handle = new_handle
      end
   end

   if user32.IsWindow(self.handle) == 0 then
      self.app:print("Window is invalid, stopping attachment.")
      self:stop()
   end

   if self.is_set then
      local rect = ffi.new("RECT")
      if user32.GetWindowRect(self.handle, rect) == 1 then
         self.app.print("Attach %s %s %s %s", rect.left, rect.top, rect.right, rect.bottom)
         self:do_attach(rect.left, rect.top, rect.right, rect.bottom)
      end
   end
end

return pane_attacher
