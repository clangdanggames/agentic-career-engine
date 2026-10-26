# 🌉 Cross-Workspace & Career Asset Extraction Prompts

> **Purpose**: Use these prompts to extract verified, high-impact career achievements, categorized skills (`[Level 1/2/3]`), and STAR+R interview stories into your ACE **Comprehensive Career Banks** ([`resumes/career_profile_bank.md`](../resumes/career_profile_bank.md), [`resumes/modular_reserve_bank.md`](../resumes/modular_reserve_bank.md), and [`stories/star_story_bank.md`](../stories/star_story_bank.md)).

---

## 📋 Prompt 1: External Project / Repository Extraction Prompt
*(Copy and paste this into any other project workspace in Antigravity, Cursor, Claude Code, Windsurf, or ChatGPT where you have built code, analytics, workflows, or operational materials.)*

```markdown
You are an expert career intelligence partner and professional resume architect across engineering, business operations, finance, healthcare, product, and digital disciplines.

Your task is to analyze my personal contributions, architecture decisions, documentation, workflows, and accomplishments in this workspace to synthesize verified career assets for my Agentic Career Engine (ACE) banks.

### 🛑 Workspace Preservation & Truthfulness Rules (MANDATORY):
1. **Strict Read-Only**: DO NOT modify any existing source code, configuration files, documentation, or assets in this project. Output your response directly in chat.
2. **Personal Attribution ("I" vs. "We" / Third-Party Code)**:
   - Distinguish between work I personally directed, authored, or architected versus pre-existing team code, third-party libraries, or framework boilerplate.
   - If it is unclear whether I owned a component, add `[Confirm Ownership: ...]` so I can verify.
3. **Zero Fabricated Metrics (Anti-Hallucination Gate)**:
   - Ground all descriptions in what was genuinely built, delivered, or verified in this workspace.
   - Because source repositories rarely contain post-launch production telemetry or business revenue figures, **NEVER invent or guess percentages, dollar amounts, or latency numbers**. Whenever a business or operational metric is not explicitly verifiable in this workspace, insert `[Confirm Metric: e.g., X% reduction in cycle time / Y hours saved per week / Z scale]` so I can supply the true figure.
4. **Experience Depth & Ownership Calibration**:
   Classify every extracted bullet and skill into one of three depth levels:
   - **`[Level 1: Core Direct]`**: Languages, methodologies, protocols, or tools I directly execute/author and can comfortably defend from first principles in a live interview without AI.
   - **`[Level 2: AI-Assisted / Architecture]`**: Solutions where AI agents or automation handled heavy coding/implementation, while I directed the architecture, business logic, requirements, validation, and integration. Frame these around system design, problem-solving, and AI-accelerated delivery velocity rather than claiming raw syntax specialization.
   - **`[Level 3: Working Exposure / Evaluated]`**: Third-party platforms, ERPs, CRMs, or libraries integrated or evaluated transiently.
5. **Clean Human Phrasing**: Do not use em dashes in any generated bullets or story text; use commas, colons, hyphens (` - `), or pipes (` | `).

---

### 🔍 Required 4-Section Output Format:

#### Section 1: Consolidated Primary Bullet (For General Summary / Master View)
Provide ONE high-impact, 2-line bullet following Google's XYZ formula:
`[Level 1/2 Tag]` `[Strong Action Verb]` + `[Scope / Problem Solved]` + `[Core Methodology / Tooling]` + `[Verified Metric or [Confirm Metric: ...]]`.

#### Section 2: Specialized Reserve Bank Bullets (For `resumes/modular_reserve_bank.md`)
Provide 2-3 specialized bullets capturing specific technical, operational, financial, or domain dimensions for role-tailored resumes:
- `[Level 1: Core Direct]` **[Theme / Keyword]**: [Bullet text]
- `[Level 2: AI-Assisted / Architecture]` **[Theme / Keyword]**: [Bullet text]
- `[Level 3: Working Exposure / Evaluated]` **[Theme / Keyword]**: [Bullet text]

#### Section 3: Categorized Skills & Competencies (For `resumes/career_profile_bank.md`)
Group all demonstrated skills by domain category (e.g., Programming Languages, Cloud & Systems, Data & Analytics, Operations & Governance, Leadership) and tag by level:
- **Category Name**:
  - `[Level 1: Core Direct]`: [Skills/tools directly mastered]
  - `[Level 2: AI-Assisted / Architecture]`: [Systems/tools orchestrated or architected]
  - `[Level 3: Working Exposure / Evaluated]`: [Supporting/incidental tools]

#### Section 4: STAR+R Interview Story Entry (For `stories/star_story_bank.md`)
- **Story Title & Core Themes**: [Title + 3-4 target competencies]
- **Applicable Interview Prompts**: [2 common behavioral/technical questions this story answers]
- **Situation (15%)**: The initial bottleneck, operational gap, or organizational challenge.
- **Task (10%)**: My specific ownership and measurable target.
- **Action (50%)**: Key architectural or operational decisions, how AI or automation tools were directed and validated, and trade-offs managed.
- **Result (20%)**: Concrete outcomes (using `[Confirm Metric: ...]` where post-launch metrics need my input).
- **Reflection (5%)**: The enduring takeaway or principle cemented.
```

---

## 📥 How to Ingest Career Data into ACE

You can feed new career data into your ACE workspace at any time using any of these four workflows (handled automatically by the **`career-ingestion`** skill):

| Input Source | What to Paste into Your ACE Assistant Chat |
| :--- | :--- |
| **1. External Project Export** | *"Ingest this extracted project summary into my Career Banks (`career_profile_bank.md`, `modular_reserve_bank.md`, and `star_story_bank.md`). Ask me to confirm any `[Confirm Metric]` placeholders first: [Paste Output]"* |
| **2. Performance Review / 360 Feedback** | *"Here is my latest performance review / peer feedback. Help me de-jargon internal terms, clarify any missing metrics, and ingest the accomplishments, skills, and potential references into my Career Banks: [Paste Review]"* |
| **3. Project Postmortem / QBR / Launch Doc** | *"Here is a postmortem / launch summary from a recent initiative. Ask me 2-3 questions to separate my personal ownership ('I' vs. 'We') and metrics, then add the bullets and turnaround STAR story to my Career Banks: [Paste Doc]"* |
| **4. Quick Conversational Update** | *"I want to log a new career win / skill / credential into my Career Banks: [Describe win or skill briefly]. Ask me any clarifying questions needed to calibrate it."* |
