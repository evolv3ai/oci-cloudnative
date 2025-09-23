# CHANGELOG

2024-02-01 (v3.0.0)

- Replaced the MuShop demo stack with the two-server VibeStack Always Free architecture.
- Simplified networking into a single public VCN and subnet with recommended security rules.
- Added dedicated block volumes sized for the KASM (60 GB) and Coolify (100 GB) servers.

2022-02-08 (v2.1.0)

- Terraform OCI Provider Updated to the latest
- Oracle Digital Assistant support on the storefront
- Schema update

2021-07-28 (v2.0.1)

- Terraform OCI Provider Updated to the latest

2021-06-22 (v2.0.0)

- Updated to use Terraform 1.0.x
- Sensitive fields special treatment
- Terraform providers updated to use newer supported versions. (ORM now is supporting the latest)
- Removal of compatibility workarounds for old/deprecated TF providers

2021-06-09 (v1.3.0)

- Multi Architecture Stack (amd64 and Arm64)
- Auto selection of Compute Shapes based on the Architecture
- Deployment improvements
- Optimization of the assets inside the stack
- Apple Silicon local build support
- Schema improvements
