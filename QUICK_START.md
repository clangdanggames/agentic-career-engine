# 🚀 Quickstart Guide

Pair your job search with an autonomous AI assistant to automate ATS discovery, tailor applications, and manage your pipeline.

---

## 📋 3-Step Setup

### Step 1: Open Your AI Assistant
Open your preferred AI assistant. If you don't have one installed:
- **[Google Antigravity](https://antigravity.google)** (Desktop GUI application)
- **[Cursor](https://cursor.com)** (Desktop AI editor & assistant)

### Step 2: Open an Empty Folder
1. Create a new folder on your computer (e.g., `Career` or `JobHunt`).
2. Open that folder in your AI assistant (**File $\rightarrow$ Open Folder**).

### Step 3: Run the Setup Prompt
Copy the prompt below, paste it into your assistant's chat panel, and press **Enter**:

```markdown
Clone https://github.com/clangdanggames/agentic-career-engine.git into this directory (or download and extract the repository zip from https://github.com/clangdanggames/agentic-career-engine/archive/refs/heads/main.zip if Git is not installed), then read and execute the instructions in GENESIS_PROMPT.md.
```

---

## 🎯 Running Your Career Operating System

Once initialized, interact with your workspace conversationally:

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
