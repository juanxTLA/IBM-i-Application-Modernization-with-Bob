# Lab 107: Extend a Field Across the Full Stack

## Overview
Extend the article description field `ARDESC` from 30 to 50 characters across all three layers: the database table in `SAMCOn`, the local display file source, and the local RPG program source — then recompile.

**Duration**: 25 minutes  
**Difficulty**: Intermediate  
**Mode**: ℹ️ IBM i Developer  
**Source**: Local workspace (`SAMCO/`)  
**Build target**: `SAMCOn`

> **Local workspace**: Source lives in the **local Git clone** exclusively (`SAMCO/QDDSSRC/`, `SAMCO/QRPGLESRC/`). Bob edits local files with `write_stream_file`. The database `ALTER TABLE` runs against `SAMCOn`. `SAMCOn` contains compiled objects and the database — no source members.

---

## Prerequisites
- Bob IDE with **IBM Bob Premium Package for i** installed
- **Code for IBM i** extension connected to your IBM i system
- **Db2 for i** extension installed
- `SAMCOn` in your library list (`n` = your team number)
- [Lab 103](lab103-premium-dds-to-sql-workflow.md) completed

---

## Use Case

The `ARDESC` field (article description) in `SAMCOn.ARTICLE` is currently 30 characters. Business requires 50. The change must be consistent across:

| Layer | Object | Change |
|-------|--------|--------|
| Database | `SAMCOn.ARTICLE` | `ARDESC CHAR(30)` → `CHAR(50)` |
| Display file | [`SAMCO/QDDSSRC/ART200D-Work_with_Article.DSPF`](SAMCO/QDDSSRC/ART200D-Work_with_Article.DSPF) | Field width 30 → 50 |
| RPG program | [`SAMCO/QRPGLESRC/ART200-Work_with_article.PGM.SQLRPGLE`](SAMCO/QRPGLESRC/ART200-Work_with_article.PGM.SQLRPGLE) | Remove hardcoded length-30 assumptions |

---

## Step 1: Discover All References to ARDESC (3 minutes)

**Switch to ℹ️ IBM i Developer mode** in the Bob chat panel.

**Prompt:**
```
Find all references to the field ARDESC:
1. Query QSYS2.SYSCOLUMNS WHERE COLUMN_NAME = 'ARDESC' AND TABLE_SCHEMA = 'SAMCOn'
2. Search the local workspace (SAMCO/ directory) for the text ARDESC
Compile a full impact list.
```

**What to observe:**
- Bob queries `QSYS2.SYSCOLUMNS` via `execute_sql_statement`
- Uses `search_ifs` on the local workspace for source references
- Returns a combined impact list across database objects and local source files

---

## Step 2: Extend the Database Field (4 minutes)

**Prompt:**
```
Generate an ALTER TABLE statement to extend ARDESC in SAMCOn.ARTICLE from CHAR(30) to CHAR(50). Validate with check_sql_syntax, then execute with guardrail approval.
```

**What to observe:**
- Bob uses `check_sql_syntax` — returns **Syntax OK**
- Presents: *"This will modify column ARDESC in SAMCOn.ARTICLE. Approve?"*
- Executes with `execute_sql_statement` after approval

**Prompt:**
```
Verify by querying QSYS2.SYSCOLUMNS for ARDESC in SAMCOn.ARTICLE.
```
Expected: `COLUMN_LENGTH = 50`

---

## Step 3: Update the Display File (6 minutes)

**Prompt:**
```
Read SAMCO/QDDSSRC/ART200D-Work_with_Article.DSPF.

Find the ARDESC field. Widen it from 30 to 50 columns. The screen is 24 rows × 80 columns — ensure the field does not overflow column 80. Show the before/after DDS snippet, then save the updated file.
```

**What to observe:**
- Bob reads the local DSPF file
- The `dds-display-files` skill enforces 24×80 screen boundary rules
- Returns before/after comparison, adjusting label or position if needed
- Writes the updated source back to `SAMCO/QDDSSRC/ART200D-Work_with_Article.DSPF`

---

## Step 4: Update the RPG Program (5 minutes)

**Prompt:**
```
Read SAMCO/QRPGLESRC/ART200-Work_with_article.PGM.SQLRPGLE.

Find any hardcoded length-30 references to ARDESC:
- Dcl-S or Dcl-Ds fields with explicit length 30
- %Subst with hardcoded length 30
- SQL host variables

Update them to length 50. Show before/after, then save the updated file.
```

**What to observe:**
- Bob reads the local SQLRPGLE file
- The `rpg-embedded-sql` skill is auto-loaded
- Finds and replaces all explicit length-30 references
- Writes the updated source back to the workspace

---

## Step 5: Recompile Display File and Program (5 minutes)

**Prompt:**
```
Compile in this order (DSPF first, then program):
1. SAMCO/QDDSSRC/ART200D-Work_with_Article.DSPF → SAMCOn
2. SAMCO/QRPGLESRC/ART200-Work_with_article.PGM.SQLRPGLE → SAMCOn

Get compile actions for each and execute. Report any errors or warnings.
```

**What to observe:**
- Bob uses `get_compile_actions` then `execute_compile_action` for each
- DSPF must compile first (program depends on the display file format)
- Both should report: `No errors, no warnings`

**If warnings appear:**
```
Explain this warning and whether it indicates a real truncation risk.
```
Bob uses `search_ibm_i_docs_with_rag` to look up the message and explain the impact.

---

## ✅ Success Criteria

- [ ] `QSYS2.SYSCOLUMNS` + local `search_ifs` confirmed all `ARDESC` references
- [ ] `ALTER TABLE` extended `ARDESC` to 50 characters with `check_sql_syntax` validation and guardrail approval
- [ ] DSPF updated in the local workspace — field widened to 50, no column boundary overflow
- [ ] RPG program updated in the local workspace — hardcoded length-30 references removed
- [ ] Both DSPF and program compiled without errors in `SAMCOn`

---

## Key Takeaways

- Bob coordinates database, screen, and program changes in one conversation
- Always search the **local workspace** first — changes there are immediately committable to Git
- `ALTER TABLE` requires guardrail approval — no silent data loss
- The `dds-display-files` skill enforces the 24×80 screen constraint automatically
- Always compile the display file **before** the program that references it

---

## Next Steps

- Commit the updated DSPF and SQLRPGLE files to your Git branch
- Extend the same field in the `CUSTOMER` or `PROVIDER` table
- Ask Bob to check if any printer file (`ORD500O.PRTF`) also uses `ARDESC`
