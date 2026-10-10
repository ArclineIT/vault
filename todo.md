# arcline-vault — Self-Hosted Encrypted Secrets Store

AES-256-GCM encrypted key-value store for small teams. REST API + CLI.
Solves "where do I put my .env files" without paying for HashiCorp Vault or Doppler.

## Stack
- Ruby on Rails 8.1 (API only) + SQLite
- Encryption: AES-256-GCM, envelope encryption (master key → data key per secret)
- Auth: API key (bearer token, stored as bcrypt hash)
- Transport: HTTPS only
- CLI: one dependency-free Ruby file (`bin/arcline-vault`)

## Done
- [x] Rails app (replaces the planned Go server)
- [x] Schema: environments, secrets, api_keys, grants, audit log
- [x] Encryption layer (AES-256-GCM, envelope encryption, bound to environment and name)
- [x] Master key loading and validation on startup
- [x] REST API: environments, secrets, export (.env and JSON), import
- [x] API key authentication (bearer token → bcrypt verify, constant time)
- [x] Keys scoped to environments, and read-only keys
- [x] CLI client (reads VAULT_URL + VAULT_TOKEN)
- [x] .env import parser and writer
- [x] Audit log, with an API endpoint and a rake task
- [x] Master key rotation and a verify task
- [x] README: security model, key rotation guide, nginx reverse proxy config

## Ideas
- [ ] Secret versions, with rollback to the previous value
- [ ] Expiring API keys
- [ ] Manage API keys over the API with a separate root credential
- [ ] Web UI behind Nexus sign-in
- [ ] Package the CLI as a gem
- [ ] Encrypt names and descriptions too
