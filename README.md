# Arcline Vault

Self-hosted encrypted secrets store. Named values, grouped by environment,
encrypted with AES-256-GCM and served over a REST API with a small
command-line client. It solves the `.env` file problem for a small team without
sending secrets to a third party or running HashiCorp Vault.

This was planned as a Go server and is built instead as an API-only Ruby on
Rails app. The command-line client is a single Ruby file with no dependencies.

## Quick start

```bash
bin/setup --skip-server
bin/rails vault:generate_key              # prints a master key
echo "VAULT_MASTER_KEY=<that key>" > .env
NAME=admin bin/rails vault:keys:create    # prints an API token, once
bin/rails server -p 8200
```

Then, from any machine with Ruby:

```sh
export VAULT_URL=https://vault.arcline.it
export VAULT_TOKEN=av_...

arcline-vault set DATABASE_URL "postgres://..." --env production
arcline-vault get DATABASE_URL                  --env production
arcline-vault list                              --env production
arcline-vault delete DATABASE_URL               --env production
arcline-vault export --env production > .env
arcline-vault import .env --env production
arcline-vault envs
arcline-vault create-env staging
```

The client is `bin/arcline-vault`. Copy that one file wherever it is needed.
`--env` defaults to `VAULT_ENV`. Pass `-` as the value to `set`, or as the file
to `import`, to read from standard input, which keeps a secret out of your
shell history. The client refuses to send a token over plain `http` except to
localhost.

## Concepts

- **Secret**: a named value with an optional description and tags.
- **Environment**: a namespace for secrets, such as `production` or `staging`.
- **API key**: a bearer token. It reaches every environment or only the ones
  granted to it, and may be read-only.

## REST API

Every request needs `Authorization: Bearer <token>`. Errors are JSON:
`{"error": "..."}`.

```
GET    /v1/envs                         list environments the key can reach
POST   /v1/envs                         create an environment        {"name": "staging"}
DELETE /v1/envs/{env}                   delete an environment and its secrets

GET    /v1/envs/{env}/secrets           list secret names (never values)
POST   /v1/envs/{env}/secrets           create or replace a secret   {"name", "value", "description", "tags"}
GET    /v1/envs/{env}/secrets/{name}    read one secret's value
DELETE /v1/envs/{env}/secrets/{name}    delete a secret

GET    /v1/envs/{env}/export            every secret as a .env file
GET    /v1/envs/{env}/export?format=json
POST   /v1/envs/{env}/import            load a .env file sent as the body; all or nothing

GET    /v1/audit?limit=100              the access log
```

Creating or deleting environments and reading the audit log need a key that is
not read-only and reaches all environments. A key that cannot reach an
environment gets `404`, the same answer as for one that does not exist.

## API keys

Keys are managed on the server, not over the API:

```bash
NAME=admin bin/rails vault:keys:create                              # everything
NAME=deploy ENVS=production bin/rails vault:keys:create             # one environment
NAME=ci ENVS=production,staging READ_ONLY=1 bin/rails vault:keys:create
bin/rails vault:keys:list
PREFIX=ab12cd34 bin/rails vault:keys:revoke
```

A token looks like `av_ab12cd34_…`. It is printed once. The server keeps only a
bcrypt hash and the eight-character prefix, which is what the audit log and
`keys:list` show.

## Security model

- **Envelope encryption.** Each value is encrypted with AES-256-GCM under a
  random key of its own. That key is encrypted under the master key. Both are
  bound to the secret's environment and name, so a row copied onto another
  secret will not decrypt, and any altered byte is detected.
- **The master key is never stored.** It is read from `VAULT_MASTER_KEY`. In
  production the server will not start without a valid one.
- **Names are not encrypted.** Secret names, descriptions and tags are stored
  as plain text so they can be listed. Do not put anything sensitive in them.
- **Audit log.** Every read, write, export, denied request and failed login is
  recorded with the time, key prefix, action, environment, secret name and
  client address. Values are never recorded, and they are filtered from the
  application log.
- **HTTPS only.** Production forces TLS. Run it behind a TLS-terminating proxy.
- Requests are limited to 120 a minute per client.

### What this does not protect against

- Someone who has both the database and the master key. Store and back them up
  separately.
- Someone with access to the running server's memory or environment.
- A leaked API token, until it is revoked. Give each consumer its own key,
  scope it to the environments it needs, and make it read-only where possible.

### Rotating the master key

```bash
bin/rails vault:generate_key                               # the new key
VAULT_NEW_MASTER_KEY=<new> bin/rails vault:rotate_master_key
# set VAULT_MASTER_KEY to the new key, restart, then:
bin/rails vault:verify
```

Rotation re-encrypts each secret's key, not the values, so it is quick. It runs
in one transaction. Take a database backup first: the old key cannot read the
database afterwards.

`bin/rails vault:verify` checks at any time that every secret decrypts with
the current master key.

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `PORT` | `3000` | HTTP listen port (the original design used `8200`) |
| `DATABASE_PATH` | `storage/<env>.sqlite3` | SQLite database file |
| `VAULT_MASTER_KEY` | — | 64 hexadecimal characters (32 bytes). Required |

## Reverse proxy

```nginx
server {
    listen 443 ssl;
    server_name vault.arcline.it;

    ssl_certificate     /etc/ssl/arcline-vault/cert.pem;
    ssl_certificate_key /etc/ssl/arcline-vault/key.pem;

    location / {
        proxy_pass http://127.0.0.1:8200;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
```

## Tests

```bash
bin/rails test
bin/rubocop
bin/brakeman
```

## Deployment

The app ships with a `Dockerfile` and a Kamal config (`config/deploy.yml`).
The SQLite database lives in `storage/`, which is mounted as a volume. Pass
`VAULT_MASTER_KEY` as a Kamal secret.

## License

Apache 2.0. See [LICENSE](LICENSE).
