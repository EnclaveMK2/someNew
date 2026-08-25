---
name: testcase-docx
description: Add, remove, reorder, renumber or edit test cases in the Theater test-case Word documents (e.g. "Test Cases - Scenario Editor.docx", TC-AUTH-xxx / TC-ROLE-xxx). Use whenever a request touches a test case inside a .docx — "add a case", "remove TC-AUTH-002", "swap these two", "shift the numbering", "change the expected result". Do NOT use for test cases in code, markdown, or spreadsheets.
---

# Test cases in .docx

## The one thing that matters

In these documents **every test case is its own `<w:tbl>`** — a 4-row table
(`ID | title`, `Preconditions`, `Steps`, `Expected result`) followed by one empty
spacer paragraph. It does *not* look like a table in the extracted text, so it is
very easy to edit at the `<w:p>` level by mistake. Don't:

> Paragraph-level splicing passes XSD validation and dumps clean-looking text,
> but it cuts across table boundaries. The user opens the file and sees the case
> as bare unformatted text with no table around it.

Use `scripts/tc.py`, which only ever moves whole table-plus-spacer units.

## Usage

```bash
uv run --no-project python .claude/skills/testcase-docx/scripts/tc.py "<file.docx>" <command>
```

`python` is not on PATH on this machine — `uv run --no-project python` is. There is
no LibreOffice or Word here either, so **the file cannot be rendered for a visual
check**; the script's own structural checks are the verification, and it is worth
asking the user to eyeball the result after a shape-changing edit.

| Command | What it does |
|---|---|
| `list [--prefix TC-AUTH]` | ids + titles |
| `show TC-AUTH-003` | one case, all fields |
| `add --title T [--precond ...] [--steps ...] [--expected ...] [--after ID\|--before ID\|--prefix P] [--template ID]` | insert a case, then resequence |
| `delete TC-AUTH-002` | remove a case, then close the numbering gap |
| `move TC-AUTH-006 --before TC-AUTH-002` | reorder within the group, then resequence |
| `swap TC-AUTH-002 TC-AUTH-006` | swap two cases' **bodies**; the ids stay put |
| `set TC-AUTH-003 [--title\|--precond\|--steps\|--expected ...]` | edit fields in place |
| `renumber --prefix TC-AUTH` | resequence after manual edits |

`--steps` and `--precond` take several arguments, one per line:

```bash
uv run --no-project python .claude/skills/testcase-docx/scripts/tc.py "$DOC" \
  add --after TC-AUTH-005 \
  --title "Logout returns the user to the login form" \
  --precond "The user is logged in and sees the map with the Logout button." \
  --steps 'Click "Logout".' 'Observe the screen.' \
  --expected 'The user is logged out and returned to the login screen.'
```

## Behaviour worth knowing

- **Renumbering is automatic** after `add`/`delete`/`move` — ids in a group stay
  consecutive, and the old→new mapping is printed. Case ids appearing *elsewhere*
  in the document (cross-references) are remapped too; `--no-refs` turns that off.
- **`swap` is the exception**: it exchanges the two bodies and leaves the ids where
  they are — that is what "swap 002 and 006" normally means for a numbered list.
- **New cases clone an existing table**, so borders, shading and fonts match. The
  step count is free — the cell's first paragraph is the pattern, repeated per line.
  Steps get `1.`, `2.` … prefixes unless the text already starts with one.
- **`--prefix` selects the group** (`TC-AUTH`, `TC-ROLE`, …); each group must be a
  contiguous run of tables, which is how these documents are laid out.
- Quotes and `&` in your text are escaped for you; write plain `"` on the CLI.
- The first edit drops a `<name>.bak.docx` beside the file (`--no-backup` to skip,
  `-o out.docx` to write elsewhere and leave the original alone).
- Before writing, the script checks `<w:tbl>` balance and re-parses `document.xml`,
  and refuses to write if either fails. All 79 `TableN` styles in these documents
  are byte-identical, so a moved or cloned table keeping its own style id is
  cosmetically irrelevant.

## Related

`viz-auth-test-results` in memory records which cases were run and what passed —
its numbering goes stale every time this skill renumbers a group, so update it
after structural edits.
