# 🚀 Quickstart Guide

Pair your job search with an autonomous AI coding assistant to automate ATS discovery, tailor single-page applications, map your network, and manage your pipeline.

---

## 📋 3-Step Setup

### Step 1: Launch an AI Assistant
If you don't already have an AI desktop assistant installed, download and install one of the following:
- **[Google Antigravity](https://antigravity.google/product/antigravity-2)** (Free desktop application with autonomous agent workflows)
- **[Claude Desktop](https://claude.ai/download)** (Approachable desktop workspace with Cowork agent capabilities)
Launch the application to get started.  
*(Developers and power users can also run ACE inside Cursor, Windsurf, or Claude Code).*

### Step 2: Open an Empty Folder
1. Create a new folder on your computer (e.g., `Career` or `JobHunt`).
   - ☁️ **Cloud Sync Friendly**: You can place this folder directly inside **Microsoft OneDrive**, **Google Drive**, **Dropbox**, or **iCloud** for automatic background backups with zero setup!
   - 💻 **Offline & Local**: You can also use any regular local folder; ACE includes 1-click local snapshots (`scripts/backup_workspace.ps1`).
   - 🐙 **Git Friendly**: If you prefer developer version control, private Git repositories are fully supported.
2. Open that folder in your AI assistant (**File $\rightarrow$ Open Folder**).

### Step 3: Run the Setup Prompt
Copy the prompt below, paste it into your assistant's chat panel, and press **Enter**:

```markdown
Clone https://github.com/clangdanggames/agentic-career-engine.git into this directory (or download and extract the repository zip from https://github.com/clangdanggames/agentic-career-engine/archive/refs/heads/main.zip if Git is not installed), then read and execute the instructions in GENESIS_PROMPT.md.
```

Your assistant will verify your environment, guide you through an onboarding intake, draft or format your master resume, and activate your personal career command center in **`DASHBOARD.md`** (while keeping `README.md` pristine as permanent project documentation).

> [!NOTE]
> **Zero Heavy Prerequisites**: ACE requires no Python, Node.js, or Git installation. It runs completely out of the box using built-in PowerShell and Microsoft Edge or Google Chrome.

> [!TIP]
> **Reduce Approval Pop-Ups (Optional)**: By default, AI assistants may ask you to click "Approve" for routine background tasks (like compiling your 1-page PDF or checking job links). See [`HARNESS_SETUP.md`](HARNESS_SETUP.md) for a quick guide to pre-approving safe commands while keeping sensitive actions strictly locked.

---

## 📁 The Application Dossier Standard

Whenever you find an opportunity to pursue, your AI assistant isolates that application into a dedicated dossier folder:

```text
applications/YYYY-MM-DD_[company]_[reqid_or_role]/
├── job_description.md                     # Requisition text, requirements, level, and compensation
├── [Candidate]_Resume_[Company]_[ReqID].md # Tailored resume source
├── [Candidate]_Resume_[Company]_[ReqID].pdf# Headless Chromium compiled 1-page PDF
├── application_form_guide.md              # Pre-calculated answers for ATS portal submission fields
├── cover_letter.md                        # Standardized 1-page cover letter (if required)
├── outreach_and_timeline.md               # Warm referral logs, email copies, and milestone funnel
└── interview_prep.md                      # 90-second screen pitch, whiteboard prep, & STAR pairings
```

### Why Dossiers Matter:
- **Zero Collision & Confusion**: Uses `[reqid]` or slugified `[role]` (with `_2` incremental fallback) so multiple applications to the same company on the same day stay cleanly separated.
- **Frictionless Submission**: The pre-filled `application_form_guide.md` removes decision fatigue by pre-calculating answers for tricky portal questions.
- **Persistent Context**: Outreach history, recruiter notes, and interview prep are coupled directly to the JD.
- **Automatic Privacy**: The repository's `.gitignore` automatically excludes `applications/20*` folders, keeping your active applications completely private.

---

## 🧠 Full-Cycle Career Partner Workflows

ACE operates as an end-to-end career chief of staff across every phase of your job search:

| Search Phase | Objective | Example Conversational Prompt |
| :--- | :--- | :--- |
| **Sourcing** | Discover ATS leads | *"Scan ATS boards for new senior roles matching my compensation floor and fit rubric."* |
| **Direct X-Ray** | 1-Click Boolean searches | *"Show me direct Boolean search strings for finding uncrowded Director of Operations roles on Greenhouse and Ashby."* |
| **Tailoring** | 20-min micro-stepped dossier | *"Tailor my resume for this requisition: [paste link or text]. Run the integrity linter, ensure strict 1-page PDF, and pre-fill an application form guide."* |
| **Whitelisting** | Verify factual integrity | *"Run `scripts/lint_resume_integrity.ps1` against my tailored resume to verify zero hallucinated skills."* |
| **Reserve Bank** | Swap specialized bullets | *"Check `resumes/modular_reserve_bank.md` and swap in our verified distributed systems bullets for this role."* |
| **Networking** | Uncover warm referral paths | *"I placed my LinkedIn Connections.csv in `network/`. Parse my connections and highlight who works at target employers."* |
| **Outreach** | Draft low-friction messages | *"Draft a concise, warm message to [Contact Name] at [Company] asking for an internal referral for requisition #[ID]."* |
| **Gap Framing** | Address career pauses | *"Help me refine my narrative in `stories/career_gap_framing.md` for explaining my recent sabbatical with confidence."* |
| **Interviewing** | Extract & refine STAR stories | *"Interview me to extract a high-stakes STAR story about turning around an off-track project, and save it to `stories/star_story_bank.md`."* |
| **Screen Prep** | Phone screen cheatsheet | *"Prepare my 90-second elevator pitch, metric cheatsheet, and reverse questions in the dossier's `interview_prep.md`."* |
| **Negotiation** | Evaluate & counter an offer | *"I received an offer of $165k base + $30k equity at [Company]. Benchmark this against our 4-factor compensation model and draft a polite, data-backed counter-proposal."* |

---

## ❓ Frequently Asked Questions

<details>
<summary><b>Where does my personal pipeline live?</b></summary>
Your active search metrics, weekly action items, and application pipeline live in <code>DASHBOARD.md</code> at the root of your workspace. This file is dynamically generated during onboarding so that <code>README.md</code> remains intact as your permanent project reference manual.
</details>

<details>
<summary><b>Do I need an existing resume to get started?</b></summary>
No. Your agent can build a master resume from scratch through a guided intake interview, or you can defer resume creation entirely and jump straight into configuring searches and tracking applications.
</details>

<details>
<summary><b>Do I need LinkedIn connections exported right now?</b></summary>
No. Network cross-referencing is completely optional. You can enter key contacts manually into <code>network/contacts_ledger.md</code> at any time, or import your connection archive later.
</details>

<details>
<summary><b>Is my career data kept private?</b></summary>
Yes. All resumes, dossiers, and notes remain on your local machine. The repository's <code>.gitignore</code> automatically prevents your personal career documents, generated PDFs, and application dossiers from ever being committed to public repositories.
</details>

<details>
<summary><b>Why enforce a strict 1-page PDF layout?</b></summary>
Recruiters and hiring managers scan resumes in seconds. Awkward page spills dilute impact. ACE's headless compiler and stream validator ensure your resume is dense, scannable, and strictly <b>1 page</b>.
</details>
