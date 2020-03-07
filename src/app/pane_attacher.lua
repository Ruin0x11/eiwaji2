local util = require("lib.util")
local wx = require("wx")
local config = require("config")
local ffi = require("ffi")

assert(util.os_name() == "Windows")
local user32 = require("win32.user32")

local pane_attacher = class.class("pane_attacher")

function pane_attacher:init(app)
   self.app = app
   self.id = util.new_id()
   self.timer = wx.wxTimer(app.frame, self.id)
   self.handle = nil

   self.app:connect(self.id, wx.wxEVT_TIMER, self, "on_timer")
end

function pane_attacher:start()
   if self.timer:IsRunning() then
      self.app:print "no"
      return
   end

   self.handle = user32.GetForegroundWindow()

   self.timer:Start(100)
end

function pane_attacher:stop()
   if not self.timer:IsRunning() then
      return
   end

   self.handle = nil

   self.timer:Stop()
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

   local w = p(self.app.widget_wordlist.pane).window:GetRect().width

   local pane = p(self.app.widget_wordlist.pane)
   pane:FloatingPosition(left - pane.window:GetRect().width, top)
       :FloatingSize(pane.window:GetRect().width, height / 2)
   pane = p(self.app.widget_input.pane)
   pane:FloatingPosition(left - pane.window:GetRect().width, top + height / 2)
       :FloatingSize(pane.window:GetRect().width, height / 2)
   pane = p(self.app.widget_lexer.pane)
   pane:FloatingPosition(left, bottom)
       :FloatingSize(width, 250)
   pane = p(self.app.widget_repl.pane)
   pane:FloatingPosition(left + width, bottom)
       :FloatingSize(w, 250)
   pane = p(self.app.widget_search.pane)
   pane:FloatingPosition(right, top)
       :FloatingSize(pane.window:GetRect().width, height / 2)
   pane = p(self.app.widget_display.pane)
   pane:FloatingPosition(right, top + height / 2)
       :FloatingSize(pane.window:GetRect().width, height / 2)

   self.app.frame:SetSize(w, 250)
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

   local new_handle = user32.GetForegroundWindow()
   self.app.print("go, %s %s", new_handle, self.handle)
   if new_handle ~= self.handle then
      local rect = ffi.new("RECT")
      if user32.GetWindowRect(new_handle, rect) == 1 then
         self.app.print("Attach %s %s %s %s", rect.left, rect.top, rect.right, rect.bottom)
         self:do_attach(rect.left, rect.top, rect.right, rect.bottom)
      end
      self:stop()
   end
end

return pane_attacher
