# Postgres Full-Text Search Practice Dataset

A ready-to-load dataset for practicing PostgreSQL full-text search, plus a progressive exercise sheet. Companion material for [Production-Ready Full-Text Search in Postgres](https://nexusrl.com) on Nexus Research Lab.

## What's inside

- **`movies.sql`** — 33,535 movies sourced from [wikipedia-movie-data](https://github.com/prust/wikipedia-movie-data): title, year, cast, genres, and a plot-summary paragraph per film. Plain SQL dump (`CREATE TABLE` + `COPY`), wrapped in a single transaction so a failed load leaves nothing behind.
- **`fts_exercises.sql`** — a worksheet that builds from `tsvector` basics through ranking, a weighted GIN-indexed generated column, `ts_headline` snippets, prefix search, and `pg_trgm` typo tolerance. Ends with five unsolved challenges.

## Loading

```bash
psql -d yourdb -f movies.sql
```

Postgres in Docker:

```bash
cat movies.sql | docker exec -i <container> psql -U postgres -d yourdb
```

Verify:

```sql
SELECT count(*) FROM movies;  -- 33535
```

## Requirements

PostgreSQL 12+ (tested on 16). Core FTS needs no extensions; the final exercise section uses `pg_trgm`, which ships with Postgres contrib — `CREATE EXTENSION pg_trgm;` is included in the worksheet.

## Schema

```sql
CREATE TABLE movies (
    id           int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title        text NOT NULL,
    year         int,
    cast_members text[],
    genres       text[],
    plot         text NOT NULL
);
```

## License

Movie data derives from Wikipedia via [prust/wikipedia-movie-data](https://github.com/prust/wikipedia-movie-data) (CC BY-SA). Exercise sheet: MIT.
