# Network & Referral Contacts Ledger

> **Purpose**: Maintain an organized registry of 1st-degree connections, former colleagues, leaders, and mentors across target organizations to secure warm internal referrals.

---

## 🎯 Target Companies — Direct Referral Paths

| Organization | Contact Name | Current Title / Role | Relationship / History | LinkedIn Profile | Strategic Action / Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| *Acme Corp* | *Jane Doe* | *Director of Operations* | *Former colleague* | [Profile](https://linkedin.com) | *Warm referral check queued* |

---

## 🏛️ Former Colleagues & Alumni Network

Group your key connections by previous organizations, universities, or professional communities:

### Previous Organization A
- **[Contact Name]** — *[Current Title] @ [Company]* | [LinkedIn Profile](https://linkedin.com)
- **[Contact Name]** — *[Current Title] @ [Company]* | [LinkedIn Profile](https://linkedin.com)

### Previous Organization B
- **[Contact Name]** — *[Current Title] @ [Company]* | [LinkedIn Profile](https://linkedin.com)

---

## 📥 How to Import LinkedIn Connections (Optional)

> [!NOTE]
> **Feel free to skip this during onboarding!** You can manually enter high-trust contacts above anytime, or import your network file later. Your command center is fully functional without it.

If you want ACE to automatically map your network against target employers:

1. **Request the Export from LinkedIn**:
   - In LinkedIn, click your profile picture at the top right $\rightarrow$ **Settings & Privacy**.
   - In the left sidebar, click **Data privacy**.
   - Under *How LinkedIn uses your data*, click **Get a copy of your data**.
   - Select the second radio button: **"Want something in particular? Select the data files you're most interested in."**
   - Check the **Connections** box only (uncheck everything else for a fast export).
   - Click **Request archive** and enter your password.
2. **Download the File**:
   - LinkedIn will generate the archive and email you a download link (typically takes 10–15 minutes).
   - Download the zip and extract `Connections.csv`.
3. **Run the Network Parser**:
   - Place `Connections.csv` into this `network/` folder.
   - Run `powershell -File scripts/parse_connections.ps1` (or ask your AI agent: *"Parse my LinkedIn connections"*).
   - Your agent will surface your connections at premier and target employers.
