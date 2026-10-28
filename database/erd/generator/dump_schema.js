// Dumps the live Orwickle schema (public tables, columns, keys, enums) as JSON.
// Run from backend/: node --env-file=.env <this file> <out.json>
const { Pool } = require(require.resolve('pg', { paths: [process.cwd()] }));
const { writeFileSync } = require('node:fs');

const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });

(async () => {
  const q = (sql) => pool.query(sql).then((r) => r.rows);
  const tables = await q(`SELECT table_name FROM information_schema.tables
    WHERE table_schema='public' AND table_type='BASE TABLE' AND table_name <> 'schema_migrations' ORDER BY table_name`);
  const columns = await q(`SELECT c.table_name, c.column_name, c.ordinal_position, c.is_nullable, c.data_type, c.udt_name,
      c.character_maximum_length, c.numeric_precision, c.numeric_scale, c.is_generated
    FROM information_schema.columns c WHERE c.table_schema='public' ORDER BY c.table_name, c.ordinal_position`);
  const cons = await q(`SELECT con.conname, con.contype, rel.relname AS table_name, frel.relname AS ref_table,
      array(SELECT a.attname FROM unnest(con.conkey) WITH ORDINALITY k(n, o) JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = k.n ORDER BY k.o) AS cols,
      array(SELECT a.attname FROM unnest(con.confkey) WITH ORDINALITY k(n, o) JOIN pg_attribute a ON a.attrelid = con.confrelid AND a.attnum = k.n ORDER BY k.o) AS ref_cols
    FROM pg_constraint con JOIN pg_class rel ON rel.oid = con.conrelid JOIN pg_namespace ns ON ns.oid = rel.relnamespace
    LEFT JOIN pg_class frel ON frel.oid = con.confrelid
    WHERE ns.nspname='public' AND con.contype IN ('p','f','u')`);
  const uniqIdx = await q(`SELECT t.relname AS table_name, i.relname AS index_name, pg_get_indexdef(i.oid) AS def
    FROM pg_index x JOIN pg_class i ON i.oid = x.indexrelid JOIN pg_class t ON t.oid = x.indrelid JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE n.nspname='public' AND x.indisunique AND NOT x.indisprimary
      AND NOT EXISTS (SELECT 1 FROM pg_constraint c WHERE c.conindid = x.indexrelid)`);
  const enums = await q(`SELECT t.typname, array_agg(e.enumlabel ORDER BY e.enumsortorder) AS labels
    FROM pg_type t JOIN pg_enum e ON e.enumtypid = t.oid JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname='public' GROUP BY t.typname`);
  writeFileSync(process.argv[2], JSON.stringify({ tables, columns, cons, uniqIdx, enums }, null, 1));
  console.log('tables', tables.length, 'columns', columns.length, 'constraints', cons.length, 'enums', enums.length);
  await pool.end();
})().catch((e) => { console.error(e); process.exit(1); });
