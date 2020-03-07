fun = require("thirdparty.fun")
inspect = require("thirdparty.inspect")
class = require("src.class")

local ffi = require("ffi")
if ffi.os == "Windows" then
   package.path = package.path .. ";lib\\luasocket\\?.lua;lib\\luautf8\\?.lua"
   package.cpath = package.cpath .. ";lib\\luautf8\\?.dll;lib\\luasocket\\?.dll;lib\\mecab\\bin\\?.dll"
end

package.path = package.path .. ";./?/init.lua;./src/?.lua;./src/?/init.lua"
package.path = package.path .. ";./thirdparty/?.lua;./thirdparty/?/init.lua"

require("ext")

app = nil

local function remove_all_metatables(item, path)
  if path[#path] ~= inspect.METATABLE then return item end
end

function ppr(...)
   local t = {...}
   local max = 0

   -- nil values in varargs will mess up ipairs, so iterate by the
   -- largest array index found instead and assume everything in
   -- between was passed as nil.
   for k, _ in pairs(t) do
      max = math.max(max, k)
   end

   for i=1,max do
      local v = t[i]
      if v == nil then
         io.write("nil")
      else
         io.write(inspect(v, {process = remove_all_metatables}))
      end
      io.write("\t")
   end
   if #{...} == 0 then
      io.write("nil")
   end
   io.write("\n")
   return ...
end

require("thirdparty/strict")

app = require("app.init"):new()
app:run()
