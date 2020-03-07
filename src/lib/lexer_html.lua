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
   if word.part_of_speech == "symbol" then
      return word.word
   end

   local ref = i
   local color = COLORS[word.part_of_speech] or "#AAFF00"
   return ("<a href='%s'><font color='%s'>%s</font></a>  ")
      :format(ref, color, word.word)
end

function lexer_html.convert(mecab)
   return table.concat(fun.iter(mecab):enumerate():map(word_to_link):to_list())
end

function lexer_html.colorize_sentence(word, start_pos, text)
   local sentence = "<div>"
   sentence = sentence .. string.sub(text, 1, start_pos-1)
   sentence = sentence .. "<font color='#FF0000'>"
   sentence = sentence .. word
   sentence = sentence .. "</font>"
   sentence = sentence .. string.sub(text, start_pos+string.len(word))
   sentence = sentence .. "</div>"
   return sentence
end

return lexer_html
