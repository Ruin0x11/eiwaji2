local wx = require("wx")

local search = class.class("search")

local COL_KANJI   = 0
local COL_KANA    = 1
local COL_MEANING = 2
local MAX_COLS    = 3

local COLS = {
   [COL_KANJI] = { name = "Kanji", type = wx.wxGRID_VALUE_STRING, width = 80 },
   [COL_KANA] = { name = "Kana", type = wx.wxGRID_VALUE_STRING, width = 80 },
   [COL_MEANING] = { name = "Meaning", type = wx.wxGRID_VALUE_STRING, width = 180 },
}

local function make_gridtable(data)
   local gridtable = wx.wxLuaGridTableBase()

    data.gridtable = gridtable
    gridtable.GetTypeName = function( self, row, col )
        return string.format("%s:80", wx.wxGRID_VALUE_STRING)
    end

    gridtable.GetNumberRows = function( self )
       print(#data)
        return #data
    end

    gridtable.GetNumberCols = function( self )
        return MAX_COLS
    end

    gridtable.IsEmptyCell = function( self, row, col )
        return false
    end

    gridtable.GetValue = function( self, row, col )
        return data[row+1][col+1]
    end

    gridtable.SetValue = function( self, row, col, value )
        data[row+1][col+1] = value
    end

    gridtable.CanGetValueAs = function( self, row, col, typeName )
        if typeName == wx.wxGRID_VALUE_STRING then
           return true
        end
        return false
    end

    gridtable.CanSetValueAs = function( self, row, col, typeName )
        return self:CanGetValueAs(row, col, typeName)
    end

    gridtable.GetValueAsLong = function( self, row, col )
       return -1
    end

    gridtable.GetValueAsBool = function( self, row, col )
       return false
    end

    gridtable.SetValueAsLong = function( self, row, col, value )
    end

    gridtable.SetValueAsBool = function( self, row, col, value )
    end

    gridtable.GetColLabelValue = function( self, col )
        return COLS[col].name
    end

   return gridtable
end

function search:init(app, frame)
   self.app = app

   self.data = {}
   self.data[1] = {"猫", "ねこ", "cat"}
   self.data[2] = {"猫", "ねこ", "cat"}

   self.grid = wx.wxGrid(frame, wx.wxID_ANY)
   self.gridtable = make_gridtable(self.data)

   self.grid:SetTable(self.gridtable, true)
   self.grid:SetRowLabelSize(0)
   self.grid:SetColLabelAlignment(wx.wxALIGN_CENTRE, wx.wxALIGN_CENTRE)

   local attr_ro = wx.wxGridCellAttr()
   attr_ro:SetReadOnly()

   for col=0,MAX_COLS-1 do
      self.grid:SetColSize(col, COLS[col].width)
      self.grid:SetColAttr(col, attr_ro)
   end

   self.grid:Connect(wx.wxEVT_GRID_SELECT_CELL, function(event) self:on_grid_select_cell(event) end)

   app:add_pane(self.grid,
                {
                   Name = "Search",
                   Caption = "Search",
                   MinSize = wx.wxSize(340, 300),
                   "Right"
                })

   self:search_word("猫")
end

function search:search_word(word)
   print("Search", word)
   self.data[#self.data+1] = {"猫", "ねこ", "cat"}
   self.gridtable = make_gridtable(self.data)
   self.grid:SetTable(self.gridtable, true)
   self.grid:ForceRefresh()
end

--
-- Events
--

function search:on_grid_select_cell(event)
   local row = event:GetRow()
   local col = event:GetCol()
   self.app.widget_display:set_text(("%d %d %s"):format(row, col, self.data[row+1][1]))
end

return search
