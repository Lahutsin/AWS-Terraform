# Platform Phase

This phase runs after the bootstrap phase in the repository root.

It configures:

- IAM Identity Center permission sets and account assignments
- central log archive, KMS, and organization CloudTrail
- AWS Config aggregator and Security Hub baseline
- workload IAM roles and sample tagged resources for ABAC

Before running it, make sure you have:

- existing account IDs from the bootstrap outputs
- bootstrap roles in the audit, log archive, shared services, and workload accounts
- IAM Identity Center enabled