local lexer_html = {}

local COLORS = {
   verb         = "#808080",
   noun         = "#000000",
   propernoun   = "#000000",
   symbol       = "#000000",
   postposition = "#FF0000",
   pronoun      = "#000000",
   adjective    = "#000000",
   adverb       = "#000000",
   conjunction  = "#000000",
   determiner   = "#000000",
   background   = "#FFFFFF",
   number       = "#000000",
   prefix       = "#000000",
   suffix       = "#000000",
   default      = "#FF00FF"
}

local function word_to_link(i, word)
   local ref = i
   local color = COLORS[word.part_of_speech] or "#AAFF00"
   return ("<a href='%s'><font color='%s'>%s</font></a>  ")
      :format(ref, color, word.word)
end

function lexer_html.convert(mecab)
   return table.concat(fun.iter(mecab):enumerate():map(word_to_link):to_list())
end

return lexer_html
