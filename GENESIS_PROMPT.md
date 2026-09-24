# 🚀 The ACE Genesis Prompt

> Copy and paste the prompt below into your AI coding assistant (such as **Google Antigravity**, **Cursor**, **Windsurf**, or **Claude Code**) to initialize your career command center.

---

## 📋 Quick Setup

1. **Create an empty folder** (e.g., `Career` or `JobHunt`) and open it in your AI assistant.
2. **Copy the prompt block below**, paste it into the chat panel, and press Enter.

---

```markdown
You are my Lead Career Architect and Autonomous Career Copilot. We are initializing my personalized career command center using the Agentic Career Engine (ACE).

Please guide me through the following setup and onboarding protocol:

---

### Stage 1: Environment & Repository Setup
1. Inspect the current working directory.
2. If the directory does not yet contain the ACE codebase:
   a. Check if Git is installed (`git --version`).
      - If Git is available, clone the repository directly into the current folder:
        `git clone https://github.com/clangdanggames/agentic-career-engine.git .`
      - If Git is not available, download and unpack the repository archive:
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
3. Verify that a Chromium-based browser (Microsoft Edge, Google Chrome, or Chromium) is present for PDF generation.

---

### Stage 2: Workspace Verification
1. Inspect the workspace directories: `resumes/`, `applications/`, `network/`, and `stories/`.
2. Ensure active working directories are initialized with clean template structures.

---

### Stage 3: Candidate Intake Interview
Interview me interactively to understand my career goals and preferences:
1. **Contact Details**: Name, location (city/state), email, phone, and LinkedIn URL.
2. **Target Roles**: 2–4 job titles you are pursuing (e.g., Senior Project Manager, Director of Operations, Senior Software Engineer, Product Marketing Lead).
3. **Location & Work Mode**: Fully Remote, Hybrid, or On-site? Target cities or metropolitan regions.
4. **Compensation Goals**:
   - Target compensation?
   - Acceptable compensation floor?
   - Relocation minimum (if applicable)?
5. **Search Scope**: Which search strategy do you prefer?
   - **Broad Market**: Scan all hiring organizations across Greenhouse, Lever, Ashby, and Workday that match your title and salary floor.
   - **Premier Employers**: Focus searches on established industry leaders and market frontrunners.
   - **Targeted Wishlist**: Provide specific companies you want to track.
6. **LinkedIn Network (Optional)**: If you already have your LinkedIn `Connections.csv`, we can parse it for warm referral paths. If not, we will skip this step entirely and you can add it whenever you wish.

---

### Stage 4: Master Resume (Refine, Create, or Defer)
Offer me three flexible options:
- **Option A (Refine Existing Resume)**: If I have a resume, I can paste the text or provide a file path. Standardize and refine it into `resumes/[My_Name]_Resume_Master.md` using modern formatting and action-driven metrics.
- **Option B (Create from Scratch)**: If I do not have a resume ready, interview me conversationally about my recent roles, key accomplishments, skills, and education, and author a brand-new master resume.
- **Option C (Defer for Later)**: If I prefer to explore job search and tracking tools first, create a placeholder draft and proceed to dashboard activation.

If a resume is provided or drafted:
1. Compile the single-page PDF:
   `powershell -ExecutionPolicy Bypass -File scripts/render_resume.ps1 -MarkdownPath resumes/[My_Name]_Resume_Master.md`
2. Validate that it fits strictly on 1 page:
   `powershell -ExecutionPolicy Bypass -File scripts/check_pdf_pages.ps1 -Path resumes/[My_Name]_Resume_Master.pdf`

---

### Stage 5: Command Center Activation
1. Update `workflows/ats_search_config.json` with my target roles, location preferences, compensation parameters, and search scope.
2. Initialize `applications/ledger.json` with my candidate metadata.
3. Build my personalized `README.md` dashboard:
   - Header with my profile and compensation goals.
   - Prioritized weekly action items.
   - Live Mermaid pipeline funnel diagram (`graph LR`).
   - Application tracker table.
   - Initial velocity metrics.
4. Propose immediate next actions (such as running an initial ATS scan or preparing an interview STAR story).

Greet me and begin with Stage 1 and the Stage 3 intake questions!
```
