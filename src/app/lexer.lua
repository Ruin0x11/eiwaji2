local wx = require("wx")
local lexer_html = require("lib.lexer_html")

local lexer = class.class("lexer")

function lexer:init(app, frame)
   self.app = app

   self.html = wx.wxLuaHtmlWindow(frame)
   self.title = "Lexer"

   self.html.OnSetTitle = function(self_, title)
      frame.Title = self.title .. " - " .. title
   end

   self.html:SetRelatedFrame(app.frame, "Status : %s")

   app:connect(wx.wxID_ANY, wx.wxEVT_HTML_LINK_CLICKED, self, "on_html_link_clicked")

   app:add_pane(self.html,
                {
                   Name = "Lexer",
                   Caption = "Lexer",
                   BestSize = wx.wxSize(600, 200),
                   "Bottom"
                })

   self:lex_text("dood")
end

function lexer:lex_text(text)
   local mecab = {}
   local html = lexer_html.convert(mecab)

   self.html:SetPage(html)
end

--
-- Events
--

function lexer:on_html_link_clicked(event)
   local href = event:GetLinkInfo():GetHref()
   print("HREF", href)
   self.app.widget_search:search_word("dood")
end

return lexer
