# cg-deploy-stratos

This is part of [cloud.gov](https://cloud.gov/), deployment pipeline for [Stratos Console](https://github.com/cloudfoundry-incubator/stratos).

## Customizing the frontend

### Get dependencies
* Install [NodeJs v10](https://nodejs.org) - `brew install node@10; brew unlink node; brew link --verwrite --force node@10`
* Install [Angular CLI](https://cli.angular.io/) - `brew install angular-cli`
* Install [Docker](https://www.docker.com/) - `brew cask install docker`
* Clone this repository
  ```
  git clone https://github.com/18F/cg-deploy-stratos.git
  ```
* Clone the upstream [Stratos project](https://github.com/cloudfoundry-incubator/stratos)
  ```
  git clone https://github.com/cloudfoundry-incubator/stratos.git
  ```
* Change your working directory to the upstream repository directory
  ```
  cd stratos
  ```
* Link the `custom-src` directory from this repository into the upstream repository directory
  ```
  ln -sf ../cg-deploy-stratos/custom-src .
  ```

### Setup the backend

#### To test with [`cfdev`](https://github.com/cloudfoundry-incubator/cfdev) (a local Cloud Foundry instance with full admin privileges)
* Install `cfdev` (if you haven't already)
  ```
  cf install-plugin -r CF-Community "cfdev"
  ```
* Start up `cfdev` (This will take a loooong time)
  ```
  cf dev start
  ```
* Run the prebuit Stratos Docker image pointing at the local `cfdev` deployment
  ```
  docker run -p 5443:443 -e CONSOLE_ADMIN_SCOPE=cloud_controller.admin -e CONSOLE_CLIENT=cf -e UAA_ENDPOINT=https://uaa.dev.cfdev.sh -e AUTO_REG_CF_URL=https://api.dev.cfdev.sh splatform/stratos
  ```
* Note your credentials you will use to login later, which are username `admin` and password `admin`

#### To test with cloud.gov (using a service account with limited permissions)
* Run the prebuit Stratos Docker image pointing at cloud.gov
  ```
  docker run -p 5443:443 -e CONSOLE_ADMIN_SCOPE=cloud_controller.admin -e CONSOLE_CLIENT=cf -e UAA_ENDPOINT=https://uaa.fr.cloud.gov -e AUTO_REG_CF_URL=https://api.fr.cloud.gov splatform/stratos
  ```

##### Create a service instance user in cloud.gov so you can login

* Create a service instance of the `cloud-gov-service-account` service, called `stratos-account`, using the `space-auditor` plan/role
  ```
  cf create-service cloud-gov-service-account space-auditor stratos-account
  ```
* Create a service key tied to that instance
  ```
  cf create-service-key stratos-account stratos-account-creds
  ```
* Note the credentials you will use to login later
  ```
  cf service-key stratos-account stratos-account-creds
  ```

### Run your frontend
* Ensure all the dependencies are installed
  ```
  npm install
  ```
* Ensure your customizations are included
  ```
  npm run customize
  ```
* Run `ng start --aot=false` for a dev server. (The app will automatically reload if you change any of the source files)
* Navigate to `https://localhost:4200/`
* Login with username `admin` and password `admin` (for `cfdev`), or else the credentials you retrieved from the service key earlier

### Customize
* Follow the [customization docs for Stratos](https://github.com/cloudfoundry-incubator/stratos/blob/v2-master/docs/customizing.md), making changes in `custom-src` directory. (You can visit https://localhost:5443 to compare your modifications with the stock version.)
* Once your changes are done, switch over to the directory for this repository, commit your changes, and make a pull-request on GitHub

## Contributing

See [CONTRIBUTING](CONTRIBUTING.md) for additional information.

## Public domain

This project is in the worldwide [public domain](LICENSE.md). As stated in [CONTRIBUTING](CONTRIBUTING.md):

> This project is in the public domain within the United States, and copyright and related rights in the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).
>
> All contributions to this project will be released under the CC0 dedication. By submitting a pull request, you are agreeing to comply with this waiver of copyright interest.
