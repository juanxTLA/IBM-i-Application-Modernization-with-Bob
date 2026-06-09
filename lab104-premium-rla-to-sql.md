# Lab 104: Convert RLA to SQL and Optimize with IBM i Database Mode

## Overview
Use the **IBM i Database** mode to convert record-level access (RLA) operations to SQL and optimize query performance. Learn how Bob uses SQL-first skills, generates ERDs, and recommends index strategies.

**Duration**: 15 minutes  
**Difficulty**: Intermediate  
**Mode**: 🛢️ IBM i Database  
**What You'll Build**: SQL queries replacing CHAIN/READ operations, optimized with indexes

---

## Prerequisites
- Bob IDE with **IBM Bob Premium Package for i** installed
- **Code for IBM i** extension connected to your IBM i system
- **Db2 for i** extension installed (for SQL execution)
- Libraries `SAMSRCn` and `SAMCOn` configured (where `n` is your student number)
- Library list set with both libraries
- Completion of [Lab 101](lab101-premium-discover-samco.md) and [Lab 103](lab103-premium-dds-to-sql-workflow.md) recommended

> **Premium Package feature**: The **IBM i Database** mode and its SQL-first skills are only available in **Bob Premium Package for i**.

---

## Use Case: Replace Two CHAIN Operations with a Single SQL JOIN

The ART200 program uses two sequential operations to fetch article details:
1. `CHAIN arid article1` — fetch article record
2. `getArtFamDesc()` — calls another procedure to CHAIN into FAMILLY table

We'll replace this with a single SQL `SELECT … LEFT JOIN` and optimize access.

---

## Step 1: Switch to IBM i Database Mode (1 minute)

In the Bob chat panel, click the **mode dropdown** and select:
- **🛢️ IBM i Database**

**What to Look For:**
- The mode description changes to: *"Generate, modernize, and tune SQL within Db2 for i"*
- Auto-loaded skills now prioritize: `db2-sql-primer`, `db2-sql-optimization`, `db2-index-strategy`

> **Premium vs. Core**: Bob Core has no built-in database mode. Premium Package provides a dedicated mode with 15 Db2-focused skills.

---

## Step 2: Generate an ERD Before Writing SQL (3 minutes)

**Prompt for Bob:**
```
/erd SAMCOn
```

**What to Look For:**
- Bob queries the QSYS2 catalog to build the schema
- A **Mermaid ERD** is generated showing:
  - ARTICLE table with columns (ARID, ARDESIG, ARFAMCOD, ARSALEPR, ARVAT)
  - FAMILLY table with columns (FAID, FADESIG)
  - Foreign key: ARTICLE.ARFAMCOD → FAMILLY.FAID

**Prompt for Bob:**
```
Based on the ERD, which tables do I need to join to get:
- Article ID
- Article description
- Family description
in a single query?
```

**Expected Answer:**
```
SELECT 
  a.ARID,
  a.ARDESIG AS article_description,
  f.FADESIG AS family_description
FROM SAMCOn.ARTICLE a
LEFT JOIN SAMCOn.FAMILLY f ON a.ARFAMCOD = f.FAID
WHERE a.ARID = ?
```

---

## Step 3: Convert CHAIN Operations to SQL (4 minutes)

**Prompt for Bob:**
```
Read the ART200 program in SAMSRCn/QRPGLESRC.

Find the section where it does:
1. CHAIN arid article1
2. Calls getArtFamDesc() to fetch family description

Replace these two operations with a single SQL SELECT … LEFT JOIN 
that retrieves both article and family descriptions in one query.

Show me the new SQL and the updated RPG code.
```

**What to Look For:**
- Bob uses `read_member` to scan the program
- The `rpg-embedded-sql` skill is auto-loaded to guide SQL embedding
- Bob generates an `EXEC SQL` block:

```rpgle
Exec SQL
  SELECT 
    ARDESIG, 
    f.FADESIG
  INTO 
    :articleDesc, 
    :familyDesc
  FROM ARTICLE a
  LEFT JOIN FAMILLY f ON a.ARFAMCOD = f.FAID
  WHERE a.ARID = :arid;

If SQLCODE = 0;
  // Success — both descriptions retrieved
ElseIf SQLCODE = 100;
  // Not found
Else;
  // Error
EndIf;
```

- The `getArtFamDesc()` procedure is no longer needed
- The `db2-sql-optimization` skill suggests using LEFT JOIN to handle missing family codes

---

## Step 4: Evaluate Index Strategy (4 minutes)

**Prompt for Bob:**
```
For the SQL query we just wrote, evaluate the index strategy.

Should I create indexes on:
1. ARTICLE(ARID)
2. FAMILLY(FAID)
3. ARTICLE(ARFAMCOD)

Use the db2-index-strategy skill to recommend the optimal approach.
```

**What to Look For:**
- Bob auto-loads the `db2-index-strategy` skill
- Recommends:
  1. **ARTICLE(ARID)**: Already exists as primary key — no action needed
  2. **FAMILLY(FAID)**: Already exists as primary key — no action needed
  3. **ARTICLE(ARFAMCOD)**: Create a secondary index for join performance

**Generated Index DDL:**
```sql
CREATE INDEX SAMCOn.ARTICLE_FAMCOD_IDX 
  ON ARTICLE(ARFAMCOD);
```

**Prompt for Bob:**
```
Validate the CREATE INDEX statement and execute it with guardrail approval.
```

**What to Look For:**
- Bob uses `check_sql_syntax` to validate
- Uses `execute_sql_statement` with approval prompt
- Confirms: **Index ARTICLE_FAMCOD_IDX created successfully**

---

## Step 5: Create a View Combining All Tables (3 minutes)

**Prompt for Bob:**
```
Create a SQL view called ARTICLE_SUMMARY that combines:
- ARTICLE (ARID, ARDESIG, ARSALEPR, ARSTOCK)
- FAMILLY (FADESIG as family_description)
- VATDEF (VATRAT as vat_rate)

Use LEFT JOINs to handle missing references.
Validate and execute the CREATE VIEW statement.
```

**Expected DDL:**
```sql
CREATE OR REPLACE VIEW SAMCOn.ARTICLE_SUMMARY AS
  SELECT 
    a.ARID AS article_id,
    a.ARDESIG AS article_description,
    a.ARSALEPR AS sale_price,
    a.ARSTOCK AS stock,
    f.FADESIG AS family_description,
    v.VATRAT AS vat_rate
  FROM ARTICLE a
  LEFT JOIN FAMILLY f ON a.ARFAMCOD = f.FAID
  LEFT JOIN VATDEF v ON a.ARVAT = v.VATCOD
  WHERE a.ARDEL = '0';
```

**What to Look For:**
- Bob uses `check_sql_syntax` before execution
- Uses `execute_sql_statement` with guardrail approval
- Confirms: **View ARTICLE_SUMMARY created successfully**

**Prompt for Bob:**
```
Query the ARTICLE_SUMMARY view and show me the first 5 rows.
```

**What to Look For:**
- Bob executes `SELECT * FROM SAMCOn.ARTICLE_SUMMARY FETCH FIRST 5 ROWS ONLY`
- Displays a formatted result set with all joined columns

---

## ✅ Success Criteria

You've successfully completed this lab when:
- [ ] Switched to IBM i Database mode and noted the SQL-first skills
- [ ] Generated an ERD with `/erd SAMCOn` showing ARTICLE → FAMILLY relationship
- [ ] Converted CHAIN + getArtFamDesc() to a single SQL LEFT JOIN
- [ ] Created a secondary index on ARTICLE(ARFAMCOD) with index strategy guidance
- [ ] Created ARTICLE_SUMMARY view combining ARTICLE, FAMILLY, and VATDEF
- [ ] Queried the view and retrieved live data

---

## Key Takeaways

1. **Database Mode First**: IBM i Database mode prioritizes SQL-first solutions with Db2 skills
2. **ERD-Driven Design**: `/erd` visualizes relationships before writing queries
3. **CHAIN → SQL**: SQL SELECT is more efficient than sequential CHAIN operations
4. **Index Strategy**: The `db2-index-strategy` skill recommends indexes based on query patterns
5. **Views for Reusability**: SQL views encapsulate complex joins for use across multiple programs

---

## Next Steps

- Proceed to [Lab 105](lab105-premium-impact-analysis.md) to analyze object dependencies
- Convert other RLA operations in ART200 (READ, READE, SETLL) to SQL cursors
- Ask Bob to generate an execution plan for the ARTICLE_SUMMARY view query
