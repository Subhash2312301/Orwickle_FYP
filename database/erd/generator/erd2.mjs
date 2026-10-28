// Orwickle ERD: one complete diagram + two module pages (A4 landscape) + PDF
import ELK from 'elkjs/lib/elk.bundled.js';
import { writeFileSync, mkdirSync } from 'node:fs';
import { chromium } from 'playwright-core';
import { GROUPS, ENUMS, T } from './data.mjs';

const OUT = process.argv[2];
mkdirSync(OUT, { recursive: true });

// ---------- parse ----------
const parseCols = (cols) => cols.map((c) => {
  const [cname, type, keys = '', n] = c.split('|');
  const ks = keys ? keys.split(',') : [];
  const fk = ks.find((k) => k.startsWith('FK>'));
  const enumRef = type.startsWith('ENUM ') ? type.slice(5) : null;
  return {
    name: cname, enumRef,
    type: enumRef ? `ENUM ‹${enumRef}›` : type,
    pk: ks.includes('PK'), uk: ks.includes('UK'), fk: fk ? fk.slice(3) : null, nullable: n === 'n',
  };
});
const ALL = T.map(([name, group, , cols, note]) => ({ name, group, note, cols: parseCols(cols) }));
const byName = Object.fromEntries(ALL.map((t) => [t.name, t]));
for (const t of ALL) for (const c of t.cols) if (c.fk && !byName[c.fk]) throw new Error(`bad FK ${t.name}.${c.name} -> ${c.fk}`);

const HEAD = 30, ROW = 19, NOTE = 18, PADX = 10, KEYW = 40;
const nameW = (s) => s.length * 6.9;
const typeW = (s) => s.length * 5.75;
const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const sizeOf = (t) => {
  const colW = Math.max(...t.cols.map((c) => nameW(c.name)));
  const tyW = Math.max(...t.cols.map((c) => typeW(c.type + (c.nullable ? '  null' : ''))));
  return {
    w: Math.ceil(Math.max(KEYW + colW + 18 + tyW + PADX, nameW(t.name) * 1.25 + 30, t.stub ? 170 : 200)),
    h: HEAD + t.cols.length * ROW + (t.note ? NOTE : 0) + 4,
  };
};
const rowY = (i) => HEAD + i * ROW + ROW / 2;

async function render({ file, title, subtitle, groups, partOf, partition }) {
  // tables on this page + stub copies of parents that live on the other page
  const own = ALL.filter((t) => groups.includes(t.group));
  const ownSet = new Set(own.map((t) => t.name));
  const stubNames = [...new Set(own.flatMap((t) => t.cols.filter((c) => c.fk && !ownSet.has(c.fk)).map((c) => c.fk)))];
  const stubs = stubNames.map((n) => ({
    name: n, group: byName[n].group, stub: true, note: `full table in ${partOf(n)}`,
    cols: [byName[n].cols[0]],
  }));
  const tables = [...stubs, ...own].map((t) => ({ ...t, ...sizeOf(t) }));
  const rels = [];
  for (const t of own) t.cols.forEach((c, i) => {
    if (c.fk) rels.push({ from: c.fk, to: t.name, row: i, oneToOne: c.uk, optional: c.nullable });
  });

  const laid = await new ELK().layout({
    id: 'root',
    layoutOptions: {
      'elk.algorithm': 'layered',
      'elk.direction': 'RIGHT',
      'elk.edgeRouting': 'ORTHOGONAL',
      'elk.layered.spacing.nodeNodeBetweenLayers': '100',
      'elk.spacing.nodeNode': '28',
      'elk.spacing.edgeEdge': '9',
      'elk.layered.spacing.edgeEdgeBetweenLayers': '9',
      'elk.spacing.edgeNode': '18',
      'elk.layered.nodePlacement.strategy': 'NETWORK_SIMPLEX',
      'elk.layered.considerModelOrder.strategy': 'NODES_AND_EDGES',
      'elk.partitioning.activate': partition ? 'true' : 'false',
    },
    children: tables.map((t) => ({
      id: t.name, width: t.w, height: t.h,
      layoutOptions: {
        'elk.portConstraints': 'FIXED_POS',
        ...(partition && { 'elk.partitioning.partition': String(t.stub ? 0 : partition[t.group]) }),
      },
      ports: [
        { id: `${t.name}:pk`, x: t.w, y: rowY(0) - 2, width: 1, height: 1, layoutOptions: { 'elk.port.side': 'EAST' } },
        ...t.cols.map((c, i) => !t.stub && c.fk && { id: `${t.name}:${i}`, x: -1, y: rowY(i) - 0.5, width: 1, height: 1, layoutOptions: { 'elk.port.side': 'WEST' } }).filter(Boolean),
      ],
    })),
    edges: rels.map((r, k) => ({ id: `e${k}`, sources: [`${r.from}:pk`], targets: [`${r.to}:${r.row}`] })),
  });
  const pos = Object.fromEntries(laid.children.map((n) => [n.id, n]));

  const MX = 40, ox = MX, oy = 112;
  const parts = [];
  // edges
  laid.edges.forEach((e, k) => {
    const r = rels[k];
    const g = GROUPS[byName[r.from].group];
    const st = `stroke="${g.color}" stroke-width="1.5"`;
    const allOptional = rels.filter((x) => x.from === r.from).every((x) => x.optional);
    for (const s of e.sections) {
      const pts = [s.startPoint, ...(s.bendPoints || []), s.endPoint].map((p) => [p.x + ox, p.y + oy]);
      parts.push(`<path d="M${pts.map((p) => p.join(',')).join(' L')}" fill="none" stroke="${g.color}" stroke-opacity="0.55" stroke-width="1.3"/>`);
      const [sx, sy] = pts[0];
      const dS = Math.sign(pts[1][0] - sx) || 1;
      if (allOptional) {
        parts.push(`<line x1="${sx + dS * 6}" y1="${sy - 6}" x2="${sx + dS * 6}" y2="${sy + 6}" ${st}/><circle cx="${sx + dS * 15}" cy="${sy}" r="3.6" fill="#fff" ${st}/>`);
      } else {
        for (const dx of [6, 10]) parts.push(`<line x1="${sx + dS * dx}" y1="${sy - 6}" x2="${sx + dS * dx}" y2="${sy + 6}" ${st}/>`);
      }
      const [ex, ey] = pts[pts.length - 1];
      const dE = Math.sign(ex - pts[pts.length - 2][0]) || 1;
      if (r.oneToOne) parts.push(`<line x1="${ex - dE * 7}" y1="${ey - 6}" x2="${ex - dE * 7}" y2="${ey + 6}" ${st}/>`);
      else parts.push(`<path d="M${ex - dE * 11},${ey} L${ex},${ey - 6} M${ex - dE * 11},${ey} L${ex},${ey + 6}" fill="none" ${st}/>`);
      parts.push(`<circle cx="${ex - dE * 16}" cy="${ey}" r="3.6" fill="#fff" ${st}/>`);
    }
  });
  // tables
  for (const t of tables) {
    const n = pos[t.name];
    const x = n.x + ox, y = n.y + oy;
    const g = GROUPS[t.group];
    parts.push(`<rect x="${x + 2}" y="${y + 3}" width="${t.w}" height="${t.h}" rx="7" fill="#0F172A" opacity="0.07"/>`);
    parts.push(`<rect x="${x}" y="${y}" width="${t.w}" height="${t.h}" rx="7" fill="#fff"/>`);
    parts.push(`<path d="M${x},${y + HEAD} V${y + 7} Q${x},${y} ${x + 7},${y} H${x + t.w - 7} Q${x + t.w},${y} ${x + t.w},${y + 7} V${y + HEAD} Z" fill="${t.stub ? g.tint : g.color}"/>`);
    parts.push(`<text x="${x + 12}" y="${y + 20}" font-size="13.5" font-weight="700" fill="${t.stub ? g.color : '#fff'}">${t.name}</text>`);
    t.cols.forEach((c, i) => {
      const ry = y + HEAD + i * ROW;
      if (i % 2 === 1) parts.push(`<rect x="${x + 1}" y="${ry}" width="${t.w - 2}" height="${ROW}" fill="${g.tint}"/>`);
      let kx = x + 8;
      for (const k of [c.pk && 'PK', c.fk && 'FK', c.uk && !c.pk && 'UK'].filter(Boolean)) { // a PK is unique already
        const kc = k === 'PK' ? '#B91C1C' : k === 'FK' ? '#1D4ED8' : '#7C3AED';
        parts.push(`<text x="${kx}" y="${ry + 13.5}" font-size="9" font-weight="800" fill="${kc}">${k}</text>`);
        kx += 15;
      }
      parts.push(`<text x="${x + KEYW}" y="${ry + 13.5}" font-size="11.5" ${c.pk ? 'font-weight="700"' : ''} fill="#0F172A">${c.name}</text>`);
      const ty = esc(c.type) + (c.nullable ? ' <tspan fill="#94A3B8" font-style="italic">null</tspan>' : '');
      parts.push(`<text x="${x + t.w - PADX}" y="${ry + 13.5}" font-size="9.5" text-anchor="end" fill="#64748B">${ty}</text>`);
    });
    if (t.note) {
      const ny = y + HEAD + t.cols.length * ROW;
      parts.push(`<line x1="${x}" y1="${ny}" x2="${x + t.w}" y2="${ny}" stroke="#E2E8F0"/>`);
      parts.push(`<text x="${x + 10}" y="${ny + 13}" font-size="9.5" fill="${t.stub ? '#64748B' : '#7C3AED'}" font-style="${t.stub ? 'italic' : 'normal'}" font-weight="600">${t.note}</text>`);
    }
    parts.push(`<rect x="${x}" y="${y}" width="${t.w}" height="${t.h}" rx="7" fill="none" stroke="${g.color}" stroke-width="${t.stub ? 1.3 : 2}" ${t.stub ? 'stroke-dasharray="5 4"' : ''}/>`);
  }

  // ---------- legend: boxes flow left to right, wrapping ----------
  const diagramW = laid.width + MX * 2;
  const maxW = Math.max(diagramW, 1300);
  const usedEnums = Object.entries(ENUMS).filter(([k]) => own.some((t) => t.cols.some((c) => c.enumRef === k)));
  const legendBoxes = [];
  let BH = 238; // grows when the enum list is longer
  // box: groups + keys
  legendBoxes.push({ w: 300, draw: (X, Y, L) => {
    let yy = Y + 48;
    for (const k of groups) {
      L.push(`<rect x="${X + 14}" y="${yy - 11}" width="26" height="14" rx="3" fill="${GROUPS[k].color}"/><text x="${X + 50}" y="${yy}" font-size="12" fill="#0F172A">${GROUPS[k].name}</text>`);
      yy += 22;
    }
    if (stubs.length) {
      L.push(`<rect x="${X + 14}" y="${yy - 12}" width="26" height="15" rx="3" fill="#fff" stroke="#64748B" stroke-width="1.3" stroke-dasharray="5 4"/><text x="${X + 50}" y="${yy}" font-size="12" fill="#0F172A">linked table from the other part</text>`);
      yy += 22;
    }
    yy += 6;
    L.push(`<text x="${X + 14}" y="${yy}" font-size="12" fill="#0F172A"><tspan fill="#B91C1C" font-weight="800">PK</tspan> primary key   <tspan fill="#1D4ED8" font-weight="800">FK</tspan> foreign key   <tspan fill="#7C3AED" font-weight="800">UK</tspan> unique</text>`);
    L.push(`<text x="${X + 14}" y="${yy + 22}" font-size="12" fill="#0F172A"><tspan fill="#94A3B8" font-style="italic">null</tspan> = column may be empty (nullable)</text>`);
  }, head: 'Legend' });
  // box: notation
  legendBoxes.push({ w: 300, head: 'Relationship notation (crow\'s foot)', draw: (X, Y, L) => {
    const st = 'stroke="#334155" stroke-width="1.5"';
    const sample = (y, kind, label) => {
      const x1 = X + 18, x2 = X + 100;
      L.push(`<line x1="${x1}" y1="${y}" x2="${x2}" y2="${y}" ${st}/>`);
      if (kind === 'one') for (const dx of [6, 10]) L.push(`<line x1="${x1 + dx}" y1="${y - 6}" x2="${x1 + dx}" y2="${y + 6}" ${st}/>`);
      if (kind === 'zeroOne') L.push(`<line x1="${x1 + 6}" y1="${y - 6}" x2="${x1 + 6}" y2="${y + 6}" ${st}/><circle cx="${x1 + 15}" cy="${y}" r="3.6" fill="#fff" ${st}/>`);
      if (kind === 'oneR') L.push(`<line x1="${x2 - 7}" y1="${y - 6}" x2="${x2 - 7}" y2="${y + 6}" ${st}/><circle cx="${x2 - 16}" cy="${y}" r="3.6" fill="#fff" ${st}/>`);
      if (kind === 'many') L.push(`<path d="M${x2 - 11},${y} L${x2},${y - 6} M${x2 - 11},${y} L${x2},${y + 6}" fill="none" ${st}/><circle cx="${x2 - 16}" cy="${y}" r="3.6" fill="#fff" ${st}/>`);
      L.push(`<text x="${x2 + 14}" y="${y + 4}" font-size="12" fill="#0F172A">${label}</text>`);
    };
    sample(Y + 56, 'one', 'exactly one (parent)');
    sample(Y + 86, 'zeroOne', 'zero or one (optional parent)');
    sample(Y + 116, 'many', 'zero or many (child rows)');
    sample(Y + 146, 'oneR', 'zero or one (1 : 1)');
    ['Lines start at the parent\'s id (PK) and', 'end at the child\'s foreign-key row.', 'Line colour = colour of the parent table.']
      .forEach((s, i) => L.push(`<text x="${X + 16}" y="${Y + 184 + i * 16}" font-size="11.5" fill="#475569">${esc(s)}</text>`));
  } });
  // box: enums (two columns when long; long value lists wrap onto extra lines)
  if (usedEnums.length) {
    const MAXC = 92;
    const wrap = (v) => v.split(', ').reduce((lines, w) => {
      const last = lines[lines.length - 1];
      if (last && (last + ', ' + w).length <= MAXC) lines[lines.length - 1] = last + ', ' + w;
      else lines.push(lines.length ? w : w);
      return lines;
    }, []).map((l, i, a) => (i < a.length - 1 ? l + ',' : l));
    const items = usedEnums.map(([k, v]) => ({ k, lines: wrap(v) }));
    const colsN = items.length > 4 ? 2 : 1;
    const cw = Math.max(...items.flatMap((it) => it.lines.map((l) => l.length * 5.9))) + 30;
    // Column split: pehle column mein lagbhag aadhi lines
    const totalRows = items.reduce((s2, it) => s2 + it.lines.length + 1.5, 0);
    let acc = 0;
    items.forEach((it) => { it.col = colsN > 1 && acc >= totalRows / 2 ? 1 : 0; acc += it.lines.length + 1.5; });
    const colH = [0, 1].map((col) => items.filter((it) => it.col === col).reduce((h, it) => h + 30 + it.lines.length * 14, 52));
    BH = Math.max(BH, Math.max(...colH) + 8);
    legendBoxes.push({ w: Math.min(colsN * cw, 1300), head: 'Enum values (‹name› in the tables)', draw: (X, Y, L) => {
      const y = [Y + 52, Y + 52];
      items.forEach((it) => {
        const cx = X + 16 + it.col * cw;
        L.push(`<text x="${cx}" y="${y[it.col]}" font-size="12" font-weight="700" fill="#0F172A">${it.k}</text>`);
        it.lines.forEach((l, j) => L.push(`<text x="${cx}" y="${y[it.col] + 17 + j * 14}" font-size="11" fill="#475569">${esc(l)}</text>`));
        y[it.col] += 30 + it.lines.length * 14;
      });
    } });
  }
  // box: table count
  legendBoxes.push({ w: 300, head: 'Tables in this diagram', draw: (X, Y, L) => {
    groups.forEach((k, i) => {
      const y = Y + 52 + i * 26;
      const n = own.filter((t) => t.group === k).length;
      L.push(`<rect x="${X + 14}" y="${y - 11}" width="14" height="14" rx="3" fill="${GROUPS[k].color}"/><text x="${X + 38}" y="${y}" font-size="12" fill="#0F172A">${GROUPS[k].name}</text><text x="${X + 284}" y="${y}" font-size="12" text-anchor="end" fill="#475569">${n}</text>`);
    });
    const y = Y + 52 + groups.length * 26;
    L.push(`<line x1="${X + 14}" y1="${y - 8}" x2="${X + 286}" y2="${y - 8}" stroke="#E2E8F0"/><text x="${X + 14}" y="${y + 12}" font-size="12.5" font-weight="800" fill="#0F172A">Total</text><text x="${X + 284}" y="${y + 12}" font-size="12.5" font-weight="800" text-anchor="end" fill="#0F172A">${own.length} tables, ${rels.length} relationships</text>`);
  } });

  const legend = [];
  let LX = MX, LY = oy + laid.height + 36, rowH = 0, rightMost = 0;
  for (const b of legendBoxes) {
    if (LX + b.w > maxW - MX && LX > MX) { LX = MX; LY += rowH + 20; rowH = 0; }
    legend.push(`<rect x="${LX}" y="${LY}" width="${b.w}" height="${BH}" rx="8" fill="#fff" stroke="#CBD5E1"/><text x="${LX + 14}" y="${LY + 24}" font-size="14" font-weight="800" fill="#0F2557">${b.head}</text>`);
    b.draw(LX, LY, legend);
    LX += b.w + 20; rowH = BH; rightMost = Math.max(rightMost, LX);
  }
  const W = Math.ceil(Math.max(diagramW, rightMost + MX - 20));
  const H = Math.ceil(LY + BH + 36);
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" font-family="Segoe UI, Arial, sans-serif">
<rect width="100%" height="100%" fill="#F8FAFC"/>
<text x="${MX}" y="50" font-size="30" font-weight="800" fill="#0F2557">${esc(title)}</text>
<text x="${MX}" y="80" font-size="15" fill="#475569">${esc(subtitle)}</text>
${parts.join('\n')}
${legend.join('\n')}
</svg>`;
  writeFileSync(`${OUT}/${file}.svg`, svg);
  console.log(file, W, 'x', H, 'ratio', (W / H).toFixed(2), 'tables', own.length, 'stubs', stubs.length, 'rels', rels.length);
  return { file, svg, W, H };
}

const PARTS = [
  { groups: ['acct', 'list', 'admin'], label: 'Part 1' },
  { groups: ['deal', 'comm', 'agree'], label: 'Part 2' },
];
const partOf = (name) => PARTS.find((p) => p.groups.includes(byName[name].group)).label;
const SUB = 'Orwickle: verified marketplace for projects with investor and buyer bidding and agreement management · PostgreSQL (Supabase)';

const results = [
  await render({ file: 'Orwickle_ERD_Complete', title: 'Orwickle: Complete Entity Relationship Diagram', subtitle: `${SUB} · all ${ALL.length} tables`, groups: Object.keys(GROUPS), partOf }),
  await render({ file: 'Orwickle_ERD_Part1', title: 'Orwickle ERD, Part 1: Accounts, Profiles, Listings & Admin Review', subtitle: SUB, groups: PARTS[0].groups, partOf, partition: { acct: 0, list: 1, admin: 1 } }),
  await render({ file: 'Orwickle_ERD_Part2', title: 'Orwickle ERD, Part 2: Access Requests, Bidding, Documents, Chat & Agreements', subtitle: SUB, groups: PARTS[1].groups, partOf, partition: { deal: 1, comm: 2, agree: 2 } }),
];

// ---------- PNG + PDF ----------
const browser = await chromium.launch({ channel: 'msedge' });
for (const r of results) {
  const page = await browser.newPage({ viewport: { width: r.W, height: r.H }, deviceScaleFactor: Number(process.argv[3] || 2) });
  await page.setContent(`<html><body style="margin:0">${r.svg}</body></html>`);
  await page.screenshot({ path: `${OUT}/${r.file}.png`, fullPage: true });
  await page.close();
}
// two-page module PDF (A4 landscape) and one-page complete PDF (A3 landscape)
const pdfPage = async (list, name, format) => {
  const page = await browser.newPage();
  const html = list.map((r) => `<div class="pg">${r.svg.replace(/width="\d+" height="\d+"/, 'width="100%" height="100%" preserveAspectRatio="xMidYMid meet"')}</div>`).join('');
  await page.setContent(`<html><head><style>@page{size:${format} landscape;margin:8mm}body{margin:0}.pg{width:100%;height:calc(100vh);page-break-after:always;display:flex}.pg:last-child{page-break-after:auto}</style></head><body>${html}</body></html>`);
  await page.pdf({ path: `${OUT}/${name}.pdf`, format, landscape: true, printBackground: true, margin: { top: '8mm', bottom: '8mm', left: '8mm', right: '8mm' } });
  await page.close();
};
await pdfPage([results[1], results[2]], 'Orwickle_ERD_Modules_2pages', 'A4');
await pdfPage([results[0]], 'Orwickle_ERD_Complete', 'A3');
await browser.close();
console.log('done');
