local wx = require("wx")
local wxstc = require("wxstc")
local util = require("lib.util")

local styled_text_ctrl = {}

local rawMethods = {"AddTextDyn", "InsertTextDyn", "AppendTextDyn", "SetTextDyn",
  "GetTextDyn", "GetLineDyn", "GetSelectedTextDyn", "GetTextRangeDyn",
  "ReplaceTargetDyn", -- this method is not available in wxlua 3.1, so it's simulated
}
local useraw = nil
local invalidUTF8, invalidLength

function styled_text_ctrl.create(...)
  local editor = wxstc.wxStyledTextCtrl(...)
  if not editor then return end

  if useraw == nil then
    useraw = true
    for _, m in ipairs(rawMethods) do
      if not pcall(function() return editor[m:gsub("Dyn", "Raw")] end) then useraw = false; break end
    end
  end

  if not util.is_valid_property(editor, "ReplaceTargetRaw") then
    editor.ReplaceTargetRaw = function(self, ...)
      self:ReplaceTarget("")
      self:InsertTextDyn(self:GetTargetStart(), ...)
    end
  end

  -- `AppendTextRaw` and `AddTextRaw` methods may accept the length of text,
  -- which is important for appending binary strings that may include zeros.
  -- Add text length when it's not provided.
  for _, m in ipairs(useraw and {"AppendTextRaw", "AddTextRaw"} or {}) do
    local orig = editor[m]
    editor[m] = function(self, text, length) return orig(self, text, length or #text) end
  end

  -- map all `GetTextDyn` to `GetText` or `GetTextRaw` if `*Raw` methods are present
  editor.useraw = useraw
  for _, m in ipairs(rawMethods) do
    -- some `*Raw` methods return `nil` instead of `""` as their "normal" calls do
    -- (for example, `GetLineRaw` and `GetTextRangeRaw` for parameters outside of text)
    local def = m:find("^Get") and "" or nil
    editor[m] = function(...) return editor[m:gsub("Dyn", useraw and "Raw" or "")](...) or def end
  end

  function editor:CopyDyn()
    invalidUTF8 = nil
    if not self.useraw then return self:Copy() end
    -- check if selected fragment is a valid UTF-8 sequence
    local text = self:GetSelectedTextRaw()
    if text == "" or wx.wxString.FromUTF8(text) ~= "" then return self:Copy() end
    local tdo = wx.wxTextDataObject()
    -- append suffix as wxwidgets (3.1+ on Windows) truncates last char for odd-length strings
    local suffix = "\0"
    local workaround = util.os_name() == "Windows" and (#text % 2 > 0) and suffix or ""
    tdo:SetData(wx.wxDataFormat(wx.wxDF_TEXT), text..workaround)
    invalidUTF8, invalidLength = text, tdo:GetDataSize()

    local clip = wx.wxClipboard.Get()
    clip:Open()
    clip:SetData(tdo)
    clip:Close()
  end

  function editor:PasteDyn()
    if not self.useraw then return self:Paste() end
    local tdo = wx.wxTextDataObject()
    local clip = wx.wxClipboard.Get()
    clip:Open()
    clip:GetData(tdo)
    clip:Close()
    local ok, text = tdo:GetDataHere(wx.wxDataFormat(wx.wxDF_TEXT))
    -- check if the fragment being pasted is a valid UTF-8 sequence
    if util.os_name() == "Windows" then text = text and text:gsub("%z+$", "") end
    if not ok or wx.wxString.FromUTF8(text) ~= ""
    or not invalidUTF8 or invalidLength ~= tdo:GetDataSize() then return self:Paste() end

    self:AddTextRaw(util.os_name() ~= "Windows" and invalidUTF8 or text)
    self:GotoPos(self:GetCurrentPos())
  end

  function editor:GotoPosEnforcePolicy(pos)
    self:GotoPos(pos)
    self:EnsureVisibleEnforcePolicy(self:LineFromPosition(pos))
  end

  function editor:MarginFromPoint(x)
    if x < 0 then return nil end
    local pos = 0
    for m = 0, util.MAXMARGIN do
      pos = pos + self:GetMarginWidth(m)
      if x < pos then return m end
    end
    return nil -- position outside of margins
  end

  function editor:CanFold()
    for m = 0, util.MAXMARGIN do
      if self:GetMarginWidth(m) > 0
      and self:GetMarginMask(m) == wxstc.wxSTC_MASK_FOLDERS then
        return true
      end
    end
    return false
  end

  -- cycle through "fold all" => "hide base lines" => "unfold all"
  function editor:FoldSome(line)
    local foldall = false -- at least one header unfolded => fold all
    local hidebase = false -- at least one base is visible => hide all

    local header = line and bit.band(self:GetFoldLevel(line),
      wxstc.wxSTC_FOLDLEVELHEADERFLAG) == wxstc.wxSTC_FOLDLEVELHEADERFLAG
    local from = line and (header and line or self:GetFoldParent(line)) or 0
    local to = line and from > -1 and self:GetLastChild(from, -1) or self:GetLineCount()-1

    for ln = from, to do
      local foldRaw = self:GetFoldLevel(ln)
      local foldLvl = foldRaw % 4096
      local foldHdr = (math.floor(foldRaw / 8192) % 2) == 1

      -- at least one header is expanded
      foldall = foldall or (foldHdr and self:GetFoldExpanded(ln))

      -- at least one base can be hidden
      hidebase = hidebase or (
        not foldHdr
        and ln > 1 -- first line can't be hidden, so ignore it
        and foldLvl == wxstc.wxSTC_FOLDLEVELBASE
        and bit.band(foldRaw, wxstc.wxSTC_FOLDLEVELWHITEFLAG) == 0
        and self:GetLineVisible(ln))
    end

    -- shows lines; this doesn't change fold status for folded lines
    if not foldall and not hidebase then self:ShowLines(from, to) end

    for ln = from, to do
      local foldRaw = self:GetFoldLevel(ln)
      local foldLvl = foldRaw % 4096
      local foldHdr = (math.floor(foldRaw / 8192) % 2) == 1

      if foldall then
        if foldHdr and self:GetFoldExpanded(ln) then
          self:ToggleFold(ln)
        end
      elseif hidebase then
        if not foldHdr and (foldLvl == wxstc.wxSTC_FOLDLEVELBASE) then
          self:HideLines(ln, ln)
        end
      else -- unfold all
        if foldHdr and not self:GetFoldExpanded(ln) then
          self:ToggleFold(ln)
        end
      end
    end
    -- if the entire file is being un/folded, make sure the cursor is on the screen
    -- (although it may be inside a folded fragment)
    if not line then self:EnsureCaretVisible() end
  end

  function editor:GetAllMarginWidth()
    local width = 0
    for m = 0, util.MAXMARGIN do width = width + self:GetMarginWidth(m) end
    return width
  end

  function editor:ShowPosEnforcePolicy(pos)
    local line = self:LineFromPosition(pos)
    self:EnsureVisibleEnforcePolicy(line)
    -- skip the rest if line wrapping is on
    if self:GetWrapMode() ~= wxstc.wxSTC_WRAP_NONE then return end
    local xwidth = self:GetClientSize():GetWidth() - self:GetAllMarginWidth()
    local xoffset = self:GetTextExtent(self:GetLineDyn(line):sub(1, pos-self:PositionFromLine(line)+1))
    self:SetXOffset(xoffset > xwidth and xoffset-xwidth or 0)
  end

  function editor:GetLineWrapped(pos, direction)
    local function getPosNear(editor, pos, direction)
      local point = editor:PointFromPosition(pos)
      local height = editor:TextHeight(editor:LineFromPosition(pos))
      return editor:PositionFromPoint(wx.wxPoint(point:GetX(), point:GetY() + direction * height))
    end
    direction = tonumber(direction) or 1
    local line = self:LineFromPosition(pos)
    if self:WrapCount(line) < 2
    or direction < 0 and line == 0
    or direction > 0 and line == self:GetLineCount()-1 then return false end
    return line == self:LineFromPosition(getPosNear(self, pos, direction))
  end

  -- wxSTC included with wxlua didn't have ScrollRange defined, so substitute if not present
  if not util:is_valid_property(editor, "ScrollRange") then
    function editor:ScrollRange() end
  end

  -- ScrollRange moves to the correct position, but doesn't unfold folded region
  function editor:ShowRange(secondary, primary)
    self:ShowPosEnforcePolicy(primary)
    self:ScrollRange(secondary, primary)
  end

  function editor:ClearAny()
    local length = self:GetLength()
    local selections = util.version_geq(util.wx_version(), "2.9.5") and self:GetSelections() or 1
    self:Clear() -- remove selected fragments

    -- check if the modification has failed, which may happen
    -- if there is "invisible" text in the selected fragment.
    -- if there is only one selection, then delete manually.
    if length == self:GetLength() and selections == 1 then
      self:SetTargetStart(self:GetSelectionStart())
      self:SetTargetEnd(self:GetSelectionEnd())
      self:ReplaceTarget("")
    end
  end

  function editor:MarkerGetAll(mask, from, to)
    mask = mask or util.ANYMARKERMASK
    local markers = {}
    local line = self:MarkerNext(from or 0, mask)
    while line ~= wx.wxNOT_FOUND do
      table.insert(markers, {line, self:MarkerGet(line)})
      if to and line > to then break end
      line = self:MarkerNext(line + 1, mask)
    end
    return markers
  end

  function editor:IsLineEmpty(line)
    local text = self:GetLineDyn(line or self:GetCurrentLine())
    local lc = self.spec and self.spec.linecomment
    return not text:find("%S") or (lc and text:find("^%s*"..string.escape_magic(lc)) ~= nil)
  end

  function editor:GetModifiedTime() return self.updated end

  -- function editor:SetupKeywords(...) return SetupKeywords(self, ...) end

  -- this is a workaround for the auto-complete popup showing large font
  -- when Settechnology(1) is used to enable DirectWrite support.
  -- See https://trac.wxwidgets.org/ticket/17804#comment:32
  for _, method in ipairs({"AutoCompShow", "UserListShow"}) do
    local orig = editor[method]
    editor[method] = function (editor, ...)
      local tech = editor:GetTechnology()
      if tech ~= 0 then editor:SetTechnology(wxstc.wxSTC_TECHNOLOGY_DEFAULT) end
      orig(editor, ...)
      if tech ~= 0 then editor:SetTechnology(tech) end
    end
  end

  -- editor:Connect(wx.wxEVT_KEY_DOWN,
  --   function (event)
  --     local keycode = event:GetKeyCode()
  --     local mod = event:GetModifiers()
  --     if (keycode == wx.WXK_DELETE and mod == wx.wxMOD_SHIFT)
  --     or (keycode == wx.WXK_INSERT and mod == wx.wxMOD_CONTROL)
  --     or (keycode == wx.WXK_INSERT and mod == wx.wxMOD_SHIFT) then
  --       local id = keycode == wx.WXK_DELETE and wx.wxID_CUT or mod == wx.wxMOD_SHIFT and wx.wxID_PASTE or wx.wxID_COPY
  --       ide.frame:AddPendingEvent(wx.wxCommandEvent(wx.wxEVT_COMMAND_MENU_SELECTED, id))
  --     elseif keycode == wx.WXK_CAPITAL and mod == wx.wxMOD_CONTROL then
  --       -- ignore Ctrl+CapsLock
  --     else
  --       event:Skip()
  --     end
  --   end)
  return editor
end

return styled_text_ctrl
