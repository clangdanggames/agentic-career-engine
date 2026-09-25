# Application Form Guide & Submission Strategy: [Company Name]

- **Role**: [Target Role Title]
- **Requisition ID**: `[e.g., #104829]`
- **Company**: [Company Name]
- **ATS Platform**: [Greenhouse / Lever / Ashby / Workday / Direct Portal]
- **Direct Application Link**: [Paste Direct Application URL]

---

## 📋 Field-by-Field Submission Guidance

*Use this pre-filled cheat sheet to eliminate decision fatigue, prevent data-entry mistakes, and rapidly submit via the portal:*

| # | Field Label | Required? | Input Type | Recommended Entry / Strategy |
| :---: | :--- | :---: | :--- | :--- |
| **1** | **Full Name** | **Yes** | Text | `[Candidate Name]` |
| **2** | **Email Address** | **Yes** | Email | `[Candidate Email]` |
| **3** | **Phone Number** | No | Phone | `[Candidate Phone]` |
| **4** | **Resume** | **Yes** | File Upload | Attach `[Candidate_Name]_Resume_[Company]_[ReqID].pdf` |
| **5** | **Cover Letter** | Optional | File / Text | Attach `cover_letter.pdf` if requested or desired |
| **6** | **LinkedIn URL** | Optional | URL | `[Candidate LinkedIn URL]` |
| **7** | **Work Authorization** | **Yes** | Select / Boolean | `Authorized to work in [Country] without sponsorship` |
| **8** | **Location / State** | **Yes** | Autocomplete | `[City, State / Metro Region]` |
| **9** | **Salary Expectations** | **Yes** | Number / Text | `$[Target Base, e.g. 150000]` *(Aligns with floor/target from `workflows/ats_search_config.json`)* |
| **10** | **Custom Screening Question** | Optional | Text | *"[Pre-drafted concise answer highlighting verified Tier 1/2 experience]"* |

---

## 💡 Submission Strategy & Next Actions

1. **Warm Referral Check**:
   - Check [`network/contacts_ledger.md`](../../network/contacts_ledger.md). If a warm contact exists, request an internal referral before submitting cold through the public portal.
2. **Direct Submission**:
   - If applying directly, attach the verified 1-page PDF: `[Candidate_Name]_Resume_[Company]_[ReqID].pdf`.
3. **Explicit Confirmation**:
   - After submitting, tell your AI assistant: *"Submitted application for [Company]"*.
   - The assistant will update `applications/ledger.json` and freeze your application artifacts.
4. **Follow-Up Cadence**:
   - Set a calendar alarm for 5 business days post-submission to check application status or send a brief recruiter LinkedIn note.
