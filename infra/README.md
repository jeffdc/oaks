# Oaks infrastructure (OpenTofu)

The AWS resources the site uses, managed with OpenTofu. Everything is in `us-east-1`, next to Fly's `iad` region. Fly itself is not managed here: the app is configured by `fly.toml` and its secrets by `fly secrets`.

## Resources

| Resource | Name | What |
|---|---|---|
| `aws_s3_bucket.litestream_backups` | `oaks-db-backups` | Litestream replication of `/data/oaks.db` (prefix `litestream/`, see `litestream.yml`) |
| `aws_s3_bucket_versioning.litestream_backups` | | Versioning never enabled (`Disabled`); Litestream keeps its own generations |
| `aws_s3_bucket_lifecycle_configuration.litestream_backups` | | Expires objects after 30 days |
| `aws_s3_bucket_public_access_block.litestream_backups` | | All public access blocked |
| `aws_iam_user.litestream` | `litestream-oaks` | The user Litestream signs in as |
| `aws_iam_policy.litestream_backup` | `LitestreamOaksBackup` | Get, put, delete and list on the backups bucket only |
| `aws_iam_user_policy_attachment.litestream` | | Attaches the policy to the user |
| `aws_iam_access_key.litestream` | | Litestream's key, in Fly secrets as `LITESTREAM_ACCESS_KEY_ID` and `LITESTREAM_SECRET_ACCESS_KEY` |

These were made by hand in February 2026 and imported into state in November 2026. An imported access key has no secret in state; the secret exists only in Fly secrets. If the key is ever replaced through tofu, read the new secret with `tofu output -raw litestream_secret_access_key` (after adding that output back) and set both Fly secrets.

### State

State is in the S3 bucket `oaks-terraform-state`, key `infra/terraform.tfstate`, locked with an S3 lock file (`use_lockfile`). The bucket was made by hand, outside tofu: versioned (so an old state can be recovered), encrypted with SSE-S3, all public access blocked.

## Running tofu

Run tofu inside the Nix dev shell, which pins its version (`flake.nix`), with AWS credentials for the account in your environment (for example `aws login`).

```bash
cd infra
tofu init      # once per checkout, and after a provider change
tofu plan      # should show "No changes" unless you changed a .tf file
tofu apply     # review the plan it prints before answering yes
```

`.terraform.lock.hcl` is committed and pins the AWS provider with hashes for macOS (arm64) and Linux (amd64). After changing the provider version, run `tofu init -upgrade`, then `tofu providers lock -platform=darwin_arm64 -platform=linux_amd64` and commit the lock file.

To bring an existing resource under management, add an `import` block for it, check with `tofu plan` that it imports with no changes, apply, then delete the block.
