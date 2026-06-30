# Lab 103: DDS to SQL Conversion Impact Analysis

## Overview
Ask Bob to analyse the `ARTICLE` physical file in your `SAMCOn` library, generate its SQL DDL equivalent, and produce a full pre-migration impact report — all saved to the IFS as a markdown file. Then refine the DDL and create the new table.

**Duration**: 20 minutes  
**Difficulty**: Intermediate  
**Mode**: ℹ️ IBM i Developer  
**Build target**: `SAMCOn`

> Bob uses IBM i–specific skills (including `dds-primer-basics`) and runs 5 automated steps: it collects the DDS source, calls `QSYS2.GENERATE_SQL`, queries database relationships and static program references via `DSPPGMREF`, collects object status/journaling/locks/authority, then renders a full impact report as a markdown file in `$HOME/docs` on the IFS.

---

## Prerequisites

- **IBM Bob Premium Package for i** extension installed and active in Bob
- `SAMCOn` in your library list (`n` = your team number)
- [Lab 101](lab101-premium-discover-samco.md) completed

---

## Step 1: Ask Bob to Generate the Impact Report (8 minutes)

Switch to **ℹ️ IBM i Developer** mode and paste the following prompt, replacing `SAMCOn` with your actual library name (e.g. `SAMCO3`). The Task scope is the Library list (`+` button at the top,`New Task in Library List ...` )

**Prompt:**
```
The ARTICLE PF in @SAMCOn is DDS described, could you suggest the equivalent in SQL?

To convert this DDS-defined physical file (PF) or logical file (LF) to its SQL DDL
equivalent, produce a full pre-migration impact report covering database relationships,
static program references (via DSPPGMREF), object statistics, journaling status, active
locks, and authority records. Generate a complete markdown file, and store it in the IFS,
in the $HOME/docs directory. Do not create any files in QSYS, just this markdown.
Use DDS Skills when necessary. Where SAMCOn is library in their lib list, n = team number.
Accept when Bob agents want to execute queries to get the necessary information.
Read the todo list to see all steps. Mention the used skill dds-primer-basics and other
IBM i specific skills used here.
```

> Replace `SAMCOn` in the prompt with your real library name before sending.

**What happens:** Bob activates the `dds-primer-basics` skill (and other IBM i–specific skills as needed), reads the DDS source for `ARTICLE`, calls `QSYS2.GENERATE_SQL`, queries `SYSTOOLS.RELATED_OBJECTS`, runs `DSPPGMREF`, queries `QSYS2.OBJECT_STATISTICS`, `QSYS2.JOURNALED_OBJECTS`, `QSYS2.OBJECT_LOCK_INFO`, and `QSYS2.OBJECT_PRIVILEGES`, then writes the full report as a `.md` file under `$HOME/docs` on the IFS.

**What to observe in the chat:**
- Bob's todo list progressing through each analysis step
- A `CREATE OR REPLACE TABLE` statement with all columns, types, and lengths
- A `LABEL ON` block reproducing the `COLHDG` and `TEXT` values from the DDS source
- A `CREATE INDEX` for any keyed access path defined in the DDS
- References to the `dds-primer-basics` skill and any other IBM i skills invoked

> ⚠️ Accept any queries Bob proposes to execute — these are the live data-collection steps.

---

## Step 2: Review the Impact Report in the IFS Browser (2 minutes)

Once Bob confirms the markdown file has been written to `$HOME/docs`:

1. Open the **IFS Browser** in the Code for IBM i side panel
2. Navigate to your `$HOME/docs` directory
3. Open the generated `.md` file to review the full impact report

**Sections to check in the report:**

### Database Relationships
Bob queries `SYSTOOLS.RELATED_OBJECTS` for `SAMCOn/ARTICLE`. Look for any logical files or views that depend on the physical file.

### Static Program References
Bob runs `DSPPGMREF` across every library in your library list and queries `QTEMP/PGMREF` for references to `ARTICLE`. Expected result is an empty list of programs here, as the `ART200` program only references the logical files `ARTICLE1` and `ARTICLE2` (views).

### Object Status & Journaling
Bob queries `QSYS2.OBJECT_STATISTICS` and `QSYS2.JOURNALED_OBJECTS`. Note whether journaling is enabled — the replacement SQL table must replicate this setting.

### Object Locks & Authorities
Bob reports any active locks (`QSYS2.OBJECT_LOCK_INFO`) and the full authority matrix (`QSYS2.OBJECT_PRIVILEGES`). Any `*PUBLIC` or user-specific grants must be recreated after the DDL is executed.

> ⚠️ **RRN note**: The report footer reminds you that if any program uses relative record numbers to access `ARTICLE`, the replacement table must **not** have `REUSEDLT(*YES)`. The default for a SQL-created table is already `*NO`.

---

## Step 3: Ask Bob to Refine and Execute the DDL (6 minutes)

Once you have reviewed the report, continue the conversation to refine and apply the DDL.

**Prompt:**
```
Looking at the generated DDL in $HOME/docs migration report for ARTICLE, add:
1. DEFAULT '0' on the ARDEL column
2. CHECK (ARDEL IN ('0', '1')) constraint on ARDEL

Then validate the result with check_sql_syntax. If it passes, create the table as
SAMCOn.ARTICLENEW and ask me to confirm before executing.
```

> Replace `SAMCOn` with your real library name.

**What to observe:**
- Bob locates the migration report markdown in `$HOME/docs` and extracts the DDL
- Edits the `CREATE TABLE` statement in-chat adding the `DEFAULT` and `CHECK` constraint
- Calls `check_sql_syntax` — must report **Syntax OK** before proceeding
- Presents: *"This will create table ARTICLENEW in SAMCOn. Approve?"*
- After your confirmation, executes with `execute_sql_statement`

---

## Step 4: Verify the Result (2 minutes)

**Prompt:**
```
Query QSYS2.SYSCOLUMNS for ARTICLENEW in SAMCOn.
Show column name, data type, length, and default value.
```

> Replace `SAMCOn` with your real library name.

Expected: 14 rows — matching the original `ARTICLE` columns — with `ARDEL` showing `DEFAULT '0'`.

---

## ✅ Success Criteria

- [ ] Bob generated the full pre-migration impact report and saved it as a markdown file in `$HOME/docs`
- [ ] Report lists database relationships, static program references, journaling status, locks, and authority
- [ ] Report mentions the `dds-primer-basics` skill and other IBM i specific skills used
- [ ] DDL reviewed in the IFS Browser via Code for IBM i
- [ ] DDL refined with `DEFAULT` and `CHECK` on `ARDEL`; `check_sql_syntax` returned OK
- [ ] `CREATE TABLE SAMCOn.ARTICLENEW` executed after approval
- [ ] `QSYS2.SYSCOLUMNS` confirmed 14 columns with correct types

---

## Key Takeaways

- A single prompt drives the entire pre-migration analysis — Bob activates the right IBM i skills automatically
- `QSYS2.GENERATE_SQL` produces complete DDL including `LABEL ON`, CCSID, and indexes — not just a bare `CREATE TABLE`
- `SYSTOOLS.RELATED_OBJECTS` + `DSPPGMREF` together cover both database-level and program-level dependencies
- SQL DDL lets you add `DEFAULT`, `CHECK`, and `FOREIGN KEY` constraints that DDS cannot express
- Always check journaling and authority on the original object — the new SQL table starts with neither
- The IFS Browser in Code for IBM i is the natural place to review and share generated documentation

---

## Next Steps

- Proceed to [Lab 104](lab104-premium-rla-to-sql.md) — convert RLA file operations to embedded SQL in RPG programs
- Run the same prompt on `SAMCOn/FAMILLY` (a simpler PF) to compare impact reports
- Try with `SAMCOn/ARTICLE1` and note how `GENERATE_SQL` produces a `CREATE VIEW` instead of a `CREATE TABLE`
