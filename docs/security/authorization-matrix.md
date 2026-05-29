# Authorization Matrix

Roles:

- `owner`: full tenant administration and fiscal operations
- `admin`: team and fiscal operations, except bootstrap-only owner creation
- `operator`: daily profile, customer, and invoice operations
- `auditor`: read-only operational and fiscal visibility

| Permission | owner | admin | operator | auditor |
| --- | --- | --- | --- | --- |
| `organizations_read` | Yes | Yes | Yes | Yes |
| `memberships_list` | Yes | Yes | Yes | Yes |
| `memberships_create` | Yes | Yes | No | No |
| `memberships_update` | Yes | Yes | No | No |
| `memberships_rotate_token` | Yes | Yes | No | No |
| `memberships_revoke_token` | Yes | Yes | No | No |
| `fiscal_profiles_list` | Yes | Yes | Yes | Yes |
| `fiscal_profiles_read` | Yes | Yes | Yes | Yes |
| `fiscal_profiles_create` | Yes | Yes | No | No |
| `fiscal_profiles_update` | Yes | Yes | No | No |
| `customers_list` | Yes | Yes | Yes | Yes |
| `customers_read` | Yes | Yes | Yes | Yes |
| `customers_create` | Yes | Yes | Yes | No |
| `customers_update` | Yes | Yes | Yes | No |
| `service_invoices_list` | Yes | Yes | Yes | Yes |
| `service_invoices_read` | Yes | Yes | Yes | Yes |
| `service_invoices_create` | Yes | Yes | Yes | No |
| `service_invoices_issue` | Yes | Yes | Yes | No |
| `service_invoices_cancel` | Yes | Yes | Yes | No |
| `service_invoices_poll_status` | Yes | Yes | Yes | No |
