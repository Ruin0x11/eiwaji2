local utf8 = require("lua-utf8")

--[[

edges["a"] = {
   {
       [10] = 120
   }
}
edges["b"]
edges["c"]

--]]

local dawg_node = {}
local dawg_node_mt = {
   __index = dawg_node,
   __tostring = function(self)
      local t = {}
      if self.final then
         t[#t+1] = "1"
      else
         t[#t+1] = "0"
      end
      for k, n in pairs(self.edges) do
         t[#t+1] = k
         t[#t+1] = tostring(n.id)
      end
      return table.concat(t, "_")
   end,
   __eq = function(self, other)
      return tostring(self) == tostring(other)
   end
}

local next_id = 0
function dawg_node:new()
   local tbl = {
      id = next_id,
      edges = {},
      final = nil,
      count = nil
   }
   next_id = next_id + 1
   return setmetatable(tbl, dawg_node_mt)
end

function dawg_node:num_reachable()
   if self.count then
      return self.count
   end

   local count = 0
   if self.final then
      count = count + 1
   end
   for _, n in pairs(self.edges) do
      count = count + n:num_reachable()
   end
   self.count = count
   return count
end


local dawg = {}
local dawg_mt = { __index = dawg }

function dawg:new()
   local tbl = {
      previous_word = "",
      data = {},
      minimized_nodes = {},
      unchecked_nodes = {},
      root = dawg_node:new()
   }
   return setmetatable(tbl, dawg_mt)
end

function dawg:insert(word, data)
   if word == self.previous_word then
      return
   end
   assert(word > self.previous_word, "words must be inserted in alphabetical order")

   local common_prefix = 1
   for i=1,math.min(utf8.len(word),utf8.len(self.previous_word)) do
      if utf8.sub(word, i, i) ~= utf8.sub(self.previous_word, i, i) then
         break
      end
      common_prefix = common_prefix + 1
   end

   self:minimize(common_prefix)

   local node
   if #self.unchecked_nodes == 0 then
      node = self.root
   else
      node = self.unchecked_nodes[#self.unchecked_nodes][3]
   end

   for i=common_prefix,utf8.len(word) do
      local ch = utf8.sub(word, i, i)
      local next_node = dawg_node:new()
      node.edges[ch] = next_node
      table.insert(self.unchecked_nodes, {node, ch, next_node})
      node = next_node
   end

   node.final = true

   self.data[node.id] = data

   self.previous_word = word
end

function dawg:minimize(down_to)
   for i = #self.unchecked_nodes, down_to, -1 do
      local entry = self.unchecked_nodes[i]
      local parent = entry[1]
      local ch = entry[2]
      local child = entry[3]
      if self.minimized_nodes[child] then
         parent.edges[ch] = self.minimized_nodes[child]
      else
         self.minimized_nodes[child] = child
      end
      self.unchecked_nodes[i] = nil
   end
end

function dawg:finish()
   self:minimize(1)
   self.root:num_reachable()
end

-- Warning! This function is only guaranteed to work if all keys are strings or numbers.
local function defaultKeySort(key1, key2)
  -- "number" < "string", so numbers will be sorted before strings.
  local type1, type2 = type(key1), type(key2)
  if type1 ~= type2 then
    return type1 < type2
  else
    return key1 < key2
  end
end

local function keysToList(t, keySort)
  local list = {}
  local index = 1
  for key in pairs(t) do
    list[index] = key
    index = index + 1
  end

  keySort = keySort or defaultKeySort

  table.sort(list, keySort)

  return list
end

-- Input a custom keySort function in the second parameter, or use the default one.
-- Creates a new table and closure every time it is called.
local function sorted_pairs(t, keySort)
  local list = keysToList(t, keySort, true)

  local i = 0
  return function()
    i = i + 1
    local key = list[i]
    if key ~= nil then
      return key, t[key]
    else
      return nil, nil
    end
  end
end

function dawg:lookup(word)
   local node = self.root
   local skipped = 0
   for i = 1, utf8.len(word) do
      local ch = utf8.sub(word, i, i)
      if not node.edges[ch] then
         return nil
      end
      for label, child in sorted_pairs(node.edges) do
         if label == ch then
            if node.final then
               skipped = skipped + 1
            end
            node = child
            break
         end
         skipped = skipped + child.count
      end
   end

   if node.final then
      return self.data[node.id]
   end
end

function dawg:search(word)
   local node = self.root
   local skipped = 0
   local cands = {}
   for i = 1, utf8.len(word) do
      local ch = utf8.sub(word, i, i)
      if not node.edges[ch] then
         return {}
      end
      for label, child in sorted_pairs(node.edges) do
         if label == ch then
            if node.final then
               skipped = skipped + 1
            end
            node = child
            break
         end
         skipped = skipped + child.count
      end
   end

   if node.final then
      cands[#cands+1] = self.data[node.id]
   end

   local stack = { node }
   local done = {}
   while #stack > 0 do
      local node = stack[#stack]
      stack[#stack] = nil
      if not done[node.id] then
         done[node.id] = true
         if node.final then
            cands[#cands+1] = self.data[node.id]
            skipped = skipped + 1
         else
            skipped = skipped + node.count
         end
         for label, child in sorted_pairs(node.edges) do
            stack[#stack+1] = child
         end
      end
   end

   return cands
end

function dawg:dump()
   local stack = { self.root }
   local done = {}
   while #stack > 0 do
      local node = stack[#stack]
      stack[#stack] = nil
      if not done[node.id] then
         done[node.id] = true
         print(("%d: (%s)"):format(node.id, node))
         for label, child in pairs(node.edges) do
            print(("    %s goto %s"):format(label, child.id))
            stack[#stack+1] = child
         end
      end
   end
end

return dawg
