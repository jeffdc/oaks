# Oaks infrastructure (OpenTofu)

The AWS resources the site uses, managed with OpenTofu. Everything is in `us-east-1`, next to Fly's `iad` region. Fly itself is not managed here: the app is configured by `fly.toml` and its secrets by `fly secrets`.

## Resources

### Litestream backups (`main.tf`)

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

### Species photos (`s3.tf`, `cloudfront.tf`, `acm.tf`, `iam.tf`)

Photos are stored in a private bucket and served only through CloudFront on `https://images.oakcompendium.org`. Created by tofu in November 2026.

| Resource | Name | What |
|---|---|---|
| `aws_s3_bucket.images` | `oaks-images` | Originals and size variants, at paths unique per import attempt |
| `aws_s3_bucket_versioning.images` | | Versioning on, so a deleted photo's files can be recovered for 30 days |
| `aws_s3_bucket_lifecycle_configuration.images` | | Expires noncurrent versions 30 days after they become noncurrent, removes expired delete markers, aborts multipart uploads after 7 days. Live objects never expire |
| `aws_s3_bucket_public_access_block.images` | | All public access blocked |
| `aws_s3_bucket_policy.images` | | Only the distribution may `s3:GetObject` (Origin Access Control); missing objects are a 403 |
| `aws_acm_certificate.images` | `images.oakcompendium.org` | DNS-validated in us-east-1, renews automatically while its validation CNAME stays at Porkbun |
| `aws_cloudfront_origin_access_control.images` | `oaks-images` | Signs CloudFront's requests to the bucket |
| `aws_cloudfront_cache_policy.images` | `OaksImages` | One-year edge TTL; nothing but the path in the cache key |
| `aws_cloudfront_distribution.images` | `E1GM6FGGDJPT7E` | Alias `images.oakcompendium.org`, HTTPS only (plain HTTP is a 403), TLS 1.2 minimum, GET and HEAD |
| `aws_iam_user.images_upload` | `oaks-images-upload` | The user the app signs in as for photos |
| `aws_iam_policy.images_upload` | `OaksImagesUpload` | Put and delete objects, list the bucket, create and get invalidations on this distribution. No read: the app never reads photos back from S3 |

DNS for `oakcompendium.org` is at Porkbun, outside tofu. It holds two records for photos: the certificate's validation CNAME (`tofu output images_cert_validation`) and `images` CNAME to the distribution (`tofu output images_distribution_domain`). Keep both.

The upload user's access key is not managed by tofu, so its secret never enters state. To issue one, create it with `aws iam create-access-key --user-name oaks-images-upload` and send it straight into Fly secrets without saving or printing it; delete the old key once the app runs on the new one.

#### Smoke test (2026-11-24)

Run with a throwaway key for `oaks-images-upload`, deleted afterwards:

- Put `smoke-test/phase1.txt` with the upload key: stored as a new version.
- `GET https://images.oakcompendium.org/smoke-test/phase1.txt`: 200, a Miss then a Hit from CloudFront.
- The same object straight from S3 (`https://oaks-images.s3.amazonaws.com/...`): 403. Over plain HTTP: 403. `https://images.oakcompendium.org/`: 403, no listing.
- The upload key cannot get objects (AccessDenied) and can list the bucket.
- After deleting the object, the CDN still served it (200) until an invalidation of its path, made with the upload key, completed. After that a fresh request was a 403.
- The bucket's lifecycle shows the three rules above; its public access block is all on.

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
