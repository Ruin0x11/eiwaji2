local mecab_util = {}

function mecab_util.get_prefix(word)
   if word.lemma ~= "*" then
      return word.lemma
   end
   return word.word
end

return mecab_util
