# Conditional Access Notes — Emergency Access Design

## Objective
Enforce MFA for all normal users while preserving a controlled emergency path for tenant recovery

## Production Policy Pattern (Microsoft recommended)
- Scope: **All users**
- Cloud apps: **All cloud apps**
- Grant: **Require multifactor authentication**
- Exclusion: **EmergencyAdmin break glass account (by object ID)**

Why: this keeps strong MFA enforcement for normal operations but avoids full tenant lockout during identity provider outages

## Lab Reality (Free Tier Constraint)
This lab currently runs on Entra free tier. Conditional Access policy authoring requires Entra ID P1, so I couldn't put the production policy above to be fully implemented on this tenant

Current workaround in lab:
- Security Defaults disabled to avoid blanket MFA lockout behavior
- Emergency access account maintained as a deliberate exception
- Rationale and controls documented in SOP

## Security Tradeoff
Disabling Security Defaults reduces baseline protections for all accounts
Because of that, this lab must demonstrate compensating controls:
- Strong unique password for EmergencyAdmin, stored offline only
- No daily use of emergency account
- Explicit post use checklist and audit review
- Immediate investigation for any emergency account sign in

## Validation Checklist
1. Confirm emergency account exists and is enabled
2. Confirm Global Administrator assignment is present
3. Confirm account is excluded from normal MFA enforcement strategy (production design note in this lab)
4. Confirm no credentials are stored in repository

## Rollback / Incident Response Notes
If emergency account is used:
1. Restore normal administrator access first
2. Rotate emergency account password immediately
3. Update sealed offline credential copy
4. Review sign in and audit logs for unauthorized actions
5. Record incident details and lessons learned

## Commands to Capture Demo Evidence

### PowerShell (copy/paste one line at a time)
```powershell
az --% account show --query "{Tenant:tenantId,User:user.name}" -o table
az --% ad user show --id EmergencyAdmin@<tenant>.onmicrosoft.com --query "{UPN:userPrincipalName,Enabled:accountEnabled,ObjectId:id}" -o table
az --% rest --method GET --url https://graph.microsoft.com/v1.0/directoryRoles --query "value[].{Role:displayName,RoleId:id}" -o table
```

### Bash / Git Bash
```bash
az account show --query "{Tenant:tenantId,User:user.name}" -o table
az ad user show --id "EmergencyAdmin@<tenant>.onmicrosoft.com" --query "{UPN:userPrincipalName,Enabled:accountEnabled,ObjectId:id}" -o table
az rest --method GET --url "https://graph.microsoft.com/v1.0/directoryRoles" --query "value[].{Role:displayName,RoleId:id}" -o table
```
