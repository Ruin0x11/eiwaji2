local display = class.class("display")
local wx = require("wx")

function display:init(app, frame)
   self.text_ctrl = wx.wxTextCtrl(frame, wx.wxID_ANY, "",
                                   wx.wxPoint(0, 0), wx.wxSize(200, 200),
                                   wx.wxTE_MULTILINE + wx.wxTE_READONLY);

   app:add_pane(self.text_ctrl,
                {
                   Name = "Result",
                   Caption = "Result",
                   MinSize = wx.wxSize(200, 200),
                   "Right"
                })
end

function display:set_text(text)
   self.text_ctrl:ChangeValue(text)
end

return display
