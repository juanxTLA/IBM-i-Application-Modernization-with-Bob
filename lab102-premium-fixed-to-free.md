# Lab 102: Convert Fixed-Format RPG to Free with the Workflow

## Overview
Use the **Fixed to Free Conversion Workflow** and the `convert_rpg_source` tool to modernize legacy RPG code. Learn how the Premium Package automates syntax conversion, guides you through each specification group (H, F, D, C), and compiles the result.

**Duration**: 20 minutes  
**Difficulty**: Intermediate  
**Mode**: ℹ️ IBM i Developer  
**What You'll Build**: Convert ART200 program from fixed-format to free-format RPG IV

---

## Prerequisites
- Bob IDE with **IBM Bob Premium Package for i** installed
- **Code for IBM i** extension connected to your IBM i system
- Libraries `SAMSRCn` and `SAMCOn` configured (where `n` is your student number)
- Library list set with both libraries
- Completion of [Lab 101](lab101-premium-discover-samco.md) recommended

> **Premium Package feature**: The `convert_rpg_source` tool and **Fixed to Free Conversion Workflow** are only available in **Bob Premium Package for i**.

---

## Use Case: Modernize the ART200 Article Maintenance Program

The `ART200` program is written in fixed-format RPG with column-dependent specifications. We'll convert it to modern free-format syntax for improved readability and maintainability.

---

## Step 1: Pre-Convert a Subroutine with CVTRPGSRC (5 minutes)

**Prompt for Bob:**
```
Use convert_rpg_source to pre-convert the s01lod subroutine in SAMSRCn/QRPGLESRC/ART200-Work_with_article.PGM.SQLRPGLE using IBM i CVTRPGSRC command.

Show me the converted output.
```

**What to Look For:**
- Bob calls the `convert_rpg_source` tool which wraps `CVTRPGSRC` on the live IBM i
- The tool reads the member, runs the conversion, and returns the free-format source
- Fixed-format specifications (BEGSR, ENDSR, IF/ENDIF, DO/ENDDO) → free-form (Dcl-Proc, If/EndIf, DoW/EndDo)

**Expected Output:**
```rpgle
Dcl-Proc LoadSubfile;
  RestorePosition();
  
  RRb01 = RRn01 + 1;
  opt01 = 0;
  count = 0;
  
  Read ARTICLE2;
  DoW Not %Eof(ARTICLE2) And count < 14;
    RRN01 += 1;
    count += 1;
    Write SFL01;
    Read ARTICLE2;
  EndDo;
  
  sflend = %Eof(ARTICLE1);
  step01 = dsp;
  SavePosition();
End-Proc;
```

> **Premium vs. Core**: Bob Core can suggest free-format conversions in chat. Premium Package **executes CVTRPGSRC on the IBM i** and returns the actual converted source.

---

## Step 2: Launch the Fixed to Free Conversion Workflow (3 minutes)

1. Open the **Bob Workflows** panel in Bob IDE (sidebar icon)
2. Find **"Fixed to Free Conversion"** in the workflows list
3. Click **Start Workflow**

**Workflow Step 1 — Define Scope:**

A form prompts for:
- **Source Library**: Enter `SAMSRCn`
- **Source File**: Enter `QRPGLESRC`
- **Member Name**: Enter `ART200-Work_with_article.PGM.SQLRPGLE`

Click **Next**.

**What to Look For:**
- The workflow validates the member exists using `read_member`
- Auto-loads the `rpg-fixed-to-free` and `rpg-free-format-fundamentals` skills
- Displays a preview of the member structure (H-specs, F-specs, D-specs, C-specs count)

---

## Step 3: Review the Conversion Plan (3 minutes)

**Workflow Step 2 — Convert:**

The workflow presents a conversion plan:

| Specification | Action |
|--------------|--------|
| H-spec | → `Ctl-Opt` declaration |
| F-spec | → `Dcl-F` file declarations |
| D-spec | → `Dcl-S`, `Dcl-Ds`, `Dcl-C` declarations |
| C-spec | → Free-form operations, `Dcl-Proc` for subroutines |

The workflow converts each group in order and shows progress.

**Prompt for Bob during this step:**
```
After converting the C-specs, replace the magic number 14 
in the LoadSubfile procedure with a named constant SUBFILE_PAGE_SIZE.
```

**What to Look For:**
- Bob inserts `Dcl-C SUBFILE_PAGE_SIZE 14;` after the Ctl-Opt section
- Replaces `count < 14` with `count < SUBFILE_PAGE_SIZE` in the loop
- The `rpg-code-review` skill suggests other magic numbers to refactor

---

## Step 4: Review the Converted Source (4 minutes)

**Workflow Step 3 — Result:**

The workflow displays a status table:

| File | Source Format | Target Format | Status | Compiled |
|------|--------------|---------------|--------|----------|
| ART200-Work_with_article.PGM.SQLRPGLE | Fixed | Free | ✅ Converted | ⏳ Pending |

**Prompt for Bob:**
```
Show me the before/after comparison for the s01lod section:
- Fixed-format version (original)
- Free-format version (converted)

Highlight the key differences.
```

**Expected Output:**
Bob displays a side-by-side comparison showing:
- `BEGSR s01lod` → `Dcl-Proc LoadSubfile;`
- `IF *IN50` → `If statusChanged;`
- `DO count < 14` → `DoW Not %Eof(ARTICLE2) And count < SUBFILE_PAGE_SIZE;`
- Column indicators (01-99) → named indicator variables

---

## Step 5: Compile the Converted Program (5 minutes)

**Prompt for Bob:**
```
Get the compile actions for SAMSRCn/QRPGLESRC/ART200-Work_with_article.PGM.SQLRPGLE 
and compile it to SAMCOn library.
```

**What to Look For:**
- Bob uses `get_compile_actions` to list available compile options (CRTBNDRPG, CRTSQLRPGI, etc.)
- Recommends `CRTSQLRPGI` since the member contains embedded SQL
- Uses `execute_compile_action` to compile the program

**If compilation errors occur**, ask Bob:
```
Explain the compilation errors and suggest fixes.
```

**Common Errors:**
- **Externally-described fields**: Don't use `Dcl-S` for fields from externally-described files
- **Indicator data structures**: Must remain as data structures, not standalone variables
- **File operation codes**: `READ` → `Read`, `CHAIN` → `Chain` (capitalization matters)

Bob will fix the errors and re-submit for compilation.

---

## ✅ Success Criteria

You've successfully completed this lab when:
- [ ] `convert_rpg_source` pre-converted the s01lod subroutine successfully
- [ ] The Fixed to Free Conversion Workflow ran through all specification groups
- [ ] Magic number 14 was replaced with `SUBFILE_PAGE_SIZE` constant
- [ ] The converted program compiled without errors in SAMCOn
- [ ] You understand the H→Ctl-Opt, F→Dcl-F, D→Dcl-S, C→free-form transformation

---

## Key Takeaways

1. **CVTRPGSRC Wrapper**: `convert_rpg_source` automates IBM i's native conversion tool
2. **Guided Workflow**: The workflow converts specification groups in order (H, F, D, C) with validation at each step
3. **Auto-Loaded Skills**: `rpg-fixed-to-free` governs conversion rules, preventing common pitfalls
4. **Compilation Integration**: `get_compile_actions` + `execute_compile_action` compile directly from chat
5. **Incremental Refactoring**: Convert one program at a time, test, and iterate

---

## Next Steps

- Proceed to [Lab 103](lab103-premium-dds-to-sql-workflow.md) to convert DDS files to SQL DDL
- Convert another program in SAMSRCn (try CUS200 or ORD201)
- Ask Bob to generate documentation for the converted ART200 program
