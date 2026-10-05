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
1. Open and read [`workflows/ats_search_config.json`](../../../workflows/ats_search_config.json).
2. Note the configured roles, ATS domains, locations, and negative filters.
3. Check existing URLs in [`applications/sourcing_inbox.json`](../../../applications/sourcing_inbox.json) to prevent processing duplicate leads.

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
1. **Extract Metadata & Direct Requisition URL (MANDATORY INVARIANT)**:
   - **Job Title**, **Company**, **Location** (Remote / Hybrid / Onsite), **Date Discovered**.
   - **Direct Requisition URL**: The URL **MUST** be a deep link to the individual job posting containing the unique requisition ID or UUID.
     > [!CAUTION]
     > **Zero Generic Portal Links**: Never record root career homepages (e.g. `boards.greenhouse.io/<company>`, `jobs.ashbyhq.com/<org>`, or `myworkdayjobs.com/...`). These drop candidates on general search pages or 404, breaking the 1-click apply workflow.
     - *Greenhouse*: `https://job-boards.greenhouse.io/<company>/jobs/<numeric_id>` or `https://boards.greenhouse.io/<company>/jobs/<numeric_id>`.
     - *Ashby*: `https://jobs.ashbyhq.com/<org-slug>/<uuid>` (confirm exact slug—e.g. `wispr-flow`, `ease-health`).
     - *Lever*: `https://jobs.lever.co/<company>/<uuid>`.
     - *Workday*: `https://<tenant>.myworkdayjobs.com/en-US/<board>/job/<title>_<req-id>` (requires specific tenant like `wd12` / `wd108` and requisition ID).
2. **Resilient Direct Link Verification Gate**:
   - **Live HTTP Check**: Check the direct requisition URL using `read_url_content`, `curl.exe`, or browser inspection.
   - **Bot-Shield Resilience (HTTP 403 / 503 / SPA Shells)**: Platforms protected by Cloudflare or WAF (e.g. Ashby, Workday) may return HTTP 403 or client-side empty SPA shells to automated CLI requests. If the URL matches verified deep requisition signatures (`/jobs/\d+`, UUIDs, or Workday `/job/` paths), preserve it as a verified direct requisition (1-click browser navigation works for the candidate).
   - **Generic Link Resolution (Fallback Search)**: If a search lead points only to a generic career root, attempt an autonomous search (`site:<ats_domain> "<company>" "<job title>"`) to resolve the deep URL.
   - **Zero High-Match Discard**: If job details and match criteria are confirmed but the specific direct requisition slug cannot be verified automatically, sort the lead into the existing Sourcing Inbox queue with a warning flag on the link (e.g. `[Job Title (⚠️ Confirm Requisition Link)](url)`). Never discard a high-match opportunity solely due to automated link verification challenges.
   - **True 404s**: If a URL returns a confirmed 404 and the search snippet is stale, discard or mark closed.
3. **Identify Compensation**:
   - If salary is stated in the posting, record the exact base salary range.
   - If salary is unlisted, estimate using the [4-Factor Compensation Estimator](../../../workflows/compensation_estimator.md) based on company tier and title.
4. **Calculate Personal Fit Score (0–100%)**:
   - Evaluate against the criteria in [Scoring Rubric](references/scoring_rubric.md):
     - **Core Technical Stack** (Languages, frameworks, tooling) $\rightarrow$ up to 40 pts.
     - **Architectural Scope** (System design, testing architecture, infrastructure, pipelines) $\rightarrow$ up to 30 pts.
     - **Seniority & Scale** (Level match, years of experience, distributed/production scale) $\rightarrow$ up to 20 pts.
     - **Domain Alignment** (Industry vertical, business model, problem space) $\rightarrow$ up to 10 pts.
5. **Cross-Reference Network Contacts**:
   - Check the company name against [`network/contacts_ledger.md`](../../../network/contacts_ledger.md).
   - If a 1st-degree connection exists at the company, note the contact name, title, and profile link.
6. **Determine Likelihood of Success**:
   - **High**: Title match + Location alignment + Compensation within target range + (Bonus: Internal referral exists).
   - **Medium**: Strong technical match, standard competitive pipeline, unlisted comp, or no immediate referral.
   - **Low**: Relocation required outside target regions or heavy non-aligned tech stack requirements.

### Step 4: Update Sourcing Inbox
1. Append all qualified leads ($\text{Fit Score} \ge 65\%$) with verified direct requisition URLs to [`applications/sourcing_inbox.json`](../../../applications/sourcing_inbox.json).
2. Regenerate [`applications/sourcing_inbox.md`](../../../applications/sourcing_inbox.md) with a ranked visual table sorted by **Fit Score** and **Likelihood of Success**. Ensure links point directly to the verified requisition URL (or include `⚠️ Confirm Requisition Link` flag if direct slug was unresolvable), with Requisition ID noted where available.

### Step 5: Report Highlights to the User
Present the top 3–5 highest-scoring opportunities in your response, highlighting:
- Role & Company (with direct ATS link).
- Fit Score & Success Likelihood.
- Listed/Estimated Compensation.
- Internal warm referral availability.
- Suggested next action (e.g. *"Warm outreach to [Contact] before applying"* or *"Run tailoring routine to generate 1-page PDF"*).

---

## 🎓 The Inbox Zero Graduation Lifecycle

The Sourcing Inbox is designed as a high-velocity triage queue rather than an indefinite parking lot:

1. **Inbox Ingestion**: New leads enter [`applications/sourcing_inbox.md`](../../../applications/sourcing_inbox.md) and `.json` in an un-triaged state.
2. **Active Graduation**: The moment the candidate decides to pursue a role (scaffolding an application dossier in `applications/YYYY-MM-DD_[company]_[reqid]/`, tailoring a resume, or reaching out for a referral), the role **graduates out of the inbox**:
   - It is removed from the active triage table in `sourcing_inbox.md`.
   - Its lifecycle is formally logged in [`applications/ledger.json`](../../../applications/ledger.json) and tracked on [`DASHBOARD.md`](../../../DASHBOARD.md).
3. **Archiving & Passing**: Leads that are evaluated and passed on (below compensation floor, location mismatch, or non-negotiable hard gaps) are moved to the `Archived & Passed Leads` section or pruned to keep active inbox triage friction at zero.

---

## ⏰ Scheduling the Scanner

To set this skill to run automatically on a recurring schedule:
- Use the `schedule` tool or recommend `/schedule` with a cron expression:
  - Example: `0 10 * * 1,4` (Every Monday and Thursday at 10:00 AM).
  - Prompt: `"Run automated ATS job scan across Greenhouse, Lever, Ashby, and Workday, score discovered leads, and update the Sourcing Inbox."`
