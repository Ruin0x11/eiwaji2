function table.shallow_copy(t)
   local rtn = {}
   for k, v in pairs(t) do rtn[k] = v end
   return rtn
 end

function table.replace_with(tbl, other)
    if tbl == other then
       return tbl
    end

    local mt = getmetatable(tbl)
    local other_mt = getmetatable(other)
    if mt and other_mt then
       table.replace_with(mt, other_mt)
    end

    for k, _ in pairs(tbl) do
       tbl[k] = nil
    end

    for k, v in pairs(other) do
       tbl[k] = v
    end

    return tbl
end

-- Returns the keys of a dictionary-like table.
-- @tparam table tbl
-- @treturn list
function table.keys(tbl)
   local arr = {}
   for k, _ in pairs(tbl) do
      arr[#arr+1] = k
   end
   return arr
end
