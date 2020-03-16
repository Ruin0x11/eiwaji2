local wordlist = class.class("wordlist")
local wx = require("wx")
local util = require("lib.util")
local json = require("thirdparty.json")
local config = require("config")

local COLUMN_WORD = 0
local COLUMN_FREQUENCY = 1
local COLUMN_ADDED = 2

local TOOL_SAVE = 5000
local TOOL_LOAD = 5001
local TOOL_CLEAR = 5002

function wordlist:init(app, frame)
   self.app = app

   self.data = {}
   self.loaded_file = nil

   self.panel = wx.wxPanel(frame, wx.wxID_ANY)
   self.sizer = wx.wxBoxSizer(wx.wxVERTICAL)

   self.tool_bar = wx.wxToolBar(self.panel, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize,
                                   wx.wxTB_FLAT + wx.wxTB_NODIVIDER + wx.wxTB_HORZ_TEXT);
   self.tool_bar:SetToolBitmapSize(wx.wxSize(16,16));
   local bmp = wx.wxArtProvider.GetBitmap(wx.wxART_FILE_SAVE, wx.wxART_OTHER, wx.wxSize(16,16));
   self.tool_bar:AddTool(TOOL_SAVE, "Save", bmp);
   bmp = wx.wxArtProvider.GetBitmap(wx.wxART_FILE_OPEN, wx.wxART_OTHER, wx.wxSize(16,16));
   self.tool_bar:AddTool(TOOL_LOAD, "Load", bmp);
   bmp = wx.wxArtProvider.GetBitmap(wx.wxART_CROSS_MARK);
   self.tool_bar:AddTool(TOOL_CLEAR, "Clear", bmp);
   self.tool_bar:Realize();
   self.sizer:Add(self.tool_bar, 0, wx.wxEXPAND, 0)

   self.list_ctrl = wx.wxListView(self.panel, wx.wxID_ANY,
         wx.wxDefaultPosition, wx.wxDefaultSize,
         wx.wxLC_REPORT + wx.wxLC_SINGLE_SEL + wx.wxLC_HRULES + wx.wxLC_VRULES)

   self.list_ctrl:InsertColumn(COLUMN_WORD, "Word", wx.wxLIST_FORMAT_LEFT, -1)
   self.list_ctrl:InsertColumn(COLUMN_FREQUENCY, "Count", wx.wxLIST_FORMAT_RIGHT, -1)
   self.list_ctrl:InsertColumn(COLUMN_ADDED, "Added", wx.wxLIST_FORMAT_LEFT, -1)

   self.list_ctrl:SetColumnWidth(COLUMN_WORD, 170)
   self.list_ctrl:SetColumnWidth(COLUMN_FREQUENCY, 45)
   self.list_ctrl:SetColumnWidth(COLUMN_ADDED, 125)
   self.sizer:Add(self.list_ctrl, 1, wx.wxEXPAND, 5)

   self.panel:SetSizer(self.sizer)
   self.sizer:SetSizeHints(self.panel)

   util.connect(self.list_ctrl, wx.wxEVT_LIST_ITEM_SELECTED, self, "on_list_item_activated")
   util.connect(self.tool_bar, wx.wxEVT_TOOL, self, "on_tool")

   self.pane = self.app:add_pane(self.panel,
                                 {
                                    Name = "Wordlist",
                                    Caption = "Wordlist",
                                    MinSize = wx.wxSize(200, 100),
                                    "Left"
                                 })
end

function wordlist:add_word(db_id, word, sentence)
   local d = self.data[db_id]
   if d then
      d.frequency = d.frequency + 1

      local add_sentence = true
      for _, s in ipairs(d.sentences) do
         if s == sentence then
            add_sentence = false
            break
         end
      end
      if add_sentence then
         d.sentences[#d.sentences+1] = sentence
      end

      self.list_ctrl:EnsureVisible(d.id)
   else
      local count = self.list_ctrl:GetItemCount()

      self.data[db_id] = {
         frequency = 1,
         sentences = {sentence},
         id = count,
         word = word,
         added = os.time()
      }

      local li = wx.wxListItem()
      li:SetId(count+1)
      li:SetText(word)
      li:SetData(db_id)
      self.list_ctrl:InsertItem(li)

      self.list_ctrl:EnsureVisible(self.list_ctrl:GetItemCount()-1)
   end

   d = self.data[db_id]
   self.list_ctrl:SetItem(d.id, COLUMN_FREQUENCY, tostring(d.frequency))
   self.list_ctrl:SetItem(d.id, COLUMN_ADDED, os.date(nil, d.added))

   if config.wordlist.autosave_on_add and self.loaded_file then
      self:save_list(self.loaded_file)
   end
end

function wordlist:remove_word(db_id)
   local d = self.data[db_id]
   if not d then
      return
   end

   self.list_ctrl:DeleteItem(d.id)
end

function wordlist:get_sentences(db_id)
   local d = self.data[db_id]
   if not d then
      return {}
   end

   return d.sentences
end

function wordlist:save_list(file_path)
   local to_save = {}
   for id, v in pairs(self.data) do
      to_save[tostring(id)] = v
   end
   local ok, text = pcall(json.encode, to_save)
   if not ok then
      return false, text
   end

   local handle, err = io.open(file_path, "wb")
   if handle == nil then
      return false, err
   end
   handle:write(text)
   handle:close()

   self.loaded_file = file_path
   self.app:print("Saved word list to '%s'.", file_path)

   return true, nil
end

function wordlist:load_list(file_path)
   local handle, err = io.open(file_path, "rb")
   if handle == nil then
      return false, err
   end
   local text = handle:read("*a")
   handle:close()

   local ok, to_load = pcall(json.decode, text)
   if not ok then
      return false, to_load
   end

   self.data = {}
   for db_id, entry in pairs(to_load) do
      self.data[tonumber(db_id)] = entry
   end

   self.list_ctrl:DeleteAllItems()

   local count = 0
   for db_id, entry in pairs(self.data) do
      local li = wx.wxListItem()
      li:SetId(count+1)
      li:SetText(entry.word)
      li:SetData(tonumber(db_id))
      self.list_ctrl:InsertItem(li)
      self.list_ctrl:SetItem(count, COLUMN_FREQUENCY, tostring(entry.frequency))
      self.list_ctrl:SetItem(count, COLUMN_ADDED, os.date(nil, entry.added))
      count = count + 1
   end

   self.loaded_file = file_path
   self.app:print("Loaded word list from '%s'.", file_path)

   return true, nil
end

function wordlist:clear_list()
   local res = wx.wxMessageBox("Are you sure you want to clear the current wordlist?",
                               "Clear wordlist",
                               wx.wxYES_NO,
                               self.panel);

   if (res == wx.wxYES) then
      self.list_ctrl:DeleteAllItems()
      self.data = {}
      self.loaded_file = nil
      self.app:print("Cleared word list.")
   end
end

local function get_wordlist_dir()
   return wx.wxGetCwd() .. "\\wordlists"
end

function wordlist:prompt_save_list()
   local file_dialog = wx.wxFileDialog(self.panel, "Save word list",
      get_wordlist_dir(),
      "",
      "eiwaji2 word list (*.json)|*.json",
      wx.wxFD_SAVE + wx.wxFD_OVERWRITE_PROMPT)
   if file_dialog:ShowModal() == wx.wxID_OK then
      local ok, err = self:save_list(file_dialog:GetPath())
      if not ok then
         wx.wxMessageBox(("Unable to save word list '%s'.\n\n%s"):format(file_dialog:GetPath(), err),
         "wxLua Error",
         wx.wxOK + wx.wxCENTRE, self.panel)
      end
   end
   file_dialog:Destroy()
end

function wordlist:prompt_load_list()
   local file_dialog = wx.wxFileDialog(self.panel, "Load word list",
      get_wordlist_dir(),
      "",
      "eiwaji2 word list (*.json)|*.json",
      wx.wxFD_OPEN + wx.wxFD_FILE_MUST_EXIST)
   if file_dialog:ShowModal() == wx.wxID_OK then
      local ok, err = self:load_list(file_dialog:GetPath())
      if not ok then
         wx.wxMessageBox(("Unable to load word list '%s'.\n\n%s"):format(file_dialog:GetPath(), err),
         "wxLua Error",
         wx.wxOK + wx.wxCENTRE, self.panel)
      end
   end
   file_dialog:Destroy()
end

--
-- Events
--

function wordlist:on_list_item_activated(event)
   local db_id = event:GetData()
   local word = self.app.widget_search.db:find_by_ids({db_id})[1]
   self.app.widget_display:set_word(word, nil, false)
end

function wordlist:on_tool(event)
   local id = event:GetId()

   if id == TOOL_SAVE then
      self:prompt_save_list()
   elseif id == TOOL_LOAD then
      self:prompt_load_list()
   elseif id == TOOL_CLEAR then
      self:clear_list()
   end
end

return wordlist