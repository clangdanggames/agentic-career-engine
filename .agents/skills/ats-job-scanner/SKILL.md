---
name: ats-job-scanner
description: >-
  Scans, ingests, and intelligently scores ATS job listings across Greenhouse, Lever, Ashby, and Workday based on the candidate's background and preferences. Use whenever asked to search for jobs, scan ATS postings, run job queries, or evaluate new job opportunities.
---

# Automated ATS Job Scanner & Sourcing Intelligence Skill

This skill automates the discovery, extraction, scoring, and organization of high-match job listings directly from primary ATS domains (Greenhouse, Lever, Ashby, Workday).

---

## 🎯 When to Use This Skill

Activate this skill when:
- The user asks to: *"scan for jobs"*, *"search ATS listings"*, *"find new roles"*, *"look for openings at target companies"*, or *"source new leads"*.
- A scheduled cron or timer fires to run a periodic job discovery scan.
- You need to evaluate a batch of job links for **Personal Fit** and **Likelihood of Success**.

---

## 📋 Execution Procedure

Follow this 5-step procedure to execute an ATS job scan:

### Step 1: Read Search Configuration
1. Open and read [`workflows/ats_search_config.json`](file:///c:/Code/ACE/workflows/ats_search_config.json).
2. Note the configured roles, ATS domains, locations, and negative filters.
3. Check existing URLs in [`applications/sourcing_inbox.json`](file:///c:/Code/ACE/applications/sourcing_inbox.json) to prevent processing duplicate leads.

### Step 2: Execute Targeted Web Searches
Run searches using `search_web` across the ATS query categories constructed from the configuration:
1. **Primary Remote Target Roles**:
   Search across configured ATS domains (`boards.greenhouse.io`, `jobs.lever.co`, `jobs.ashbyhq.com`, `myworkdayjobs.com`) filtering for remote roles and target titles.
2. **Specialized Target Roles & Tech Stacks**:
   Search focusing on the candidate's core language/technology preferences and high-priority specializations.
3. **Target Regional / Metro Openings**:
   Search focusing on preferred local or hybrid geographic regions if specified.
4. **Target Company Career Pages**:
   Search specific target company domains configured in `ats_search_config.json` where internal network contacts exist.

### Step 3: Extract & Evaluate Core Details
For each discovered job posting:
1. **Extract Metadata**: Job Title, Company, Location (Remote / Hybrid / Onsite), Job URL, Date Discovered.
2. **Identify Compensation**:
   - If salary is stated in the posting, record the exact base salary range.
   - If salary is unlisted, estimate using the [4-Factor Compensation Estimator](file:///c:/Code/ACE/workflows/compensation_estimator.md) based on company tier and title.
3. **Calculate Personal Fit Score (0–100%)**:
   - Evaluate against the criteria in [Scoring Rubric](file:///c:/Code/ACE/.agents/skills/ats-job-scanner/references/scoring_rubric.md):
     - **Core Technical Stack** (Languages, frameworks, tooling) $\rightarrow$ up to 40 pts.
     - **Architectural Scope** (System design, testing architecture, infrastructure, pipelines) $\rightarrow$ up to 30 pts.
     - **Seniority & Scale** (Level match, years of experience, distributed/production scale) $\rightarrow$ up to 20 pts.
     - **Domain Alignment** (Industry vertical, business model, problem space) $\rightarrow$ up to 10 pts.
4. **Cross-Reference Network Contacts**:
   - Check the company name against [`network/contacts_ledger.md`](file:///c:/Code/ACE/network/contacts_ledger.md).
   - If a 1st-degree connection exists at the company, note the contact name, title, and profile link.
5. **Determine Likelihood of Success**:
   - **High**: Title match + Location alignment + Compensation within target range + (Bonus: Internal referral exists).
   - **Medium**: Strong technical match, standard competitive pipeline, unlisted comp, or no immediate referral.
   - **Low**: Relocation required outside target regions or heavy non-aligned tech stack requirements.

### Step 4: Update Sourcing Inbox
1. Append all qualified leads ($\text{Fit Score} \ge 65\%$) to [`applications/sourcing_inbox.json`](file:///c:/Code/ACE/applications/sourcing_inbox.json).
2. Regenerate [`applications/sourcing_inbox.md`](file:///c:/Code/ACE/applications/sourcing_inbox.md) with a ranked visual table sorted by **Fit Score** and **Likelihood of Success**.

### Step 5: Report Highlights to the User
Present the top 3–5 highest-scoring opportunities in your response, highlighting:
- Role & Company (with direct ATS link).
- Fit Score & Success Likelihood.
- Listed/Estimated Compensation.
- Internal warm referral availability.
- Suggested next action (e.g. *"Warm outreach to [Contact] before applying"* or *"Run tailoring routine to generate 1-page PDF"*).

---

## ⏰ Scheduling the Scanner

To set this skill to run automatically on a recurring schedule:
- Use the `schedule` tool or recommend `/schedule` with a cron expression:
  - Example: `0 10 * * 1,4` (Every Monday and Thursday at 10:00 AM).
  - Prompt: `"Run automated ATS job scan across Greenhouse, Lever, Ashby, and Workday, score discovered leads, and update the Sourcing Inbox."`
