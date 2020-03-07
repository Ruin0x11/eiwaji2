function string.split(s, re)
   local i1, ls = 1, { }
    if not re then re = '%s+' end
    if re == '' then return { s } end
    while true do
      local i2, i3 = s:find(re, i1)
      if not i2 then
        local last = s:sub(i1)
        if last ~= '' then ls[#ls+1] = last end
        if #ls == 1 and ls[1] == '' then
          return  { }
        else
          return ls
        end
      end
      ls[#ls+1] = s:sub(i1, i2 - 1)
      i1 = i3 + 1
    end
  end

function string.escape_magic(s)
   return s:gsub("([%(%)%.%%%+%-%*%?%[%^%$%]])", "%%%1")
end

function string.trim(str, chars)
  if not chars then return str:match("^[%s]*(.-)[%s]*$") end
  chars = string.escape_magic(chars)
  return str:match("^[" .. chars .. "]*(.-)[" .. chars .. "]*$")
end