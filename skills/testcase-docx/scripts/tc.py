#!/usr/bin/env python3
"""Add / remove / reorder test cases in a Google-Docs-exported test-case .docx.

Every test case in these documents is its own <w:tbl> (4 rows: ID|title,
Preconditions, Steps, Expected result) followed by one empty spacer paragraph.
All operations here work on that table-plus-spacer unit, never on loose
paragraphs -- paragraph-level splicing passes XSD validation but renders the
case as bare text with no table around it.
"""
import argparse
import os
import re
import shutil
import sys
import zipfile
from xml.etree import ElementTree
from xml.sax.saxutils import escape, unescape

DOC = 'word/document.xml'
TOK = re.compile(r'<w:tbl>.*?</w:tbl>|<w:p(?: [^>]*)?>.*?</w:p>|<w:p/>', re.S)
TR = re.compile(r'<w:tr(?: [^>]*)?>.*?</w:tr>', re.S)
TC = re.compile(r'<w:tc>.*?</w:tc>', re.S)
P = re.compile(r'<w:p(?: [^>]*)?>.*?</w:p>|<w:p/>', re.S)
T = re.compile(r'<w:t(?: [^>]*)?>(.*?)</w:t>', re.S)
CASE_ID = re.compile(r'^([A-Z][A-Z0-9]*-[A-Z0-9]+)-(\d+)$')

ROW = {'preconditions': 1, 'steps': 2, 'expected': 3}


# ---------------------------------------------------------------- xml helpers

def first_text(xml):
    m = T.search(xml)
    return m.group(1) if m else ''


def set_para_text(para, text):
    """Put `text` in the paragraph's first <w:t>, blank the rest -- runs keep their formatting."""
    out, pos, n = [], 0, 0
    for m in T.finditer(para):
        out.append(para[pos:m.start(1)])
        out.append(text if n == 0 else '')
        pos, n = m.end(1), n + 1
    if n == 0:
        return para
    out.append(para[pos:])
    return ''.join(out)


def set_cell_lines(cell, lines):
    """Rewrite a cell's paragraphs to `lines`, cloning its first paragraph as the pattern."""
    paras = P.findall(cell)
    if not paras:
        return cell
    pattern = strip_ids(paras[0])
    body = ''.join(set_para_text(pattern, line) for line in (lines or ['']))
    head = cell[:cell.index(paras[0])]
    tail = cell[cell.index(paras[-1]) + len(paras[-1]):]
    return head + body + tail


def strip_ids(xml):
    """Drop w14:paraId/textId so a cloned block does not duplicate Word paragraph ids."""
    return re.sub(r'\s+w14:(paraId|textId)="[^"]*"', '', xml)


def enc(s):
    """Escape for XML, and use &quot; for quotes like the rest of these documents do."""
    return escape(s).replace('"', '&quot;')


def dec(s):
    """Inverse of enc(), for printing case text on the terminal."""
    return unescape(s, {'&quot;': '"', '&apos;': "'"})


def remap(xml, mapping):
    """Replace old ids with new ones in one pass, so 003->002 cannot eat an existing 002."""
    keys = list(mapping)
    for i, old in enumerate(keys):
        xml = xml.replace(old, f'@@TCMAP{i}@@')
    for i, old in enumerate(keys):
        xml = xml.replace(f'@@TCMAP{i}@@', mapping[old])
    return xml


# ------------------------------------------------------------- document model

class Case:
    """One test case: its table plus the trailing spacer paragraph."""

    def __init__(self, tbl, spacer, start=0, end=0):
        self.tbl, self.spacer, self.start, self.end = tbl, spacer, start, end

    @classmethod
    def clone(cls, other):
        return cls(strip_ids(other.tbl), strip_ids(other.spacer))

    # -- identity -----------------------------------------------------------
    @property
    def rows(self):
        return TR.findall(self.tbl)

    @property
    def id(self):
        return first_text(self.rows[0])

    @property
    def prefix(self):
        return CASE_ID.match(self.id).group(1)

    @property
    def width(self):
        return len(CASE_ID.match(self.id).group(2))

    @property
    def unit(self):
        return self.tbl + self.spacer

    # -- content ------------------------------------------------------------
    def cells(self, row_idx):
        return TC.findall(self.rows[row_idx])

    @property
    def title(self):
        c = self.cells(0)
        return first_text(c[1]) if len(c) > 1 else ''

    def field(self, name):
        c = self.cells(ROW[name])
        return [''.join(T.findall(p)) for p in P.findall(c[1])] if len(c) > 1 else []

    # -- edits --------------------------------------------------------------
    def _edit_cell(self, row_idx, cell_idx, lines):
        row = self.rows[row_idx]
        cells = TC.findall(row)
        if len(cells) <= cell_idx:
            return
        cell = cells[cell_idx]
        self.tbl = self.tbl.replace(row, row.replace(cell, set_cell_lines(cell, lines), 1), 1)

    def set_id(self, new_id):
        self._edit_cell(0, 0, [new_id])

    def set_title(self, title):
        self._edit_cell(0, 1, [enc(title)])

    def set_field(self, name, lines):
        self._edit_cell(ROW[name], 1, [enc(l) for l in lines])


class Doc:
    def __init__(self, path):
        self.path = path
        with zipfile.ZipFile(path) as z:
            self.names = z.namelist()
            self.parts = {n: z.read(n) for n in self.names}
        self.xml = self.parts[DOC].decode('utf-8')
        self._scan()

    def _scan(self):
        toks = list(TOK.finditer(self.xml))
        self.cases = []
        for i, m in enumerate(toks):
            if not m.group(0).startswith('<w:tbl'):
                continue
            rows = TR.findall(m.group(0))
            if not rows or not CASE_ID.match(first_text(rows[0])):
                continue
            nxt = toks[i + 1] if i + 1 < len(toks) else None
            spacer = nxt if (nxt and not nxt.group(0).startswith('<w:tbl')
                             and not ''.join(T.findall(nxt.group(0))).strip()) else None
            self.cases.append(Case(m.group(0), spacer.group(0) if spacer else '',
                                   m.start(), spacer.end() if spacer else m.end()))

    def find(self, case_id):
        for c in self.cases:
            if c.id == case_id:
                return c
        sys.exit(f'error: {case_id} not found; document has '
                 f'{", ".join(c.id for c in self.cases)[:300]}')

    def group(self, prefix):
        """The contiguous run of cases sharing a prefix."""
        g = [c for c in self.cases if c.prefix == prefix]
        if not g:
            have = sorted({c.prefix for c in self.cases})
            sys.exit(f'error: no cases with prefix {prefix} (have: {", ".join(have)})')
        return g

    def write_group(self, prefix, cases, refs=None):
        """Replace the prefix's span with `cases`; apply `refs` id mapping outside that span."""
        old = self.group(prefix)
        start, end = old[0].start, old[-1].end
        head, tail = self.xml[:start], self.xml[end:]
        if refs:
            head, tail = remap(head, refs), remap(tail, refs)
        self.xml = head + ''.join(c.unit for c in cases) + tail
        self._scan()

    def save(self, out):
        self.parts[DOC] = self.xml.encode('utf-8')
        self.check()
        tmp = out + '.tmp'
        with zipfile.ZipFile(tmp, 'w', zipfile.ZIP_DEFLATED) as z:
            for n in self.names:
                z.writestr(n, self.parts[n])
        os.replace(tmp, out)

    def check(self):
        if self.xml.count('<w:tbl>') != self.xml.count('</w:tbl>'):
            sys.exit('error: unbalanced <w:tbl> tags -- refusing to write')
        try:
            ElementTree.fromstring(self.xml)
        except ElementTree.ParseError as e:
            sys.exit(f'error: document.xml is not well-formed ({e}) -- refusing to write')


# -------------------------------------------------------------------- actions

def numbered(steps):
    return [s if re.match(r'^\d+\.\s', s) else f'{i}. {s}' for i, s in enumerate(steps, 1)]


def resequence(cases, prefix):
    """Give `cases` consecutive ids; return the old->new mapping for cross-references."""
    width = max(c.width for c in cases if CASE_ID.match(c.id))
    mapping = {}
    for n, c in enumerate(cases, 1):
        new_id = f'{prefix}-{n:0{width}d}'
        if c.id != new_id:
            if CASE_ID.match(c.id):
                mapping[c.id] = new_id
            c.set_id(new_id)
    return mapping


def apply_change(doc, prefix, cases, no_refs, note):
    mapping = resequence(cases, prefix)
    doc.write_group(prefix, cases, refs=None if no_refs else mapping)
    if mapping:
        note += '; renumbered ' + ', '.join(f'{k}->{v}' for k, v in mapping.items())
    print(note)


def cmd_list(doc, a):
    for c in doc.cases:
        if not a.prefix or c.prefix == a.prefix:
            print(f'{c.id}  {dec(c.title)}')


def cmd_show(doc, a):
    c = doc.find(a.id)
    print(f'{c.id}  {dec(c.title)}')
    for name in ROW:
        print(f'  {name}:')
        for line in c.field(name):
            print(f'    {dec(line)}')


def cmd_add(doc, a):
    prefix = a.prefix or (doc.find(a.after or a.before).prefix if (a.after or a.before) else None)
    if not prefix:
        sys.exit('error: pass --prefix, --after or --before')
    cases = doc.group(prefix)
    template = doc.find(a.template) if a.template else cases[-1]
    new = Case.clone(template)
    new.set_title(a.title)
    new.set_field('preconditions', a.precond or ['—'])
    new.set_field('steps', numbered(a.steps or []))
    new.set_field('expected', a.expected or [])
    ids = [c.id for c in cases]
    pos = ids.index(a.after) + 1 if a.after else ids.index(a.before) if a.before else len(cases)
    new.set_id('')  # unnumbered until resequence, so it contributes no old->new mapping
    cases.insert(pos, new)
    apply_change(doc, prefix, cases, a.no_refs, f'added at position {pos + 1} of {len(cases)}')


def cmd_delete(doc, a):
    prefix = doc.find(a.id).prefix
    cases = [c for c in doc.group(prefix) if c.id != a.id]
    apply_change(doc, prefix, cases, a.no_refs, f'deleted {a.id}')


def cmd_move(doc, a):
    prefix = doc.find(a.id).prefix
    cases = doc.group(prefix)
    ids = [c.id for c in cases]
    item = cases.pop(ids.index(a.id))
    ids.remove(a.id)
    pos = ids.index(a.after) + 1 if a.after else ids.index(a.before)
    cases.insert(pos, item)
    apply_change(doc, prefix, cases, a.no_refs, f'moved {a.id} to position {pos + 1}')


def cmd_swap(doc, a):
    """Swap two cases' bodies -- the ids stay where they are."""
    c1, c2 = doc.find(a.id1), doc.find(a.id2)
    if c1.prefix != c2.prefix:
        sys.exit('error: swap needs two cases with the same prefix')
    cases = doc.group(c1.prefix)
    ids = [c.id for c in cases]
    i1, i2 = ids.index(a.id1), ids.index(a.id2)
    cases[i1], cases[i2] = cases[i2], cases[i1]
    cases[i1].set_id(a.id1)
    cases[i2].set_id(a.id2)
    doc.write_group(c1.prefix, cases)
    print(f'swapped bodies of {a.id1} and {a.id2}')


def cmd_set(doc, a):
    c = doc.find(a.id)
    if a.title:
        c.set_title(a.title)
    if a.precond:
        c.set_field('preconditions', a.precond)
    if a.steps:
        c.set_field('steps', numbered(a.steps))
    if a.expected:
        c.set_field('expected', a.expected)
    cases = [c if x.id == c.id else x for x in doc.group(c.prefix)]
    doc.write_group(c.prefix, cases)
    print(f'updated {a.id}')


def cmd_renumber(doc, a):
    apply_change(doc, a.prefix, doc.group(a.prefix), a.no_refs, f'{a.prefix}')


# ----------------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('docx')
    ap.add_argument('-o', '--out', help='write here instead of editing in place')
    ap.add_argument('--no-backup', action='store_true')
    ap.add_argument('--no-refs', action='store_true',
                    help='do not rewrite case ids referenced elsewhere in the document')
    sub = ap.add_subparsers(dest='cmd', required=True)

    p = sub.add_parser('list', help='list case ids and titles')
    p.add_argument('--prefix')
    p.set_defaults(fn=cmd_list)

    p = sub.add_parser('show', help='print one case in full')
    p.add_argument('id')
    p.set_defaults(fn=cmd_show)

    p = sub.add_parser('add', help='insert a new case, cloning an existing one for formatting')
    p.add_argument('--title', required=True)
    p.add_argument('--precond', nargs='+')
    p.add_argument('--steps', nargs='+')
    p.add_argument('--expected', nargs='+')
    p.add_argument('--prefix')
    p.add_argument('--after')
    p.add_argument('--before')
    p.add_argument('--template', help='case id to clone formatting from (default: last in group)')
    p.set_defaults(fn=cmd_add)

    p = sub.add_parser('delete', help='remove a case and close the numbering gap')
    p.add_argument('id')
    p.set_defaults(fn=cmd_delete)

    p = sub.add_parser('move', help='reorder a case within its group')
    p.add_argument('id')
    g = p.add_mutually_exclusive_group(required=True)
    g.add_argument('--after')
    g.add_argument('--before')
    p.set_defaults(fn=cmd_move)

    p = sub.add_parser('swap', help='swap two cases\' bodies, keeping the ids in place')
    p.add_argument('id1')
    p.add_argument('id2')
    p.set_defaults(fn=cmd_swap)

    p = sub.add_parser('set', help='edit fields of an existing case')
    p.add_argument('id')
    p.add_argument('--title')
    p.add_argument('--precond', nargs='+')
    p.add_argument('--steps', nargs='+')
    p.add_argument('--expected', nargs='+')
    p.set_defaults(fn=cmd_set)

    p = sub.add_parser('renumber', help='resequence a group after manual edits')
    p.add_argument('--prefix', required=True)
    p.set_defaults(fn=cmd_renumber)

    a = ap.parse_args()
    doc = Doc(a.docx)
    a.fn(doc, a)
    if a.cmd in ('list', 'show'):
        return
    out = a.out or a.docx
    if not a.out and not a.no_backup:
        bak = re.sub(r'\.docx$', '.bak.docx', a.docx)
        if not os.path.exists(bak):
            shutil.copy2(a.docx, bak)
            print(f'backup: {bak}')
    doc.save(out)
    print(f'wrote: {out}')


if __name__ == '__main__':
    main()
