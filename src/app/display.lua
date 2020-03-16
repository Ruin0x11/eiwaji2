local display = class.class("display")
local wx = require("wx")
local util = require("lib.util")
local lexer_html = require("lib.lexer_html")

local TOOL_ADD = 5003

function display:init(app, frame)
   self.app = app

   self.entry = nil
   self.entry_text = nil

   self.panel = wx.wxPanel(frame, wx.wxID_ANY)
   self.sizer = wx.wxBoxSizer(wx.wxVERTICAL)

   self.tool_bar = wx.wxToolBar(self.panel, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize,
                                   wx.wxTB_FLAT + wx.wxTB_NODIVIDER + wx.wxTB_HORZ_TEXT);
   self.tool_bar:SetToolBitmapSize(wx.wxSize(16,16));
   local bmp = wx.wxArtProvider.GetBitmap(wx.wxART_ADD_BOOKMARK, wx.wxART_OTHER, wx.wxSize(16,16));
   self.tool_bar:AddTool(TOOL_ADD, "Add", bmp);
   self.tool_bar:Realize();
   self.sizer:Add(self.tool_bar, 0, wx.wxEXPAND, 0)

   self.html = wx.wxLuaHtmlWindow(self.panel);
   self.sizer:Add(self.html, 1, wx.wxEXPAND, 5)

   self.panel:SetSizer(self.sizer)
   self.sizer:SetSizeHints(self.panel)

   util.connect(self.tool_bar, wx.wxEVT_TOOL, self, "on_tool")

   self.pane = self.app:add_pane(self.panel,
                                 {
                                    Name = "Result",
                                    Caption = "Result",
                                    MinSize = wx.wxSize(200, 100),
                                    "Right"
                                 })
end

function display:set_word(entry, sentence, enable_add)
   self.entry = entry

   if entry == nil then
      self.entry_text = nil
      self.sentence = nil
      self.html:SetPage("")
      self.tool_bar:EnableTool(TOOL_ADD, false)
      return
   end

   self.sentence = sentence
   if enable_add == nil then
      enable_add = true
   end

   local kanjis = fun.iter(entry.kanjis):extract("reading"):to_list()
   local readings = fun.iter(entry.readings):extract("reading"):to_list()
   local senses = fun.iter(entry.senses)
      :map(function(sense)
            return table.concat(sense.glosses, ", ")
            end)
      :to_list()

   if kanjis[1] then
      self.entry_text = ("%s (%s)"):format(kanjis[1], readings[1])
   else
      self.entry_text = ("%s"):format(readings[1])
   end

   local text = ([[
<div><b>Kanji:</b></div><br><font size=4>%s</font>
<div><b>Reading:</b></div><br><font size=4>%s</font>
<div><b>Meaning:</b></div><br><font size=4>%s</font>
]]):format(
      table.concat(kanjis, "; "),
      table.concat(readings, "; "),
      table.concat(senses, "\n")
   )

   local example_sentences = self.app.widget_wordlist:get_sentences(entry.sequence_number)

   if #example_sentences > 0 then
      text = text .. "<br><div><u><font size=4>Examples</font></u></div>"
      for _, s in ipairs(example_sentences) do
         text = text .. "<br>" .. lexer_html.colorize_sentence(s.word, s.start_pos, s.text)
      end
   end

   self.html:SetPage(text)
   self.tool_bar:EnableTool(TOOL_ADD, enable_add)
end

--
-- Events
--

function display:on_tool(event)
   local id = event:GetId()

   if id == TOOL_ADD and self.entry then
      self.app.widget_wordlist:add_word(self.entry.sequence_number, self.entry_text, self.sentence)
      self.tool_bar:EnableTool(TOOL_ADD, false)
   end
end

return display
