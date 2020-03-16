local wx = require("wx")
local config = require("config")
local db = require("lib.db")
local gridtable = require("widget.gridtable")
local util = require("lib.util")

local search = class.class("search")

local COL_KANJI   = 0
local COL_KANA    = 1
local COL_MEANING = 2

local COLS = {
   [COL_KANJI] = { name = "Kanji", type = wx.wxGRID_VALUE_STRING, width = 80 },
   [COL_KANA] = { name = "Kana", type = wx.wxGRID_VALUE_STRING, width = 80 },
   [COL_MEANING] = { name = "Meaning", type = wx.wxGRID_VALUE_STRING, width = 180 },
}

function search:init(app, frame)
   self.app = app

   self.context = {}
   self.data = {{"猫", "ねこ", "cat"}}

   self.panel = wx.wxPanel(frame, wx.wxID_ANY)
   self.sizer = wx.wxBoxSizer(wx.wxVERTICAL)

   self.search_text_ctrl = wx.wxTextCtrl(self.panel, wx.wxID_ANY, "",
                                         wx.wxPoint(0, 0), wx.wxSize(0, 20),
                                         wx.wxTE_PROCESS_ENTER);
   self.sizer:Add(self.search_text_ctrl, 0, wx.wxEXPAND, 0)

   self.choice_box = wx.wxComboBox(self.panel, wx.wxID_ANY, "",
                                    wx.wxDefaultPosition, wx.wxDefaultSize,
                                    {}, wx.wxTE_READONLY)
   self.sizer:Add(self.choice_box, 0, wx.wxEXPAND, 0)

   self.grid = wx.wxGrid(self.panel, wx.wxID_ANY)
   self.gridtable = gridtable.create(COLS, self.data, self.grid)
   self.sizer:Add(self.grid, 1, wx.wxEXPAND, 5)

   self.panel:SetSizer(self.sizer)
   self.sizer:SetSizeHints(self.panel)

   util.connect(self.grid, wx.wxEVT_GRID_SELECT_CELL, self, "on_grid_select_cell")
   util.connect(self.search_text_ctrl, wx.wxEVT_COMMAND_TEXT_ENTER , self, "on_text_enter")
   util.connect(self.choice_box, wx.wxEVT_COMBOBOX, self, "on_combobox")

   self.pane = self.app:add_pane(self.panel,
                                 {
                                    Name = "Search",
                                    Caption = "Search",
                                    MinSize = wx.wxSize(200, 200),
                                    "Right"
                                 })

   self.db = db:new(config.db_path)
end

function search:search_text(text)
    local id = text:match("^id:(.*)")
    if id then
      local results = self.db:find_by_ids({tonumber(id)})
      self:set_results(results)
    else
      self:set_context({{display = ("%s (search)"):format(text), term = text}})
    end
end

function search:set_context(words)
   self.context = words or {}

   -- { display = "猫 (lemma)", term = "猫" }

   local display_choices = fun.iter(self.context):extract("display")
   self.choice_box:Clear()
   for _, disp in display_choices:unwrap() do
      self.choice_box:Append(disp)
   end

   self.choice_box:SetSelection(0)

   for i = 1, #self.context do
      local results = self:search_word(i)
      if #results > 0 then
         break
      end
   end
end

function search:search_word(idx)
   local word = self.context[idx]
   if word == nil then
      return
   end

   self.choice_box:SetSelection(idx-1)
   self.search_text_ctrl:SetValue(word.term)

   local results = self.db:search(word.term)
   self:set_results(results)
   return results
end

function search:set_results(results)
   local conv = function(entry)
      local kanjis = fun.iter(entry.kanjis):extract("reading"):to_list()
      local readings = fun.iter(entry.readings):extract("reading"):to_list()
      local senses = fun.iter(entry.senses)
         :map(function(sense)
               return table.concat(sense.glosses, ";")
             end)
         :to_list()
      return {
         table.concat(kanjis, ";"),
         table.concat(readings, ";"),
         table.concat(senses, ";"),
      }
   end

   self.data = fun.iter(results):map(conv):to_list()
   self.results = results

   self.gridtable = gridtable.create(COLS, self.data, self.grid)
   self.grid:ForceRefresh()

   self:on_grid_select_cell(0)
end

--
-- Events
--

function search:on_grid_select_cell(event)
   -- wxGridEvent doesn't have a constructor...
   local row
   if type(event) == "userdata" then
      row = event:GetRow()
   else
      row = event
   end

   local data = self.results[row+1]
   if data == nil then
      self.app.widget_display:set_word(nil)
      return
   end

   self.app.widget_display:set_word(data, self.context.sentence)
end

function search:on_text_enter()
   local text = self.search_text_ctrl:GetValue()
   self:search_text(text)
end

function search:on_combobox()
   local idx = self.choice_box:GetSelection()
   self:search_word(idx+1)
end

return search
