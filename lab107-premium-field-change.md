# Lab 107: Extend a Field Across the Full Stack

## Overview
Perform a common IBM i maintenance task — extending a field length — across all three layers simultaneously: the database table, the green-screen display file, and the RPG program. Bob coordinates the impact analysis, edits, and recompile cycle in a single conversation.

**Duration**: 25 minutes  
**Difficulty**: Intermediate  
**Mode**: ℹ️ IBM i Developer  
**What You'll Build**: ARDESIG field extended from 30 → 50 characters in ARTICLE table, ART200D display file, and ART200 program

---

## Prerequisites
- Bob IDE with **IBM Bob Premium Package for i** installed
- **Code for IBM i** extension connected to your IBM i system
- **Db2 for i** extension installed (for ALTER TABLE execution)
- Libraries `SAMSRCn` and `SAMCOn` configured (where `n` is your student number)
- Library list set with both libraries
- Completion of [Lab 103](lab103-premium-dds-to-sql-workflow.md) recommended

> **Premium Package feature**: `read_member`, `write_member`, `check_sql_syntax`, and auto-loaded `dds-display-files`, `dds-physical-files`, `rpg-embedded-sql` skills are only available in **Bob Premium Package for i**.

---

## Use Case: Extend the Article Description Field from 30 to 50 Characters

The `ARDESIG` field (article description) in the ARTICLE table is currently 30 characters. Business requirements call for 50 characters. This change must be reflected consistently in:

| Layer | Object | Change |
|-------|--------|--------|
| Database | `SAMCOn.ARTICLE` | `ARDESIG CHAR(30)` → `CHAR(50)` |
| Display file | `ART200D.DSPF` | Field width 30 → 50, reposition if needed |
| RPG program | `ART200.SQLRPGLE` | Update any hardcoded length-30 assumptions |

---

## Step 1: Discover All Objects Referencing ARDESIG (4 minutes)

**Switch to IBM i Developer mode** in the Bob chat panel.

**Prompt for Bob:**
```
What objects in SAMCOn and SAMSRCn reference the field ARDESIG?

1. Use execute_sql_statement with QSYS2.SYSCOLUMNS to find all tables/views with ARDESIG
2. Use search_qsys to find all source members in SAMSRCn that contain the text ARDESIG
3. Compile a full impact list
```

**What to Look For:**
- Bob queries `QSYS2.SYSCOLUMNS WHERE COLUMN_NAME = 'ARDESIG' AND TABLE_SCHEMA = 'SAMCOn'`
- Bob uses `search_qsys` with `searchTerm="ARDESIG"` across `SAMSRCn`
- Returns a combined impact list:

| Object | Type | Location | Reference |
|--------|------|----------|-----------|
| ARTICLE | *FILE | SAMCOn | Column definition |
| ARTICLE_BY_FAM | *FILE | SAMCOn | Logical file field |
| ART200D | *FILE (DSPF) | SAMCOn | Display field |
| ART200 | *PGM | SAMCOn | Ext-described |
| ART400 | *SRVPGM | SAMCOn | SQL SELECT |

> **Premium vs. Core**: Premium Package runs both catalog queries and full-text source searches automatically. With Bob Core you would need to paste each file manually.

---

## Step 2: Extend the Database Field (5 minutes)

**Prompt for Bob:**
```
Generate an ALTER TABLE statement to extend ARDESIG in SAMCOn.ARTICLE 
from CHAR(30) to CHAR(50).

Validate the SQL syntax with check_sql_syntax before executing.
```

**Expected DDL:**
```sql
ALTER TABLE SAMCOn.ARTICLE 
  ALTER COLUMN ARDESIG SET DATA TYPE CHAR(50);
```

**What to Look For:**
- Bob uses `check_sql_syntax` — returns **Syntax OK**
- Presents the statement for guardrail approval:
  > *"This will modify column ARDESIG in SAMCOn.ARTICLE. Approve?"*
- After approval, uses `execute_sql_statement` to execute

**Prompt for Bob:**
```
Verify the change was applied by querying QSYS2.SYSCOLUMNS 
for ARDESIG in SAMCOn.ARTICLE.
```

**Expected result**: `COLUMN_LENGTH = 50`

---

## Step 3: Update the Green Screen Display File (7 minutes)

**Prompt for Bob:**
```
Read the display file SAMSRCn/QDDSSRC/ART200D-Work_with_Article.DSPF.

Find the ARDESIG field in the record format.
Widen it from 30 to 50 columns.

Rules:
- The screen is 24 rows × 80 columns
- The field starts at row 8, column 10 (currently ends at column 39)
- If widening causes column > 80, wrap to next row or reduce label space
- Show me the before/after DDS snippet.
```

**What to Look For:**
- Bob uses `read_member` to fetch the DSPF source
- The `dds-display-files` skill is auto-loaded, enforcing 24×80 screen boundaries
- Bob identifies the field and adjacent screen elements
- Returns before/after comparison:

**Before:**
```
     A            ARDESIG       30A  B  8 10TEXT('Description')
     A                                  8  2'Description . . . .'
```

**After (label shortened, field extended):**
```
     A            ARDESIG       50A  B  8 10TEXT('Description')
     A                                  8  2'Description . . :'
```

> **Note**: 50 columns starting at position 10 ends at column 59 — still within 80-column boundary.

**Prompt for Bob:**
```
Write the updated display file source back to SAMSRCn/QDDSSRC/ART200D-Work_with_Article.DSPF 
using write_member.
```

**What to Look For:**
- Bob uses `write_member` to overwrite the DSPF source
- **Code for IBM i** explorer auto-refreshes the member in the browser

---

## Step 4: Update the RPG Program (5 minutes)

**Prompt for Bob:**
```
Read ART200-Work_with_article.PGM.SQLRPGLE from SAMSRCn/QRPGLESRC.

Find any references to ARDESIG that assume a length of 30:
1. Dcl-S or Dcl-Ds fields with explicit length 30 for ARDESIG
2. %Subst or hardcoded length values like %Subst(ARDESIG : 1 : 30)
3. Any truncation-risk SQL host variables

Update them to length 50. Show the before/after changes.
```

**What to Look For:**
- Bob reads the program with `read_member`
- The `rpg-embedded-sql` and `rpg-code-review` skills are auto-loaded
- Finds and reports any explicit length-30 references:

| Line | Before | After |
|------|--------|-------|
| 45 | `Dcl-S artDesc Char(30)` | `Dcl-S artDesc Char(50)` |
| 112 | `%Subst(ARDESIG:1:30)` | `%Subst(ARDESIG:1:50)` |

**Prompt for Bob:**
```
Write the updated program source back to SAMSRCn/QRPGLESRC/ART200-Work_with_article.PGM.SQLRPGLE.
```

---

## Step 5: Recompile the Display File and Program (4 minutes)

**Prompt for Bob:**
```
Compile the display file first:
  SAMSRCn/QDDSSRC/ART200D-Work_with_Article.DSPF → SAMCOn

Then compile the program:
  SAMSRCn/QRPGLESRC/ART200-Work_with_article.PGM.SQLRPGLE → SAMCOn

Get compile actions for each and execute. Tell me if there are any errors or warnings.
```

**What to Look For:**
- Bob uses `get_compile_actions` for each file
- Compiles DSPF first (program depends on it)
- Uses `execute_compile_action` for both
- Reports results:
  - **DSPF**: `ART200D created in SAMCOn — No errors, no warnings`
  - **Program**: `ART200 created in SAMCOn — No errors, no warnings`

**If warnings appear**, ask Bob:
```
Explain warning MCH1234 and whether it indicates a real truncation risk.
```

Bob will use `search_ibm_i_docs_with_rag` to look up the warning message and explain the impact.

---

## ✅ Success Criteria

You've successfully completed this lab when:
- [ ] `QSYS2.SYSCOLUMNS` + `search_qsys` confirmed all ARDESIG references
- [ ] `ALTER TABLE` extended ARDESIG to 50 characters with `check_sql_syntax` validation and guardrail approval
- [ ] DSPF updated — field widened to 50, no column boundary overflow
- [ ] RPG program updated — all hardcoded length-30 references removed
- [ ] Both DSPF and program compiled without errors in SAMCOn

---

## Key Takeaways

1. **Cross-Layer Awareness**: Bob coordinates database, screen, and program changes in one conversation
2. **Impact First**: `QSYS2.SYSCOLUMNS` + `search_qsys` identify all affected objects before editing
3. **Guardrails Prevent Accidents**: ALTER TABLE requires explicit approval — no silent data loss
4. **DDS Screen Boundary Rules**: The `dds-display-files` skill enforces the 24×80 constraint automatically
5. **Ordered Compilation**: Always compile the display file before the program that references it

---

## Next Steps

- Proceed to [Lab 108](lab108-premium-workflows-samco.md) to apply all workflows across the full application
- Extend the same field in the CUSTOMER or PROVIDER table
- Ask Bob to check if any printer file (PRTF) also uses ARDESIG and needs updating
