# ⚡ Quickstart Guide

> Pair your job search with an autonomous AI assistant (such as **Google Antigravity**, **Cursor**, **Windsurf**, or **Claude Code**) to automate ATS discovery, tailor applications, and manage your pipeline.

---

## 🚀 3-Step Setup

### Step 1: Open Your AI Assistant
Open your preferred AI assistant. If you don't have one installed:
- [Google Antigravity](https://deepmind.google/technologies/antigravity/)
- [Cursor](https://cursor.com/)
- [Windsurf](https://codeium.com/windsurf)
- [Claude Code](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview)

### Step 2: Open an Empty Folder
1. Create a new folder on your computer (e.g., `Career` or `JobHunt`).
2. Open that folder in your AI assistant (**File $\rightarrow$ Open Folder**).

### Step 3: Run the Genesis Prompt
1. Copy the prompt block below.
2. Open your assistant's chat panel (press `Ctrl + L` or click the chat icon).
3. Paste the prompt and press **Enter**.

---

## 📋 The Setup Prompt

```markdown
You are my Lead Career Architect and Autonomous Career Copilot. We are initializing my personalized career command center using the Agentic Career Engine (ACE).

Please guide me through the following setup and onboarding protocol:

1. Check if the ACE codebase exists in this directory. If not, clone it via `git clone https://github.com/clangdanggames/agentic-career-engine.git .` (or if Git is not installed, download and extract the repository zip from https://github.com/clangdanggames/agentic-career-engine/archive/refs/heads/main.zip directly).
2. Verify environment prerequisites (PowerShell / Bash and Headless Edge/Chrome for PDF printing).
3. Verify workspace integrity (ensure active directories resumes/, applications/, network/, and stories/ are clean).
4. Conduct an interactive candidate intake interview to capture my contact details, target roles, location preferences, compensation floor/target, and search scope (Broad Market, Premier Employers, or Custom Wishlist). Note: LinkedIn connections import is optional and can be skipped.
5. Handle my master resume flexibly: refine an existing resume if provided, interview me to author a brand-new resume from scratch, or create a placeholder draft if I prefer to defer resume writing for later. If drafted, compile an exact 1-page PDF using scripts/render_resume.ps1 and validate it with scripts/check_pdf_pages.ps1.
6. Configure workflows/ats_search_config.json, initialize applications/ledger.json, and generate my active README.md command center dashboard!

Begin by greeting me and walking through the intake interview!
```

---

## 🎯 Running Your Career Operating System

Once initialized, you interact with your workspace conversationally:

| Objective | Example Prompt for Your AI Agent |
| :--- | :--- |
| **Discover Open Roles** | *"Scan ATS boards for new senior roles matching my compensation target and fit rubric."* |
| **Tailor for a Job Requisition** | *"Tailor my resume for this requisition: [paste link or text]. Keep it strictly to 1 page and create an application dossier."* |
| **Activate Your Network** | *"I placed my LinkedIn Connections.csv in `network/`. Parse my connections and highlight who works at target companies."* |
| **Draft Warm Referral Outreach** | *"Draft a concise, warm message to [Contact Name] at [Company] asking for an internal referral."* |
| **Estimate Unlisted Salary** | *"Estimate the total compensation for this unlisted job posting using our 4-factor heuristic."* |
| **Prepare for Interviews** | *"Interview me on a STAR story about leading a major initiative and save it to my story bank."* |

---

## ❓ Frequently Asked Questions

<details>
<summary><b>Do I need an existing resume to get started?</b></summary>
No. Your agent can build a master resume from scratch through a guided interview, or you can defer resume creation entirely and jump straight into configuring searches and tracking applications.
</details>

<details>
<summary><b>Do I need LinkedIn connections exported right now?</b></summary>
No. Network cross-referencing is completely optional. You can enter key contacts manually into <code>network/contacts_ledger.md</code> at any time, or import your connection archive later.
</details>

<details>
<summary><b>Is my data kept private?</b></summary>
Yes. All resumes, dossiers, and notes remain on your local machine. The repository's <code>.gitignore</code> prevents your personal career documents from ever being committed to public repositories.
</details>

<details>
<summary><b>Why enforce a strict 1-page PDF layout?</b></summary>
Recruiters and hiring managers scan resumes in seconds. Awkward page spills dilute impact. ACE's headless compiler and stream validator ensure your resume is dense, scannable, and strictly <b>1 page</b>.
</details>
