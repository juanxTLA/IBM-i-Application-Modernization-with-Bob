# HMC Operations with IBM Bob — Workshop

> **Audience:** Power Systems administrators and engineers
> **Tool:** IBM Bob AI Assistant
> **Pre-requisites:** Basic IBM Power Systems knowledge, familiarity with REST APIs

> 💡 **Lab Environment Access:** An HMC can be requested on **IBM TechZone** — ask your IBM Representative or Business Partner for access.

> ⚠️ **Disclaimer:** This lab is provided **as-is** for exploration and learning purposes. Always use a **test or non-production HMC** — never run power operations, configuration changes, or automation scripts against a production system without proper validation and change management approval.

---

## Extending Bob for HMC Operations

IBM Bob is a general-purpose AI assistant. Out of the box it can query the HMC REST API, interpret responses, and help diagnose issues — but its knowledge of HMC-specific concepts, API patterns, and operational best practices is generic.

> **HMC is one example.** The same approach applies to other Power Systems management interfaces: Bob can be prompted to interact with **PowerVC** (IBM's OpenStack-based cloud management for Power) or a vanilla **OpenStack** endpoint or **K8s/OpenShift** based Clouds - using the same pattern of REST API/cli calls, and natural-language diagnosis. Any management plane with a CLI or a documented REST API is a candidate.

**Custom modes, skills, and tools can significantly enhance Bob's behavior for HMC work:**

- A dedicated **`hmc-operator` custom mode** can give Bob a role definition focused on Power Systems infrastructure, HMC REST API conventions, and operational safety guardrails (e.g., always validate before executing power operations).
- **Custom skills** can encode HMC-specific knowledge: LPAR state machine, DLPAR constraints, LPM pre-requisites, SEA failover patterns, SSP quorum rules — so Bob applies them consistently without being re-explained each session.
- **MCP tools** could wrap common HMC REST API calls (authenticate, list LPARs, get events) to let Bob interact with HMC directly rather than generating curl commands for the user to run. The same pattern applies to **PowerVC / OpenStack** APIs.

The exercises in this workshop use Bob in its default Agent mode — a deliberate choice to show what is achievable without any customization. Building the right mode and skills on top of this foundation is the natural next step for teams that want to operationalize Bob for HMC management.

---

## Contents

| # | Section |
|---|---------|
| — | [Extending Bob for HMC Operations](#extending-bob-for-hmc-operations) |
| — | [Lab Environment](#lab-environment) |
| — | [Learning Objectives](#learning-objectives) |
| — | [REST API Quick Reference](#rest-api-quick-reference) |
| **Part 1** | **HMC Operations 101** |
| 1 | [Step 1 – Authenticate and Understand Session Management](#step-1--authenticate-and-understand-session-management) |
| 2 | [Step 2 – Discover the Management Console](#step-2--discover-the-management-console) |
| 3 | [Step 3 – Explore Managed Systems](#step-3--explore-managed-systems) |
| 4 | [Step 4 – Discover Logical Partitions (LPARs)](#step-4--discover-logical-partitions-lpars) |
| 5 | [Step 5 – Explore Virtual Networking](#step-5--explore-virtual-networking) |
| 6 | [Step 6 – Explore Virtual Storage](#step-6--explore-virtual-storage) |
| 7 | [Step 7 – Query System Events and Logs](#step-7--query-system-events-and-logs) |
| 8 | [Step 8 – Resource Profiles and Configuration Management](#step-8--resource-profiles-and-configuration-management) |
| 9 | [Step 9 – Performance and Capacity Monitoring](#step-9--performance-and-capacity-monitoring) |
| **Part 2** | **Troubleshooting & Advanced Operations** |
| T1 | [Troubleshooting Scenario 1 – LPAR Won't Start](#troubleshooting-scenario-1--lpar-wont-start) |
| A1 | [Advanced Operation – Dynamic Resource Allocation (DLPAR)](#advanced-operation--dynamic-resource-allocation-dlpar) |
| — | [Troubleshooting Quick Reference](#troubleshooting-quick-reference) |
| — | [Using IBM Bob Effectively](#using-ibm-bob-effectively) |
| — | [Additional Resources](#additional-resources) |

---

## Lab Environment

```
HMC Host:     https://<your-hmc-host>
HMC User:     <your-username>  (must have "Allow remote access via the web" privilege)
HMC Password: <your-password>
```

**Reference Documentation**
- [HMC REST API Reference](https://public.dhe.ibm.com/systems/power/docs/hw/p8/p8ehl.pdf)
- [IBM Power Systems Documentation](https://www.ibm.com/docs/en/power9)
- [Enabling API Access on HMC](https://www.ibm.com/docs/en/systems-hardware/linuxone/3906-LM1?topic=i-enabling-accessing-api)

---

## Learning Objectives

By the end of this workshop you will be able to:

1. Authenticate to the HMC and manage sessions via the REST API
2. Navigate the resource hierarchy: HMC → Managed System → LPAR / VIOS
3. Perform basic power operations and monitor jobs
4. Explore virtual networking and storage configurations
5. Troubleshoot LPAR startup, network, and storage failures
6. Perform live migration (LPM) and dynamic resource allocation (DLPAR)
7. Automate HMC operations with scripts and orchestration tools

---

## Golden Troubleshooting Rule

```
1. Check LPAR/VIOS state   → What is failing?
2. Query recent events     → What happened?
3. Check job status        → Did operations complete?
4. Review resource alloc   → Are resources sufficient?
5. Verify adapter mappings → Is connectivity correct?
```

---

## REST API Quick Reference

| Operation | Endpoint | Method |
|-----------|----------|--------|
| Authenticate | `/rest/api/uom/LogOn` | PUT |
| List Managed Systems | `/rest/api/uom/ManagedSystem` | GET |
| List LPARs | `/rest/api/uom/LogicalPartition` | GET |
| List VIOSs | `/rest/api/uom/VirtualIOServer` | GET |
| Power On LPAR | `/rest/api/uom/LogicalPartition/<uuid>/do/PowerOn` | POST |
| Power Off LPAR | `/rest/api/uom/LogicalPartition/<uuid>/do/PowerOff` | POST |
| Get Events | `/rest/api/uom/Event` | GET |
| Get PCM Metrics | `/rest/api/pcm/ManagedSystem/<uuid>/ProcessedMetrics` | GET |
| Monitor Job | `/rest/api/uom/jobs/<job-id>` | GET |

---

## Part 1 — HMC Operations 101

### Step 1 – Authenticate and Understand Session Management

Authentication is the entry point for every HMC operation. The HMC uses `X-API-Session` tokens — credentials are sent once, and the token is used for all subsequent calls.

**Prompt:**
```
Connect to the HMC at https://<your-hmc-host> using your credentials.

Explain:
- How HMC authentication works (PUT /rest/api/uom/LogOn)
- What is the X-API-Session token and how long is it valid?
- How to verify the connection is successful
- What information does the logon response provide?
```

**What to observe:**
- HTTP 200 OK with `X-API-Session` token in response headers
- User permissions and role (RBAC) in the logon response
- HMC version and management console details

**Checkpoint:** ✅ Authenticated · ✅ Token obtained · ✅ Session details displayed

---

### Step 2 – Discover the Management Console

The Management Console object represents the HMC itself. Querying it reveals the connected managed systems and available capabilities.

**Prompt:**
```
Query the Management Console (GET /rest/api/uom/ManagementConsole):
- What version of HMC is running?
- What managed systems are connected?
- What capabilities does this HMC support?
```

**What to observe:** HMC version (e.g., `V9R2M950`), list of managed systems, feature flags.

**Checkpoint:** ✅ HMC version identified · ✅ Managed systems listed · ✅ Capabilities understood

---

### Step 3 – Explore Managed Systems

Managed Systems are the physical IBM Power servers. All LPARs and resources live within them.

**Prompt:**
```
Discover all managed systems (GET /rest/api/uom/ManagedSystem).
For each system show: name, model, state, firmware level, total CPU/memory, and partition count.
Explain the resource hierarchy: HMC → Managed System → LPAR / VIOS.
```

**What to observe:**
- System state (`operating`, `standby`, `power off`)
- Firmware currency and resource utilization vs. capacity

**Checkpoint:** ✅ All managed systems listed · ✅ Resource inventory complete · ✅ Hierarchy understood

---

### Step 4 – Discover Logical Partitions (LPARs)

LPARs are virtual machines on IBM Power. Each has its own OS, resource allocation, and virtual adapters.

**Prompt:**
```
List all LPARs (GET /rest/api/uom/LogicalPartition).
For each, show: name, state, OS type, CPU allocation (dedicated vs. shared), memory (min/desired/max), and virtual adapters.
Explain LPAR state transitions.
```

**What to observe:**
- States: `running`, `not activated`, `shutting down`, `error`
- Dedicated vs. shared processor allocation patterns

**Checkpoint:** ✅ All LPARs discovered · ✅ States and resource allocations understood

---

### Step 5 – Explore Virtual Networking

Virtual networking connects LPARs through VIOS to external networks via Shared Ethernet Adapters (SEA).

**Prompt:**
```
Analyze virtual networking:
1. List virtual switches (GET /rest/api/uom/VirtualSwitch)
2. List virtual networks (GET /rest/api/uom/VirtualNetwork)
3. Trace the path: LPAR → Virtual NIC → Virtual Switch → VIOS → SEA → Physical Adapter
4. Show VLAN assignments and SEA failover configuration
```

**Network path:**
```
LPAR (Client NIC) → Virtual Switch → VIOS → SEA → Physical Adapter → External Switch
```

**Checkpoint:** ✅ Virtual switches and VLANs mapped · ✅ Network path traced to physical

---

### Step 6 – Explore Virtual Storage

Virtual storage connects LPARs to physical disks through VIOS via vSCSI or NPIV.

**Prompt:**
```
Analyze virtual storage:
1. List physical volumes (GET /rest/api/uom/PhysicalVolume)
2. Show virtual SCSI mappings (GET /rest/api/uom/VirtualSCSIMapping)
3. Trace the path: LPAR → Virtual SCSI Adapter → VIOS → Physical Volume
4. Show volume groups and storage pools
```

**Storage path:**
```
LPAR → Virtual SCSI Client Adapter → VIOS → Virtual SCSI Server Adapter → Physical Volume
```

**Checkpoint:** ✅ Physical volumes inventoried · ✅ SCSI mappings traced · ✅ Storage pools identified

---

### Step 7 – Query System Events and Logs

Events are your observability layer — they capture state changes, errors, and warnings across all managed resources.

**Prompt:**
```
Query HMC events (GET /rest/api/uom/Event):
- Filter by severity (error, warning) and last 24 hours
- Filter by resource type (LPAR, VIOS, managed system)
- Explain event categories and retention policy
```

**What to observe:** Error and warning events, patterns indicating systemic issues, event timestamps vs. operational changes.

**Checkpoint:** ✅ Events queried and filtered · ✅ Event interpretation understood

---

### Step 8 – Resource Profiles and Configuration Management

LPAR profiles capture the full configuration of a partition (CPU, memory, adapters, boot settings). They enable repeatable deployments and disaster recovery.

**Prompt:**
```
Explore LPAR profiles (GET /rest/api/uom/LogicalPartitionProfile):
- List all profiles for an LPAR (default, current, saved)
- Compare profiles to understand configuration differences
- Explain when profiles are applied and whether restart is required
```

**Checkpoint:** ✅ Profiles listed · ✅ Current vs. default profile understood · ✅ Profile lifecycle clear

---

### Step 9 – Performance and Capacity Monitoring

The HMC Performance and Capacity Monitoring (PCM) API provides CPU, memory, and I/O utilization data for proactive capacity management.

**Prompt:**
```
Explore performance monitoring:
1. Check if PCM is enabled (GET /rest/api/pcm/ManagedSystem/<uuid>/ProcessedMetrics)
2. Query CPU and memory utilization for managed systems and LPARs
3. Query VIOS I/O throughput
4. Explain entitled vs. consumed CPU and when to be concerned
```

**What to observe:** Utilization percentages, resource contention indicators, trends over time.

**Checkpoint:** ✅ PCM metrics retrieved · ✅ Utilization data interpreted · ✅ Capacity planning considerations understood

---

### Architecture Reference

```
┌──────────────────────────────────────────────────────┐
│           Hardware Management Console (HMC)          │
│  Auth: X-API-Session  ·  REST: /rest/api/uom/*       │
│                                                      │
│  ┌───────────────────────────────────────────────┐  │
│  │         Managed System (Physical Server)      │  │
│  │                                               │  │
│  │  ┌──────────┐  ┌──────────┐  ┌─────────────┐ │  │
│  │  │  LPAR 1  │  │  LPAR 2  │  │   LPAR 3    │ │  │
│  │  │ AIX/Linux│  │ AIX/Linux│  │   IBM i     │ │  │
│  │  └────┬─────┘  └────┬─────┘  └──────┬──────┘ │  │
│  │       └─────────────┼────────────────┘        │  │
│  │                     │                         │  │
│  │  ┌──────────────────▼──────────────────────┐  │  │
│  │  │        Virtual I/O Server (VIOS)        │  │  │
│  │  │  • Virtual Switches · SEA               │  │  │
│  │  │  • Virtual SCSI · NPIV · Physical I/O   │  │  │
│  │  └─────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────┘
```

---

## Part 2 — Troubleshooting & Advanced Operations

### Troubleshooting Scenario 1 – LPAR Won't Start

**Prompt:**
```
An LPAR won't start. Walk me through a systematic diagnosis:
1. Check LPAR state and error flags
2. Review recent events filtered to this LPAR
3. Check for failed PowerOn jobs and their error messages
4. Verify available CPU and memory on the managed system
5. Validate the LPAR profile
6. Identify the root cause and recommend a fix
```

**Diagnostic steps Bob should follow:**
- `GET /rest/api/uom/LogicalPartition/<uuid>` — state, error flags
- `GET /rest/api/uom/Event?filter=<lpar>` — errors in the last 1–2 hours
- `GET /rest/api/uom/jobs` — failed PowerOn jobs and return codes
- `GET /rest/api/uom/LogicalPartitionProfile` — profile validation

**Common root causes:**

| Symptom | Root Cause | Solution |
|---------|------------|----------|
| State: `error` | Previous operation failed | Clear error state, retry |
| "Insufficient memory/processors" | No free capacity | Reduce LPAR resources or free up system capacity |
| "Profile validation failed" | Invalid profile | Fix profile or switch to a known-good profile |
| "Virtual adapter error" | VIOS down or misconfigured | Check VIOS state, verify adapter mappings |

**Checkpoint:** ✅ State identified · ✅ Events reviewed · ✅ Root cause found · ✅ Fix applied

---

### Advanced Operation – Dynamic Resource Allocation (DLPAR)

DLPAR adds or removes CPU, memory, and virtual adapters from a running LPAR without restart.

**Prompt:**
```
Show me how to dynamically adjust LPAR resources:
1. Check current allocation and available system capacity
2. Add CPU capacity (virtual processors / entitled capacity)
3. Add memory (must be within min/max range)
4. Add a virtual network adapter
5. Verify the OS recognizes the new resources
```

**DLPAR capabilities:**

| Resource | Hot-Add | Hot-Remove | Notes |
|----------|---------|------------|-------|
| Virtual Processors | ✅ | ✅ | OS support required |
| Processor Entitlement | ✅ | ✅ | Within min/max range |
| Memory | ✅ | ✅ | OS support required |
| Virtual Network Adapter | ✅ | ✅ | Available slots needed |
| Virtual SCSI Adapter | ✅ | ✅ | Available slots needed |
| Physical I/O Adapter | ❌ | ❌ | Requires LPAR restart |

**Checkpoint:** ✅ Resources added · ✅ OS recognizes changes · ✅ Functionality verified

---

## Troubleshooting Quick Reference

| Symptom | Diagnostic Steps | Common Causes |
|---------|-----------------|---------------|
| LPAR won't start | State → Events → Jobs → Resources | Insufficient resources, profile error, VIOS down |
| DLPAR fails | OS support → Free resources → Min/max limits | OS unsupported, no capacity, limits violated |
| High CPU | PCM metrics → LPAR allocations → Workload | Undersized LPAR, workload spike, resource contention |

---

## Using IBM Bob Effectively

**Prompt tips:**
- Include LPAR name, UUID, and managed system — specificity gets better results
- Share exact error text from events or job details
- Include a timeline: when it last worked, what changed recently
- Ask for step-by-step diagnostics, not just answers

**Example of a good diagnostic prompt:**
```
LPAR "prod-db-01" (UUID: 12345-abcde) won't start on system "sys-01".
Last successful start: yesterday 14:00.
Recent change: DLPAR memory increase from 8GB to 10GB at 09:00 today.
Event log shows "Profile validation failed" at 10:15.
Verified: managed system has free memory, VIOS is running.

Please:
1. Explain why profile validation is failing
2. Identify what the DLPAR change may have broken
3. Fix the issue and get the LPAR started
4. Recommend how to prevent this
```

---

## Additional Resources

- [HMC REST API Reference](https://public.dhe.ibm.com/systems/power/docs/hw/p8/p8ehl.pdf)

---

🎉 **Congratulations!** You've completed the HMC Operations workshop. Understanding *why* systems behave the way they do is more valuable than memorizing *how* to fix specific issues — the HMC REST API gives you full visibility to investigate deeply.
