# Azure Identity & Security Lab

> A hands on lab demonstrating enterprise grade Identity & Access Management (IAM) and
> security hardening practices on Microsoft Azure / Entra ID  managed entirely through
> code (Azure CLI & PowerShell)

---

## Purpose

This lab is made to demonstrate real world cloud identity security skills using Azure CLI and PowerShell, creating an emergency account through EntraID

**Core competencies demonstrated:**

| Pillar | What's Covered |
------------------------------
| Identity Management | User provisioning and Entra ID role assignments via CLI/PowerShell |
| Security Hardening | Emergency access account design and MFA exclusion rationale |
| Governance | Standard Operating Procedures (SOPs) and audit trail documentation |
| Infrastructure-as-Code | Repeatable script driven configuration |

---

## Lab Components

### Phase 1: Emergency Access ("Break Glass")

A dedicated **Global Administrator break glass account** has been provisioned following
Microsofts emergency access best practices.

- Provisioned via **Azure CLI** (documented, repeatable)
- Intentionally **excluded from standard MFA policy scope** in production design
- Credentials stored offline per the SOP (see [`docs/break-glass-sop.md`](docs/break-glass-sop.md))
- Account purpose: regain tenant access if all normal admin accounts are locked out

### Phase 2: Identity Governance Automation

- `scripts/provision-break-glass.sh` validates/creates break glass account state
- `scripts/assign-roles.ps1` assigns, removes, and lists Entra ID directory role memberships
- `policies/conditional-access-notes.md` documents production policy target and lab tradeoffs

> **Why exclude it from MFA?**
> If your Identity Provider (e.g., Authenticator app, FIDO2 key) experiences an outage,
> standard MFA enforced accounts become inaccessible locking you out of your own tenant
> The break glass account deliberately bypasses this dependency. It is not for day to day
> use. Its use must be logged, alerted on, and reviewed after every activation

---

## 📁 Repository Structure

```
Azure-Identity-Lab/
├── README.md                   - You are here
├── docs/
│   └── break-glass-sop.md      - Standard Operating Procedure for Emergency Access
├── scripts/
│   ├── provision-break-glass.sh    - Azure CLI: Emergency account provisioning
│   └── assign-roles.ps1            - PowerShell: Role assignment automation
└── policies/
    └── conditional-access-notes.md - CA policy design decisions
```


---
## Prerequisites

```bash
# Verify Azure CLI is installed and authenticated
az --version
az account show

# Verify PowerShell Az module (if using PS scripts)
Get-Module -Name Az -ListAvailable
```

---

## Getting Started

```bash
# Clone / open the lab root
cd C:\dev\Azure-Identity-Lab

# Authenticate to Azure
az login

# Confirm target tenant
az account show --query "{Tenant:tenantId, Subscription:name}" -o table
```

---

## Script Usage

```bash
# Validate or create break-glass account (Bash + Azure CLI)
cd C:\dev\Azure-Identity-Lab\scripts
./provision-break-glass.sh --upn EmergencyAdmin@<tenant>.onmicrosoft.com
```

```powershell
# Assign Global Administrator role by template ID
cd C:\dev\Azure-Identity-Lab\scripts
.\assign-roles.ps1 -Action Assign `
  -UserPrincipalName "EmergencyAdmin@<tenant>.onmicrosoft.com" `
  -RoleTemplateId "62e90394-69f5-4237-9190-012177145e10"
```

```powershell
# List role memberships for a user
.\assign-roles.ps1 -Action List -UserPrincipalName "student@<tenant>.onmicrosoft.com"
```

---

## Security Notes

- **No secrets or credentials are stored in this repository
- Break glass account credentials are stored offline only (printed, sealed envelope
  in a physically secured location) per Microsoft's recommended guidance (I wanted to follow it as closely as I could lol)
- All scripts use least privilege principles where possible; the break glass account
  is the only account with standing Global Admin rights
- Any activation of the break glass account should trigger an Azure Monitor alert
  and be reviewed within 24 hours

---

## 📚 Reference

- [Microsoft: Manage emergency access accounts in Azure AD](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/security-emergency-access)
- [Microsoft: Conditional Access — exclude emergency accounts](https://learn.microsoft.com/en-us/entra/identity/conditional-access/howto-conditional-access-policy-all-users-mfa)
- [NIST SP 800-53: AC-2 Account Management](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final)

---
