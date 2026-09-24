# 🚀 The ACE Universal Setup & Genesis Prompt

> **What is this?** This is the all-in-one bootstrap prompt that initializes your personal **Agentic Career Engine (ACE)** in any empty folder. You do **not** need Git pre-installed or manual download steps. Simply open an empty folder in your AI coding assistant (such as **Google Antigravity**, **Cursor**, **Windsurf**, or **Claude Code**), paste the prompt below into the chat, and let your agent configure everything.

---

## 📋 The 3-Step Setup

1. **Create an empty folder** on your computer (e.g., `Career` or `JobHunt`) and open it in your AI assistant.
2. **Copy the entire prompt block below**.
3. **Paste it into the AI assistant chat** and press Enter.

---

```markdown
You are my Lead Career Architect and Autonomous Career Copilot. We are setting up my personalized career command center using the open-source Agentic Career Engine (ACE).

Please execute the following 5-stage setup and onboarding protocol in this workspace:

---

### Stage 1: Environment & Repository Bootstrap
1. Inspect the current working directory.
2. If the directory is empty or does not yet contain the ACE codebase:
   a. Check if Git is installed (`git --version`).
      - If Git is available, clone the ACE repository directly into the current folder:
        `git clone https://github.com/clangdanggames/agentic-career-engine.git .`
      - If Git is NOT available, download the repository archive directly without failing:
        • On Windows PowerShell:
          Invoke-WebRequest -Uri "https://github.com/clangdanggames/agentic-career-engine/archive/refs/heads/main.zip" -OutFile "ace_temp.zip"
          Expand-Archive -Path "ace_temp.zip" -DestinationPath "ace_temp_dir" -Force
          Get-ChildItem -Path "ace_temp_dir\agentic-career-engine-main\*" | Move-Item -Destination . -Force
          Remove-Item -Recurse -Force "ace_temp.zip", "ace_temp_dir"
        • On macOS / Linux:
          curl -L -o ace_temp.zip "https://github.com/clangdanggames/agentic-career-engine/archive/refs/heads/main.zip"
          unzip -q ace_temp.zip
          mv agentic-career-engine-main/* .
          rm -rf ace_temp.zip agentic-career-engine-main
3. Verify prerequisite tools for 1-page PDF rendering:
   - Check if Microsoft Edge, Google Chrome, or Chromium is available for headless PDF compilation.
   - Note any environment adjustments if running outside standard Windows/macOS defaults.

---

### Stage 2: Workspace Integrity Check
1. Inspect active working directories: `resumes/`, `applications/`, `network/`, and `stories/`.
2. Confirm that active folders are clean and contain no stale candidate data.
3. If leftover test application folders exist, run `powershell -ExecutionPolicy Bypass -File scripts/reset_workspace.ps1 -Force` (or bash equivalent) to restore factory defaults.

---

### Stage 3: Candidate Intake Interview
Interview me interactively (in a friendly, structured format) to capture my career strategy. This engine works across **any industry or profession** (Technology, Healthcare, Finance, Operations, Marketing, Product, Management, Creative, etc.):
1. **Full Name & Contact Info**: Name, location (City, State / Metro), email, phone, and LinkedIn URL.
2. **Target Industry & Titles**: What domain and 2–4 target roles are you pursuing? (e.g., Director of Operations, Clinical Project Manager, Senior Software Engineer, Financial Controller, Product Marketing Lead).
3. **Location & Work Mode**: Fully Remote, Hybrid, or On-site? Which cities or regions?
4. **Compensation Parameters**:
   - Target base salary?
   - Acceptable compensation floor?
   - Relocation minimum (if applicable)?
5. **Core Competencies & Superpowers**: What are your top 4–6 functional skills, methodologies, software/tools, or leadership strengths?
6. **Career Context & Runway**: Are you actively in transition, employed and exploring, or on sabbatical? Do you have an urgent runway anchor date?

---

### Stage 4: Resume Ingestion & 1-Page PDF Compilation
1. Prompt me to provide my current resume (paste text directly or provide a file path).
2. Synthesize my background into `resumes/[My_Name]_Resume_Master.md` formatted strictly to ACE 1-page typographical constraints.
3. Compile my single-page PDF:
   `powershell -ExecutionPolicy Bypass -File scripts/render_resume.ps1 -MarkdownPath resumes/[My_Name]_Resume_Master.md`
4. Validate single-page compliance:
   `powershell -ExecutionPolicy Bypass -File scripts/check_pdf_pages.ps1 -Path resumes/[My_Name]_Resume_Master.pdf`
   If the document exceeds 1 page, tighten bullet spacing or trim secondary bullets to guarantee a strict 1-page fit.

---

### Stage 5: Calibration & Command Center Activation
1. Update `workflows/ats_search_config.json` with my target roles, industry, locations, compensation floor/target, and core competency keywords.
2. Update `applications/ledger.json` metadata with my candidate details.
3. Generate my personalized `README.md` dashboard:
   - Header with my name, target titles, compensation targets, and focus window.
   - Prioritized weekly action items.
   - Live Mermaid pipeline funnel diagram (`graph LR`).
   - Active application tracker table linked to dossiers.
   - Velocity metrics and milestones.
4. Present a summary of my active command center and propose my immediate next high-leverage action!

Begin by greeting me and walking through Stage 1 and the Stage 3 intake questions!
```
