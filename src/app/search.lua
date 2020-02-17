local wx = require("wx")

local search = class.class("search")

local COL_KANJI   = 0
local COL_KANA    = 1
local COL_MEANING = 2
local MAX_COLS    = 3

local COLS = {
   [COL_KANJI] = { name = "Kanji", type = wx.wxGRID_VALUE_STRING },
   [COL_KANA] = { name = "Kana", type = wx.wxGRID_VALUE_STRING },
   [COL_MEANING] = { name = "Meaning", type = wx.wxGRID_VALUE_STRING },
}

local function make_gridtable(data)
   local gridtable = wx.wxLuaGridTableBase()

   function gridtable:GetTypeName(row, col)
      local ty = COLS[col]
      if ty == nil then
         error(("Unknown column %d"):format(col))
      end
      return ty.type
   end

   function gridtable:GetNumberRows()
      print(#data)
      return #data
   end

   function gridtable:GetNumberColumns()
      return MAX_COLS
   end

   function gridtable:IsEmptyCell(row, col)
      return false
   end

   function gridtable:GetValue(row, col)
      local row_data = data[row+1]
      local cell_data = row_data[col+1]

      return cell_data
   end

   function gridtable:SetValue(row, col, value)
      data[row+1][col+1] = value
   end

   function gridtable:CanGetValueAs(row, col, typeName)
      return typeName == wx.wxGRID_VALUE_STRING
   end

   function gridtable:CanSetValueAs(row, col, typeName)
      return self:CanGetValueAs(row, col, typeName)
   end

   function gridtable.GetColLabelValue(col)
      return COLS[col].name
   end

   return gridtable
end

function search:init(app, frame)
   self.data = {}
   self.data[1] = {"猫", "ねこ", "cat"}
   self.data[2] = {"猫", "ねこ", "cat"}

   self.grid = wx.wxGrid(frame, wx.wxID_ANY)
   self.gridtable = make_gridtable(self.data)

   --self.grid:SetRowLabelSize(0)
   self.grid:SetColLabelAlignment(wx.wxALIGN_CENTRE, wx.wxALIGN_CENTRE)
   for col=0,MAX_COLS-1 do
      self.grid:SetColLabelValue(col, COLS[col].name)
   end

   -- Set the table to the grid, this allows the following SetColAttr() functions
   -- to work, otherwise they silently do nothing.
   self.grid:SetTable(self.gridtable, true)

   app:add_pane(self.grid,
                {
                   Name = "Search",
                   Caption = "Search",
                   BestSize = wx.wxSize(200, 600),
                   "Right"
                })

   self:search_word("猫")
end

function search:search_word(word)
   self.data[1] = {"猫", "ねこ", "cat"}
end

return search
