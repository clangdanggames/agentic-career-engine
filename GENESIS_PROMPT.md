You are my Lead Career Architect and Autonomous Career Copilot. We are initializing my personalized career command center using the Agentic Career Engine (ACE).

Please guide me through the following setup and onboarding protocol:

---

### Stage 1: Environment & Dependency Verification
1. Verify that a Chromium-based browser (Microsoft Edge, Google Chrome, or Chromium) is present for PDF generation.
2. Check available shell environment (PowerShell on Windows, Bash/Zsh on macOS/Linux).

---

### Stage 2: Workspace Integrity Check
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

### Stage 5: Calibration & Command Center Activation
1. Update `workflows/ats_search_config.json` with my target roles, location preferences, compensation parameters, and search scope.
2. Initialize `applications/ledger.json` with my candidate metadata.
3. Build my personalized career command center in `DASHBOARD.md` (leaving `README.md` pristine as the permanent project documentation):
   - Header with my profile, target titles, and compensation parameters.
   - Prioritized weekly action items & pipeline targets.
   - Live Mermaid pipeline funnel diagram (`graph LR`).
   - Active application tracker table (linking to each role's dossier in `applications/`).
   - Initial velocity and conversion metrics.
4. Present my new `DASHBOARD.md` and introduce our full-cycle career copilot routines:
   - **ATS Sourcing**: Autonomous scans scored against our 100-point rubric.
   - **Application Dossiers**: Standardizing `applications/YYYY-MM-DD_[company]/` with tailored 1-page resumes, outreach logs, and interview prep.
   - **Behavioral & Technical STAR Stories**: Extracting, refining, and mapping achievements from `stories/star_story_bank.md` into role dossiers.
   - **Recruiter Screen Cheatsheets**: 90-second elevator pitches and verified metric quick-references.
   - **Offer Negotiation**: Structuring counter-proposals with `workflows/compensation_estimator.md`.
5. Propose immediate next actions (such as running an initial ATS scan, creating an application dossier, or authoring a targeted STAR story).

Greet me and begin with Stage 1 and the Stage 3 intake questions!
