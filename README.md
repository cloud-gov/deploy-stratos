# cg-deploy-stratos 

This is part of [cloud.gov](https://cloud.gov/), deployment pipeline for
[Stratos Console](https://github.com/cloudfoundry/stratos).

## Customizing the frontend

### Get dependencies

- Install [NodeJs](https://nodejs.org)
- Install [Angular CLI](https://cli.angular.io/)
  ```
  npm install -g @angular/cli
  ```
- Clone this repository
  ```
  git clone https://github.com/18F/cg-deploy-stratos.git
  ```
- Clone the upstream [Stratos
  project](https://github.com/cloudfoundry/stratos)
  ```
  git clone https://github.com/cloudfoundry/stratos.git
  ```
- Change your working directory to the upstream repository directory
  ```
  cd stratos
  ```
- Link the `custom-src` directory from this repository into the upstream
  repository directory
  ```
  ln -sf ../cg-deploy-stratos/custom-src .
  ```

### Deploy the backend to your cloud.gov sandbox

- Pre-build the assets to run on cloud.gov
  ```
  npm install
  npm run customize
  npm run prebuild-ui
  ```
- Decide on a URL for the backend that we'll deploy in our sandbox,
e.g., `stratos-{myinitials}.app.cloud.gov`.
- Push the app to your cloud.gov sandbox
  ```
  cf target -o sandbox-{org} -s {my.email@address.gov}
  cf push stratos -m 1G -n stratos-{myinitials} -d app.cloud.gov
  ```

### Create a service instance user so you can login

- Create a service instance of the `cloud-gov-service-account` service, called
  `stratos-account`, using the `space-auditor` plan/role
  ```
  cf create-service cloud-gov-service-account space-auditor stratos-account
  ```
- Create a service key tied to that instance
  ```
  cf create-service-key stratos-account stratos-account-creds
  ```
- Get a copy of the credentials so you can login later
  ```
  cf service-key stratos-account stratos-account-creds
  ```

### Modify frontend configuration

- Copy the template for proxy configuration
  ```
  cp proxy.conf.template.js proxy.conf.js
  ```
- Now edit `proxy.conf.js` and change the `host` to the chosen hostname you
  used to deploy the backend. e.g. `stratos-{myinitials}.app.cloud.gov`.

### Run the frontend

- Run `npm start` for a dev server. (the app will automatically reload if
  you change any of the source files)
- Navigate to `https://localhost:4200/`
- Login with the credentials you setup earlier

### Customize

- Follow the customization docs for Stratos, making changes in `custom-src`
  directory
- Once your changes are done, switch over to the directory for this
  repository, and commit your changes to GitHub

## Theming the v3 (CAPI v3 / Stratos 5.x) build

The `stratos-v3` deployment is themed entirely through files in the
[`custom-v3/`](custom-v3/) folder — no changes to the upstream Stratos source
are required. The CI pipeline merges these files into the Stratos build tree
during the `compile-stratos-v3` job (see [`ci/pipeline.yml`](ci/pipeline.yml)).

### What lives in `custom-v3/`

```
custom-v3/
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
by the theme package at runtime (it replaces the theme package's default
`company-config.json`). Top-level sections:

| Section        | Configures                                             |
|----------------|--------------------------------------------------------|
| `company`      | Company / application name and display name            |
| `theme`        | Brand colors (primary/secondary/accent, etc.)          |
| `navigation`   | Left-nav colors and styling                            |
| `layout`       | Page background/text and header colors                 |
| `login`        | Login page title/subtitle, logo, background            |
| `footer`       | Footer text / copyright                                |
| `logos`        | Paths to the logo / nav-logo / favicon assets          |
| `defaults`     | Default UI preferences (theme mode, sidenav, etc.)     |

Because branding is data-driven here, most look-and-feel changes are just edits
to `company-config.json` — no rebuild logic changes needed.

### How the files are merged in the pipeline

During `compile-stratos-v3`, before the frontend build, the pipeline copies the
`custom-v3/` files into the checked-out Stratos source:

- `custom-v3/company-config.json` → `src/frontend/packages/theme/company-config.json`
- `custom-v3/assets/core/logo.png` → `src/frontend/packages/core/assets/logo.png`
- `custom-v3/assets/core/nav-logo.png` → `src/frontend/packages/core/assets/nav-logo.png`
- `custom-v3/assets/favicon.ico` → the core package's `favicon.ico`

The build then bakes these into the compiled bundle that gets pushed to
Cloud Foundry. Build-time settings such as the browser tab `title` and the
`packages.exclude` list live separately in [`stratos.yaml`](stratos.yaml).

To change the theme: edit the files in `custom-v3/`, commit, and re-run the
pipeline (`compile-stratos-v3` → `deploy-stratos-v3-dev`).

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
