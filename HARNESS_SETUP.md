# 🎛️ Agent Harness Setup & Security Guide

A practical guide to configuring your AI assistant's execution permissions for the **Agentic Career Engine (ACE)**. Achieve the **Goldilocks Zone**: *zero repetitive approval pop-ups while maintaining strict protection over your private career data.*

---

# Part 1: Candidate Overview (Non-Technical)

### Why Configure Your Agent's Permissions?
When you use an AI coding assistant (like Cursor, Claude Code, Google Antigravity, Windsurf, or VS Code with Cline/Roo), it operates with safety guardrails. By default, many tools ask you to click "Approve" for **every single terminal command** (such as compiling your resume PDF or checking a link) and **every single website visit**. 

During a job search, this causes **approval fatigue**—clicking dozens of confirmation dialogs every day disrupts your focus and slows down the 20-minute application routine.

Configuring your harness grants your assistant pre-approval for routine, safe tasks while keeping critical actions strictly gated behind manual confirmation.

---

### What Your Assistant Is Allowed To Do (In Plain English)
When configured according to this guide, your assistant can automatically:
1. 📄 **Compile 1-Page Resume PDFs**: Run background browser commands to turn your customized markdown resume into a pixel-perfect PDF and verify that it never spills onto an awkward second page.
2. 🛡️ **Audit Factual Integrity**: Check your tailored resume against your Master Resume whitelist to ensure zero AI hallucinations or embellishments before you apply.
3. ⚡ **Synchronize Your Pipeline**: Keep your job ledger (`ledger.json`) and Career Command Center (`DASHBOARD.md`) in lockstep parity whenever you confirm an application or interview.
4. 🔍 **Discover & Verify ATS Job Postings**: Search Greenhouse, Ashby, Lever, and Workday for open roles matching your compensation floor, and test links to ensure they take you directly to live job applications.
5. 🧹 **Clean Up Temporary Scratch Files**: Create and delete transient test scripts and temporary HTML files inside the designated `scratch/` folder without bothering you for permission.

---

### What Remains Strictly Locked & Protected (Safety Guarantees)
Even with auto-approvals active, your assistant is **never** permitted to:
- 🛑 **Push Code to Public Repositories**: Any `git push` command requires your explicit, manual approval, ensuring your personal resume, salary targets, and notes remain private (Rule 7).
- 🛑 **Delete Important Career Assets**: Your assistant cannot recursively delete core folders (`resumes/`, `applications/`, `stories/`, `network/`) or project root files.
- 🛑 **Touch Files Outside Your Project**: File access is confined strictly to your workspace folder (with read-only access to your installed Chrome or Edge browser binary to generate PDFs).

---

### Quick Setup Choices

| Approach | Effort | Description |
| :--- | :---: | :--- |
| **Option A: Auto-Configuration (Easiest)** | ~30 seconds | Copy and paste the [Self-Configuring Agent Prompt](#-the-self-configuring-agent-prompt) into your assistant chat. It will inspect your environment and set up or guide your permissions automatically. |
| **Option B: Step-by-Step Settings** | ~2 minutes | Follow the quick settings instructions for your specific tool in [Harness Profiles](#-harness-configuration-profiles). |
| **Option C: Skip for Now** | 0 seconds | You can skip configuration entirely. ACE functions 100% out of the box using default prompt-by-prompt approvals; you can configure permissions whenever you wish. |

---

# Part 2: Technical Specification & Configuration Matrix

*(For AI Agents, Engineers, and Power Users)*

This section defines the precise operational boundaries, command patterns, domain whitelists, and harness configuration files required by the Agentic Career Engine.

---

## 📋 Permissions Matrix

### 1. Terminal Command Whitelist

The following command patterns should be configured for automatic execution (auto-approval) without interactive prompts:

```text
# Resume PDF Rendering & Page Validation
powershell -File scripts/render_resume.ps1 *
pwsh -File scripts/render_resume.ps1 *
powershell -File scripts/check_pdf_pages.ps1 *
pwsh -File scripts/check_pdf_pages.ps1 *

# Factual Integrity & Whitelist Linter
powershell -File scripts/lint_resume_integrity.ps1 *
pwsh -File scripts/lint_resume_integrity.ps1 *

# State Parity & Pipeline Synchronization
powershell -File scripts/sync_pipeline.ps1 *
pwsh -File scripts/sync_pipeline.ps1 *

# ATS Job Scanner & Ingestion
powershell -File scripts/scan_ats_jobs.ps1 *
pwsh -File scripts/scan_ats_jobs.ps1 *

# LinkedIn Connection Parser & Workspace Tools
powershell -File scripts/parse_connections.ps1 *
pwsh -File scripts/parse_connections.ps1 *
powershell -File scripts/update_engine.ps1 *
pwsh -File scripts/update_engine.ps1 *

# Safe Local Git Inspection & Milestone Tracking
git status
git diff*
git log*
git add *
git commit *

# Lightweight HTTP Header Auditing
curl.exe *
curl *

# Scratch Execution & Parsing
python scratch/*
python -c *
```

### 2. Forbidden / Manually-Gated Commands

The following commands **MUST ALWAYS** require explicit interactive human approval and should **NEVER** be auto-approved:

```text
# Remote Pushing (Rule 7: Private Vault Push Lock)
git push*

# Destructive Deletion Outside Scratch
rm -rf *
Remove-Item -Recurse *
rmdir /s /q *

# Privilege Escalation & Global Package Installation
sudo *
npm install -g *
pip install --break-system-packages *
```

---

## 🗂️ File System Boundaries & Scratchpad Exemption Rule

1. **Workspace Boundary**:
   - The assistant has full Read and Write authority within the workspace root (`resumes/`, `applications/`, `stories/`, `network/`, `workflows/`, `scripts/`, `DASHBOARD.md`, `scratch/`).
   - The assistant has **Zero Write Authority** outside the workspace directory.
2. **Scratchpad Exemption Zone (`scratch/*`)**:
   - Transient files, temporary HTML preview renders, and scratch evaluation scripts are housed inside `scratch/` or `.backups/tmp_*`.
   - The assistant has **full autonomy to create, modify, and delete** files inside `scratch/` and files ending in `.tmp`. Deletion within this designated zone is safe and expected.
3. **Browser Binary Read Exemption**:
   - Read-only execution access is granted to locate installed Chromium browsers for headless PDF compiling:
     - Windows: `C:\Program Files\Google\Chrome\Application\chrome.exe`, `C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`
     - macOS: `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`, `/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge`
     - Linux: `/usr/bin/google-chrome`, `/usr/bin/chromium`, `/usr/bin/google-chrome-stable`

---

## 🌐 Allowed Web Domains Whitelist

The assistant should be permitted to make outbound HTTP GET/HEAD requests and fetch page content across the following domain patterns:

```text
# Primary Applicant Tracking Systems (ATS)
*.greenhouse.io
job-boards.greenhouse.io
boards.greenhouse.io
*.ashbyhq.com
jobs.ashbyhq.com
app.ashbyhq.com
*.lever.co
jobs.lever.co
*.myworkdayjobs.com
*.smartrecruiters.com
*.icims.com

# Compensation & Prevailing Wage Intelligence
*.levels.fyi
levels.fyi
h1bdata.info

# Technical Repositories & Engine Lifecycle
github.com
api.github.com
raw.githubusercontent.com
```

---

## 💻 Harness Configuration Profiles

### Profile 1: Cursor (`.cursor/settings.json`)
If you are using Cursor, create or update `.cursor/settings.json` in your project root:

```json
{
  "cursor.terminal.autoExecution": true,
  "cursor.terminal.allowedCommands": [
    "powershell -File scripts/*",
    "pwsh -File scripts/*",
    "git status",
    "git diff*",
    "git log*",
    "git add *",
    "git commit *",
    "curl.exe *",
    "curl *",
    "python scratch/*"
  ],
  "cursor.terminal.deniedCommands": [
    "git push*",
    "rm -rf *",
    "Remove-Item -Recurse *"
  ],
  "cursor.web.allowedDomains": [
    "*.greenhouse.io",
    "job-boards.greenhouse.io",
    "boards.greenhouse.io",
    "*.ashbyhq.com",
    "jobs.ashbyhq.com",
    "*.lever.co",
    "jobs.lever.co",
    "*.myworkdayjobs.com",
    "*.smartrecruiters.com",
    "*.icims.com",
    "*.levels.fyi",
    "h1bdata.info",
    "github.com",
    "api.github.com"
  ]
}
```

### Profile 2: Claude Code (`.claude/config.json` or `/permissions`)
For Claude Code CLI, add the pre-approved tools and commands to `.claude/config.json`:

```json
{
  "allowedTools": [
    "Bash(powershell -File scripts/*)",
    "Bash(pwsh -File scripts/*)",
    "Bash(git status)",
    "Bash(git diff*)",
    "Bash(git log*)",
    "Bash(git add *)",
    "Bash(git commit *)",
    "Bash(curl.exe *)",
    "Bash(curl *)",
    "Bash(python scratch/*)",
    "WebFetch"
  ]
}
```

### Profile 3: Google Antigravity
1. Navigate to **Settings $\rightarrow$ Capabilities & Tool Execution**.
2. Under **Command Execution**, set pre-approval pattern to `powershell -File scripts/*` and `pwsh -File scripts/*`.
3. Under **Allowed URL Domains**, add the ATS domains listed above.
4. Verify that **Interactive Confirmation** remains enabled for `git push`.

### Profile 4: VS Code Extension (Cline / Roo Code)
In VS Code Settings (`Ctrl+,` or `Cmd+,` $\rightarrow$ search `cline` or `roo`):
1. **Auto-Approve Terminal Commands**: Add `powershell -File scripts/*`, `pwsh -File scripts/*`, `git status`, `git diff`, `git add`, `git commit`.
2. **Auto-Approve Directory Cleanup**: Enable for `scratch/` only.
3. **Forbidden Commands**: Add `git push`.
4. **Auto-Approve Web Requests**: Enable.

---

## 🤖 The Self-Configuring Agent Prompt

Copy and paste this prompt into your assistant to have it detect your runtime and configure settings automatically:

```markdown
You are configuring your execution permissions for the Agentic Career Engine (ACE) in this workspace.

Please review the Technical Specification in HARNESS_SETUP.md:
1. Inspect your current runtime environment. Identify your specific agent harness (for example: Cursor, Claude Code, Antigravity, Windsurf, VS Code extension like Cline or Roo Code, or any other agentic environment). Do not assume you are in one of the example environments if your runtime indicates otherwise.
2. Determine how your harness manages tool approvals (e.g. workspace settings file, global config, or manual UI toggles).
3. If your harness supports workspace-level configuration files (such as `.cursor/settings.json` or `.claude/config.json`), offer to generate the configuration file directly using the exact allowed commands and domains from HARNESS_SETUP.md. If configuration requires manual UI toggles, provide step-by-step instructions specific to this environment.
4. Enforce the Scratchpad Exemption: Verify that transient file creation and cleanup inside `scratch/*` is permitted, while any deletion outside `scratch/` or any `git push` remains strictly locked behind manual human confirmation.
5. Present a clear, concise summary of the active or recommended permissions.
```
