local input = class.class("input")
local wx = require("wx")
local utf8 = require("lua-utf8")
local config = require("config")
local util = require("lib.util")

function input:init(app, frame)
   self.app = app

   self.history = {}

   self.panel = wx.wxPanel(frame, wx.wxID_ANY)
   self.sizer = wx.wxBoxSizer(wx.wxVERTICAL)

   self.history_box = wx.wxComboBox(self.panel, wx.wxID_ANY, "",
                                    wx.wxDefaultPosition, wx.wxDefaultSize,
                                    {}, wx.wxTE_READONLY)
   self.sizer:Add(self.history_box, 0, wx.wxEXPAND, 0)

   self.text_ctrl = wx.wxTextCtrl(self.panel, wx.wxID_ANY, "",
                                   wx.wxPoint(0, 0), wx.wxSize(400, 300),
                                   wx.wxTE_MULTILINE);
   self.sizer:Add(self.text_ctrl, 1, wx.wxEXPAND, 5)

   self.panel:SetSizer(self.sizer)
   self.sizer:SetSizeHints(self.panel)

   util.connect(self.history_box, wx.wxEVT_COMBOBOX, self, "on_combobox")

   app:add_pane(self.panel,
                {
                   Name = "Text Input",
                   Caption = "Text Input",
                   MinSize = wx.wxSize(400, 300),
                   "Top",
                   "Left"
                })
end

function input:set_text(text)
   self.text_ctrl:SetValue(text)
end

function input:send_to_lexer(no_history)
   local text = tostring(self.text_ctrl:GetValue())
   local display_text = text
   local max_len = config.input.max_history_display_length
   if utf8.len(text) > max_len then
      display_text = utf8.sub(text, 1, max_len) .. "..."
   end

   self.app.widget_lexer:lex_text(text)

   if no_history then
      return
   end

   self.history[self.history_box:GetCount()+1] = text
   self.history_box:Append(display_text)

   while self.history_box:GetCount() > config.input.max_history_size do
      self.history_box:Delete(0)
      table.remove(self.history, 1)
   end
end

--
-- Events
--

function input:on_combobox()
   local idx = self.history_box:GetSelection()
   local text = self.history[idx+1]
   self:set_text(text)
   self:send_to_lexer(true)
end

return input
