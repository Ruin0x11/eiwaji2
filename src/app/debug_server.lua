local json = require("thirdparty.json")
local socket = require("socket")
local util = require("lib.util")
local wx = require("wx")

local debug_server = class.class("debug_server")

function debug_server:init(app, port)
   self.app = app
   self.id = util.new_id()
   self.timer = wx.wxTimer(app.frame, self.id)
   self.port = port

   self.app:connect(self.id, wx.wxEVT_TIMER, self, "on_timer")

   self:start()
end

function debug_server:start()
   if self.server then
      error("Server is already running.")
   end

   local server, err = socket.bind("127.0.0.1", self.port)
   if not server then
      self.app:print("!!! Failed to start debug server: %s !!!", err)
      return
   end

   self.app:print("Debug server listening on %d.", self.port)

   self.server = server
   self.server:settimeout(0)

   self.timer:Start(100)
end

function debug_server:stop()
   if self.server == nil then
      return
   end

   self.app:print("Stopping debug server.")

   self.timer:Stop()

   self.server:close()
   self.server = nil
   self.coro = nil
end

--
-- Events
--

local commands = {}

local function error_result(err)
   return {
      success = false,
      message = err
   }
end

function commands.run(self, text)
   local status, success, result

   local s, err = loadstring(text)
   if s then
      success, result = xpcall(s, function(e) return e .. "\n" .. debug.traceback(2) end)
      if success then
         self.app:print("Success: %s", result)
         status = "success"
      else
         self.app:print("Exec error:\n\t%s", result)
         status = "exec_error"
      end
   else
      self.app:print("Compile error:\n\t%s", err)
      status = "compile_error"
   end

   if not success then
      return error_result(status)
   end

   return {}
end

-- Request:
--
-- {
--   "command":"hotload",
--   "content":"src.app"
-- }
--
-- Response:
--
-- {
--   "success":true
-- }
function commands.hotload(self, require_path)
   local success, status = xpcall(util.hotload, debug.traceback, require_path)

   if not success then
      return error_result(status)
   else
      self.app:print("Hotloaded %s.", require_path)
   end

   return {}
end

function commands.signature(self)
   return {}
end

function debug_server:on_timer(event)
   if event:GetTimer() ~= self.timer then
      return
   end

   local client, _, err = self.server:accept()

   if err and err ~= "timeout" then
      error(err)
   end

   local cmd_name = nil
   local result = nil

   while client ~= nil do
      local text = client:receive("*l")

      -- JSON should have this format:
      --
      -- {
      --   "command":"help",
      --   "content":"Chara.create"
      -- }

      local ok, req = pcall(json.decode, text)
      if not ok then
         result = error_result(req)
      else
         cmd_name = req.command
         local content = req.content
         if type(cmd_name) ~= "string" or type(content) ~= "string" then
            result = error_result("Request must have 'command' and 'content' keys")
         else
            local cmd = commands[cmd_name]
            if cmd == nil then
               result = error_result("No command named " .. cmd_name)
            else
               local ok, err = xpcall(cmd, debug.traceback, self, content)
               if not ok then
                  result = error_result(err)
               else
                  result = err
                  if result.success == nil then
                     result.success = true
                  end
               end
            end
         end
      end

      local ok, resp = pcall(json.encode, result)
      if not ok then
         result = error_result("JSON encoding error: " .. resp)
         resp = json.encode(result)
      end

      local byte, err = client:send(resp .. "")
      client:close()

      result = result.success

      client, _, err = self.server:accept()
      if err and err ~= "timeout" then
         error(err)
      end
   end

   return cmd_name, result
end

return debug_server
