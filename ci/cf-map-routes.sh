#!/bin/bash

set -eux

cf api "${CF_API_URL}"
(set +x; cf auth "${CF_USERNAME}" "${CF_PASSWORD}")

cf target -o "${CF_ORG}" -s "${CF_SPACE}"

cf map-route stratos fr.cloud.gov -n dashboard-beta
