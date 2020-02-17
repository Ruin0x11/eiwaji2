-- Expose events not provided by stock wxLua
local function add_private_events(wx)
   local private = {
      wxEVT_HTML_LINK_CLICKED = 10221
   }

   for k, v in pairs(private) do
      if not wx[k] then
         wx[k] = v
      end
   end
end

return function(wx)
   add_private_events(wx)
end
