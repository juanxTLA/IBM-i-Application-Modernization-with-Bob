# IBM Bob and IBM i Workshop (Premium Package for i)

## Overview

Hands-on labs to learn IBM i modernization using IBM Bob AI assistant. Each lab focuses on one practical use case you can complete quickly.

<table>
<tr>

<td align="center" width="33%">
<a href="https://github.com/bmarolleau/flight400-demo">
<img src="pics/image-bobppi.png" width="200">
<br>
<strong>✈️ Flight400 + Premium Package for i</strong>
</a>
<br>
⭐ <em>Recommended starting point</em><br>
Simple RPG/DDS app, source in QSYS — ideal for quick demos and half-day workshops. Easiest setup.
</td>

<td align="center" width="33%">
<a href="./lab100-premium-package-introduction.md">
<img src="pics/image-bobppi.png" width="200">
<br>
<strong>SAMCO + Premium Package for i</strong>
</a>
<br>
Multi-language app (RPG, COBOL, CL, C, C++, DDS, SQL) — best for 3h+ workshops and customers with mixed-language codebases.
</td>

<td align="center" width="33%">
<a href="./lab00_ibm-bob-ibmi-labs.md">
<img src="pics/image-bob.png" width="200">
<br>
<strong>IBM Bob & IBM i (no PPi)</strong>
</a>
<br>
Bonus exercises with minimal or no IBM i connection: Ansible/DevOps automation, Green Screen to React, IBM i MCP Server, and custom Bob extensions.
</td>

</tr>
</table>

---

### Which application should I use?

| | Flight400 | SAMCO |
|---|---|---|
| **Best for** | Quick demos, half-day workshops, first PPi contact | 3h+ workshops, mixed-language apps |
| **Languages** | RPG (OPM/ILE), DDS | RPG, COBOL, CL, C, C++, DDS, SQL |
| **Code location** | Native IBM i libraries (QSYS) — direct PPi connection, no extra scripting | Local workspace / Git — requires setup scripts to sync to source members |
| **Setup** | Restore via SQL script, duplicate with `CPYLIB` per user | See [build instructions](./lab00_ibm-bob-ibmi-labs.md#building-the-application) |
| **Repo** | [flight400-demo](https://github.com/bmarolleau/flight400-demo) | this repo |

> **Flight400** lives natively in IBM i libraries — the primary PPi differentiator is that users connect directly to their IBM i source files from the Bob IDE, with no workspace sync required. This makes it the go-to choice for showing PPi features. For multi-user setups (shared LPAR), restore the app once then run `CPYLIB FROMLIB(FLGHT400) TOLIB(FLIGHT401)` (and so on) so each participant gets their own isolated copy.

---

> 💡 **Instructor notes:** Installation scripts are in the [setup directory](./setup/). SAMCO build instructions are [here](./lab00_ibm-bob-ibmi-labs.md#building-the-application). To get an IBM i virtual machine for testing, see [here](./lab4-ibmi-mcp-mode.md#how-to-get-an-ibm-i-virtual-machine-aka-lpar).
