# ATS Job Scanner — Scoring Rubric & Evaluation Framework

> **Purpose**: A deterministic, transparent 100-point scoring algorithm and qualitative evaluation rubric to assess job opportunities against the candidate's professional background, compensation targets, and network leverage.

---

## 📊 1. Personal Fit Score (0–100 Points)

The **Personal Fit Score** measures alignment between the target job posting and the candidate's verified skills, experience, and career trajectory as defined in `workflows/ats_search_config.json` and `resumes/[User_Name]_Resume_Master.md`.

| Evaluation Category | Max Points | Universal Dimensions & Evaluation Criteria |
| :--- | :---: | :--- |
| **Core Domain Competencies** | **40 pts** | • **Primary Methodologies & Skills (up to 20 pts)**: Overlap with candidate's core functional skills (e.g. software engineering, financial modeling, clinical trials, product roadmaps, brand strategy).<br>• **Toolsets & Platforms (up to 15 pts)**: Familiarity with essential software, platforms, CRM/ERP systems, or technical infrastructure.<br>• **Certifications & Compliance (up to 5 pts)**: Required professional licensures, PMP, CPA, AWS, Six Sigma, or industry-specific certifications. |
| **Scope & Measurable Impact** | **30 pts** | • Track record delivering comparable business or technical outcomes (e.g. revenue generated, budgets managed, latency reduced, efficiency increased, regulatory audits passed).<br>• Project scale, customer/user volume, transaction throughput, or organizational footprint matching role expectations. |
| **Seniority & Leadership** | **20 pts** | • Seniority tier match (Senior, Staff, Lead, Manager, Director, Head of, VP).<br>• People leadership, cross-functional stakeholder management, or technical mentorship history.<br>• Relevant years of progressive responsibility. |
| **Domain & Industry Alignment** | **10 pts** | • Industry vertical familiarity (e.g. Healthcare, Fintech, Enterprise SaaS, Consumer, Manufacturing, Energy, Media).<br>• Business model overlap (B2B, B2C, Marketplace, Regulated, High-Growth). |

### Fit Score Tiers:
- **90–100%**: **Exceptional Fit** (Direct alignment across core competencies, project scope, seniority, and industry).
- **75–89%**: **High Fit** (Strong match on primary responsibilities and functional competencies; negotiable gaps).
- **65–74%**: **Moderate Fit** (Solid baseline alignment; candidate possesses transferable skills with minor domain gaps).
- **< 65%**: **Filtered Out** (Below threshold; not added to active Sourcing Inbox unless warm referral exists).

---

## 🔍 2. Pragmatic 3-Tier Gap Analysis & Calibrated Advisory Deductions

Job descriptions often include aspirational wishlists or legacy boilerplate under "Required Qualifications" that hiring managers in practice are flexible about waiving for candidates with strong foundational depth. To reflect this real-world dynamic without sycophantic embellishment:

### The 3-Tier Gap Classification:
1. **Tier 1: Direct Strengths**: 1:1 verified skills, metrics, tools, and seniority matching the requisition.
2. **Tier 2: Transferable / Adjacent**: Similar challenges solved with adjacent frameworks, tools, or methodologies (e.g. custom telemetry vs Datadog, enterprise Oracle vs PostgreSQL, hospital ops vs clinical clinic ops). Accurately framed around the underlying architectural or operational problem solved.
3. **Tier 3: Notable Requirement Gaps (Check Negotiability)**: Requirements listed in the JD that are absent from the candidate's background.

### Calibrated Advisory Deductions (Softened Dealbreaker Scoring):
- Rather than hastily disqualifying high-potential roles with heavy -40 pt penalties, apply a **calibrated advisory deduction (-10 to -15 points)** when an explicit requirement is missing.
- **Transparent Gap Warning**: The assistant clearly flags the gap in the lead analysis:
  > *"Advisory Note: Requisition lists [Tool/Credential X] under required qualifications. However, your Tier 1 depth in [Y] and adjacent experience in [Z] keep this role viable (Fit Score: 78%). If you choose to pursue this, we will emphasize your transferable problem-solving in your outreach and application materials."*
- If the missing requirement is an inflexible statutory/legal hurdle (e.g. active medical board license, secret security clearance, CPA for signing audits), the assistant explicitly flags it as a **Hard Legal/Statutory Dealbreaker** and recommends passing.

---

## 🎯 2. Likelihood of Success Rating (High / Medium / Low)

The **Likelihood of Success** assesses the probability of securing an interview and moving through the hiring loop, considering credentials, work authorization/location, and network leverage:

### 🟢 High Likelihood
- **Title Match**: Requisition title matches candidate's target seniority and focus areas.
- **Location Alignment**: 100% Remote (US/Target Region) OR within acceptable commuting distance.
- **Compensation**: Explicitly within or above target compensation parameters.
- **Network Multiplier**: **Internal 1st-degree connection exists** in [`network/contacts_ledger.md`](../../../../network/contacts_ledger.md). *Provides an automatic +30 point boost to candidate prioritization.*

### 🟡 Medium Likelihood
- Strong functional overlap, but role is hybrid outside primary metro (requiring remote exception), or compensation band is unlisted and requires heuristic validation.
- Standard competitive ATS pipeline without an immediate internal referral.

### 🔴 Low Likelihood
- Requisition mandates specialized credentials or non-transferable domain licenses outside candidate profile, or rigid on-site requirements outside target regions without relocation support.

---

## 💰 3. Compensation Validation & Heuristic Estimator

1. **Explicitly Listed Salary**:
   - Extract minimum and maximum base salary directly from the posting.
   - If range overlaps with the target compensation defined in `workflows/ats_search_config.json`, mark as **Target Compliant**.
2. **Unlisted Salary**:
   - Apply the [4-Factor Compensation Estimator](../../../../workflows/compensation_estimator.md):
     $$\text{Estimated Base} = \text{Role Baseline} \times \text{Company Tier Multiplier} \times \text{Geo Index}$$
   - Validate against live benchmarks (Levels.fyi, Glassdoor, Indeed, Salary.com, Bureau of Labor Statistics).
   - Clearly flag as *(Estimated)* in the Sourcing Inbox.
