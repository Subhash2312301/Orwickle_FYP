// Converts schema.json (live database) into data.mjs for erd2.mjs.
import { readFileSync, writeFileSync } from 'node:fs';

const dir = new URL('.', import.meta.url);
const s = JSON.parse(readFileSync(new URL('schema.json', dir), 'utf8'));
// pg returns some arrays (name[], enum[]) as "{a,b}" strings
const arr = (v) => (Array.isArray(v) ? v : String(v).replace(/^\{|\}$/g, '').split(',').filter(Boolean).map((x) => x.replace(/^"|"$/g, '')));
for (const e of s.enums) e.labels = arr(e.labels);
for (const c of s.cons) { c.cols = arr(c.cols); c.ref_cols = arr(c.ref_cols); }

export const GROUPS = {
  acct: { name: 'Accounts, sessions & profiles', color: '#3730A3', tint: '#EEF0FB' },
  list: { name: 'Categories & project listings', color: '#0E7490', tint: '#ECF7FA' },
  admin: { name: 'Evidence review & audit (admin)', color: '#475569', tint: '#F1F4F8' },
  deal: { name: 'Access requests & bidding', color: '#7C3AED', tint: '#F4EFFD' },
  comm: { name: 'Documents, chat & notifications', color: '#0F766E', tint: '#ECF7F5' },
  agree: { name: 'Agreements, deals & reports', color: '#B45309', tint: '#FDF4EA' },
};

const GROUP_OF = {
  users: 'acct', auth_tokens: 'acct', profiles: 'acct', owner_profiles: 'acct', investor_profiles: 'acct',
  buyer_profiles: 'acct', user_category_interests: 'acct',
  categories: 'list', listings: 'list', listing_confidential: 'list', listing_photos: 'list',
  evidence_submissions: 'admin', review_decisions: 'admin', audit_logs: 'admin',
  access_requests: 'deal', offers: 'deal', offer_versions: 'deal',
  documents: 'comm', document_grants: 'comm', conversations: 'comm', messages: 'comm', notifications: 'comm',
  agreements: 'agree', agreement_versions: 'agree', agreement_acknowledgements: 'agree',
  agreement_revision_requests: 'agree', deals: 'agree', reports: 'agree',
};
// order of tables inside the diagram (parents first helps the layout)
const ORDER = Object.keys(GROUP_OF);

// partial unique indexes, in words
const RULES = {
  access_requests: 'one active request per listing and requester',
  offers: 'one open offer per listing and bidder',
  offer_versions: 'one pending version per offer',
  document_grants: 'one active grant per document and request',
  evidence_submissions: 'one current file per user and kind',
};

const enumLabels = Object.fromEntries(s.enums.map((e) => [e.typname, e.labels]));
const ENUMS = {};
const typeOf = (c) => {
  const t = c.udt_name;
  if (c.data_type === 'USER-DEFINED' && enumLabels[t]) {
    const labels = enumLabels[t];
    const inline = `ENUM(${labels.join(',')})`;
    if (inline.length <= 34) return inline;
    ENUMS[t] = labels.join(', ');
    return `ENUM ${t}`;
  }
  if (c.data_type === 'ARRAY') return `${{ _text: 'TEXT', _uuid: 'UUID' }[t] || t.slice(1).toUpperCase()}[]`;
  const map = { uuid: 'UUID', text: 'TEXT', timestamptz: 'TIMESTAMPTZ', bool: 'BOOLEAN', jsonb: 'JSONB', inet: 'INET',
    int2: 'SMALLINT', int4: 'INT', int8: 'BIGINT', tsvector: 'TSVECTOR', date: 'DATE', citext: 'CITEXT' };
  if (t === 'numeric') return c.numeric_precision ? `NUMERIC(${c.numeric_precision},${c.numeric_scale})` : 'NUMERIC';
  if (t === 'varchar') return `VARCHAR(${c.character_maximum_length})`;
  if (t === 'bpchar') return `CHAR(${c.character_maximum_length})`;
  return map[t] || t.toUpperCase();
};

const T = [];
for (const name of ORDER) {
  if (!s.tables.some((t) => t.table_name === name)) throw new Error(`missing table ${name}`);
  const cols = s.columns.filter((c) => c.table_name === name);
  const cons = s.cons.filter((c) => c.table_name === name);
  const pk = new Set(cons.filter((c) => c.contype === 'p').flatMap((c) => c.cols));
  const singlePk = pk.size === 1;
  const fk = {};
  for (const c of cons.filter((x) => x.contype === 'f')) {
    c.cols.forEach((col, i) => {
      // only the column that points at the parent's id draws the relationship line
      if (c.ref_cols[i] === 'id' || (c.ref_cols[i] === 'user_id' && c.ref_table.endsWith('profiles'))) fk[col] ??= c.ref_table;
    });
  }
  const uk = new Set(cons.filter((c) => c.contype === 'u' && c.cols.length === 1).flatMap((c) => c.cols));
  // only a plain unique index makes a column unique; partial ones (WHERE ...) are business rules, shown as notes
  for (const ix of s.uniqIdx.filter((x) => x.table_name === name)) {
    const m = ix.def.match(/\(([a-z_]+)\)$/);
    if (m) uk.add(m[1]);
  }
  const composite = cons.filter((c) => c.contype === 'u' && c.cols.length > 1 && !c.conname.endsWith('_key')).map((c) => c.cols);
  const rows = cols.map((c) => {
    const keys = [];
    if (pk.has(c.column_name)) keys.push('PK');
    if (fk[c.column_name]) keys.push(`FK>${fk[c.column_name]}`);
    // a primary key that is also a foreign key (profiles.user_id) is a 1 : 1 link
    if (uk.has(c.column_name) || (singlePk && pk.has(c.column_name) && fk[c.column_name])) keys.push('UK');
    return `${c.column_name}|${typeOf(c)}|${keys.join(',')}${c.is_nullable === 'YES' ? '|n' : ''}`;
  });
  const note = RULES[name] ?? (composite.length ? `UNIQUE (${composite[0].join(', ')})` : undefined);
  T.push([name, GROUP_OF[name], true, rows, ...(note ? [note] : [])]);
}

const out = `// Generated from the live Orwickle database by to_data.mjs
export const GROUPS = ${JSON.stringify(GROUPS, null, 2)};

export const ENUMS = ${JSON.stringify(ENUMS, null, 2)};

// Column format: "name|TYPE|keys|n"  keys = PK, FK>table, UK; n = nullable
export const T = ${JSON.stringify(T, null, 1)};
`;
writeFileSync(new URL('data.mjs', dir), out);
console.log('tables', T.length, 'enums in box', Object.keys(ENUMS).length);
for (const [n, g, , rows, note] of T) console.log(n.padEnd(28), g.padEnd(6), rows.length, rows.filter((r) => r.includes('FK>')).map((r) => r.split('|')[0] + '>' + r.split('FK>')[1].split(/[,|]/)[0]).join(' '), note || '');
