-- Copyright 2011-16 Paul Kulchenko, ZeroBrane LLC
-- authors: Luxinia Dev (Eike Decker & Christoph Kubisch)
---------------------------------------------------------

local wx = require("wx")
local wxstc = require("wxstc")
local util = require("lib.util")
local styled_text_ctrl = require("widget.styled_text_ctrl")

local ID = require("lib.ids")

local tint = function(c) return c end
local markers = {
  message = {3, wxstc.wxSTC_MARK_CHARACTER+(' '):byte(), {0, 0, 0}, {220, 220, 220}},
  output = {4, wxstc.wxSTC_MARK_BACKGROUND, {0, 0, 0}, {240, 240, 240}},
  prompt = {5, wxstc.wxSTC_MARK_ARROWS, {0, 0, 0}, {220, 220, 220}},
  error = {6, wxstc.wxSTC_MARK_BACKGROUND, {0, 0, 0}, {255, 220, 220}},
}
local function StylesGetMarker(marker)
  local id, ch, fg, bg = unpack(markers[marker] or {})
  return id, ch, fg and wx.wxColour(unpack(tint(fg))), bg and wx.wxColour(unpack(tint(bg)))
end

local PROMPT_MARKER = StylesGetMarker("prompt")
local PROMPT_MARKER_VALUE = 2^PROMPT_MARKER
local ERROR_MARKER = StylesGetMarker("error")
local OUTPUT_MARKER = StylesGetMarker("output")
local MESSAGE_MARKER = StylesGetMarker("message")

local config = require("config")

local TR = function(s) return s end

local repl = class.class("repl")

local function concat(sep, ...)
  local text = ""
  for i=1, select('#',...) do
    text = text .. (i > 1 and sep or "") .. tostring(select(i,...))
  end

  -- split the text into smaller chunks as one large line
  -- is difficult to handle for the editor
  local prev, maxlength = 0, config.debugger.maxdatalength
  if #text > maxlength and not text:find("\n.") then
    text = text:gsub("()(%s+)", function(p, s)
        if p-prev >= maxlength then
          prev = p
          return "\n"
        else
          return s
        end
      end)
  end
  return text
end

function repl:init(app, frame)
   self.app = app

   local console = styled_text_ctrl.create(frame, wx.wxID_ANY,
                                           wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxBORDER_NONE)

   console:SetFont(util.create_font(config.repl.fontsize or 10, wx.wxFONTFAMILY_MODERN, wx.wxFONTSTYLE_NORMAL,
                                    wx.wxFONTWEIGHT_NORMAL, false, config.repl.fontname or "",
                                    config.repl.fontencoding or wx.wxFONTENCODING_DEFAULT)
   )
   console:StyleSetFont(wxstc.wxSTC_STYLE_DEFAULT, console:GetFont())
   console:StyleClearAll()

   console:SetTabWidth(config.editor.tabwidth or 2)
   console:SetIndent(config.editor.tabwidth or 2)
   console:SetUseTabs(config.editor.usetabs and true or false)
   console:SetViewWhiteSpace(config.editor.whitespace and true or false)
   console:SetIndentationGuides(true)

   console:SetWrapMode(wxstc.wxSTC_WRAP_WORD)
   console:SetWrapStartIndent(0)
   console:SetWrapVisualFlagsLocation(wxstc.wxSTC_WRAPVISUALFLAGLOC_END_BY_TEXT)
   console:SetWrapVisualFlags(wxstc.wxSTC_WRAPVISUALFLAG_END)

   console:MarkerDefine(StylesGetMarker("prompt"))
   console:MarkerDefine(StylesGetMarker("error"))
   console:MarkerDefine(StylesGetMarker("output"))
   console:MarkerDefine(StylesGetMarker("message"))
   console:SetReadOnly(false)

   -- console:SetupKeywords("lua",nil,config.stylesoutshell)

   self.console = console

   self:bind_console_events()

   self.env = self:createenv()

   self.pane = self.app:add_pane(self.console,
                                {
                                  Name = "REPL",
                                  Caption = "REPL",
                                  BestSize = wx.wxSize(300, 400),
                                  "Bottom"
                                })

   self.app:connect_frame(nil, wx.wxEVT_DESTROY, self, "on_destroy")

   self:load_history()

   self:displayShellIntro()
end

function repl:getPromptLine()
  local totalLines = self.console:GetLineCount()
  return self.console:MarkerPrevious(totalLines+1, PROMPT_MARKER_VALUE)
end

function repl:getPromptText()
  local prompt = self:getPromptLine()
  return self.console:GetTextRangeDyn(self.console:PositionFromLine(prompt), self.console:GetLength())
end

function repl:setPromptText(text)
  local length = self.console:GetLength()
  self.console:SetSelectionStart(length - string.len(self:getPromptText()))
  self.console:SetSelectionEnd(length)
  self.console:ClearAny()
  self.console:AddTextDyn(text)
  -- refresh the output window to force recalculation of wrapped lines;
  -- otherwise a wrapped part of the last line may not be visible.
  self.console:Update(); self.console:Refresh()
  self.console:GotoPos(self.console:GetLength())
end

function repl:positionInLine(line)
  return self.console:GetCurrentPos() - self.console:PositionFromLine(line)
end

function repl:caretOnPromptLine(disallowLeftmost, line)
  local promptLine = self:getPromptLine()
  local currentLine = line or self.console:GetCurrentLine()
  local boundary = disallowLeftmost and 0 or -1
  return (currentLine > promptLine
    or currentLine == promptLine and self:positionInLine(promptLine) > boundary)
end

local function chomp(line) return (line:gsub("%s+$", "")) end

function repl:getInput(line)
   local nextMarker = line
   local count = self.console:GetLineCount()

  repeat -- check until we find at least some marker
    nextMarker = nextMarker+1
  until self.console:MarkerGet(nextMarker) > 0 or nextMarker > count-1
  return chomp(self.console:GetTextRangeDyn(
    self.console:PositionFromLine(line), self.console:PositionFromLine(nextMarker)))
end

function repl:ConsoleSelectCommand(point)
  local cpos = self.console:ScreenToClient(point or wx.wxGetMousePosition())
  local position = self.console:PositionFromPoint(cpos)
  if position == wxstc.wxSTC_INVALID_POSITION then return end

  local promptline = self.console:MarkerPrevious(self.console:LineFromPosition(position), PROMPT_MARKER_VALUE)
  if promptline == wxstc.wxSTC_INVALID_POSITION then return end
  local nextline = self.console:MarkerNext(promptline+1, util.ANYMARKERMASK)
  local epos = nextline ~= wxstc.wxSTC_INVALID_POSITION and self.console:PositionFromLine(nextline) or self.console:GetLength()
  self.console:SetSelection(self.console:PositionFromLine(promptline), epos)
  return true
end

local currentHistory
local lastCommand = ""
function repl:getNextHistoryLine(forward, promptText)
  local count = self.console:GetLineCount()
  if currentHistory == nil then currentHistory = count end

  if forward then
    currentHistory = self.console:MarkerNext(currentHistory+1, PROMPT_MARKER_VALUE)
    if currentHistory == wx.wxNOT_FOUND then
      currentHistory = count
      return ""
    end
  else
    currentHistory = self.console:MarkerPrevious(currentHistory-1, PROMPT_MARKER_VALUE)
    if currentHistory == wx.wxNOT_FOUND then
      return lastCommand
    end
  end
  -- need to skip the current prompt line
  -- or skip repeated commands
  if currentHistory == self:getPromptLine()
  or self:getInput(currentHistory) == promptText then
    return self:getNextHistoryLine(forward, promptText)
  end
  return self:getInput(currentHistory)
end

function repl:getNextHistoryMatch(promptText)
  local count = self.console:GetLineCount()
  if currentHistory == nil then currentHistory = count end

  local current = currentHistory
  while true do
    currentHistory = self.console:MarkerPrevious(currentHistory-1, PROMPT_MARKER_VALUE)
    if currentHistory == wx.wxNOT_FOUND then -- restart search from the last item
      currentHistory = count
    elseif currentHistory ~= self:getPromptLine() then -- skip current prompt
      local input = self:getInput(currentHistory)
      if input:find(promptText, 1, true) == 1 then return input end
    end
    -- couldn't find anything and made a loop; get out
    if currentHistory == current then return end
  end

  assert(false, "getNextHistoryMatch coudn't find a proper match")
end

local HISTORY_FILE = "repl_history.txt"
function repl:save_history()
   local f = io.open(HISTORY_FILE, "w")

   currentHistory = -1
   local line = self:getNextHistoryLine(true)
   while line ~= "" do
      f:write(line)
      f:write("\n")
      line = self:getNextHistoryLine(true)
   end

   f:close()
end

function repl:load_history()
   local f, err = io.open(HISTORY_FILE, "r")
   if not f then
       return
   end

   for line in f:lines() do
      local insertAt = self.console:PositionFromLine(self:getPromptLine())
      local insertLineAt = self:getPromptLine()
      local text = self.console.useraw and line or util.fix_utf8(line, function (s) return '\\'..string.byte(s) end)
      local promptLine = self:getPromptLine()
      local lines = self.console:GetLineCount()

      self.console:InsertTextDyn(insertAt, text .. "\n")
      local linesAdded = self.console:GetLineCount() - lines
      for insert_line = insertLineAt, insertLineAt + linesAdded - 1 do
         self.console:MarkerAdd(insert_line, PROMPT_MARKER)
      end

      self.console:MarkerDelete(promptLine, PROMPT_MARKER)
      self.console:MarkerAdd(promptLine+linesAdded, PROMPT_MARKER)
      self.console:GotoPos(self.console:GetLength())
   end

   self.console:EmptyUndoBuffer()
   self.console:EnsureVisibleEnforcePolicy(self.console:GetLineCount()-1)

   currentHistory = self:getPromptLine()

   f:close()
end

local partial = false
function repl:shellPrint(marker, text, newline)
  if not text or text == "" then return end -- return if nothing to print
  if newline then text = text:gsub("\n+$", "").."\n" end
  local isPrompt = marker and (self:getPromptLine() ~= wx.wxNOT_FOUND)
  local lines = self.console:GetLineCount()
  local promptLine = isPrompt and self:getPromptLine() or nil
  local insertLineAt = isPrompt and not partial and self:getPromptLine() or self.console:GetLineCount()-1
  local insertAt = isPrompt and not partial and self.console:PositionFromLine(self:getPromptLine()) or self.console:GetLength()
  self.console:InsertTextDyn(insertAt, self.console.useraw and text or util.fix_utf8(text, function (s) return '\\'..string.byte(s) end))
  local linesAdded = self.console:GetLineCount() - lines

  partial = text:find("\n$") == nil

  if marker then
    if promptLine then self.console:MarkerDelete(promptLine, PROMPT_MARKER) end
    for line = insertLineAt, insertLineAt + linesAdded - 1 do
      self.console:MarkerAdd(line, marker)
    end
    if promptLine then self.console:MarkerAdd(promptLine+linesAdded, PROMPT_MARKER) end
  end

  self.console:EmptyUndoBuffer() -- don't allow the user to undo shell text
  self.console:GotoPos(self.console:GetLength())
  self.console:EnsureVisibleEnforcePolicy(self.console:GetLineCount()-1)

  self:save_history()
end

repl.displayShellDirect = function (self, ...) self:shellPrint(nil, concat("\t", ...), true) end
repl.DisplayShell = function (self, ...) self:shellPrint(OUTPUT_MARKER, concat("\t", ...), true) end
repl.DisplayShellErr = function (self, ...) self:shellPrint(ERROR_MARKER, concat("\t", ...), true) end
repl.DisplayShellMsg = function (self, ...) self:shellPrint(MESSAGE_MARKER, concat("\t", ...), true) end
-- don't print anything; just mark the line with a prompt mark
repl.DisplayShellPrompt = function (self, ...) self.console:MarkerAdd(self.console:GetLineCount()-1, PROMPT_MARKER) end

local function filterTraceError(err, addedret)
  local err = err:match("(.-:%d+:.-)\n[^\n]*\n[^\n]*\n[^\n]*src/editor/repl.lua:.*in function 'executeShellCode'")
              or err
        err = err:gsub("stack traceback:.-\n[^\n]+\n?","")
        if addedret then err = err:gsub('^%[string "return ', '[string "') end
        err = err:match("(.*)\n[^\n]*%(tail call%): %?$") or err
  return err
end

function repl:createenv()
  local env = {}
  setmetatable(env,{__index = _G})

  local function luafilename(level)
    level = level and level + 1 or 2
    local src
    while (true) do
      src = debug.getinfo(level)
      if (src == nil) then return nil,level end
      if (string.byte(src.source) == string.byte("@")) then
        return string.sub(src.source,2),level
      end
      level = level + 1
    end
  end

  local function luafilepath(level)
    local src,level = luafilename(level)
    if (src == nil) then return src,level end
    src = string.gsub(src,"[\\/][^\\//]*$","")
    return src,level
  end

  local function relativeFilename(file)
    assert(type(file)=='string',"String as filename expected")
    local name = file
    local level = 3
    while (name) do
      if (wx.wxFileName(name):FileExists()) then return name end
      name,level = luafilepath(level)
      if (name == nil) then break end
      name = name .. "/" .. file
    end

    return file
  end

  local function relativeFilepath(file)
    local name = luafilepath(3)
    return (file and name) and name.."/"..file or file or name
  end

  local _loadfile = loadfile
  local function loadfile(file)
    assert(type(file)=='string',"String as filename expected")
    local name = relativeFilename(file)

    return _loadfile(name)
  end

  local function dofile(file, ...)
    assert(type(file) == 'string',"String as filename expected")
    local fn,err = loadfile(file)
    local args = {...}
    if not fn then
      self:DisplayShellErr(err)
    else
      setfenv(fn,env)
      return fn(unpack(args))
    end
  end

  local os = {
    exit = function()
      self.app.frame:AddPendingEvent(wx.wxCommandEvent(wx.wxEVT_COMMAND_MENU_SELECTED, ID.EXIT))
    end,
  }
  env.os = setmetatable(os, {__index = _G.os})
  env.io = setmetatable({write = function(...) self.console:Write(...) end}, {__index = _G.io})
  env.print = function(...) self.console:Print(...) end
  env.dofile = dofile
  env.loadfile = loadfile
  env.RELFILE = relativeFilename
  env.RELPATH = relativeFilepath

  env.config = require "config"
  env.util = require "lib.util"

  return env
end

function repl:ShellSetAlias(alias, table)
  local value = self.env[alias]
  self.env[alias] = table
  return value
end

local function packResults(status, ...) return status, {...} end

function repl:executeShellCode(tx)
  if tx == nil or tx == '' then return end

  self:DisplayShellPrompt('')

  -- try to compile as statement
  local loadstring = loadstring or load
  local _, err = loadstring(tx)
  local isstatement = not err

  -- if remotesend and not forcelocal then remotesend(tx, isstatement); return end

  local addedret, forceexpression = true, tx:match("^%s*=%s*")
  tx = tx:gsub("^%s*=%s*","")
  local fn
  fn, err = loadstring("return "..tx)
  if not forceexpression and err then
    fn, err = loadstring(tx)
    addedret = false
  end

  if fn == nil and err then
    self:DisplayShellErr(filterTraceError(err, addedret))
  elseif fn then
    setfenv(fn,self.env)

    -- set the project dir as the current dir to allow "require" calls
    -- to work from shell
    local projectDir, cwd = util.get_project(), nil
    if projectDir and #projectDir > 0 then
      cwd = wx.wxFileName.GetCwd()
      wx.wxFileName.SetCwd(projectDir)
    end

    local ok, res = packResults(xpcall(fn,
      function(err)
        self:DisplayShellErr(filterTraceError(debug.traceback(err), addedret))
      end))

    -- restore the current dir
    if cwd then wx.wxFileName.SetCwd(cwd) end

    if ok and (addedret or #res > 0) then
      if addedret then
        for i,v in pairs(res) do -- stringify each of the returned values
          res[i] = (forceexpression and i > 1 and '\n' or '') .. inspect(v)
        end
        -- add nil only if we are forced (using =) or if this is not a statement
        -- this is needed to print 'nil' when asked for 'foo',
        -- and don't print it when asked for 'print(1)'
        if #res == 0 and (forceexpression or not isstatement) then
          res = {'nil'}
        end
      end
      self:DisplayShell(unpack(res))
    end
  end
end

repl.ShellExecuteInline = repl.executeShellCode
function repl:ShellExecuteCode(code)
  self:displayShellDirect(code)
  self:executeShellCode(code)
end

function repl:displayShellIntro()
  self:DisplayShellPrompt('')
  self:DisplayShellMsg(self.app:get_info())
end

function repl:bind_console_events()
   self.console.Print = function(_, ...) return self:DisplayShell(...) end
   self.console.Write = function(_, ...) return self:shellPrint(OUTPUT_MARKER, concat("", ...), false) end
   self.console.Error = function(_, ...) return self:DisplayShellErr(...) end

   self.console:Connect(wx.wxEVT_KEY_DOWN,
     function (event)
       -- this loop is only needed to allow to get to the end of function easily
       -- "return" aborts the processing and ignores the key
       -- "break" aborts the processing and processes the key normally
       while true do
         local key = event:GetKeyCode()
         local modifiers = event:GetModifiers()
         if key == wx.WXK_UP or key == wx.WXK_NUMPAD_UP then
           -- if we are below the prompt line, then allow to go up
           -- through multiline entry
           if self.console:GetCurrentLine() > self:getPromptLine() then break end

           -- if we are not on the caret line, or are on wrapped caret line, move normally
           if not self:caretOnPromptLine()
           or self.console:GetLineWrapped(self.console:GetCurrentPos(), -1) then break end

           -- only change prompt if no modifiers are used (to allow for selection movement)
           if modifiers == wx.wxMOD_NONE then
             local promptText = self:getPromptText()
             self:setPromptText(self:getNextHistoryLine(false, promptText))
             -- move to the end of the updated prompt
             self.console:GotoPos(self.console:GetLineEndPosition(self:getPromptLine()))
           end
           return
         elseif key == wx.WXK_DOWN or key == wx.WXK_NUMPAD_DOWN then
           -- if we are above the last line, then allow to go down
           -- through multiline entry
           local totalLines = self.console:GetLineCount()-1
           if self.console:GetCurrentLine() < totalLines then break end

           -- if we are not on the caret line, or are on wrapped caret line, move normally
           if not self:caretOnPromptLine()
           or self.console:GetLineWrapped(self.console:GetCurrentPos(), 1) then break end

           -- only change prompt if no modifiers are used (to allow for selection movement)
           if modifiers == wx.wxMOD_NONE then
             local promptText = self:getPromptText()
             self:setPromptText(self:getNextHistoryLine(true, promptText))
             -- staying at the end of the updated prompt
           end
           return
         elseif key == wx.WXK_TAB then
           -- if we are above the prompt line, then don't move
           local promptline = self:getPromptLine()
           if self.console:GetCurrentLine() < promptline then return end

           local promptText = self:getPromptText()
           -- save the position in the prompt text to restore
           local pos = self.console:GetCurrentPos()
           local text = promptText:sub(1, self:positionInLine(promptline))
           if #text == 0 then return end

           -- find the next match and set the prompt text
           local match = self:getNextHistoryMatch(text)
           if match then
             self:setPromptText(match)
             -- restore the position to make it easier to find the next match
             self.console:GotoPos(pos)
           end
           return
         elseif key == wx.WXK_ESCAPE then
           self:setPromptText("")
           return
         elseif key == wx.WXK_BACK or key == wx.WXK_LEFT or key == wx.WXK_NUMPAD_LEFT then
           if (key == wx.WXK_BACK or self.console:LineFromPosition(self.console:GetCurrentPos()) >= self:getPromptLine())
           and not self:caretOnPromptLine(true) then return end
         elseif key == wx.WXK_DELETE or key == wx.WXK_NUMPAD_DELETE then
           if not self:caretOnPromptLine()
           or self.console:LineFromPosition(self.console:GetSelectionStart()) < self:getPromptLine() then
             return
           end
         elseif key == wx.WXK_PAGEUP or key == wx.WXK_NUMPAD_PAGEUP
             or key == wx.WXK_PAGEDOWN or key == wx.WXK_NUMPAD_PAGEDOWN
             or key == wx.WXK_END or key == wx.WXK_NUMPAD_END
             or key == wx.WXK_HOME or key == wx.WXK_NUMPAD_HOME
             -- `key == wx.WXK_LEFT or key == wx.WXK_NUMPAD_LEFT` are handled separately
             or key == wx.WXK_RIGHT or key == wx.WXK_NUMPAD_RIGHT
             or key == wx.WXK_SHIFT or key == wx.WXK_CONTROL
             or key == wx.WXK_ALT then
           break
         elseif key == wx.WXK_RETURN or key == wx.WXK_NUMPAD_ENTER then
           if not self:caretOnPromptLine()
           or self.console:LineFromPosition(self.console:GetSelectionStart()) < self:getPromptLine() then
             return
           end

           -- allow multiline entry for shift+enter
           if self:caretOnPromptLine(true) and event:ShiftDown() then break end

           local promptText = self:getPromptText()
           if #promptText == 0 then return end -- nothing to execute, exit
           if promptText == 'clear' then
             self.console:Erase()
           elseif promptText == 'reset' then
             self.console:Reset()
             self:setPromptText("")
           else
             self:displayShellDirect('\n')
             self:executeShellCode(promptText)
           end
           currentHistory = self:getPromptLine() -- reset history
           return -- don't need to do anything else with return
         elseif modifiers == wx.wxMOD_NONE or self.console:GetSelectedText() == "" then
           -- move cursor to end if not already there
           if not self:caretOnPromptLine() then
             self.console:GotoPos(self.console:GetLength())
             self.console:SetReadOnly(false) -- allow the current character to appear at the new location
           -- check if the selection starts before the prompt line and reset it
           elseif self.console:LineFromPosition(self.console:GetSelectionStart()) < self:getPromptLine() then
             self.console:GotoPos(self.console:GetLength())
             self.console:SetSelection(self.console:GetSelectionEnd()+1,self.console:GetSelectionEnd())
           end
         end
         break
       end
       event:Skip()
     end)


   -- Scintilla 3.2.1+ changed the way markers move when the text is updated
   -- ticket: http://sourceforge.net/p/scintilla/bugs/939/
   -- discussion: https://groups.google.com/forum/?hl=en&fromgroups#!topic/scintilla-interest/4giFiKG4VXo
   if util.version_geq(util.wx_version(), "2.9.5") then
     -- this is a workaround that stores a position of the last prompt marker
     -- before insert and restores the same position after as the marker
     -- could have moved if the text is added at the beginning of the line.
     local promptAt
     self.console:Connect(wxstc.wxEVT_STC_MODIFIED,
       function (event)
         local evtype = event:GetModificationType()
         if bit.band(evtype, wxstc.wxSTC_MOD_BEFOREINSERT) ~= 0 then
           local promptLine = self:getPromptLine()
           if promptLine and event:GetPosition() == self.console:PositionFromLine(promptLine)
           then promptAt = promptLine end
         end
         if bit.band(evtype, wxstc.wxSTC_MOD_INSERTTEXT) ~= 0 then
           local promptLine = self:getPromptLine()
           if promptLine and promptAt then
             self.console:MarkerDelete(promptLine, PROMPT_MARKER)
             self.console:MarkerAdd(promptAt, PROMPT_MARKER)
             promptAt = nil
           end
         end
       end)

   self.console:Connect(wxstc.wxEVT_STC_UPDATEUI,
     function (event) self.console:SetReadOnly(not self:inputEditable()) end)

   -- only allow copy/move text by dropping to the input line
   self.console:Connect(wxstc.wxEVT_STC_DO_DROP,
     function (event)
       if not self:inputEditable(self.console:LineFromPosition(event:GetPosition())) then
         event:SetDragResult(wx.wxDragNone)
       end
     end)

   if config.nomousezoom then
     -- disable zoom using mouse wheel as it triggers zooming when scrolling
     -- on OSX with kinetic scroll and then pressing CMD.
     self.console:Connect(wx.wxEVT_MOUSEWHEEL,
       function (event)
         if wx.wxGetKeyState(wx.WXK_CONTROL) then return end
         event:Skip()
       end)
   end
   end

   self.console.Erase = function()
      -- save the last command to keep when the history is cleared
      currentHistory = self:getPromptLine()
      lastCommand = self:getNextHistoryLine(false, "")
      -- allow writing as the editor may be read-only depending on current cursor position
      self:SetReadOnly(false)
      self:ClearAll()
      self:displayShellIntro()
   end

   self.console.Reset = function()
      self.env = self:createenv() -- recreate the environment to "forget" all changes in it
   end

  -- self.console.Activate = function(_)
  --   local uimgr = self.app.aui
  --   local pane = uimgr:GetPane(nb)
  --   if pane:IsOk() and not pane:IsShown() then
  --     pane:Show(true)
  --     uimgr:Update()
  --   end
  --   return true
  -- end

  util.connect(self.console, wx.wxEVT_SIZE, self, "on_size")
end

function repl:inputEditable(line)
   return self:caretOnPromptLine(false, line) and
      not (self.console:LineFromPosition(self.console:GetSelectionStart()) < self:getPromptLine())
end

function repl:activate()
   return self.console:SetFocus()
end

function repl:set_variable(k, v)
   self.env[k] = v
end

--
-- Events
--

function repl:on_size()
  self.console:GotoPos(self.console:GetLength())
end

function repl:on_destroy()
   print("Saving history.")
   self:save_history()
end

return repl
