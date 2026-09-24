# 🚀 Quickstart Guide

Pair your job search with an autonomous AI coding assistant to automate ATS discovery, tailor single-page applications, map your network, and manage your pipeline.

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

Your assistant will verify your environment, guide you through an onboarding intake, draft or format your master resume, and activate your personal career command center in **`DASHBOARD.md`** (while keeping `README.md` pristine as permanent project documentation).

---

## 📁 The Application Dossier Standard

Whenever you find an opportunity to pursue, your AI assistant isolates that application into a dedicated dossier folder:

```text
applications/YYYY-MM-DD_[company]/
├── job_description.md              # Requisition text, requirements, level, and compensation
├── [Your_Name]_Resume_[Company].md # Tailored resume source
├── [Your_Name]_Resume_[Company].pdf# Headless Chromium compiled 1-page PDF
├── outreach_and_timeline.md        # Warm referral logs, email copies, and milestone funnel
└── interview_prep.md               # 90-second screen pitch, metric cheat-sheet, & STAR pairings
```

### Why Dossiers Matter:
- **Zero Confusion**: You always know exactly which resume variation and bullet points were submitted.
- **Persistent Context**: Outreach history, recruiter notes, and interview prep are coupled directly to the JD.
- **Automatic Privacy**: The repository's `.gitignore` automatically excludes `applications/20*` folders, keeping your active applications completely private.

---

## 🧠 Full-Cycle Career Partner Workflows

ACE operates as an end-to-end career chief of staff across every phase of your job search:

| Search Phase | Objective | Example Conversational Prompt |
| :--- | :--- | :--- |
| **Sourcing** | Discover ATS leads | *"Scan ATS boards for new senior roles matching my compensation floor and fit rubric."* |
| **Tailoring** | Create application dossier | *"Tailor my resume for this requisition: [paste link or text]. Create an application dossier and ensure the PDF is strictly 1 page."* |
| **Networking** | Uncover warm referral paths | *"I placed my LinkedIn Connections.csv in `network/`. Parse my connections and highlight who works at target employers."* |
| **Outreach** | Draft low-friction messages | *"Draft a concise, warm message to [Contact Name] at [Company] asking for an internal referral for requisition #[ID]."* |
| **Interviewing** | Extract & refine STAR stories | *"Interview me to extract a high-stakes STAR story about turning around an off-track project, and save it to `stories/star_story_bank.md`."* |
| **Screen Prep** | Build recruiter cheatsheet | *"Generate my 90-second elevator pitch and high-impact metric cheatsheet for my upcoming screen at [Company]. Save it to the dossier's `interview_prep.md`."* |
| **Due Diligence** | Questions for interviewers | *"What 5 strategic, senior-level questions should I ask the VP of Engineering during my panel interview?"* |
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
