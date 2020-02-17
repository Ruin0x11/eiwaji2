local config = require("config")
local lexer_html = require("lib.lexer_html")
local wx = require("wx")
local yukie = require("thirdparty.yukie")

local lexer = class.class("lexer")

function lexer:init(app, frame)
   self.app = app

   self.html = wx.wxLuaHtmlWindow(frame)
   self.title = "Lexer"
   self.results = {}

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
end

function lexer:lex_text(text)
   self.app:print("Lex text: %s", text)

   self.results = yukie.parse_to_words(text, {"-Owakati", "-N2"})
   local html = lexer_html.convert(self.results)

   self.html:SetPage(html)
end

--
-- Events
--

function lexer:on_html_link_clicked(event)
   local href = event:GetLinkInfo():GetHref()
   local word = self.results[tonumber(href)]
   if word == nil then
      error("missing word " .. href)
   end
   self.app.widget_search:search_word(word)
end

return lexer
