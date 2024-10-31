# bounty-targets [![Tests](https://github.com/arkadiyt/bounty-targets/actions/workflows/build-test.yml/badge.svg)](https://github.com/arkadiyt/bounty-targets/actions/workflows/build-test.yml/badge.svg) [![License](https://img.shields.io/github/license/arkadiyt/bounty-targets-data.svg)](https://github.com/arkadiyt/bounty-targets/blob/main/LICENSE.md)

### What's it for

This project crawls all the Hackerone, Bugcrowd, & other bug bounty platform scopes hourly and dumps them into the bounty-targets-data repository:

https://github.com/arkadiyt/bounty-targets-data

Supported platforms:

- Hackerone
- Bugcrowd
- Intigriti
<!-- - Hackenproof -->
- YesWeHack
- Federacy

### Installation

If you want to run bounty-targets yourself you can follow these steps:

1. Clone the project and install the dependencies with `bundle`

1. Set the following environment variables:
    - `SENTRY_DSN`: (Optional) [Sentry](https://sentry.io/) API key for exception tracking.
    - `SSH_PRIV_KEY`: An SSH private key that is authorized to write to the github project you want to push data to.
    - `SSH_PUB_KEY`: The public key corresponding to `SSH_PRIV_KEY`.
    - `GIT_HOST`: The github project to write to. For this project it's `git@github.com:arkadiyt/bounty-targets-data.git`.
1. Execute `bin/bounty-targets`

### Getting in touch

Feel free to contact me on Signal: @arkadiyt.01
