local wx = require("wx")

local gridtable = {}

function gridtable.create(cols, data, grid)
   local gridtable = wx.wxLuaGridTableBase()

   data.gridtable = gridtable
   gridtable.GetTypeName = function(self, row, col)
      return string.format("%s:80", wx.wxGRID_VALUE_STRING)
   end

   gridtable.GetNumberRows = function(self)
      return #data
   end

   gridtable.GetNumberCols = function(self)
      return #cols + 1 -- zero indexed
   end

   gridtable.IsEmptyCell = function(self, row, col)
      return false
   end

   gridtable.GetValue = function(self, row, col)
      local dat = data[row+1][col+1]
      if dat == nil then
         error("Invalid data: " .. row .. " " .. col)
      end
      return dat
   end

   gridtable.SetValue = function(self, row, col, value)
      data[row+1][col+1] = value
   end

   gridtable.CanGetValueAs = function(self, row, col, typeName)
      if typeName == wx.wxGRID_VALUE_STRING then
         return true
      end
      return false
   end

   gridtable.CanSetValueAs = function(self, row, col, typeName)
      return self:CanGetValueAs(row, col, typeName)
   end

   gridtable.GetValueAsLong = function(self, row, col)
      return -1
   end

   gridtable.GetValueAsBool = function(self, row, col)
      return false
   end

   gridtable.SetValueAsLong = function(self, row, col, value)
   end

   gridtable.SetValueAsBool = function(self, row, col, value)
   end

   gridtable.GetColLabelValue = function(self, col)
      return cols[col].name or ""
   end

   grid:SetTable(gridtable, true)
   grid:SetRowLabelSize(0)
   grid:SetColLabelAlignment(wx.wxALIGN_CENTRE, wx.wxALIGN_CENTRE)

   for col=0,#cols do
      local attr_ro = wx.wxGridCellAttr()
      attr_ro:SetReadOnly()
      grid:SetColSize(col, cols[col].width)
      grid:SetColAttr(col, attr_ro)
   end

   return gridtable
end

return gridtable
