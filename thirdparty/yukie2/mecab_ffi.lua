local ffi = require("ffi")
local libmecab = ffi.load(ffi.os == "Windows" and "libmecab.dll" or "mecab")

ffi.cdef([[
struct mecab_node_t {
  struct mecab_node_t  *prev;
  struct mecab_node_t  *next;
  struct mecab_node_t  *enext;
  struct mecab_node_t  *bnext;
  struct mecab_path_t  *rpath;
  struct mecab_path_t  *lpath;
  const char           *surface;
  const char           *feature;
  unsigned int          id;
  unsigned short        length;
  unsigned short        rlength;
  unsigned short        rcAttr;
  unsigned short        lcAttr;
  unsigned short        posid;
  unsigned char         char_type;
  unsigned char         stat;
  unsigned char         isbest;
  float                 alpha;
  float                 beta;
  float                 prob;
  short                 wcost;
  long                  cost;
};

enum {
  MECAB_NOR_NODE = 0,
  MECAB_UNK_NODE = 1,
  MECAB_BOS_NODE = 2,
  MECAB_EOS_NODE = 3,
  MECAB_EON_NODE = 4
};

typedef struct mecab_t mecab_t;
typedef struct mecab_node_t mecab_node_t;

mecab_t*            mecab_new(int argc, char **argv);
const char*         mecab_strerror(mecab_t *mecab);
void                mecab_destroy(mecab_t *mecab);
const char*         mecab_sparse_tostr(mecab_t *mecab, const char *str);
const mecab_node_t* mecab_sparse_tonode(mecab_t *mecab, const char*);
const char*         mecab_nbest_sparse_tostr(mecab_t *mecab, size_t N, const char *str);
]])

local mecab = {}

mecab.C = libmecab

mecab.tagger = ffi.metatype( 'struct mecab_t', {
    __new = function(self, argc, argv)
       local tagger = libmecab.mecab_new(argc, ffi.cast("char**", argv))
       if tagger == nil then
          return nil, tagger:strerror()
       end
       return tagger
    end,

    __gc = libmecab.mecab_destroy,

    -- methods
    __index = {
       sparse_tostr = function(self, c_str)
          local result = libmecab.mecab_sparse_tostr(self, c_str)
          if result == nil then
             return nil, self:strerror()
          end
          return result
       end,

       sparse_tonode = function(self, c_str)
          local result = libmecab.mecab_sparse_tonode(self, c_str)
          if result == nil then
             return nil, self:strerror()
          end
          return result
       end,

       nbest_sparse_tostr = function(self, n, c_str)
          local result = libmecab.mecab_nbest_sparse_tostr(self, n, c_str)
          if result == nil then
             return nil, self:strerror()
          end
          return result
       end,

       strerror = libmecab.mecab_strerror
    }
})

return mecab
