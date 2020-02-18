local PRIVATE_EVENTS = {
   wxEVT_HTML_LINK_CLICKED = 10221
}

-- Expose events not provided by stock wxLua
local function add_private_events(wx)
   for k, v in pairs(PRIVATE_EVENTS) do
      if not wx[k] then
         wx[k] = v
      end
   end
end

return function(wx)
   add_private_events(wx)
end
