# Customer Rules Security Audit

```json
{
  "score": 5,
  "summary": "The v1 server-only baseline denies every Firebase client read and write, while service-account access remains governed by IAM outside Firebase Rules. No deployment is offered until the cross-project client principal decision is settled.",
  "findings": []
}
```

The score covers the current deny-by-default baseline only. It must be audited
again if a future decision introduces direct Flutter client access, role-aware
reads, or any client write path.

The server-only decision is now settled. IAM grants are outside Firebase Rules
and are documented in `customer_server_access.md`; the rules score remains 5
because no client permission was introduced. Deployment to active ARM customer
projects remains disabled until server ingress and query endpoints replace
direct client writes and reads.
