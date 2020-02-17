local input = class.class("input")
local wx = require("wx")

function input:init(app, frame)
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
end

return input
