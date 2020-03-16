PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS senses;
DROP TABLE IF EXISTS readings;
DROP TABLE IF EXISTS kanjis;
DROP TABLE IF EXISTS entries;

CREATE TABLE entries (
  sequence_number INTEGER PRIMARY KEY,
  type INTEGER NOT NULL
);

CREATE TABLE senses (
  glosses TEXT NOT NULL,
  parts_of_speech TEXT,
  miscs TEXT,
  entry_id INTEGER NOT NULL,
  FOREIGN KEY (entry_id) REFERENCES entries
);

CREATE TABLE readings (
  reading TEXT NOT NULL,
  pris TEXT,
  entry_id INTEGER NOT NULL,
  FOREIGN KEY (entry_id) REFERENCES entries
);

CREATE TABLE kanjis (
  reading TEXT NOT NULL,
  pris TEXT,
  entry_id INTEGER NOT NULL,
  FOREIGN KEY (entry_id) REFERENCES entries
);
