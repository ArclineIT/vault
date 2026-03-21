# arcline-vault

Self-hosted encrypted secrets store. AES-256-GCM encrypted key-value pairs organized by environment, exposed via a REST API and CLI. No HashiCorp Vault complexity, no SaaS subscription.

Solves the `.env` file problem for small teams without sending secrets to a third party.

## Status

Planned. Not yet started.

## Stack

- Go — REST API server + CLI client in one binary
- SQLite for storage (encrypted at rest)
- AES-256-GCM with envelope encryption (master key per server, data key per secret)
- Auth: API key (bearer token, stored as bcrypt hash)
- Transport: HTTPS only

## Usage

```sh
# Start the server
arcline-vault server --config vault.yaml

# Manage secrets
arcline-vault set DATABASE_URL "postgres://..." --env production
arcline-vault get DATABASE_URL                  --env production
arcline-vault list                              --env production
arcline-vault delete DATABASE_URL              --env production
arcline-vault export --env production > .env
arcline-vault import .env --env production
```

## Security model

- Master key loaded from environment variable only — never written to disk
- Each secret encrypted with its own data key, wrapped by the master key
- API keys stored as bcrypt hashes; plaintext never stored after creation
- Full audit log: timestamp, API key prefix, action, secret name
- Read-only API keys supported

## Config

```yaml
listen: "0.0.0.0:8200"
tls:
  cert: /etc/ssl/arcline-vault/cert.pem
  key:  /etc/ssl/arcline-vault/key.pem
database: /var/lib/arcline-vault/vault.db
master_key_env: VAULT_MASTER_KEY    # 32-byte hex
```

See [todo.md](todo.md) for the full task list, API reference, and threat model notes.

## License

Apache 2.0 — see [LICENSE](LICENSE).
