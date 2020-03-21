local config = require("config")
local lexer_html = require("lib.lexer_html")
local wx = require("wx")
local yukie = require("thirdparty.yukie")
local util = require("lib.util")

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
   local s = config.lexer.fontsize or 16
   self.html:SetFonts(config.lexer.fontname or "", "", {s,s,s,s,s,s,s})

   util.connect(self.html, wx.wxEVT_HTML_LINK_CLICKED, self, "on_html_link_clicked")

   self.pane = self.app:add_pane(self.html,
                                 {
                                    Name = "Lexer",
                                    Caption = "Lexer",
                                    BestSize = wx.wxSize(600, 200),
                                    "Bottom"
                                 })
end

function lexer:lex_text(text)
   self.text = text
   self.results = yukie.parse_to_words(text, config.lexer.mecab_opts)
   local pos = 1
   for _, result in ipairs(self.results) do
      result.start_pos = pos
      pos = pos + string.len(result.word)
   end

   local html = lexer_html.convert(self.results)

   self.html:SetPage(html)
end

--
-- Events
--

local function is_all_katakana(text)
   return false
end

local function katakana_to_hiragana(text)
   return text
end

function lexer:on_html_link_clicked(event)
   local href = event:GetLinkInfo():GetHref()
   local word = self.results[tonumber(href)]
   if word == nil then
      error("missing word " .. href)
   end

   self.app:print("Word: %s (%s)", word.word, inspect(word))

   local ctxt = {
      sentence = { word = word.word, start_pos = word.start_pos, text = self.text, added = os.time() }
   }

   if word.lemma ~= "*" then
      ctxt[#ctxt+1] = { display = ("%s (lemma)"):format(word.lemma), term = word.lemma }
   end
   ctxt[#ctxt+1] = { display = ("%s (word)"):format(word.word), term = word.word }

   -- TODO hiragana to katakana

   for i, token in ipairs(word.tokens) do
      ctxt[#ctxt+1] = {
         display = ("%s (literal %d)"):format(token.literal, i),
         term = token.literal,
      }

      if token.lemma ~= "*" and token.lemma ~= token.literal then
         ctxt[#ctxt+1] = {
            display = ("%s (token %d)"):format(token.lemma, i),
            term = token.lemma,
         }
      end
   end

   self.app.widget_search:set_context(ctxt)
end

return lexer
