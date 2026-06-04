# Lab 103: Convert DDS to SQL with the Workflow

## Overview
Use the **DDS to SQL Conversion Impact Analysis Workflow** to assess the migration of the ARTICLE physical file to SQL DDL — generating an impact report, refining the DDL, and executing it in `SAMCOn`.

**Duration**: 20 minutes
**Difficulty**: Intermediate
**Mode**: ℹ️ IBM i Developer
**Source**: Local workspace (`SAMCO/QDDSSRC/`) + live IBM i catalog
**Build target**: `SAMCOn`

> **Local workspace**: Bob reads DDS source from the **local Git clone** (`SAMCO/QDDSSRC/`). The workflow queries the live IBM i catalog for dependency and object status analysis. The resulting SQL table is created in `SAMCOn` — which contains database objects and compiled programs, not source members.

---

## Prerequisites
- Bob IDE with **IBM Bob Premium Package for i** installed
- **Code for IBM i** extension connected to your IBM i system
- **Db2 for i** extension installed
- `SAMCOn` in your library list (`n` = your team number)
- [Lab 101](lab101-premium-discover-samco.md) completed (SAMCO context)

---

## Step 1: Launch the DDS to SQL Conversion Workflow (2 minutes)

1. Open the **Bob Workflows** panel in Bob IDE
2. Select **"DDS to SQL Conversion Impact Analysis"** → **Start Workflow**
3. In the form, enter:
   - **Library**: `SAMCOn` (where the compiled `ARTICLE` physical file lives)
   - **Object**: `ARTICLE`
   - **Logical File?**: No

**What to observe:**
- Workflow validates the object exists via `execute_cl_command` (`DSPOBJD`)
- Auto-loads `dds-physical-files` and `db2-dds-to-ddl` skills

---

## Step 2: Review the Generated DDL (4 minutes)

The workflow calls `QSYS2.GENERATE_SQL` and returns a `CREATE TABLE` statement with `LABEL ON`, CCSID, and index options.

**Prompt:**
```
Review the generated DDL for ARTICLE. Suggest:
1. Any CHAR fields that should be VARCHAR
2. Missing foreign key constraints (ARFAMCOD → FAMILLY, ARVAT → VATDEF)
3. A CHECK constraint for the soft-delete flag ARDEL
```

**What to observe:**
- Bob suggests `ARDESC CHAR(30)` → `VARCHAR(30)` for variable-length descriptions
- Recommends `FOREIGN KEY (ARFAMCOD) REFERENCES FAMILLY(FAID)`
- Suggests `CHECK (ARDEL IN ('0', '1'))`

---

## Step 3: Review the Impact Report (5 minutes)

The workflow generates a full impact report covering:

**Database relationships** (from `SYSTOOLS.RELATED_OBJECTS`):

| Related Object | Type | Relationship |
|---------------|------|--------------|
| ORDER | *FILE | Foreign key via ORDERLIN |
| FAMILLY | *FILE | ARTICLE.ARFAMCOD → FAMILLY.FAID |
| VATDEF | *FILE | ARTICLE.ARVAT → VATDEF.VATCOD |

**Static program references** (from `DSPPGMREF` across `SAMCOn`):

| Program | Reference Type |
|---------|---------------|
| ART200 | Externally-described file |
| ART300 | SQL embedded SELECT |
| ART400 | SQL embedded SELECT |

**Object status**: journaling, locks, and authority matrix — the new SQL table must replicate these settings.

> **Note**: If the report shows RRN-based access in ART200, review the `REUSEDLT` warning before executing.

---

## Step 4: Refine, Validate, and Execute (5 minutes)

**Prompt:**
```
Refine the generated DDL:
1. Change ARDESC to VARCHAR(50)
2. Add CHECK (ARDEL IN ('0', '1'))
3. Add FOREIGN KEY constraints for ARFAMCOD and ARVAT

Validate with check_sql_syntax, then execute in SAMCOn with guardrail approval.
```

**What to observe:**
- Bob modifies the DDL and calls `check_sql_syntax` — must return **Syntax OK** before proceeding
- Presents: *"This will create table ARTICLE in SAMCOn. Approve?"*
- Executes with `execute_sql_statement` after approval

---

## Step 5: Verify the Migration (2 minutes)

**Prompt:**
```
Query QSYS2.SYSCOLUMNS to confirm the ARTICLE table was created correctly in SAMCOn. Show column names, data types, and lengths.
```

---

## ✅ Success Criteria

- [ ] Workflow generated a full impact report for ARTICLE (DDL, relationships, program references, authority)
- [ ] DDL refined with VARCHAR, CHECK, and FOREIGN KEY constraints
- [ ] `check_sql_syntax` validated the DDL before execution
- [ ] `CREATE TABLE` executed with guardrail approval in `SAMCOn`
- [ ] `QSYS2.SYSCOLUMNS` confirmed the correct structure

---

## Key Takeaways

- Impact-first migration: analyze dependencies before touching any code
- `QSYS2.GENERATE_SQL` produces DDL with `LABEL ON`, CCSID, and indexes automatically
- `SYSTOOLS.RELATED_OBJECTS` + `DSPPGMREF` reveal all dependent objects
- Guardrails require explicit approval for destructive SQL — no accidental drops

---

## Next Steps

- Proceed to [Lab 104](lab104-premium-rla-to-sql.md) — convert RLA operations to SQL in program code
- Run the workflow on a logical file (e.g., `ARTICLE1.LF` in `SAMCO/QDDSSRC/`)
