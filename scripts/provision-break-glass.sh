#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./provision-break-glass.sh --upn <user@tenant.onmicrosoft.com> [options]

Options:
  --display-name <name>     Display name (default: EmergencyAdmin)
  --tenant-id <tenantId>    Expected tenant ID safety check
  --create-if-missing        Create the account if it does not exist
  --password-env <VAR_NAME> Environment variable name containing password
                             (required only with --create-if-missing)
  -h, --help                Show help

Examples:
  ./provision-break-glass.sh --upn EmergencyAdmin@contoso.onmicrosoft.com
  BREAK_GLASS_PASSWORD='UseStrongPassword' \
  ./provision-break-glass.sh --upn EmergencyAdmin@contoso.onmicrosoft.com \
    --create-if-missing --password-env BREAK_GLASS_PASSWORD
EOF
}

UPN=""
DISPLAY_NAME="EmergencyAdmin"
EXPECTED_TENANT=""
CREATE_IF_MISSING="false"
PASSWORD_ENV=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --upn)
      UPN="${2:-}"
      shift 2
      ;;
    --display-name)
      DISPLAY_NAME="${2:-}"
      shift 2
      ;;
    --tenant-id)
      EXPECTED_TENANT="${2:-}"
      shift 2
      ;;
    --create-if-missing)
      CREATE_IF_MISSING="true"
      shift
      ;;
    --password-env)
      PASSWORD_ENV="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$UPN" ]]; then
  echo "Error: --upn is required." >&2
  usage
  exit 1
fi

if ! command -v az >/dev/null 2>&1; then
  echo "Error: Azure CLI (az) is required." >&2
  exit 1
fi

echo "Checking Azure CLI sign-in context..."
CURRENT_TENANT="$(az account show --query tenantId -o tsv 2>/dev/null | tr -d '\r' || true)"
if [[ -z "$CURRENT_TENANT" ]]; then
  echo "Error: Not signed in to Azure CLI. Run: az login" >&2
  exit 1
fi

if [[ -n "$EXPECTED_TENANT" && "$CURRENT_TENANT" != "$EXPECTED_TENANT" ]]; then
  echo "Error: Tenant mismatch. Current=$CURRENT_TENANT Expected=$EXPECTED_TENANT" >&2
  exit 1
fi

echo "Tenant verified: $CURRENT_TENANT"
echo "Looking up emergency account: $UPN"

USER_ID="$(az ad user show --id "$UPN" --query id -o tsv 2>/dev/null | tr -d '\r' || true)"

if [[ -z "$USER_ID" ]]; then
  if [[ "$CREATE_IF_MISSING" != "true" ]]; then
    echo "Account not found. Re-run with --create-if-missing to create it."
    exit 2
  fi

  if [[ -z "$PASSWORD_ENV" ]]; then
    echo "Error: --password-env is required with --create-if-missing." >&2
    exit 1
  fi

  PASSWORD_VALUE="${!PASSWORD_ENV:-}"
  if [[ -z "$PASSWORD_VALUE" ]]; then
    echo "Error: Environment variable '$PASSWORD_ENV' is empty or not set." >&2
    exit 1
  fi

  echo "Creating break-glass account..."
  az ad user create \
    --display-name "$DISPLAY_NAME" \
    --user-principal-name "$UPN" \
    --password "$PASSWORD_VALUE" \
    --force-change-password-next-sign-in false \
    --output none

  USER_ID="$(az ad user show --id "$UPN" --query id -o tsv | tr -d '\r')"
fi

echo "User object ID: $USER_ID"
echo "Checking Global Administrator role assignment..."

GA_ROLE_TEMPLATE_ID="62e90394-69f5-4237-9190-012177145e10"
GA_ROLE_ID="$(az rest --method GET --url "https://graph.microsoft.com/v1.0/directoryRoles" --query "value[?roleTemplateId=='$GA_ROLE_TEMPLATE_ID'] | [0].id" -o tsv | tr -d '\r')"

if [[ -z "$GA_ROLE_ID" ]]; then
  echo "Global Administrator directory role is not active; enabling it..."
  az rest \
    --method POST \
    --url "https://graph.microsoft.com/v1.0/directoryRoles" \
    --headers "Content-Type=application/json" \
    --body "{\"roleTemplateId\":\"$GA_ROLE_TEMPLATE_ID\"}" \
    --output none
  GA_ROLE_ID="$(az rest --method GET --url "https://graph.microsoft.com/v1.0/directoryRoles" --query "value[?roleTemplateId=='$GA_ROLE_TEMPLATE_ID'] | [0].id" -o tsv | tr -d '\r')"
fi

IS_MEMBER="$(az rest --method GET --url "https://graph.microsoft.com/v1.0/directoryRoles/$GA_ROLE_ID/members" --query "value[?id=='$USER_ID'] | length(@)" -o tsv | tr -d '\r')"
if [[ "$IS_MEMBER" == "0" ]]; then
  echo "Assigning Global Administrator role..."
  az rest \
    --method POST \
    --url "https://graph.microsoft.com/v1.0/directoryRoles/$GA_ROLE_ID/members/\$ref" \
    --headers "Content-Type=application/json" \
    --body "{\"@odata.id\":\"https://graph.microsoft.com/v1.0/directoryObjects/$USER_ID\"}" \
    --output none
  echo "Role assignment complete."
else
  echo "Role assignment already present."
fi

echo
echo "Verification output:"
az ad user show --id "$UPN" --query "{displayName:displayName,userPrincipalName:userPrincipalName,id:id,accountEnabled:accountEnabled}" -o table
echo
echo "Directory role memberships for $UPN:"
printf "%-32s %-38s\n" "RoleName" "RoleTemplateId"
printf "%-32s %-38s\n" "--------" "--------------"
FOUND_ROLE="false"
while IFS=$'\t' read -r role_id role_name role_template_id; do
  [[ -z "$role_id" ]] && continue
  member_count="$(az rest --method GET --url "https://graph.microsoft.com/v1.0/directoryRoles/$role_id/members" --query "value[?id=='$USER_ID'] | length(@)" -o tsv | tr -d '\r')"
  if [[ "$member_count" != "0" ]]; then
    printf "%-32s %-38s\n" "$role_name" "$role_template_id"
    FOUND_ROLE="true"
  fi
done < <(az rest --method GET --url "https://graph.microsoft.com/v1.0/directoryRoles" --query "value[].{id:id,name:displayName,template:roleTemplateId}" -o tsv | tr -d '\r')

if [[ "$FOUND_ROLE" == "false" ]]; then
  echo "(no directory roles found for this user)"
fi
echo
echo "Done. Store credentials offline and do not print or commit secrets."
