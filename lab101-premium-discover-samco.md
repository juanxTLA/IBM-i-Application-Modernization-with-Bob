# Lab 101: Discover SAMCO with IBM i Developer Mode

## Overview
Explore the SAMCO application using the **IBM i Developer** mode's built-in tools and automatically loaded skills. Learn how Bob reads live IBM i source members, explains business logic, and uses RAG-powered documentation to answer technical questions on the fly.

**Duration**: 15 minutes  
**Difficulty**: Beginner  
**Mode**: ℹ️ IBM i Developer  
**What You'll Learn**: Navigate a live IBM i codebase, generate architecture diagrams, and use inline documentation retrieval

---

## Prerequisites
- Bob IDE with **IBM Bob Premium Package for i** installed
- **Code for IBM i** extension connected to your IBM i system
- Libraries `SAMSRCn` and `SAMCOn` configured (where `n` is your student number)
- Library list set with both libraries

> **Premium Package feature**: The `read_member`, `search_qsys`, `/erd` command, and `search_ibm_i_docs_with_rag` tool are only available in **Bob Premium Package for i**, not in Bob Core.

---

## Use Case: Understand the SAMCO Business Domain

SAMCO is a sample order management system with articles, customers, providers, and orders. We'll use Bob to discover its structure, business rules, and database schema without reading source code manually.

---

## Step 1: Navigate the SAMCO Library (3 minutes)

**Switch to IBM i Developer mode** in the Bob chat panel (select the mode dropdown).

**Prompt for Bob:**
```
I want to discover the SAMCO application. 

First, list all source files in library SAMSRCn. Show me:
- The source file names
- Object types (QRPGLESRC, QDDSSRC, etc.)
- Brief description of each file's purpose
```

**What to Look For:**
- Bob uses `search_qsys` to scan the library
- Auto-loads the `dds-primer-basics` and `rpg-primer-basics` skills
- Returns a structured list with QRPGLESRC (programs), QDDSSRC (DDS files), QCLSRC (CL), etc.

---

## Step 2: Read a Key Program (4 minutes)

**Prompt for Bob:**
```
Read the member ART200-Work_with_article.PGM.SQLRPGLE from SAMSRCn/QRPGLESRC.

Explain:
1. What this program does
2. What the panel-step state machine pattern is (panel, step01, step02 variables)
3. What business rules govern the article lifecycle (VAT calculation, soft-delete ARDEL field)

Keep it concise.
```

**What to Look For:**
- Bob uses `read_member` to fetch the source from IBM i
- The `rpg-primer-basics` and `rpg-embedded-sql` skills are auto-loaded
- Bob explains the panel/step variables control which screen and action (PRP/DSP/VAL) executes
- VAT is calculated from `VATDEF` table, soft-delete uses `ARDEL='1'` instead of physical deletion

> **Premium vs. Core**: Bob Core requires you to paste the source code. Premium Package **reads it live** from the connected IBM i.

---

## Step 3: Generate an ERD (3 minutes)

**Prompt for Bob:**
```
/erd SAMCOn
```

**What to Look For:**
- Bob queries `QSYS2.SYSTABLES`, `SYSCOLUMNS`, `SYSCST`, `SYSREFCST` to build the schema
- A **Mermaid ERD diagram** is generated showing:
  - All tables (ARTICLE, CUSTOMER, ORDERHDR, ORDERLIN, FAMILLY, VATDEF, PROVIDER)
  - Primary keys (ARID, CUID, ORID, etc.)
  - Foreign key relationships (ORDERLIN → ARTICLE, ORDERHDR → CUSTOMER, etc.)
  - Column data types (PACKED, CHAR, DATE)

> **Premium feature**: The `/erd` slash command is exclusive to Bob Premium Package for i.

---

## Step 4: Ask a Documentation Question Mid-Task (3 minutes)

**Prompt for Bob:**
```
What is the panel-step pattern in RPG, and where is it documented in IBM i guides?
```

**What to Look For:**
- Bob uses `search_ibm_i_docs_with_rag` to search IBM i documentation semantically
- Returns excerpts from ILE RPG programmer guides explaining state machine patterns, indicators, and structured control flow
- Provides page references or section links for further reading

> **Premium feature**: `search_ibm_i_docs_with_rag` is only available in Premium Package modes, not in Bob Core.

---

## Step 5: Generate an Architecture Document (2 minutes)

**Prompt for Bob:**
```
Generate a markdown architecture document for SAMCO covering:
- Application purpose
- Database schema (tables and relationships from the ERD)
- Key business rules (VAT, soft-delete, order lifecycle)
- Program inventory (maintenance vs. reporting programs)

Save it as a file in the IFS.
```

**What to Look For:**
- Bob synthesizes the information from previous steps
- Uses `write_stream_file` to save `/home/<youruser>/SAMCO_Architecture.md` on the IBM i IFS
- The document includes the ERD, business rules explained earlier, and program descriptions

---

## ✅ Success Criteria

You've successfully completed this lab when:
- [ ] Bob listed all source files in SAMSRCn using `search_qsys`
- [ ] Bob read and explained ART200 program logic with auto-loaded skills
- [ ] An ERD was generated with `/erd SAMCOn` showing all tables and relationships
- [ ] Bob retrieved IBM i documentation inline with `search_ibm_i_docs_with_rag`
- [ ] A markdown architecture document was saved to the IFS

---

## Key Takeaways

1. **Live IBM i Reading**: `read_member` and `search_qsys` eliminate manual file browsing
2. **Auto-Loaded Skills**: Bob loads `rpg-primer-basics`, `dds-primer-basics`, `db2-system-catalog` automatically based on context
3. **Instant ERDs**: `/erd` generates live schema diagrams from the QSYS2 catalog in seconds
4. **Inline Documentation**: `search_ibm_i_docs_with_rag` answers technical questions without leaving the chat
5. **Context Awareness**: Bob knows your library list, CCSID, and IBM i OS version — no manual setup required

---

## Next Steps

- Proceed to [Lab 102](lab102-premium-fixed-to-free.md) to convert fixed-format RPG to free-form using the workflow
- Ask Bob to generate a similar ERD for another library on your system
- Use `search_qsys` with a pattern like `filePattern="ART*"` to find all article-related members
