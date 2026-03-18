# Standard Operating Procedure: Emergency Access Account

**Document Type:** Security SOP  
**Author:** Alfred Gabriel  
**Last Reviewed:** March 2026  

---

## 1. Purpose

This document defines the procedures for managing
and using the Emergency Access account (also known as a break-glass account)
in the Azure and Entra ID tenant.

The emergency access account exists for one reason only: to restore administrative
access to the tenant if all normal administrator accounts are locked out. This is
not a day-to-day account. It is the last resort.

Here are some real situations where this account would be needed:

- Microsoft Authenticator or another MFA method goes down, making it impossible
  for standard admins to log in
- All other Global Administrator accounts are accidentally deleted or disabled
- A misconfigured policy locks every admin out of the tenant at the same time

---

## 2. Account Details

| Field | Value |
-------------------
| **Display Name** | EmergencyAdmin |
| **Account Type** | Cloud only (lives in Entra ID, not connected to any on premises system) |
| **Role Assigned** | Global Administrator |
| **MFA Required** | No, intentionally excluded |
| **Used for daily work** | Never |
| **Location** | Default Directory (our Entra ID tenant) |

---

## 3. Why MFA Is Turned Off for This Account

Every other account in this tenant is expected to use MFA. The emergency access
account is a deliberate exception, and here is the reasoning behind that decision.

MFA works by requiring a second verification step, usually through an app on your
phone or a physical security key. The problem is that if that second factor becomes
unavailable, such as during a Microsoft Authenticator outage, a lost phone, or a
broken security key, then even the administrator cannot get in. That creates a
situation where the tenant is completely locked out with no way back in.

The emergency access account removes that dependency on purpose. It can always
get in, regardless of whether MFA services are working or not.

**How this is currently implemented in my lab:**

Azure Security Defaults have been disabled for this tenant. Security Defaults is
a setting that forces MFA on every single account with no exceptions. Turning it
off removes that blanket enforcement.

This was a deliberate tradeoff. In a production environment, the correct approach
would be to use a Conditional Access policy instead. That policy would require MFA
for all users, but specifically exclude the emergency access account by its unique
Object ID. This is the Microsoft recommended approach.

Conditional Access requires an Entra ID P1 license. This lab runs on the free
tier, so that option is not available here. The design is documented below as the
intended production target.

**What the production policy would look like:**

```
IF:     Users = All Users
AND:    App = All Cloud Apps
THEN:   Require MFA

EXCEPT: Exclude EmergencyAdmin (identified by Object ID)
```

---

## 4. Credential Storage

The password for this account must never be stored in the same digital systems
it is meant to protect. If those systems go down or get compromised, a digitally
stored password would be inaccessible or exposed.

| Storage Method | Details |
-----------------------------
| Printed and sealed | Write the password down and seal it in an envelope |
| Physical safe | Store the envelope in a locked and physically secured location |
| Dual person access | In an enterprise setting, require two people to open it together |
| Not a password manager | Do not store this in LastPass, 1Password, or any cloud based tool |
| Not this repository | Never commit credentials to a code repository |

---

## 5. When To Use This Account

This account should only be used when all of the following are true:

- All standard Global Administrator accounts have been confirmed inaccessible
- The reason for the lockout has been clearly identified
- The decision to use this account has been approved by a manager or security lead

**This account should never be used for:**

- Everyday administration tasks
- Testing configurations or changes
- Browsing user data, emails, or files

---

## 6. How To Activate the Account

1. Retrieve the sealed credentials from their secure physical location
2. Open a private or incognito browser window so no session data is saved
3. Go to https://portal.azure.com
4. Sign in using the EmergencyAdmin credentials
5. Perform only the actions needed to restore normal administrator access
6. Sign out immediately once the issue is resolved
7. Return the credentials to their secure storage location
8. Complete every item in the Post Use Checklist in Section 7

---

## 7. Post Use Checklist

After every single use of this account, the following steps must be completed
within 24 hours. No exceptions.

- [ ] Write down the exact date and time the account was accessed
- [ ] Write down the reason it was needed
- [ ] Write down every action that was taken during the session
- [ ] Change the account password immediately
- [ ] Update the printed credentials in the physical safe with the new password
- [ ] Review the Azure audit logs to confirm nothing unexpected happened
- [ ] File an incident report if this is an enterprise environment

---

## 8. Monitoring and Alerting

Every sign in from this account should immediately notify the security team. This
matters because the emergency access account is never supposed to be used during
normal operations. If it is being used and nobody authorized it, that is a security
incident and needs to be treated as one right away.

**How alerting would be set up in production:**

```
Entra ID Sign in Logs
        |
        v
Log Analytics Workspace
        |
        v
Azure Monitor Alert Rule
(triggers when EmergencyAdmin signs in)
        |
        v
Email or SMS notification sent to security team
```

**Steps to build this:**

1. Create a Log Analytics Workspace in Azure Monitor
2. Go to Entra ID and open Diagnostic Settings
3. Forward the Sign in Logs to the Log Analytics Workspace
4. Create an alert rule that triggers when the userPrincipalName matches EmergencyAdmin

Why I cant do this:
- Forwarding sign in logs from Entra ID to Azure Monitor requires
    an Entra ID P1 license. This lab runs on the free tier, so this alerting pipeline
    has not been built yet. The design above represents the intended production setup.

For now, sign in activity can be checked manually at any time by going to
Entra ID, then Monitoring, then Sign in Logs, and filtering by the EmergencyAdmin
username.

---

## 9. Quarterly Review

This account needs to be reviewed every three months to make sure everything is
still in order. A lot can change in a tenant over time, and this account is too
important to leave unchecked.

- [ ] Confirm the account still exists and has not been disabled
- [ ] Confirm the Global Administrator role is still assigned
- [ ] Confirm the credentials in physical storage match the current password
- [ ] Check the audit logs for any sign in activity that was not authorized
- [ ] Confirm that no MFA methods have been added to the account

---

## 10. References

- Microsoft: Manage emergency access accounts in Entra ID
  https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/security-emergency-access

- Microsoft: Conditional Access, exclude emergency accounts from MFA
  https://learn.microsoft.com/en-us/entra/identity/conditional-access/howto-conditional-access-policy-all-users-mfa

- NIST SP 800 53: AC 2 Account Management
  https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final
