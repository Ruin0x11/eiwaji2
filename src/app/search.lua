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

   self.choices = {}
   self.data = {{"猫", "ねこ", "cat"}}

   self.panel = wx.wxPanel(frame, wx.wxID_ANY)
   self.sizer = wx.wxBoxSizer(wx.wxVERTICAL)

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
   util.connect(self.choice_box, wx.wxEVT_COMBOBOX, self, "on_combobox")

   app:add_pane(self.panel,
                {
                   Name = "Search",
                   Caption = "Search",
                   MinSize = wx.wxSize(340, 300),
                   "Right"
                })

   self.db = db:new(config.db_path)
end

function search:set_context(words)
   self.choices = words or {}

   -- { display = "猫 (lemma)", term = "猫" }

   local display_choices = fun.iter(self.choices):extract("display")
   self.choice_box:Clear()
   for _, disp in display_choices:unwrap() do
      self.choice_box:Append(disp)
   end

   self.choice_box:SetSelection(0)
   self:search_word(1)
end

function search:search_word(idx)
   local word = self.choices[idx]
   if word == nil then
      return
   end

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

   local results = self.db:search(word.term)

   self.data = fun.iter(results):map(conv):to_list()
   self.app:print("Results: %s", inspect(results))

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

   local data = self.data[row+1]
   if data == nil then
      self.app.widget_display:set_text("")
      return
   end

   local body = ([[
Kanji: %s
Kana: %s
Meaning: %s
]]):format(data[1], data[2], data[3])

   self.app.widget_display:set_text(body)
end

function search:on_combobox()
   local idx = self.choice_box:GetSelection()
   self:search_word(idx+1)
end

return search
