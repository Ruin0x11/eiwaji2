local util = require("lib.util")
local wx = require("wx")
local jeejah = require("jeejah")

local debug_server = class.class("debug_server")

function debug_server:init(app, port)
   self.app = app
   self.id = util.new_id()
   self.timer = wx.wxTimer(app.frame, self.id)
   self.port = port
   self.server = nil

   self.app:connect(self.id, wx.wxEVT_TIMER, self, "on_timer")

   self:start()
end

function debug_server:start()
   if self.server then
      error("Server is already running.")
   end

   local pp = function(x) return require("inspect").inspect(x, {depth=2}) end
   local handlers = {}
   function handlers.reload(conn, msg, session, send, response_for)
      local success, status = xpcall(util.hotload, debug.traceback, msg.ns)

      if success then
         self.app:print("Hotloaded %s.", msg.ns)
         return send(conn, response_for(msg, {status={"done"}}))
      else
         return send(conn, response_for(msg, {status={"done"},err=status}))
      end
   end

   self.server = jeejah.start(self.port, {debug=true,pp=pp,handlers=handlers})

   self.app:print("Debug server listening on %d.", self.port)

   self.timer:Start(100)
end

function debug_server:stop()
   if self.server == nil then
      return
   end

   self.app:print("Stopping debug server.")

   self.timer:Stop()

   jeejah.stop(self.server)
   self.server = nil
   self.coro = nil
end

--
-- Events
--

function debug_server:on_timer(event)
   if event:GetTimer() ~= self.timer then
      return
   end

   coroutine.resume(self.server)
end

return debug_server
