	-- ============================================================
-- Postgres Full-Text Search practice — movies dataset (33,535 rows)
-- Load movies.sql first:  psql -d yourdb -f movies.sql
-- ============================================================

-- ---------- 1. Basics: tsvector / tsquery ----------

-- See what normalization does (stemming, stopword removal, positions)
SELECT to_tsvector('english', 'The quick brown foxes were jumping over lazy dogs');

-- Basic match: films about time travel
SELECT title, year
FROM movies
WHERE to_tsvector('english', plot) @@ to_tsquery('english', 'time <-> travel')
LIMIT 20;

-- Compare the query parsers: to_tsquery (strict syntax),
-- plainto_tsquery (AND everything), phraseto_tsquery (phrase),
-- websearch_to_tsquery (Google-style, supports "quotes", OR, -exclusion)
SELECT websearch_to_tsquery('english', '"serial killer" -comedy');

-- ---------- 2. Ranking ----------

-- ts_rank vs ts_rank_cd (cover density rewards proximity)
SELECT title, year,
       ts_rank(to_tsvector('english', plot), q)    AS rank,
       ts_rank_cd(to_tsvector('english', plot), q) AS rank_cd
FROM movies, websearch_to_tsquery('english', 'alien invasion earth') q
WHERE to_tsvector('english', plot) @@ q
ORDER BY rank_cd DESC
LIMIT 10;

-- ---------- 3. Make it fast: generated column + GIN index ----------

-- Without an index, every query above seq-scans and re-parses 33k plots.
ALTER TABLE movies
  ADD COLUMN search_vec tsvector
  GENERATED ALWAYS AS (
    setweight(to_tsvector('english', title), 'A') ||
    setweight(to_tsvector('english', plot),  'B')
  ) STORED;

CREATE INDEX movies_search_idx ON movies USING GIN (search_vec);

-- Prove it: compare plans
EXPLAIN ANALYZE
SELECT title FROM movies
WHERE to_tsvector('english', plot) @@ to_tsquery('english', 'vampire');

EXPLAIN ANALYZE
SELECT title FROM movies
WHERE search_vec @@ to_tsquery('english', 'vampire');

-- Weighted ranking now favors title hits over plot hits
SELECT title, year, ts_rank(search_vec, q) AS rank
FROM movies, websearch_to_tsquery('english', 'godfather') q
WHERE search_vec @@ q
ORDER BY rank DESC
LIMIT 10;

-- ---------- 4. Headlines (snippets with highlighted matches) ----------

SELECT title,
       ts_headline('english', plot, q,
                   'StartSel=<b>, StopSel=</b>, MaxWords=25, MinWords=15') AS snippet
FROM movies, websearch_to_tsquery('english', 'submarine nuclear') q
WHERE search_vec @@ q
ORDER BY ts_rank(search_vec, q) DESC
LIMIT 5;

-- ---------- 5. Combining FTS with regular predicates ----------

-- Ranked search restricted to 1990s horror
SELECT title, year, genres, ts_rank(search_vec, q) AS rank
FROM movies, websearch_to_tsquery('english', 'haunted house') q
WHERE search_vec @@ q
  AND year BETWEEN 1990 AND 1999
  AND 'Horror' = ANY(genres)
ORDER BY rank DESC;

-- ---------- 6. Search-as-you-type: prefix matching ----------

SELECT title FROM movies
WHERE search_vec @@ to_tsquery('english', 'assassi:*')
LIMIT 10;

-- ---------- 7. Typo tolerance: pg_trgm (not FTS, but pairs with it) ----------

CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX movies_title_trgm_idx ON movies USING GIN (title gin_trgm_ops);

-- Misspelled title still found
SELECT title, similarity(title, 'The Shawhsank Redemtion') AS sim
FROM movies
ORDER BY title <-> 'The Shawhsank Redemtion'
LIMIT 5;

-- ---------- 8. Challenges (no answers provided) ----------

-- a) Find the 10 highest-ranked "courtroom drama" films that are NOT
--    tagged 'Drama' in genres. Why do results still appear?
-- b) Build one query powering a search box: websearch_to_tsquery input,
--    weighted rank, ts_headline snippet, keyset-friendly ordering.
-- c) Use ts_stat over search_vec to find the 20 most common lexemes in
--    the corpus. What does that tell you about stopword handling?
-- d) Create a custom text search configuration that maps a synonym
--    dictionary ('cop' -> 'police') and re-run a search with it.
-- e) Measure index size: pg_relation_size on the GIN index vs the trgm
--    index. Which is bigger, and why?
