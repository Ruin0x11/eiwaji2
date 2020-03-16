local util = require("lib.util")
local wx = require("wx")
local config = require("config")

local clipboard_watcher = class.class("clipboard_watcher")

function clipboard_watcher:init(app, delay)
   self.app = app
   self.id = util.new_id()
   self.timer = wx.wxTimer(app.frame, self.id)
   self.delay = delay
   self.last_buffer = nil

   self.app:connect(self.id, wx.wxEVT_TIMER, self, "on_timer")
end

function clipboard_watcher:start()
   if self.timer:IsRunning() then
      return
   end

   self.timer:Start(self.delay)
end

function clipboard_watcher:stop()
   if not self.timer:IsRunning() then
      return
   end

   self.timer:Stop()
end

function clipboard_watcher:on_clipboard_changed(buffer)
   if config.clipboard.max_length then
      buffer = string.sub(buffer, 1, config.clipboard.max_length)
   end
   self.app.widget_input:set_text(buffer)
   self.app.widget_input:send_to_lexer()
end

--
-- Events
--

function clipboard_watcher:on_timer(event)
   if event:GetTimer() ~= self.timer then
      return
   end

   local clipboard = wx.wxClipboard.Get()
   if not clipboard then
      print("Failed to open clipboard.")
      return
   end

   local log = wx.wxLogNull()
   clipboard:Open()
   clipboard.UsePrimarySelection = true
   local text_obj = wx.wxTextDataObject()
   local result = clipboard:GetData(text_obj)
   clipboard:Close()
   log:delete()

   local buffer
   if result == nil then
      buffer = ""
   else
      buffer = text_obj:GetText()
   end

   if self.last_buffer and self.last_buffer ~= buffer then
      self:on_clipboard_changed(buffer)
   end

   self.last_buffer = buffer
end

return clipboard_watcher
