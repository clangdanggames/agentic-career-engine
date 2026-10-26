---
name: career-ingestion
description: Clarifies, validates, calibrates, and ingests user-provided career data (conversational updates, employee performance reviews, project outcomes/postmortems, and external project extraction prompts) into the candidate's Comprehensive Career Banks (career_profile_bank.md, modular_reserve_bank.md, star_story_bank.md) and optional Master Resume summary. Use whenever the user shares new accomplishments, skills, credentials, references, feedback, or project summaries.
---

# Continuous Career Ingestion & Truth-Validation Skill

This skill governs how new career data is clarified, validated for truthful ownership, and stored in the candidate's **Comprehensive Career Banks**.

---

## 🏛️ 1. Core Architectural Doctrines

1. **User-Driven Context Over Blind Scraping**:
   - Never blindly scrape raw project directories or multi-author repositories without user context, as doing so risks misattributing teammates' work or boilerplate code to the candidate.
   - Instead, rely on user-provided inputs—or recommend [`workflows/project_ingestion_prompt.md`](../../../workflows/project_ingestion_prompt.md) when the user wants an external agent (which already holds session context in another project workspace) to summarize their work.
2. **Bank-First Storage Architecture (Rule 3)**:
   - Store **all** verified skills, experience bullets, credentials, references, and stories comprehensively in the **Career Banks**:
     - [`resumes/career_profile_bank.md`](../../../resumes/career_profile_bank.md): Identity, Categorized Skills (stratified by `[Level 1]`, `[Level 2]`, `[Level 3]`), Education, Certifications/Awards, and Professional References.
     - [`resumes/modular_reserve_bank.md`](../../../resumes/modular_reserve_bank.md): Complete chronological employment history, core role bullets, and specialized/thematic reserve bullets (tagged with `[Level 1/2/3]`).
     - [`stories/star_story_bank.md`](../../../stories/star_story_bank.md): Behavioral and technical STAR+R narratives.
   - **Master Resume as a Compiled Summary View**: `resumes/[Name]_Resume_Master.md` is **not** a primary data store; it is the un-tailored general summary synthesized from the banks. Only update the Master Resume when a newly ingested achievement or skill represents a core, broadly applicable addition to the candidate's general summary.

---

## 📥 2. The Four Primary Input Channels

### Channel A: Conversational Statements & Incremental Updates
- *Examples*: *"We just cut customer onboarding time by 30% using a new automated intake flow"*, *"Add Python and SQL to my skills"*, *"Here are two former managers to save as references."*
- **Handling**:
  - Check which legs of the Google XYZ formula (`[Strong Action Verb] + [Scope / Problem Solved] + [Core Methodology / Tooling] + [Quantified Result]`) or competency depth (`[Level 1/2/3]`) are missing.
  - Ask at most **2-3 targeted clarifying questions** before drafting the bank entries.

### Channel B: Employee Performance Reviews, Peer Kudos & Promotion Packets
- *Examples*: Pasted manager evaluations, 360 peer feedback, annual review summaries, or promotion justifications.
- **Handling**:
  - **Extract Signal from Praise**: Convert qualitative praise (*"Alex was the glue during the Q3 ERP migration and mentored junior analysts"*) into concrete accomplishment bullets and leadership stories.
  - **De-Jargon Internal Terminology**: Translate internal company codenames, proprietary tool names, or org-specific acronyms into industry-standard terminology recognizable to external hiring managers.
  - **Prompt for Conservative Metrics**: Reviews often omit baseline numbers that were obvious internally. Ask the candidate for conservative, defensible scale metrics (e.g., team size, budget, time saved, error reduction) to anchor the bullets.
  - **Capture Endorsements**: If a manager or peer is named in 360 feedback, offer to log them in **Section 5 (Professional References & Endorsements)** of `resumes/career_profile_bank.md` along with the specific strengths they praised.

### Channel C: Project Outcomes, Postmortems, QBRs & Launch Summaries
- *Examples*: Incident postmortems, quarterly business reviews (QBRs), clinical trial closeouts, P&L reports, or architecture decision records (ADRs).
- **Handling**:
  - **The "We vs. I" Attribution Gate**: Postmortems and QBRs almost always describe *team-wide* outcomes. Explicitly ask the candidate to clarify their **personal decision-making, execution, and ownership boundary** versus the broader team's work so bullets are 100% truthful and defensible under interview questioning.
  - **Turnaround & Resilience Framing**: Incident postmortems and off-track project recoveries make exceptional **Story 2 (Crisis / Risk Mitigation / Turnaround)** entries in `stories/star_story_bank.md`. Frame them around diagnostic rigor, root-cause containment, and permanent institutional safeguards established.

### Channel D: External Project Extraction Prompt (`workflows/project_ingestion_prompt.md`)
- *When to Recommend*: Whenever the user mentions a project, codebase, or analytics workflow living in another workspace or repository, proactively point them to [`workflows/project_ingestion_prompt.md`](../../../workflows/project_ingestion_prompt.md) so the agent in that workspace can generate a structured 4-section export.
- **Handling**:
  - Inspect the pasted 4-section output for any `[Confirm Metric: ...]` or `[Confirm Ownership: ...]` placeholders emitted by the external agent.
  - Resolve any placeholders with the user, then route all 4 sections into `career_profile_bank.md`, `modular_reserve_bank.md`, and `star_story_bank.md`.

---

## 🔍 3. The 4-Step Ingestion & Truth-Validation Pipeline

### Step 1: Gap Detection & Socratic Clarification (Max 2-3 Questions)
Review the user's input. If it already specifies personal ownership, methodology/tools, competency depth, and defensible impact, proceed directly to **Step 2**. Otherwise, ask **no more than 2-3 high-leverage questions** focused on:
1. **Personal Ownership ("I" vs. "We")**: *"What was your specific role, decision, or deliverable on this initiative versus the rest of the team?"*
2. **Defensible Metric / Scale**: *"Roughly what was the measurable impact or scale (e.g., hours saved per week, % improvement, volume/budget handled, or SLA met), even as a conservative floor?"*
3. **Competency Depth (`[Level 1/2/3]`)**:
   - **`[Level 1: Core Direct]`**: Can you execute and defend this skill/tool from first principles in a live interview without AI?
   - **`[Level 2: AI-Assisted / Architecture]`**: Did you direct the architecture, requirements, and validation while AI or automation handled implementation?
   - **`[Level 3: Working Exposure / Evaluated]`**: Was this a supporting platform, ERP/CRM, or tool touched transiently?

### Step 2: Calibration & Preview (Rule 3 & Rule 9 Enforcement)
Before modifying any files, present a concise preview of the proposed vault additions in chat:
- **Skills / Credentials / References** for `resumes/career_profile_bank.md` (categorized by domain and `[Level 1/2/3]`).
- **Role / Project Bullets** for `resumes/modular_reserve_bank.md` (with `[Level 1/2/3]` tags preserved for internal tailoring intelligence, and zero em dashes per **Rule 9**).
- **STAR+R Story** for `stories/star_story_bank.md` (if applicable).
- **Optional Master Resume Summary Update**: State whether you recommend keeping this strictly in the Reserve/Profile Banks (for targeted tailoring) or also updating `resumes/[Name]_Resume_Master.md` (e.g., swapping out a weaker bullet on the general Master Resume).

### Step 3: Deterministic Bank Routing
Once the user confirms the preview:
1. **Update [`resumes/career_profile_bank.md`](../../../resumes/career_profile_bank.md)**:
   - Add new skills under the appropriate category and `[Level 1/2/3]` line in **Section 2**.
   - Add new degrees, certifications, awards, or references to **Sections 3-5**.
2. **Update [`resumes/modular_reserve_bank.md`](../../../resumes/modular_reserve_bank.md)**:
   - Add role-specific bullets under the matching employer in **Part 1 (Chronological Work History)**, or project bullets under **Part 2 (Thematic & Cross-Cutting Project Bullets)**.
3. **Update [`stories/star_story_bank.md`](../../../stories/star_story_bank.md)** *(when a story is generated)*:
   - Append the new `## 📖 Story N: [Title]` entry with `Situation`, `Task`, `Action`, `Result`, and `Reflection`.
4. **Optional Master Resume & Search Config Sync**:
   - If the user approves updating `resumes/[Name]_Resume_Master.md`, strip all `[Level 1/2/3]` tags (Rule 3) and em dashes (Rule 9) from the Master Resume text. If a bullet was displaced from the Master Resume, ensure the displaced bullet remains safely stored in `resumes/modular_reserve_bank.md`.
   - If new `[Level 1]` or `[Level 2]` core competencies were added, offer to append them to `scoring_weights.core_competencies.keywords` in [`workflows/ats_search_config.json`](../../../workflows/ats_search_config.json).

### Step 4: Post-Ingestion Verification
1. Run `powershell -File scripts/sync_career_banks.ps1` to verify bank parity.
2. If `resumes/[Name]_Resume_Master.md` was updated, run:
   - `powershell -File scripts/lint_resume_integrity.ps1 -TailoredResumePath resumes/[Name]_Resume_Master.md`
   - `powershell -File scripts/render_resume.ps1 -MarkdownPath resumes/[Name]_Resume_Master.md`
   - `powershell -File scripts/check_pdf_pages.ps1 -Path resumes/[Name]_Resume_Master.pdf`
