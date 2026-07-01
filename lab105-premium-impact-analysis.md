# Lab 105: Analyze Impact and Extend a Field Across the Full Stack

## Overview

Use the IBM i system catalog and `search_ifs` to perform a dependency analysis on the SAMCO
application, simulate the impact of a field change — then execute that change consistently
across all three layers: database, display file, and RPG program.

**Duration**: 35 minutes  
**Difficulty**: Intermediate  
**Mode**: ℹ️ IBM i Developer  
**Source**: QSYS (SAMSRCn / SAMCOn) + Local workspace (`SAMCO/`) 
**Build target**: `SAMCOn`

---

## Prerequisites

- Bob IDE with **IBM Bob Premium Package for i** installed
- **Code for IBM i** extension connected to your IBM i system
- `SAMCOn` in your library list (`n` = your team number)
- [Lab 103](lab103-premium-dds-to-sql-workflow.md) completed

---

## Use Case

The `ARDESC` field (article description) in `SAMCOn.ARTICLE` is currently 30 characters.
Business requires 50. Before touching anything, perform a full impact analysis. Then execute the change consistently across:

| Layer | Object | Change |
|-------|--------|--------|
| Database | `SAMCOn.ARTICLE` | `ARDESC CHAR(30)` → `CHAR(50)` |
| Display file | [`SAMCO/QDDSSRC/ART200D-Work_with_Article.DSPF`](SAMCO/QDDSSRC/ART200D-Work_with_Article.DSPF) | Field width 30 → 50 |
| RPG program | [`SAMCO/QRPGLESRC/ART200-Work_with_article.PGM.SQLRPGLE`](SAMCO/QRPGLESRC/ART200-Work_with_article.PGM.SQLRPGLE) | Remove hardcoded length-30 assumptions |

---

## Part 1 — Impact Analysis (know before you act)

### Step 1: Find All Objects Depending on ARTICLE (3 minutes)

**Switch to ℹ️ IBM i Developer mode** in the Bob chat panel.

**Prompt:**
```
Find all objects that depend on ARTICLE in @SAMCOn   on IBM i.
Return object name, object type, and dependency type as a table.
```

**What to observe:**
- Bob uses `execute_sql_statement` against `QSYS2.SYSTABLEDEP` etc.
- Returns dependent programs, service programs, logical files, and views

---

### Step 2: Map Foreign Key Relationships (3 minutes)

**Prompt:**
```
Map all relationships for the ARTICLE file in SAMCOn on IBM i.
Show me every file or table that is linked to it — logical files built on top of it, any foreign keys, and any joins found in source code. For each relationship, tell me the dependent object name, what type it is, and how the relationship is defined (database rule vs. code only).
```

**What to observe:**
- Are there zero foreign keys? → Integrity is enforced by code only — any direct table update bypasses all rules
- Do logical files cover only some fields? → Field-level access control may be inconsistent
- Are there multiple logicals over the same PF? → Each one is a potential breaking point when the PF structure changes
- PF with no FK → candidate for CREATE TABLE with FOREIGN KEY constraints

---

### Step 3: Search Local Source for ARDESC References (3 minutes)

**Prompt:**
```
Find every place the field ARDESC is used in the SAMCOn library on IBM i.

Look in all source files — RPG programs, display files, SQL scripts, and copybooks. For each hit, show the source member name, line number, and the line of code. Then show which database tables and views also contain this field. Finally, summarize what would break if this field was renamed or its length changed. What is the current field length and the impact if changing to 100.

```

**What to expect:**
- Every source member that mentions the field by name — DDS definitions, RPG procedures, display file screen positions, and SQL view definitions
- Every database object (table, logical file, view) that carries the field as a column, with its position and length
- A plain-English summary of what stops working if the field is renamed or resized

**What to observe:**
- Is the field copied into a denormalized table? SAMREF holds its own ARDESC column with no database link to ARTICLE — a length change there is silent and manual
- Is the field used as a key? ARTICLE2 is keyed by ARDESC — a rename or resize rebuilds the access path and breaks any program that opens that logical
- Is the return type derived with like()? ART300 and its prototype use like(ardesc) — the size cascades automatically at compile time, but running objects stay stale until recompiled
- How many screen positions reference it? Three in ART200D, including one input/output field — a length increase risks a UI layout overflow that only shows up at runtime
---

### Step 4: Simulate Recompile Impact (4 minutes)

**Prompt:**
```
Simulate Recompile Impact . Based on the ARTICLE dependents found in Step 1, which objects need to be recompiled after widening ARDESC from 30 to 50?
Consider for example:
1. Programs using ARTICLE with externally-described fields (F-spec)
2. Programs using embedded SQL with SELECT *
3. Logical files built over ARTICLE
```

**What to expect:**
- A categorized list of every object that must be recompiled, grouped by type — DDS files, SQL objects, RPG modules, and display files — with the reason each one is affected
- An ordered recompile sequence showing which objects must be rebuilt before others, and which SQL DDL statements (ALTER TABLE, DROP/CREATE VIEW) replace a traditional recompile

**What to observe:**
- Returns a recompile impact list with reasons for each object
- Is a display file field used as input? ART200D has ARDESC at column 29 as an input/output field — widening to 100 chars overflows a standard screen; the layout must be redesigned before recompile, not after
- Which objects use like(fieldname) or REFFLD? These inherit the field size at compile time — Bob used QSYS2.SYSCOLUMNS2 to confirm the current length across all objects, and source searches (FARTICLE, /copy, REFFLD) to identify every compiled object whose buffer size is derived from ARDESC
- Is there a safe recompile order? The physical file must go first — every logical file, view, RPG module, and display file that depends on it is blocked until ARTICLE.PF is rebuilt with the new length
---

### Step 5: Save the Impact Report (2 minutes)

**Prompt:**
```
Generate a markdown impact report for the ARDESC widening in SAMC0n.ARTICLE summarizing:
dependent objects, foreign key relationships, ARDESC field usage across source files, and the recompile list. Save it as docs/ARTICLE-ARDESC-impact-report.md in the IFS, in my home directory.
```

**What to observe:**
- Bob synthesizes all previous steps into a single document
- Uses `write_stream_file` to save `docs/ARTICLE-ARDESC-impact-report.md`
- Visualize the resulting markdown file using the IFS Browser (Code for i)
---

## Part 2 — Execute the Change (act correctly across every layer)

### Step 6: Extend the Database Field (4 minutes)

**Prompt:**
```
Extend ARDESC in SAMCOn.ARTICLE from CHAR(30) to CHAR(50).
Execute with guardrail approval if possible (SQL). 
Plan the differents tasks, and ask me before executing anything.
Generate a markdown in the IFS in my home directory in the docs folder in not already generated ,  with this plan. 
```

---

### Step 7: Update the Display File (6 minutes)

Push the `+`top right button, and let's edit the local SAMCO file in the local workspace by selecting `New Task in SAMCO`. 
Note that if you want to directly edit source files in QSYS (SAMSRCn library), please adapt the prompts in this lab accordingly. 

**Prompt:**
```
Read @SAMCOn/QDDSSRC/ART200D-Work_with_Article.DSPF.

Find the ARDESC field. Widen it from 30 to 50 columns. The screen is 24 rows × 80 columns —ensure the field does not overflow column 80. Show the before/after DDS snippet, then save the updated file to the source file in the local workspace (not in QSYS)
```

**What to observe:**
- Bob reads the local DSPF file
- The `dds-display-files` skill enforces 24×80 screen boundary rules
- Returns before/after comparison (diff), adjusting label or position if needed
- Writes the updated source back to [`SAMCO/QDDSSRC/ART200D-Work_with_Article.DSPF`](SAMCO/QDDSSRC/ART200D-Work_with_Article.DSPF)

---

### Step 8: Update the RPG Program (5 minutes)

**Prompt:**
```
Read @SAMCOn/QRPGLESRC/ART200-Work_with_article.PGM.SQLRPGLE.

Find any hardcoded length-30 references to ARDESC:
- Dcl-S or Dcl-Ds fields with explicit length 30
- %Subst with hardcoded length 30
- SQL host variables

Update them to length 50. Show before/after, then save the updated file in the local workspace (not in QSYS).
```

**What to observe:**
- Bob reads the local SQLRPGLE file
- Finds and replaces all explicit length-30 references. Here there is none.
- Writes the updated source back to [`SAMCO/QRPGLESRC/ART200-Work_with_article.PGM.SQLRPGLE`](SAMCO/QRPGLESRC/ART200-Work_with_article.PGM.SQLRPGLE)

---

### Step 9: Recompile Display File and Program (5 minutes)

**Prompt:**
```
Compile in this order (DSPF first, then program):
1. @QDDSSRC/ART200D-Work_with_Article.DSPF   → SAMCOn
2. @QRPGLESRC/ART200-Work_with_article.PGM.SQLRPGLE → SAMCOn

Get compile actions for each and execute. Report any errors or warnings.
```
> Note: Replace SAMCOn with your SAMCO library name (n = team number) and reference your files with @ and the name of the file, so Bob can reference those files and trigger the compilation Action.

**What to observe:**
- Bob uses `get_compile_actions` then `execute_compile_action` for each
- DSPF must compile first — the program depends on the display file format
- Compilation errors (bad DDS column...) will be fixed by Bob , but feel free to interrupt if necessary. Bob will ask permission before executing any command or scripts to get information or edit a file.  
- At the end , the compilation should be successful and Bob will list the issue encountered and how it fixed it. 

## ✅ Success Criteria

- [ ] All ARTICLE dependents listed 
- [ ] Foreign key map generated 
- [ ] `ARDESC` references found
- [ ] Recompile impact list generated before any change was made
- [ ] DSPF updated in the local workspace — field widened to 50, no column boundary overflow
- [ ] RPG program updated in the local workspace — hardcoded length-30 references removed
- [ ] Both DSPF and program compiled without errors in `SAMCOn`

---

## Next Steps

- If you use git, Commit the updated DSPF, SQLRPGLE, and impact report to your Git branch
- Proceed to [Lab 106](lab106-premium-test-rpgunit.md) — generate RPGUnit tests for SAMCO
