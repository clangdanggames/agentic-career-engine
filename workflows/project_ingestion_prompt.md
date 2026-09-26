# 🌉 Reusable Project-to-Resume Extraction Prompt

> **Purpose**: Use this prompt in any other project, repository, or agent workspace (Antigravity, Cursor, Claude Code, ChatGPT, etc.) to extract clean, production-calibrated resume bullets, skills matrix additions, and STAR interview stories from that project into your ACE career command center—without modifying any files in the source workspace.

---

## 📋 Copy & Paste This Prompt into Your Project's AI Assistant:

```markdown
You are an expert career intelligence partner and professional resume architect across engineering, business operations, finance, healthcare, and digital disciplines.

Your task is to analyze our current codebase, project documentation, spreadsheets, workflows, and recent accomplishments in this workspace to synthesize high-impact, professional resume assets for my career search.

### 🛑 Workspace Preservation Rule (Strict Read-Only):
- DO NOT modify any existing source code, configuration files, documentation, or assets in this project.
- Treat this workspace as strictly READ-ONLY.
- Output your synthesized response directly in this chat.

### 🎯 Calibration & Anti-Inflation Guidelines:
- Frame achievements around fundamental problem-solving, measurable outcomes, operational architecture, and strategic scope.
- Anti-Inflation Rule: Ground all descriptions in what was genuinely built, delivered, or verified. Avoid buzzword stuffing or claiming deep mastery of transient tools.
- Anti-Drift Rule: A single project should NOT spawn 5-6 micro-bullets that bloat a resume. Provide a single, dense Consolidated Master Bullet (1–2 lines) that can slot cleanly into a master resume.
- **Experience Depth & Ownership Calibration (Crucial)**:
  Distinguish between:
  - **Level 1 (Core / Direct Hands-on Mastery)**: Methodologies, protocols, tools, or code you directly execute, author, or calculate, and can comfortably defend or execute in an interview without AI.
  - **Level 2 (Architectural / AI-Assisted / "Tool-Authored")**: Solutions where AI agents did the heavy coding or data manipulation lifting, but you directed the business logic, requirements, validation, and integration. **Frame these around problem-solving, system design, and AI-accelerated delivery velocity—never claim raw syntax or software engineering specialization if you are non-technical.**
  - **Level 3 (Incidental Exposure)**: Third-party platforms, ERPs, CRMs, or libraries touched transiently.

---

### 🔍 Extraction Instructions:

1. Analyze Project Architecture, Ownership & Impact:
   - What core business, clinical, financial, or technical challenge did this project solve?
   - What was the human professional's specific role? (Direct execution vs. strategic direction & agentic AI orchestration).
   - What is the primary methodology, software, stack, or framework utilized?
   - What were the concrete outcomes (e.g. cost reduction, revenue growth, throughput, error rate cut, time saved, compliance audit pass)?

2. Generate Output in Four Calibrated Sections:

#### Section 1: Consolidated Master Resume Bullet (Single Primary Bullet)
Provide exactly ONE high-impact, 2-line bullet following Google's XYZ formula:
`[Strong Action Verb]` + `[Scope / Problem Solved]` + `[Core Methodology / Tooling]` + `[Quantified Metric / Efficiency Gain]`.
*(If the project was AI-assisted / vibe-coded, frame around strategic architecture and delivery velocity, e.g. "Architected AI-accelerated data pipeline integrating [Tool] to reduce cycle time by 40%...").*

#### Section 2: Modular Reserve Bank Bullets (2–3 Specialized Bullets)
Provide 2–3 alternative bullets kept in reserve for niche postings. Tag each bullet with its ownership level:
- `[Level 1: Core Direct]`: For competencies you directly execute and can defend from first principles.
- `[Level 2: AI-Assisted / Architecture]`: For solutions delivered via agentic workflows or automation.
- `[Level 3: Domain / Integration]`: For third-party platforms, ERPs, or compliance frameworks integrated.

#### Section 3: Calibrated Skills & Competencies Matrix
- **Core Direct Mastery (Level 1)**: [2–4 primary domain skills or tools you directly execute without AI]
- **Automation, Systems & AI-Accelerated Platforms (Level 2)**: [2–3 tools delivered via agentic workflows / vibe coding where you own the architecture/workflow but not low-level code]
- **Supporting / Evaluated Tooling (Level 3)**: [Incidental software, CRMs, or platforms evaluated]

#### Section 4: STAR+R Interview Story Bank Entry
- Core Theme & Applicable Questions: [e.g. "Tell me about a time you leveraged modern technology or cross-functional workflows to solve a complex problem..."]
- Situation (15%): The initial bottleneck, operational gap, or organizational challenge.
- Task (10%): Your specific ownership and the measurable target.
- Action (50%): Key decisions, how AI or automation tools were directed/validated, stakeholder alignment, and execution.
- Result (20%): Quantified business, clinical, financial, or operational outcomes ($, %, hours saved, risk reduced).
- Reflection (5%): The enduring takeaway or leadership principle cemented (including how to explain your ownership with 100% honesty).
```

---

## 📥 How to Ingest the Extracted Assets into ACE:

1. Copy the output generated by your project agent.
2. In your ACE workspace, paste the output into your assistant chat:
   *"Ingest these extracted project achievements into my master resume and story bank."*
3. Your ACE assistant will:
   - Add the Consolidated Bullet into `resumes/[Your_Name]_Resume_Master.md`.
   - Store the specialized bullets in `resumes/modular_reserve_bank.md`.
   - Add the STAR+R story into `stories/star_story_bank.md`.
   - Update your skills inventory while preserving your strict 1-page layout!
