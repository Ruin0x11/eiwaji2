# yukie
A LuaJIT binding to mecab.

Word identification was mostly just ported from [ve](https://github.com/Kimtaro/ve).

## usage
```lua
local yukie = require("yukie")
local inspect = require("inspect")

local words = yukie.parse_to_words("吾輩は猫である。名前はまだない。")
print(inspect(words[1]))
-- {
--    extra = {
--      pronounciation = "ワガハイ",
--      reading = "ワガハイ"
--    },
--    lemma = "吾輩",
--    part_of_speech = "pronoun",
--    tokens = { {
--        inflection_form = "*",
--        inflection_type = "*",
--        lemma = "吾輩",
--        literal = "吾輩",
--        pos = "名詞",
--        pos2 = "代名詞",
--        pos3 = "一般",
--        pos4 = "*",
--        pronounciation = "ワガハイ",
--        reading = "ワガハイ"
--      } },
--    word = "吾輩"
--  }
```
