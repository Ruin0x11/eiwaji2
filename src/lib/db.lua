local dawg = require "lib.dawg"
local sqlite = require "thirdparty.ljsqlite3"
local util = require"lib.util"

local split = util.split

local db = class.class("db")

function db:init(file)
   self.conn = sqlite.open(file)
   self.dawg = nil
end

local function build_dawg(conn)
   print "build index"

   local corpus = {}

   local stmt, t

   stmt = [[SELECT * FROM readings]]
   t = conn:exec(stmt)
   for i=1, #t[1] do
      local id = tonumber(t[3][i])
      local reading = t[1][i]
      corpus[#corpus+1] = { reading, id }
   end

   print "reading"

   stmt = [[SELECT * FROM kanjis]]
   t = conn:exec(stmt)
   for i=1, #t[1] do
      local id = tonumber(t[3][i])
      local reading = t[1][i]
      corpus[#corpus+1] = { reading, id }
   end

   print "kanji"

   t = nil
   collectgarbage()
   collectgarbage()

   table.sort(corpus, function(a, b) return a[1] < b[1] end)

   print "sort"

   local d = dawg:new()

   for _, v in ipairs(corpus) do
      d:insert(v[1], v[2])
   end

   d:finish()

   print "finish"

   return d
end

function db:search(prefix)
   if self.dawg == nil then
      self.dawg = build_dawg(self.conn)
   end

   local result = self.dawg:search(prefix)

   if #result == 0 then
      return {}
   end

   return self:find_by_ids(result)
end

function db:find_by_ids(ids)
   local s = "("
   for i, id in ipairs(ids) do
      if i == #ids then
         s = s .. tostring(id) .. ")"
      else
         s = s .. tostring(id) .. ", "
      end
   end

   local entries = {}
   local mapping = {}
   for _, id in ipairs(ids) do
      if not mapping[id] then
         entries[#entries+1] = {
            sequence_number = id,
            senses = {},
            kanjis = {},
            readings = {},
         }
         mapping[id] = #entries
      end
   end

   local stmt, t

   stmt = ([[SELECT * FROM senses WHERE entry_id IN %s]]):format(s)
   t = self.conn:exec(stmt)
   if t then
      for i=1, #t[1] do
         local id = tonumber(t[4][i])
         local sense = {
            glosses = split(t[1][i], "|"),
            parts_of_speech = split(t[2][i], "|"),
            miscs = split(t[3][i], "|"),
         }
         table.insert(entries[mapping[id]].senses, sense)
      end
   end

   stmt = ([[SELECT * FROM readings WHERE entry_id IN %s]]):format(s)
   t = self.conn:exec(stmt)
   if t then
      for i=1, #t[1] do
         local id = tonumber(t[3][i])
         local reading = {
            reading = t[1][i],
            pris = split(t[2][i], "|"),
         }
         table.insert(entries[mapping[id]].readings, reading)
      end
   end

   stmt = ([[SELECT * FROM kanjis WHERE entry_id IN %s]]):format(s)
   t = self.conn:exec(stmt)
   if t then
      for i=1, #t[1] do
         local id = tonumber(t[3][i])
         local kanji = {
            reading = t[1][i],
            pris = split(t[2][i], "|"),
         }
         table.insert(entries[mapping[id]].kanjis, kanji)
      end
   end

   return entries
end

return db
