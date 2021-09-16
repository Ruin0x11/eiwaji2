local ffi = require("ffi")
local mecab = require("yukie.mecab_ffi")

local function set(arr)
   local tbl = {}
   for _, k in ipairs(arr) do
      tbl[k] = true
   end
   return tbl
end

local vars = set {
   "id",
   "length",
   "rlength",
   "posid",
   "char_type",
   "stat",
}

local node = {}
node.__index = node

local feature_keys = {
   "pos",
   "pos2",
   "pos3",
   "pos4",
   "inflection_type",
   "inflection_form",
   "lemma",
   "reading",
   "pronounciation"
}

function node:new(inner)
   return setmetatable(
      {
         _inner = inner,
         surface = ffi.string(inner.surface, inner.length)
      },
      {
         __index = function(self, key)
            if vars[key] then
               return self._inner[key]
            elseif key == "feature" then
               return ffi.string(self._inner.feature)
            end

            return node[key]
         end
      }
   )
end

function node:is_unknown()
   return self.stat == mecab.C.MECAB_UNK_NODE
end

function node:whitespace()
   return string.rep(" ", self.rlength - self.length)
end

function node:get_features()
   local feature = ffi.string(self._inner.feature)
   local features = { literal = self.surface }
   local i = 1
   for tok in feature:gmatch("([^,]+)[,]?") do
      local k = feature_keys[i]
      features[k] = tok
      i = i + 1
   end
   return features
end

return node
