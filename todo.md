# arcline-vault — Self-Hosted Encrypted Secrets Store

AES-256-GCM encrypted key-value store for small teams. REST API + CLI.
Solves "where do I put my .env files" without paying for HashiCorp Vault or Doppler.

## Stack
- Language: Go
- Storage: SQLite (encrypted at rest)
- Encryption: AES-256-GCM (envelope encryption — master key → data key per secret)
- Auth: API key (bearer token, stored as bcrypt hash)
- Transport: HTTPS only (TLS cert via Let's Encrypt or provided cert)

## Concepts
- **Secret** — a named key-value pair (name, value, description, tags)
- **Environment** — a namespace grouping secrets (e.g. `production`, `staging`)
- **API key** — bearer token granting access to one or more environments

## REST API
```
GET    /v1/envs                       # list environments
POST   /v1/envs                       # create environment

GET    /v1/envs/{env}/secrets         # list secret names (values redacted)
POST   /v1/envs/{env}/secrets         # create/update secret
GET    /v1/envs/{env}/secrets/{name}  # get single secret value
DELETE /v1/envs/{env}/secrets/{name}  # delete secret

GET    /v1/envs/{env}/export          # export as .env format
GET    /v1/envs/{env}/export?format=json
```

## CLI interface
```
arcline-vault server --config vault.yaml        # start the server

arcline-vault set DATABASE_URL "postgres://..."  --env production
arcline-vault get DATABASE_URL                   --env production
arcline-vault list                               --env production
arcline-vault delete DATABASE_URL                --env production
arcline-vault export --env production > .env    # dump to .env file
arcline-vault import .env --env production      # load from .env file
```

## Config (vault.yaml)
```yaml
listen: "0.0.0.0:8200"
tls:
  cert: /etc/ssl/arcline-vault/cert.pem
  key:  /etc/ssl/arcline-vault/key.pem
database: /var/lib/arcline-vault/vault.db
master_key_env: VAULT_MASTER_KEY    # 32-byte hex, set via environment
```

## Security model
- Master key loaded from environment variable (never stored on disk)
- Each secret encrypted with its own data key (wrapped by master key)
- API keys stored as bcrypt hashes — server never sees plaintext key again
- All access logged (timestamp, API key prefix, action, secret name)
- Read-only API keys supported (read-only flag on key)

## Tasks
- [ ] Project scaffold
- [ ] SQLite schema (environments, secrets, api_keys, audit_log)
- [ ] Encryption layer (AES-256-GCM, envelope encryption)
- [ ] Master key loading + validation on startup
- [ ] REST API server (net/http or chi router)
- [ ] API key middleware (bearer token → bcrypt verify)
- [ ] Environment CRUD handlers
- [ ] Secret CRUD handlers
- [ ] Export endpoint (.env + JSON formats)
- [ ] CLI client (reads VAULT_URL + VAULT_TOKEN env vars)
- [ ] .env import parser
- [ ] TLS setup (provided cert or ACME)
- [ ] Audit log
- [ ] Read-only API key support
- [ ] systemd unit file
- [ ] README: threat model, key rotation guide, nginx reverse proxy config
- [ ] Cross-compile Makefile
