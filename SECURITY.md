# Security Policy

Thanks for helping keep `tokopt` and its users safe.

## Supported versions

Only the latest minor release line receives security updates.

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |
| < 0.1   | :x:                |

## Reporting a vulnerability

**Please do not report security issues in public GitHub issues.**

The preferred channel is GitHub's private vulnerability reporting:

1. Click the **Report a vulnerability** button on the repository's
   **Security** tab, or
2. Open a private security advisory directly at
   <https://github.com/shinyay/tokopt/security/advisories/new>.

Both routes deliver the report only to the maintainer.

### What to include

A useful report contains as many of the following as you can provide:

- The affected version (`tokopt --version`) and platform (`uname -a`,
  or Windows build number).
- A clear description of the vulnerability and its impact.
- A minimal reproduction — exact commands, input files, environment.
- A suggested fix or mitigation, if you have one (entirely optional).

### Disclosure timeline

- **Acknowledgement** within 7 days of receipt.
- **Triage and confirmation** within 14 days.
- **Coordinated disclosure** preferred. The default embargo is **90 days**
  from acknowledgement; we will work with you to extend if a fix needs more
  time, or shorten if a patch is ready earlier.
- After a fix ships, we publish a security advisory (CVE if appropriate)
  and credit the reporter unless they prefer to remain anonymous.

## Scope

In scope:

- The `tokopt` binary distributed via this repository's GitHub Releases.
- The `scripts/install.sh` installer.
- Documented usage shown in `docs/`.

Out of scope (please report upstream):

- Vulnerabilities in third-party Go dependencies — report to the upstream
  maintainer; we will track and update once an upstream fix is available.
- Issues in the Go standard library or runtime.
- Misconfigurations in user repositories that `tokopt` happens to surface.

## Safe-harbour

Good-faith security research conducted within this scope is welcome.
We will not pursue legal action against researchers who follow this policy.
