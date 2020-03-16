package.path = package.path .. ";src\\?.lua"
package.cpath = package.cpath .. ";lib\\?.dll"

class = require("class")

local config = require("config")
local lxp = require("lxp")

local entries = {}
local senses = {}
local readings = {}
local kanjis = {}

local entry
local cur

local state = {}

local callbacks = {
   StartElement = function(parser, name)
      state[#state+1] = name
      if name == "entry" then
         entry = {
            sequence_number = 0,
            type = 0
         }
      elseif name == "sense" then
         cur = {
            glosses = {},
            parts_of_speech = {},
            miscs = {}
         }
      elseif name == "r_ele" then
         cur = {
            reading = nil,
            pris = {}
         }
      elseif name == "k_ele" then
         cur = {
            reading = nil,
            pris = {}
         }
      end
   end,
   Default = function(parser, str)
      local st = state[#state]

      if st == "gloss" then
         table.insert(cur.glosses, str)
      elseif st == "pos" then
         table.insert(cur.parts_of_speech, str)
      elseif st == "misc" then
         table.insert(cur.miscs, str)
      elseif st == "reb" or st == "keb" then
         assert(cur.reading == nil)
         cur.reading = str
      elseif st == "ke_pri" or st == "re_pri" then
         table.insert(cur.pris, str)
      elseif st == "ent_seq" then
         entry.sequence_number = tonumber(str)
      end
   end,
   EndElement = function(parser, name)
      state[#state] = nil

      if name == "entry" then
         entries[#entries+1] = entry
      elseif name == "sense" then
         cur.entry = entry
         table.insert(senses, cur)
      elseif name == "r_ele" then
         cur.entry = entry
         table.insert(readings, cur)
      elseif name == "k_ele" then
         cur.entry = entry
         table.insert(kanjis, cur)
      end
   end
}

local p = lxp.new(callbacks)

local file = arg[1]
assert(file, "usage: build_db.lua path/to/JMdict_e")
local f = assert(io.open(file))

print("Parsing JMdict...")

for l in f:lines() do  
   p:parse(l)
   p:parse("\n")
end
f:close()

p:parse()
p:close()

print("Adding entries to DB...")

local db = require("lib.db"):new(config.db_path)

db:dofile("tools/schema.sql")
db:add(entries, senses, readings, kanjis)
db:close()

print("Done.")
