# Lab 105: Analyze SAMCO Object Dependencies

## Overview
Use the IBM i system catalog and `search_ifs` to perform a dependency analysis on the SAMCO application, then simulate the impact of a new field before making any changes.

**Duration**: 15 minutes
**Difficulty**: Intermediate
**Mode**: ℹ️ IBM i Developer
**Source**: Local workspace (`SAMCO/`) + live IBM i catalog
**Output**: Impact report saved to `docs/`

> **Local workspace**: Bob searches source in the **local Git clone** using `search_ifs`. Live IBM i catalog queries (`QSYS2.SYSDEP`, `SYSCST`) run via `execute_sql_statement` against `SAMCOn` — which contains compiled objects and the database, not source members.

---

## Prerequisites
- Bob IDE with **IBM Bob Premium Package for i** installed
- **Code for IBM i** extension connected to your IBM i system
- **Db2 for i** extension installed
- `SAMCOn` in your library list (`n` = your team number)
- [Lab 101](lab101-premium-discover-samco.md) completed

---

## Step 1: Find All Objects Depending on ARTICLE (3 minutes)

**Switch to ℹ️ IBM i Developer mode** in the Bob chat panel.

**Prompt:**
```
Find all objects in SAMCOn that depend on the ARTICLE file using QSYS2.SYSDEP. Return object name, object type, and dependency type as a table.
```

**What to observe:**
- Bob uses `execute_sql_statement` against `QSYS2.SYSDEP`
- The `db2-system-catalog` skill is auto-loaded
- Returns dependent programs, service programs, logical files, and views

---

## Step 2: Map Foreign Key Relationships (3 minutes)

**Prompt:**
```
Map all foreign key relationships in SAMCOn using QSYS2.SYSCST and QSYS2.SYSREFCST. Show constraint name, child table, parent table, and FK column as a table.
```

**What to observe:**
- Bob generates and runs the join query across `SYSCST`, `SYSREFCST`, `SYSKEYCST`
- Returns constraints for ARTICLE → FAMILLY, ARTICLE → VATDEF, ORDERLIN → ARTICLE

---

## Step 3: Search Local Source for Field References (3 minutes)

**Prompt:**
```
Search the local workspace (SAMCO/ directory) for all references to the field ARSALEPR. Show file name, line number, and line content.
```

**What to observe:**
- Bob uses `search_ifs` on the local workspace files
- Returns occurrences in RPG programs, DDS files, and SQL members from the Git clone

---

## Step 4: Simulate a New Field Impact (4 minutes)

**Prompt:**
```
If I add a new field ARDISCOUNT (packed 5,2) to the ARTICLE table in SAMCOn, which objects need to be recompiled?

Consider:
1. Programs using ARTICLE with externally-described fields (F-spec)
2. Programs using embedded SQL with SELECT *
3. Logical files built over ARTICLE

Use QSYS2.SYSDEP and search the local workspace for SELECT * patterns.
```

**What to observe:**
- Bob queries `QSYS2.SYSDEP` and searches local source for `SELECT *`
- The `rpg-code-review` and `db2-system-catalog` skills are auto-loaded
- Returns a recompile impact list with reasons

---

## Step 5: Save the Impact Report (2 minutes)

**Prompt:**
```
Generate a markdown impact report for ARTICLE summarizing: dependent objects, foreign key relationships, ARSALEPR field usage, and recompile list for adding ARDISCOUNT. Save it as docs/ARTICLE-impact-report.md in the local workspace.
```

**What to observe:**
- Bob synthesizes results from all previous steps
- Uses `write_stream_file` to save `docs/ARTICLE-impact-report.md`

---

## ✅ Success Criteria

- [ ] All ARTICLE dependents listed using `QSYS2.SYSDEP`
- [ ] Foreign key map generated from `QSYS2.SYSCST` + `QSYS2.SYSREFCST`
- [ ] `ARSALEPR` references found in the local workspace
- [ ] Recompile impact list generated for adding `ARDISCOUNT`
- [ ] `docs/ARTICLE-impact-report.md` saved in the local workspace

---

## Key Takeaways

- `QSYS2.SYSDEP`, `SYSCST`, and `SYSREFCST` reveal all dependencies from the live catalog
- `search_ifs` searches local workspace files — no IBM i connection needed for source
- Know what breaks before making any changes — impact-first analysis
- `write_stream_file` saves reports to `docs/` in the Git repo for team sharing

---

## Next Steps

- Proceed to [Lab 106](lab106-premium-test-rpgunit.md) — generate RPGUnit tests for SAMCO
- Use `QSYS2.SYSDEP` to analyze CUSTOMER or ORDER dependencies
