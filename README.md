# deploy-stratos

This is part of [cloud.gov](https://cloud.gov/), the deployment pipeline for
[Stratos Console](https://github.com/cloudfoundry/stratos).

---

## Pipeline overview

The Concourse pipeline in [`ci/pipeline.yml`](ci/pipeline.yml) builds and
deploys Stratos 5.x to dev, staging, and production:

```
compile-stratos-v5
  └── deploy-dev-v5
        └── deploy-staging-v5
              └── deploy-production-v5
```

The build pulls from `cloudfoundry/stratos` (upstream), applies cloud.gov
theming from the [`theming/`](theming/) folder, and packages the result as a
CF-pushable zip using `make build release cf`.

---

## Theming

The v5 deployment is themed entirely through files in the
[`theming/`](theming/) folder — no changes to the upstream Stratos source are
required. The pipeline copies these files into the Stratos build tree before
compilation.

### What lives in `theming/`

```
theming/
├── company-config.json          # all branding: colors, fonts, styles, names
└── assets/
    ├── core/
    │   ├── logo.png             # main logo
    │   └── nav-logo.png         # left-nav logo
    └── favicon.ico              # browser tab icon
```

### `company-config.json`

This is the Stratos 5.x runtime branding config. It configures **all of the
colors, fonts, and styles**, plus the app/company name, login page, navigation,
layout, and footer. It is served at `/assets/company-config.json` and applied
by the theme package at runtime. Top-level sections:

| Section        | Configures                                              |
|----------------|---------------------------------------------------------|
| `company`      | Company / application name and display name             |
| `theme`        | Brand colors (primary/secondary/accent, etc.)           |
| `navigation`   | Left-nav colors and styling                             |
| `layout`       | Page background/text and header colors                  |
| `login`        | Login page title/subtitle, logo, background             |
| `footer`       | Footer text / copyright                                 |
| `logos`        | Paths to the logo / nav-logo / favicon assets           |
| `defaults`     | Default UI preferences (theme mode, sidenav, etc.)      |

To change the theme: edit the files in `theming/`, commit (GPG-signed), push to
the `v3` branch, and the pipeline will pick up the change and rebuild.

### Build-time settings

Build-time settings that are not part of the runtime theme live in
[`stratos.yaml`](stratos.yaml):

- `title` — browser tab / window title baked into the build
- `packages.exclude` — packages removed from the build entirely (e.g.
  `@stratosui/kubernetes` to hide the Workloads/Helm nav items)

---

## Local development build

These instructions are for cloud.gov team members who want to build and test
Stratos 5.x locally or deploy to a personal sandbox.

### Prerequisites

- Go 1.26+ (`go version`)
- Node 26.x via nvm (`nvm install 26`)
- Bun 1.3+ (`curl -fsSL https://bun.sh/install | bash`)
- CF CLI v8 (`cf version`)
- `uaac` gem (`gem install cf-uaac`)
- Access to a cloud.gov org/space
- Access to the cloud.gov UAA admin credentials (to create a UAA client)

### 1. Clone and configure

```bash
git clone https://github.com/cloudfoundry/stratos.git
cd stratos

# Apply cloud.gov theming
cp /path/to/cg-deploy-stratos/stratos.yaml ./stratos.yaml
cp /path/to/cg-deploy-stratos/theming/company-config.json \
   src/frontend/packages/theme/company-config.json
cp /path/to/cg-deploy-stratos/theming/assets/core/logo.png \
   src/frontend/packages/core/assets/logo.png
cp /path/to/cg-deploy-stratos/theming/assets/core/nav-logo.png \
   src/frontend/packages/core/assets/nav-logo.png
cp /path/to/cg-deploy-stratos/theming/assets/favicon.ico \
   src/frontend/packages/core/favicon.ico
```

### 2. Install dependencies and build

```bash
# Install frontend and backend dependencies
bun install

# Regenerate the extension module from stratos.yaml (applies packages.exclude)
node build/extension-generator.mjs \
  --output src/frontend/packages/core/src/custom-import.module.ts
node build/extension-generator.mjs \
  --output src/frontend/packages/core/src/_custom-import.module.ts

# Build frontend + backend and package as a CF-pushable zip
make build release cf
# Output: dist/stratos-cf-<version>.zip
```

### 3. Create a UAA client

Stratos requires a UAA client with the `authorization_code` grant type and SSO
configured. Replace `<your-initials>` and `<route>` with your sandbox values.

```bash
# Target the UAA for your environment
uaac target https://uaa.<system-domain>

# Authenticate as admin
uaac token client get admin -s <uaa-admin-client-secret>

# Create the Stratos UAA client
uaac client add stratos-<your-initials> \
  --name "Stratos <your-initials>" \
  --secret <choose-a-client-secret> \
  --authorized_grant_types "authorization_code,client_credentials,refresh_token" \
  --redirect_uri "https://<route>/pp/v1/auth/sso_login_callback" \
  --scope "cloud_controller.admin_read_only,cloud_controller.global_auditor,openid,\
routing.router_groups.write,network.write,scim.read,cloud_controller.admin,\
uaa.user,cloud_controller.read,password.write,routing.router_groups.read,\
cloud_controller.write,stratos.admin,network.admin,doppler.firehose,scim.write" \
  --autoapprove true \
  --access_token_validity 600 \
  --refresh_token_validity 43200
```

> **Note:** The `redirect_uri` must exactly match the route you will use to
> access Stratos. If the URI doesn't match, UAA will reject the login with
> "Invalid redirect ... did not match one of the registered values".

### 4. Create a database service

```bash
cf target -o <your-org> -s <your-space>

cf create-service aws-rds medium-psql stratos-db-<your-initials>
# RDS provisioning takes several minutes — wait until the service is ready:
cf service stratos-db-<your-initials>
```

### 5. Create `manifest.yml`

Create a `manifest.yml` in the `dist/` directory (or use the one from this
repo as a template), substituting your values:

```yaml
applications:
  - name: stratos-<your-initials>
    routes:
      - route: <route>
    memory: 512M
    disk_quota: 512M
    timeout: 180
    buildpacks:
      - binary_buildpack
    health-check-type: port
    instances: 1
    services:
      - stratos-db-<your-initials>
    command: ./jetstream
```

### 6. Deploy

```bash
cd dist
cf push stratos-<your-initials> \
  -f manifest.yml \
  --var name=stratos-<your-initials> \
  --var route=<route> \
  --var db_service=stratos-db-<your-initials> \
  -e CF_API_URL=https://api.<system-domain> \
  -e SSO_LOGIN=true \
  -e SSO_OPTIONS="nosplash,logout" \
  -e SSO_WHITELIST="https://<route>/*" \
  -e CF_CLIENT=stratos-<your-initials> \
  -e CF_CLIENT_SECRET=<client-secret> \
  -e SESSION_STORE_SECRET=$(openssl rand -hex 16) \
  -e ENCRYPTION_KEY=$(openssl rand -hex 32) \
  -e DB_SSL_MODE=verify-ca
```

> **Important:** Save the `ENCRYPTION_KEY` value — if the app is redeployed
> with a different key, all stored tokens will be invalidated and every user
> will need to log back in.

---

## Contributing

See [CONTRIBUTING](CONTRIBUTING.md) for additional information.

## Public domain

This project is in the worldwide [public domain](LICENSE.md). As stated in
[CONTRIBUTING](CONTRIBUTING.md):

> This project is in the public domain within the United States, and
> copyright and related rights in the work worldwide are waived through the
> [CC0 1.0 Universal public domain
> dedication](https://creativecommons.org/publicdomain/zero/1.0/).
>
> All contributions to this project will be released under the CC0
> dedication. By submitting a pull request, you are agreeing to comply with
> this waiver of copyright interest.
