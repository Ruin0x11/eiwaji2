local input = class.class("input")
local wx = require("wx")

function input:init(app, frame)
   self.app = app

   self.text_ctrl = wx.wxTextCtrl(frame, wx.wxID_ANY, "Text Input",
                                   wx.wxPoint(0, 0), wx.wxSize(400, 300),
                                   wx.wxTE_MULTILINE);

   app:add_pane(self.text_ctrl,
                {
                   Name = "Text Input",
                   Caption = "Text Input",
                   MinSize = wx.wxSize(400, 300),
                   "Top",
                   "Left"
                })

   self.text_ctrl:ChangeValue("NeXTSTEP風のデスクトップです。 しっかりと作り込まれたすばらしいデザインのアイコンで、とても高級感のあるデスクトップが楽しめます。")
end

function input:send_to_lexer()
   self.app.widget_lexer:lex_text(self.text_ctrl:GetValue())
end

return input
