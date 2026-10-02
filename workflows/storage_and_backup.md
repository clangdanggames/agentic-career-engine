# 💾 Storage & Backup Standard Operating Procedure (SOP)

This document provides deterministic instructions for the AI Career Architect to detect, configure, operate, and safeguard candidate workspace data across different storage paradigms: **Cloud Drive Sync**, **Private Git & GitHub**, and **Local Directory with Snapshots**.

---

## 🎯 Core Operating Invariant: Zero Heavy Prerequisites

The core Agentic Career Engine operates entirely on native PowerShell and Chromium-based headless browsers (Microsoft Edge on Windows, Google Chrome on macOS/Linux). 

- **Git is completely optional**.
- **Python is completely optional**.
- **Node.js/npm is completely optional**.

The assistant **MUST NEVER** require or pressure a candidate to install Git, Python, or external developer toolchains to use ACE.

---

## 🔍 Stage 1: Silent Storage Detection Matrix

During **Stage 1 (Environment Verification)**, the assistant must silently inspect the workspace environment before greeting the candidate:

### 1. Git Detection
- Check if Git CLI is available: `Get-Command git -ErrorAction SilentlyContinue`
- Check if workspace is an initialized Git repository: `Test-Path "$workspaceRoot\.git"`
- If Git is initialized, inspect remote URLs: `git remote -v`

### 2. Cloud Drive Sync Detection
Check if the workspace directory path resides within a known cloud sync root:
- **Microsoft OneDrive**: Check if `$workspaceRoot` contains `OneDrive` or matches `$env:OneDrive`, `$env:OneDriveConsumer`, or `$env:OneDriveCommercial`.
- **Google Drive**: Check if `$workspaceRoot` contains `Google Drive` or `My Drive`.
- **Dropbox**: Check if `$workspaceRoot` contains `Dropbox`.
- **iCloud Drive**: Check if `$workspaceRoot` contains `iCloudDrive` or `iCloud`.
- **Nextcloud / Other**: Check for active synchronization client roots.

### 3. Fallback Classification
If neither an active Git repository nor a cloud sync root is detected, classify the workspace as **Local Directory (Offline)**.

---

## 💬 Stage 3: Low-Friction Storage Checkpoint (Part B — Turn 2 Action)

In accordance with **Rule 9 (Sequential Conversational Pacing)**, this checkpoint is presented exclusively on **Turn 2**, immediately after the candidate responds to Stage 3 Part A (Harness Permissions). It must never be bundled into Turn 1.

The assistant presents a simple, binary confirmation checkpoint based on the detected storage:

### The Checkpoint Question:
> *"I detected **[Detected Storage]** as your current workspace storage. Would you like to use this for backup?"*

### Response Handling:
1. **If Candidate Confirms (Yes / Proceeds)**:
   - Immediately lock in the detected storage mode with zero additional prompts or setup.
   - Proceed directly to the next onboarding step.

2. **If Candidate Declines (No / Wants to Configure Differently)**:
   - Present the 3 storage paradigms:
     1. **Private Git & GitHub**: Developer-grade version control with commit milestones, branching, and GitHub backup.
     2. **Cloud Drive Sync**: Automatic background versioning and sync via Microsoft OneDrive, Google Drive, Dropbox, or iCloud.
     3. **Local Snapshots**: Keep files strictly local on this machine, using 1-click zip snapshots via `scripts/backup_workspace.ps1`.
   - **Recommendation Hierarchy**:
     - *Priority 1*: Recommend **Git & Private GitHub** if `git` is installed on the system.
     - *Priority 2*: Recommend **Cloud Drive Sync** if an installed cloud drive (e.g. OneDrive) is present on the machine.
     - *Priority 3*: Recommend **Local Snapshots** via `scripts/backup_workspace.ps1`, or offer to cancel configuring backup.

---

## ⚙️ Operating Directives by Storage Paradigm

### Paradigm 1: Cloud Drive Sync (OneDrive, Google Drive, Dropbox, iCloud)
- **Automatic Background Backup**: The candidate's cloud sync client handles all synchronization, file history, and trash restoration natively.
- **Strict Command Lock**: The assistant **MUST NOT** execute `git` commands (`git status`, `git add`, `git commit`, `git push`) or warn about missing Git repositories.
- **Rule 7 Invariant**: Rule 7 (Push Lock) is satisfied by default because no remote git pushes are attempted.

### Paradigm 2: Private Git & GitHub Repository
- **Rule 7 Enforcement**: All commits and pushes must push strictly to `origin main` (the candidate's private repository). Pushing candidate data to `upstream` (public ACE template) is strictly forbidden.
- **Integrity Audit**: Verify that `.gitignore` is active and unedited to prevent personal dossiers, master resumes, and contact exports from being tracked publicly.

### Paradigm 3: Local-Only Directory (Native Snapshots)
- **Zero Remote Dependencies**: Works completely offline.
- **Autonomous Local Snapshots**: Use `scripts/backup_workspace.ps1` to create timestamped `.zip` archives of the candidate's career state (`resumes/`, `applications/`, `stories/`, `network/`, `companies/`, `workflows/ats_search_config.json`, `DASHBOARD.md`) in `.backups/`.
- **Trigger Points for Local Snapshots**:
  - Prior to running `scripts/update_engine.ps1` (engine upgrades).
  - Prior to running `scripts/migrate_workspace.ps1` (importing old workspace data).
  - Whenever the candidate explicitly asks to "back up", "save a snapshot", or "checkpoint my workspace".

---

## 🛠️ Snapshot & Recovery Reference Commands

### Create Candidate State Snapshot (Default):
```powershell
powershell -ExecutionPolicy Bypass -File scripts/backup_workspace.ps1
```

### Create Full Workspace Snapshot:
```powershell
powershell -ExecutionPolicy Bypass -File scripts/backup_workspace.ps1 -Full
```

### Save Snapshot to Custom Location (e.g. External Drive or Cloud Folder):
```powershell
powershell -ExecutionPolicy Bypass -File scripts/backup_workspace.ps1 -Destination "D:\Backups\JobSearch\"
```

### List Existing Snapshots:
```powershell
powershell -ExecutionPolicy Bypass -File scripts/backup_workspace.ps1 -List
```
