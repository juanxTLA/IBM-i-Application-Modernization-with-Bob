# Lab 102: Convert Fixed-Format RPG to Free

## Overview
Use the **Fixed to Free Conversion Workflow** and the `convert_rpg_source` tool to modernize legacy RPG. The workflow converts each specification group (H, F, D, C) in order and compiles the result to `SAMCOn`.

**Duration**: 20 minutes
**Difficulty**: Intermediate
**Mode**: ℹ️ IBM i Developer
**Source**: Local workspace (`SAMCO/QRPGLESRC/`)
**Build target**: `SAMCOn`

> **Local workspace**: Source lives exclusively in your **local Git clone** (`SAMCO/` directory). Bob reads and edits local files with `read_stream_file` / `write_stream_file`. `SAMCOn` contains compiled objects only — no source members. `SAMSRC` is never used for code modifications.

---

## Prerequisites
- Bob IDE with **IBM Bob Premium Package for i** installed
- **Code for IBM i** extension connected to your IBM i system
- `SAMCOn` in your library list (`n` = your team number)
- [Lab 101](lab101-premium-discover-samco.md) completed (business rules context)

---

## Step 1: Pre-Convert with CVTRPGSRC (3 minutes)

**Prompt:**
```
Use convert_rpg_source to pre-convert the file SAMCO/QRPGLESRC/ART200-Work_with_article.PGM.SQLRPGLE using the IBM i CVTRPGSRC command. Show me the converted output.
```

**What to observe:**
- Bob calls `convert_rpg_source` which wraps `CVTRPGSRC` on the live IBM i
- Returns the syntax-converted free-format source as a preview

---

## Step 2: Launch the Fixed to Free Conversion Workflow (3 minutes)

1. Open the **Bob Workflows** panel in Bob IDE
2. Select **"Fixed to Free Conversion"** → **Start Workflow**
3. In the scope form, enter:
   - **File**: `SAMCO/QRPGLESRC/ART200-Work_with_article.PGM.SQLRPGLE`
   - **Target library**: `SAMCOn`

**What to observe:**
- The workflow reads the local file and identifies spec groups (H, F, D, C)
- Auto-loads `rpg-fixed-to-free` and `rpg-free-format-fundamentals` skills
- Shows a conversion plan table:

| Specification | Converts to |
|--------------|-------------|
| H-spec | `Ctl-Opt` |
| F-spec | `Dcl-F` |
| D-spec | `Dcl-S`, `Dcl-Ds`, `Dcl-C` |
| C-spec | Free-form operations |

---

## Step 3: Review and Refine the Conversion (5 minutes)

The workflow converts each group and shows progress. During the C-spec conversion, ask:

**Prompt:**
```
After converting the C-specs, replace the magic number 14 in the subfile load loop with a named constant SUBFILE_PAGE_SIZE.
```

**What to observe:**
- Bob inserts `Dcl-C SUBFILE_PAGE_SIZE 14;` after `Ctl-Opt`
- Replaces `count < 14` with `count < SUBFILE_PAGE_SIZE`

The workflow outputs a status table:

| File | Format Before | Format After | Status |
|------|--------------|--------------|--------|
| ART200-Work_with_article.PGM.SQLRPGLE | Fixed | Free | ✅ Converted |

---

## Step 4: Compile the Converted Program (5 minutes)

**Prompt:**
```
Get the compile actions for SAMCO/QRPGLESRC/ART200-Work_with_article.PGM.SQLRPGLE and compile it to SAMCOn.
```

**What to observe:**
- Bob uses `get_compile_actions` — recommends `CRTSQLRPGI` for embedded SQL
- Uses `execute_compile_action` targeting `SAMCOn`

**If compilation errors occur:**
```
Explain the compilation errors and suggest fixes.
```

Common pitfalls Bob will catch:
- `Dcl-S` added for externally-described file fields (must be removed)
- `EXSR *INZSR` used explicitly (auto-executes — must be removed)
- `TAG/GOTO` remaining from C-specs

---

## ✅ Success Criteria

- [ ] `convert_rpg_source` pre-converted the ART200 source
- [ ] Fixed to Free Workflow ran through all spec groups
- [ ] `SUBFILE_PAGE_SIZE` constant replaced magic number 14
- [ ] Converted program compiled without errors in `SAMCOn`

---

## Key Takeaways

- `convert_rpg_source` wraps IBM i's native `CVTRPGSRC` — faster than manual conversion
- The workflow converts spec groups in order with skill-enforced rules
- `rpg-fixed-to-free` skill prevents common pitfalls (ext-described fields, `*INZSR`, indicators)
- Always compile to `SAMCOn` — never to the shared `SAMCO` library
- Source is always saved locally — never written back to QSYS members

---

## Next Steps

- Proceed to [Lab 103](lab103-premium-dds-to-sql-workflow.md) — convert DDS files to SQL DDL
- Try converting `CUS200.PGM.SQLRPGLE` or `ORD201.PGM.SQLRPGLE` from the local workspace
