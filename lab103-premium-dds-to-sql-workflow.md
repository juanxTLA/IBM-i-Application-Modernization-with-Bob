# Lab 103: Convert DDS to SQL with the Workflow

## Overview
Use the **DDS to SQL Conversion Impact Analysis Workflow** to assess the migration of a DDS physical file to SQL DDL. Learn how Bob generates DDL, analyzes dependencies, and produces a full impact report before any code changes.

**Duration**: 20 minutes  
**Difficulty**: Intermediate  
**Mode**: ℹ️ IBM i Developer  
**What You'll Build**: Migration impact report and CREATE TABLE DDL for ARTICLE file

---

## Prerequisites
- Bob IDE with **IBM Bob Premium Package for i** installed
- **Code for IBM i** extension connected to your IBM i system
- **Db2 for i** extension installed (for SQL execution)
- Libraries `SAMSRCn` and `SAMCOn` configured (where `n` is your student number)
- Library list set with both libraries
- Completion of [Lab 101](lab101-premium-discover-samco.md) recommended

> **Premium Package feature**: The **DDS to SQL Conversion Impact Analysis Workflow** is only available in **Bob Premium Package for i**.

---

## Use Case: Migrate ARTICLE Physical File to SQL Table

The `ARTICLE` physical file is defined in DDS with keyed access. We'll use the workflow to generate SQL DDL, analyze which programs depend on it, and understand the migration impact.

---

## Step 1: Launch the DDS to SQL Conversion Workflow (2 minutes)

1. Open the **Bob Workflows** panel in Bob IDE
2. Find **"DDS to SQL Conversion Impact Analysis"** in the workflows list
3. Click **Start Workflow**

**Workflow Step 1 — Select DDS Object:**

A form prompts for:
- **Library Name**: Enter `SAMCOn`
- **Object Name**: Enter `ARTICLE`
- **Is this a Logical File (LF)?**: Select `No` (ARTICLE is a PF)

Click **Next**.

**What to Look For:**
- The workflow validates the object exists using `execute_cl_command` (`DSPOBJD`)
- Auto-loads the `dds-physical-files` and `db2-dds-to-ddl` skills
- Displays object metadata (type: *FILE, attribute: PF, record length, member count)

---

## Step 2: Review the Generated SQL DDL (5 minutes)

**Workflow Step 2 — Generate SQL DDL:**

The workflow calls `QSYS2.GENERATE_SQL` with options:
- `ADDITIONAL_INDEX_OPTION=1` (generate CREATE INDEX for keyed access)
- `CCSID_OPTION=1` (preserve CCSID)
- `LABEL_OPTION=1` (convert TEXT to LABEL ON)
- `CONSTRAINT_OPTION=2` (inline primary key constraints)

**Generated DDL Example:**
```sql
CREATE TABLE SAMCO3.ARTICLE (
  ARID DECIMAL(7, 0) NOT NULL PRIMARY KEY,
  ARDESIG CHAR(30) NOT NULL CCSID 37,
  ARFAMCOD CHAR(2) NOT NULL,
  ARSALEPR DECIMAL(11, 2) NOT NULL,
  ARSTOCK DECIMAL(7, 0) NOT NULL,
  ARVAT CHAR(2) NOT NULL,
  ARDEL CHAR(1) NOT NULL DEFAULT '0',
  LABEL ON COLUMN ARTICLE.ARID IS 'Article ID',
  LABEL ON COLUMN ARTICLE.ARDESIG IS 'Description',
  LABEL ON COLUMN ARTICLE.ARFAMCOD IS 'Family Code',
  LABEL ON TABLE ARTICLE IS 'Article Master'
);

CREATE INDEX SAMCO3.ARTICLE_ARID ON ARTICLE(ARID);
```

**Prompt for Bob:**
```
Review the generated DDL for ARTICLE. Suggest improvements:
1. Should any CHAR fields be VARCHAR?
2. Are there missing foreign key constraints?
3. Should ARDEL have a CHECK constraint?
```

**What to Look For:**
- Bob suggests `ARDESIG CHAR(30)` → `VARCHAR(30)` for variable-length descriptions
- Recommends `FOREIGN KEY (ARFAMCOD) REFERENCES FAMILLY(FAID)` if FAMILLY exists
- Suggests `CHECK (ARDEL IN ('0', '1'))` for soft-delete flag validation
- The `db2-ddl-generation` skill is auto-loaded to guide constraint logic

---

## Step 3: Analyze Database Relationships (4 minutes)

**Workflow Step 3 — Collect Relationships & Static References:**

The workflow queries:
- `SYSTOOLS.RELATED_OBJECTS` for database-level dependencies
- `DSPPGMREF PGM(SAMCOn/*ALL)` for static program references across the library list

**Report Section: Database Relationships**

| Related Object | Type | Relationship |
|---------------|------|--------------|
| ORDERLIN | *FILE | Foreign key: OLARTID → ARTICLE.ARID |
| FAMILLY | *FILE | Foreign key: ARTICLE.ARFAMCOD → FAMILLY.FAID |
| VATDEF | *FILE | Foreign key: ARTICLE.ARVAT → VATDEF.VATCOD |

**Report Section: Static Program References**

| Program | Library | Reference Type |
|---------|---------|---------------|
| ART200 | SAMCOn | Externally-described file |
| ART300 | SAMCOn | SQL embedded SELECT |
| ART400 | SAMCOn | SQL embedded SELECT |
| ORD100 | SAMCOn | SQL embedded SELECT (via ORDERLIN) |

**What to Look For:**
- All programs referencing ARTICLE are listed — any not updated will fail after DDS→SQL migration
- Logical files built over ARTICLE will need separate conversion (the workflow shows a warning)

---

## Step 4: Review Object Status & Authority (3 minutes)

**Workflow Step 4 — Collect Object Status & Authority:**

The workflow queries:
- `QSYS2.OBJECT_STATISTICS` (size, owner, last used date)
- `QSYS2.JOURNALED_OBJECTS` (journal name, images, omit entry)
- `QSYS2.OBJECT_LOCK_INFO` (active locks)
- `QSYS2.OBJECT_PRIVILEGES` (per-user authorities)

**Report Section: Object Status**

- **Size**: 10 MB
- **Owner**: QSECOFR
- **Last Used**: 2024-01-15
- **Journaling**: Yes — journal `SAMCOn/QSQJRN`, images `*BOTH`
- **Active Locks**: None

**Report Section: Authority Matrix**

| User | Authority |
|------|-----------|
| *PUBLIC | *USE |
| SAMCOn | *ALL |

**What to Look For:**
- Journaling status — the new SQL table must be journaled to match
- Authority settings — must replicate on the CREATE TABLE

---

## Step 5: Execute the CREATE TABLE (6 minutes)

**Workflow Step 5 — Impact Report:**

The workflow generates a markdown report with all sections above and a summary:

> **Summary**: ARTICLE has 4 dependent programs and 3 foreign key relationships. No active locks detected. Migration risk: **MEDIUM** (RRN-based access detected in ART200 line 134 — review for REUSEDLT compatibility).

**Prompt for Bob:**
```
Refine the generated DDL:
1. Change ARDESIG to VARCHAR(50) (extended from 30)
2. Add CHECK (ARDEL IN ('0', '1'))
3. Add FOREIGN KEY constraints for ARFAMCOD and ARVAT

Validate the refined DDL with check_sql_syntax before executing.
```

**What to Look For:**
- Bob modifies the DDL based on your requirements
- Uses `check_sql_syntax` to validate — no execution yet
- Returns validation result: **Syntax OK** or error messages

**Prompt for Bob:**
```
Execute the refined CREATE TABLE statement in SAMCOn with guardrail approval.
```

**What to Look For:**
- Bob uses `execute_sql_statement` with destructive SQL guardrail
- You are prompted: *"This will create table ARTICLE in SAMCOn. Approve?"*
- After approval, the table is created
- Bob confirms: **Table ARTICLE created successfully**

---

## Step 6: Compare DDS vs. SQL Structures (2 minutes)

**Prompt for Bob:**
```
Query QSYS2.SYSCOLUMNS to compare the DDS physical file 
and the new SQL table side-by-side. Show column names, data types, and lengths.
```

**Expected Output:**
| Column | DDS Type | DDS Length | SQL Type | SQL Length |
|--------|----------|------------|----------|------------|
| ARID | PACKED | 7,0 | DECIMAL | 7,0 |
| ARDESIG | CHAR | 30 | VARCHAR | 50 |
| ARFAMCOD | CHAR | 2 | CHAR | 2 |

**What to Look For:**
- Bob uses `execute_sql_statement` to query `SYSCOLUMNS`
- Confirms the migration preserved data types and lengths (except for VARCHAR refinement)

---

## ✅ Success Criteria

You've successfully completed this lab when:
- [ ] The DDS to SQL Conversion Workflow generated a full impact report for ARTICLE
- [ ] SQL DDL was refined with VARCHAR, CHECK, and FOREIGN KEY constraints
- [ ] `check_sql_syntax` validated the DDL before execution
- [ ] The CREATE TABLE executed successfully with guardrail approval
- [ ] Side-by-side comparison confirmed the DDS→SQL structure match

---

## Key Takeaways

1. **Impact-First Migration**: The workflow analyzes dependencies before any code changes
2. **GENERATE_SQL Automation**: `QSYS2.GENERATE_SQL` produces DDL with LABEL ON, CCSID, and indexes
3. **Dependency Analysis**: `SYSTOOLS.RELATED_OBJECTS` + `DSPPGMREF` find all dependent objects
4. **Guardrails**: Destructive SQL requires explicit approval — no accidental table drops
5. **Auto-Loaded Skills**: `db2-dds-to-ddl`, `dds-physical-files`, `db2-system-catalog` guide the process

---

## Next Steps

- Proceed to [Lab 104](lab104-premium-rla-to-sql.md) to convert RLA operations to SQL in program code
- Run the workflow again on a logical file (e.g., ARTICLE_BY_FAMILY)
- Ask Bob to generate a migration script for all SAMCO physical files
