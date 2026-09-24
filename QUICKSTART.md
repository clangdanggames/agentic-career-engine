# ⚡ Quickstart: The 3-Step Setup for Any Job Seeker

> **Welcome to the Agentic Career Engine (ACE)!**  
> You don't need to know how to code, use Git, or manage complex terminal commands. By pairing your job search with an autonomous AI coding assistant (like **Google Antigravity**, **Cursor**, **Windsurf**, or **Claude Code**), your AI agent installs the engine, tailors your applications, and tracks your pipeline automatically.  
> Works across **all industries and professions** (Technology, Healthcare, Finance, Operations, Marketing, Product, Management, Sales, and more).

---

## 🚀 The 3-Step Setup (Under 3 Minutes)

### Step 1: Open Your AI Assistant
If you don't already have one installed, download any modern AI coding assistant:
- [Google Antigravity](https://deepmind.google/technologies/antigravity/)
- [Cursor](https://cursor.com/)
- [Windsurf](https://codeium.com/windsurf)
- [Claude Code](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview)

### Step 2: Create an Empty Folder
1. Create a new empty folder anywhere on your computer (e.g., `Career` or `My_Job_Hunt`).
2. Open that empty folder in your AI assistant (**File $\rightarrow$ Open Folder**).

### Step 3: Paste the Bootstrap Setup Prompt
1. Open [`GENESIS_PROMPT.md`](file:///c:/Code/ACE/GENESIS_PROMPT.md) (or copy the prompt block below).
2. Open your AI agent's chat panel (press `Ctrl + L` or click the chat icon).
3. Paste the prompt and hit **Enter**.

---

## 📋 The One-Shot Bootstrap Prompt

Copy and paste this directly into your empty project chat:

```markdown
You are my Lead Career Architect and Autonomous Career Copilot. We are setting up my personalized career command center using the open-source Agentic Career Engine (ACE).

Please execute the following 5-stage setup and onboarding protocol in this workspace:

1. Check if the ACE codebase exists in this directory. If not, clone it via `git clone https://github.com/clangdanggames/agentic-career-engine.git .` (or if Git is not installed, download and extract the repository zip from https://github.com/clangdanggames/agentic-career-engine/archive/refs/heads/main.zip directly).
2. Verify environment prerequisites (PowerShell / Bash and Headless Edge/Chrome for PDF printing).
3. Verify workspace integrity (ensure active directories resumes/, applications/, network/, and stories/ are clean).
4. Conduct an interactive candidate intake interview to capture my name, target industry & roles, location preferences, compensation floor/target, and core competencies.
5. Ingest my current resume into resumes/[My_Name]_Resume_Master.md, compile an exact 1-page PDF using scripts/render_resume.ps1, validate it with scripts/check_pdf_pages.ps1, configure workflows/ats_search_config.json, and generate my active README.md command center dashboard!

Begin by greeting me and walking through the intake interview!
```

---

## 🎯 How to Run Your Career Operating System

Once initialized, you never have to manually edit JSON files, configure search strings, or wrestle with document formatting. Simply chat with your AI agent naturally:

| Goal | What to Tell Your AI Agent |
| :--- | :--- |
| **Discover Open Roles** | *"Scan ATS boards for new senior roles matching my compensation target and fit rubric."* |
| **Tailor for a Specific Opening** | *"Tailor my resume for this requisition: [paste link or text]. Keep it strictly to 1 page and create an application dossier."* |
| **Activate Your Network** | *"I placed my LinkedIn Connections.csv in `network/`. Parse my connections and highlight who works at target companies."* |
| **Draft Warm Referral Outreach** | *"Draft a concise, warm message to [Contact Name] at [Company] asking for an internal referral."* |
| **Estimate Unlisted Salary** | *"Estimate the total compensation for this unlisted job posting using our 4-factor heuristic."* |
| **Prepare for Interviews** | *"Interview me on a STAR story about leading a major project and save it to my story bank."* |

---

## ❓ Frequently Asked Questions

<details>
<summary><b>Do I need Git installed?</b></summary>
No! The AI agent checks whether Git is installed on your machine. If Git is present, it clones the repo. If Git is missing, it automatically downloads and unpacks the repository archive using built-in system tools (PowerShell or curl/unzip).
</details>

<details>
<summary><b>Is ACE only for software engineers?</b></summary>
Not at all. ACE is built for job seekers in <b>any profession</b>—including healthcare, finance, operations, product management, marketing, sales, executive leadership, and technology. The scoring rubric and ATS scanner calibrate to your specific functional skills, certifications, and industry benchmarks.
</details>

<details>
<summary><b>Is my resume and private information kept private?</b></summary>
Yes, 100%. Everything runs locally on your computer. The built-in <code>.gitignore</code> file ensures that personal resumes, compiled PDFs, and LinkedIn connection files are never pushed to public repositories.
</details>

<details>
<summary><b>Why do you enforce a strict 1-page PDF rule?</b></summary>
Recruiters and hiring managers spend an average of 6 seconds reviewing an initial resume. Spilling a few stray lines onto a second page looks sloppy. ACE's Headless Chromium compiler and deterministic stream validator guarantee that your resume is dense, readable, and strictly <b>1 page</b>.
</details>
