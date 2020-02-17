-- Copyright 2011-17 Paul Kulchenko, ZeroBrane LLC
-- authors: Lomtik Software (J. Winwood & John Labenski)
--          Luxinia Dev (Eike Decker & Christoph Kubisch)
---------------------------------------------------------

local util = require("lib.util")
local wx = require("wx")

-- Generate a unique new wxWindowID
local ID_IDCOUNTER = wx.wxID_HIGHEST + 1
local function NewID()
  ID_IDCOUNTER = math.floor(ID_IDCOUNTER + 1) -- make sure it's integer
  return ID_IDCOUNTER
end

-- some Ubuntu versions (Ubuntu 13.10) ignore labels on stock menu IDs,
-- so don't use stock IDs on Linux (http://trac.wxwidgets.org/ticket/15958)
local linux = util.os_name() == "Unix"

local ids = {
   ID_LEX              = NewID(),
   -- File menu
   ID_NEW              = linux and NewID() or wx.wxID_NEW,
   ID_OPEN             = linux and NewID() or wx.wxID_OPEN,
   ID_SAVE             = linux and NewID() or wx.wxID_SAVE,
   ID_SAVEAS           = linux and NewID() or wx.wxID_SAVEAS,
   ID_EXIT             = linux and NewID() or wx.wxID_EXIT,
   -- Edit menu
   ID_CUT              = linux and NewID() or wx.wxID_CUT,
   ID_COPY             = linux and NewID() or wx.wxID_COPY,
   ID_PASTE            = linux and NewID() or wx.wxID_PASTE,
   ID_SELECTALL        = linux and NewID() or wx.wxID_SELECTALL,
   ID_UNDO             = linux and NewID() or wx.wxID_UNDO,
   ID_REDO             = linux and NewID() or wx.wxID_REDO,
   -- don't use wx.wxID_PREFERENCES to avoid merging with OSX app menu, because
   -- Apple guidelines describe Preferences as a "normal" item without submenus.
   ID_PREFERENCES      = NewID(),
   ID_PREFERENCESSYSTEM = NewID(),
   ID_PREFERENCESUSER  = NewID(),
   -- Search menu
   ID_FIND             = linux and NewID() or wx.wxID_FIND,
   -- View menu
   -- Project menu
   -- Help menu
   ID_ABOUT            = linux and NewID() or wx.wxID_ABOUT,

   ID_STATUS_BAR       = NewID()
}

return setmetatable({}, {
  __index = function(_, id) return ids["ID_"..id] end
})
