local lexer_html = {}

local function word_to_link(i, word)
   local ref = i
   local color = "#AA0000"
   return ("<a href='%s'><font color='%s'>%s</font></a>  ")
      :format(ref, color, word)
end

function lexer_html.convert(mecab)
   mecab = {
      "ああああ",
      "すすすす",
      "、",
      "すみません"
   }

   return table.concat(fun.iter(mecab):enumerate():map(word_to_link):to_list())
end

return lexer_html
