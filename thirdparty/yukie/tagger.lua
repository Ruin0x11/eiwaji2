local ffi = require("ffi")
local mecab = require("yukie.mecab_ffi")
local node = require("yukie.node")

local tagger = {}
tagger.__index = tagger

function tagger:new(args)
   args = args or {"-Owakati"}
   local argc = #args
   local argv = ffi.new("const char*[?]", argc)
   for i, s in ipairs(args) do
      argv[i-1] = ffi.new("const char*", s)
   end
   return setmetatable(
      {
         inner = mecab.tagger(argc, argv)
      },
      { __index = tagger }
   )
end

function tagger:sparse_tostr(str)
   local c_str = ffi.new("const char*", str)
   local result, err = self.inner:sparse_tostr(c_str)
   if result == nil then
      return nil, ffi.string(err)
   end

   return ffi.string(result)
end

function tagger:sparse_tonode(str)
   local c_str = ffi.new("const char*", str)

   local raw, err = self.inner:sparse_tonode(c_str)
   if raw == nil then
      return nil, ffi.string(err)
   end
   local nodes = {}

   -- skip BOS and EOS
   while raw.next do
      raw = raw.next
      if raw.stat == mecab.C.MECAB_EOS_NODE then
         break
      end
      nodes[#nodes+1] = node:new(raw)
   end

   return nodes
end

return tagger
