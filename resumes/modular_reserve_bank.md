# 🧩 Modular Tailoring Reserve Bank

> **Purpose**: A categorized reserve of specialized, verified alternative resume bullets. Because a resume must fit strictly on **1 page**, your Master Resume cannot display every single accomplishment or specialized tool simultaneously. When tailoring for a specific job posting with unique requirements (e.g. distributed queues, regulatory compliance, multi-provider LLM routing, cloud cost optimization, clinical operations), pull bullets from this bank to swap into your tailored resume.
> 
> 🛡️ **Integrity Rule**: All bullets in this bank are considered part of your verified factual whitelist by `scripts/lint_resume_integrity.ps1`.

---

## 📂 Category 1: [Specialized Architecture, Infrastructure, or Domain A]

### [Focus Area / Sub-Discipline 1]
- **[Keyword / Theme]**: [Draft a high-impact, 2-line bullet following: `[Strong Action Verb]` + `[Problem Solved / Scope]` + `[Tools / Methodology]` + `[Quantifiable Result]`].
- **[Keyword / Theme]**: [Draft secondary specialized bullet].

### [Focus Area / Sub-Discipline 2]
- **[Keyword / Theme]**: [Draft bullet].

---

## 📂 Category 2: [Operations, Process Optimization, or Domain B]

### [Focus Area / Sub-Discipline 1]
- **[Keyword / Theme]**: [Draft bullet detailing operational scaling, P&L management, or cross-functional alignment].
- **[Keyword / Theme]**: [Draft bullet].

---

## 📂 Category 3: [Recent R&D, Side Projects, or Modern Tooling]

### [Project Name / Modern Initiative]
- **[Keyword / Theme]**: [Draft bullet extracted via `workflows/project_ingestion_prompt.md` highlighting modern tools and rapid prototyping].

---

## 🤖 How to Direct Your AI Assistant to Use This Bank:

When you drop a job description into chat, prompt your assistant:

> *"Tailor my resume for this requisition. If the JD strongly emphasizes [Target Competency, e.g. distributed event streaming or clinical trial budgeting], check `resumes/modular_reserve_bank.md` and swap in relevant reserve bullets to replace less relevant bullets while keeping the PDF strictly to 1 page."*
