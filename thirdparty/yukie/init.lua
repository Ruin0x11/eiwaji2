local tagger = require("yukie.tagger")
local ipadic = require("yukie.ipadic")

local yukie = {}

local NA = "な"
local NI = "に"
local TE = "て"
local DE = "で"
local BA = "ば"
local NN = "ん"
local SA = "さ"

local function make_set(arr)
   local tbl = {}
   for _, k in ipairs(arr) do
      tbl[k] = true
   end
   return tbl
end

function yukie.parse_to_nodes(str, args)
   assert(type(str)=="string", "string must be passed")

   local the_tagger = tagger:new(args)

   local nodes, err = the_tagger:sparse_tonode(str)
   if nodes == nil then
      error(err)
   end

   return nodes
end

function yukie.parse_to_words(str, args)
   assert(type(str)=="string", "string must be passed")

   local the_tagger = tagger:new(args)

   local nodes, err = the_tagger:sparse_tonode(str)
   if nodes == nil then
      error(err)
   end

   local words = {}
   local previous = nil

   for i, node in ipairs(nodes) do
      local pos = nil
      local grammar = nil
      local eat_next = false
      local eat_lemma = true
      local attach_to_previous = false
      local attach_to_lemma = false
      local update_pos = false

      local features = node:get_features()

      if features.pos == ipadic.MEISHI then
         pos = "noun"

         local pos2 = features.pos2
         if pos2 == ipadic.KOYUUMEISHI then
            pos = "proper_noun"
         elseif pos2 == ipadic.DAIMEISHI then
            pos = "pronoun"
         elseif pos2 == ipadic.FUKUSHIKANOU
            or pos2 == ipadic.SAHENSETSUZOKU
            or pos2 == ipadic.KEIYOUDOUSHIGOKAN
            or pos2 == ipadic.NAIKEIYOUSHIGOKAN
         then
            if i < #nodes then
               local following = nodes[i+1]:get_features()
               if following.inflection_type == ipadic.SAHEN_SURU then
                  pos = "verb"
                  eat_next = true
               elseif following.inflection_type == ipadic.TOKUSHU_DA then
                  pos = "adjective"
                  if following.inflection_type == ipadic.TAIGENSETSUZOKU then
                     eat_next = true
                     eat_lemma = false
                  end
               elseif following.inflection_type == ipadic.TOKUSHU_NAI then
                  pos = "adjective"
               elseif following.pos == ipadic.JOSHI and following.literal == NI then
                  pos = "adverb"
                  eat_next = false
               end
            end
         elseif pos2 == ipadic.HIJIRITSU
            or pos2 == ipadic.TOKUSHU
         then
            if i < #nodes then
               local following = nodes[i+1]:get_features()
               local pos3 = features.pos3
               if pos3 == ipadic.FUKUSHIKANOU then
                  if following.pos == ipadic.JOSHI and following.literal == NI then
                     pos = "adverb"
                     eat_next = true
                  end
               elseif pos3 == ipadic.JODOUSHIGOKAN then
                  if following.inflection_type == ipadic.TOKUSHU_DA then
                     pos = "verb"
                     grammar = "auxillary"
                     if following.inflection_form == ipadic.TAIGENSETSUZOKU then
                        eat_next = true
                     elseif following.pos == ipadic.JOSHI and following.pos2 == ipadic.FUKUSHIKA then
                        pos = "adverb"
                        eat_next = true
                     end
                  end
               elseif pos3 == ipadic.KEYOUDOUSHIGOKAN then
                  pos = "adjective"
                  if (following.inflection_type == ipadic.TOKUSHU_DA and following.inflection_form == ipadic.TAIGENSETSUZOKU)
                     or following.pos2 == ipadic.RENTAIKA
                  then
                     eat_next = true
                  end
               end
            end
         elseif pos2 == ipadic.KAZU then
            pos = "number"
            -- TODO
         elseif pos2 == ipadic.SETSUBI then
            if features.pos3 == ipadic.JINMEI then
               pos = "suffix"
            else
               if features.pos3 == ipadic.TOKUSHU and features.lemma == SA then
                  pos = "noun"
                  update_pos = true
               else
                  attach_to_lemma = true
               end
               attach_to_previous = true
            end
         elseif pos2 == ipadic.SETSUZOKUSHITEKI then
            pos = "conjunction"
         elseif pos2 == ipadic.DOUSHIHIJIRITSUTEKI then
            pos = "verb"
            grammar = "nominal"
         end
      elseif features.pos == ipadic.SETTOUSHI then
         pos = "prefix"
      elseif features.pos == ipadic.JODOUSHI then
         pos = "postposition"
         local set = make_set {
            ipadic.TOKUSHU_TA,
            ipadic.TOKUSHU_NAI,
            ipadic.TOKUSHU_TAI,
            ipadic.TOKUSHU_MASU,
            ipadic.TOKUSHU_NU
         }
         if (previous == nil or previous.pos2 ~= ipadic.KAKARIJOSHI) and set[features.inflection_type] then
            attach_to_previous = true
         elseif features.inflection_type == ipadic.FUHENKAGATA and (features.lemma == ipadic.NN or features.lemma == ipadic.U) then
            attach_to_previous = true
         elseif (features.inflection_type == ipadic.TOKUSHU_DA
                    or features.inflection_type == ipadic.TOKUSHU_DESU)
            and features.literal ~= NA
         then
            pos = "verb"
         end
      elseif features.pos == ipadic.DOUSHI then
         pos = "verb"
         if features.pos2 == ipadic.SETSUBI then
            attach_to_previous = true
         elseif features.pos2 == ipadic.HIJIRITSU and features.inflection_form ~= ipadic.MEIREI_I then
            attach_to_previous = true
         end
      elseif features.pos == ipadic.KEIYOUSHI then
         pos = "adjective"
      elseif features.pos == ipadic.JOSHI then
         pos = "postposition"
         if features.pos2 == ipadic.SETSUZOKUJOSHI and make_set({TE, DE, BA})[features.literal] then
            attach_to_previous = true
         end
      elseif features.pos == ipadic.RENTAISHI then
         pos = "determiner"
      elseif features.pos == ipadic.SETSUZOKUSHI then
         pos = "conjunction"
      elseif features.pos == ipadic.FUKUSHI then
         pos = "adverb"
      elseif features.pos == ipadic.KIGOU then
         pos = "symbol"
      elseif features.pos == ipadic.FIRAA or features.pos == ipadic.KANDOUSHI then
         pos = "interjection"
      elseif features.pos == ipadic.SONOTA then
         pos = "other"
      end

      if attach_to_previous and #words > 0 then
         local word = words[#words]
         table.insert(word.tokens, features)
         word.word = word.word .. features.literal
         if features.reading then
            word.extra.reading = word.extra.reading .. features.reading
         end
         if features.pronounciation then
            word.extra.pronounciation = word.extra.pronounciation .. features.pronounciation
         end
         if attach_to_lemma then
            word.lemma = word.lemma .. features.lemma
         end
         if update_pos then
            word.part_of_speech = pos
         end
      else
         pos = pos or "unknown"
         local word = {
            word = features.literal,
            lemma = features.lemma,
            part_of_speech = pos,
            tokens = { features },
            extra = {
               reading = features.reading or "",
               pronounciation = features.pronounciation or "",
               grammar = grammar
            }
         }

         if eat_next then
            local following = nodes[i+1]:get_features()
            table.insert(word.tokens, following)
            word.word = word.word .. following.literal
            if following.reading then
               word.extra.reading = word.extra.reading .. following.reading
            end
            if following.pronounciation then
               word.extra.pronounciation = word.extra.pronounciation .. following.pronounciation
            end
            if eat_lemma then
               word.lemma = word.lemma .. following.lemma
            end
         end

         words[#words+1] = word
      end

      previous = features
   end

   return words
end

return yukie
