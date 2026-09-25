# 🔄 Engine Lifecycle, Updates & Workspace Migration Guide

> **Core Guarantee**: ACE enforces a strict architectural boundary between **Engine Code** (`scripts/`, `.agents/`, `workflows/`) and **Personal User State** (`resumes/`, `applications/`, `stories/`, `network/`, `DASHBOARD.md`).
>
> You can update the engine or migrate your entire career history across machines or releases with **zero data loss** and **zero Git merge conflicts**.

---

## 🧭 The Two Upgrade Paths

Depending on the scale of the upgrade, ACE provides two automated mechanisms:

| Operation | Best Used For | Tool | Mental Model |
| :--- | :--- | :--- | :--- |
| **In-Place Update** | Bug fixes, new ATS scrapers, updated PDF compiler, minor prompt tweaks. | [`scripts/update_engine.ps1`](../scripts/update_engine.ps1) | *"Update the engine in my current folder."* |
| **Fresh Workspace Migration** | Major releases (e.g. v2.0), moving to a new machine, or starting clean. | [`scripts/migrate_workspace.ps1`](../scripts/migrate_workspace.ps1) | *"Clone a new ACE and import all my data."* |

---

## 🛠️ Path 1: In-Place Engine Updates

When you just want the latest scripts, skills, or prompt enhancements without creating a new folder:

### 🤖 Via AI Assistant (Recommended)
Simply message your assistant:
> *"Update my ACE engine to the latest release."*

The assistant executes [`scripts/update_engine.ps1`](../scripts/update_engine.ps1) in the background and reports back what changed.

### 💻 Manual PowerShell Command
```powershell
# Standard In-Place Update (Creates automatic backup snapshot in .backups/)
powershell -ExecutionPolicy Bypass -File scripts/update_engine.ps1

# Dry-run test (simulates update without touching files)
powershell -ExecutionPolicy Bypass -File scripts/update_engine.ps1 -DryRun
```

### 🔒 Safety Guarantees During In-Place Updates:
1. **Automatic Backup Snapshot**: Before any files are updated, your current configuration and scripts are saved to `.backups/backup_YYYY-MM-DD_HHmmss/`.
2. **Untouchable User State**: Resumes, active application dossiers (`applications/YYYY-MM-DD_*`), `stories/`, `network/`, `ledger.json`, `sourcing_inbox.*`, and `DASHBOARD.md` are **strictly ignored and never overwritten**.
3. **Smart Config Merging**: If upstream adds new ATS search fields, they are added with defaults into `workflows/ats_search_config.json` without altering your target compensation, titles, or locations.

---

## 📦 Path 2: Fresh Workspace Migration

When upgrading to a major new version or migrating from an older career repository (e.g. `Job Hunt`):

### Step-by-Step Procedure:
1. **Clone the new ACE release into your target directory**:
   ```powershell
   git clone https://github.com/clangdanggames/agentic-career-engine.git C:\Code\Career-HQ
   cd C:\Code\Career-HQ
   ```
2. **Open the workspace in your AI Assistant** (Google Antigravity, Cursor, etc.).
3. **Tell your assistant to import your data**:
   > *"Migrate my career history and assets from `C:\Code\MyOldJobHunt` into this workspace."*

### 💻 Manual PowerShell Command
```powershell
# Run Dry-Run first to review what will be migrated:
powershell -ExecutionPolicy Bypass -File scripts/migrate_workspace.ps1 -SourcePath "C:\Code\MyOldJobHunt" -DryRun

# Execute Migration:
powershell -ExecutionPolicy Bypass -File scripts/migrate_workspace.ps1 -SourcePath "C:\Code\MyOldJobHunt"
```

### 📋 What Gets Migrated Automatically:
* **`resumes/`**: Master resumes, modular reserve bank (`modular_reserve_bank.md`), and role variants.
* **`stories/`**: All STAR+R story banks, cheat sheets, and narrative guides.
* **`network/`**: `contacts_ledger.md`, `Connections.csv`, and outreach templates.
* **`companies/`**: `target_tier_list.md` and research files.
* **`applications/`**:
  * Every submitted application folder (`YYYY-MM-DD_[company]_[reqid]`).
  * Seamless merge of `applications/ledger.json` (preserves candidate info, compensation floor, and all tracked application records).
  * `sourcing_inbox.json` and `sourcing_inbox.md`.
* **Dashboard**: Automatically migrates `DASHBOARD.md` (or detects legacy `career_dashboard.md` / dashboard `README.md` and ports it cleanly).
* **Integrity Validation**: Runs [`scripts/lint_resume_integrity.ps1`](../scripts/lint_resume_integrity.ps1) immediately post-migration to confirm all master resume bullets verify cleanly.
