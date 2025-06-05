aws organizations list-create-account-status \
  --states SUCCEEDED \
  --output json \
| jq -r '.CreateAccountStatuses[]
         | select(.GovCloudAccountId != null)
         | "\(.AccountId),\(.GovCloudAccountId)"'
