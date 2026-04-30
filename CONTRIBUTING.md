# Contributing to tokopt

Thanks for your interest in improving `tokopt`! This repository is the
**public, binary + documentation** home for `tokopt`. The Go source code
lives in a separate, private repository — behavioural changes to the
binary land there and are shipped to users via the binaries attached to
this repo's [Releases](https://github.com/shinyay/tokopt/releases).

That shapes what kind of contributions land here.

## What we welcome

- **Documentation improvements** — typo fixes, clarifications, additional
  examples, better diagrams, restructuring for readability.
- **Use-case stories** — share how you use `tokopt` in the real world.
  We may turn your story into a featured page under `docs/use-cases/`
  (with attribution, if you'd like).
- **Bug reports** against the binary, the install script, or the example
  files. Use the **Bug report** issue template.
- **Feature requests** — propose new commands, flags, output formats, or
  integrations. Use the **Feature request** issue template.
- **Questions** — use the **Question** issue template (or
  [Discussions](https://github.com/shinyay/tokopt/discussions) for
  open-ended topics).

## What we cannot accept here

- **Source-code patches.** The Go source for `tokopt` lives in a
  separate private repository. We cannot accept code patches against
  this repo because there is no source to patch. If you have a concrete
  code change in mind, please open a **Feature request** describing the
  intended behaviour change — we will consider it for a future release.
- **Translations of the docs.** English only for the `v0.1.x` line.
  Japanese mirrors are planned for `v0.2.x` — see
  [`docs/roadmap.md`](docs/roadmap.md).

## Documentation PR workflow

1. Fork the repo and create a topic branch
   (`git checkout -b docs/clarify-anatomy-flags`).
2. Edit the markdown. Keep one doc to one purpose
   (we follow the [Diátaxis](https://diataxis.fr/) model — tutorials,
   how-to guides, reference, and explanation each have their own home).
3. Verify links render correctly (`python3 -m http.server 8000` from the
   repo root and browse, or use any local markdown viewer).
4. If you have `markdownlint` installed locally, run it on the files
   you touched.
5. Open a PR using the PR template. Fill in **what** changed and **why**.

## Use-case PR workflow

1. Open an issue using the **Use case story** template — this lets us
   confirm fit before you spend time writing.
2. Once we agree it's a fit, copy the structure of an existing
   `docs/use-cases/*.md` page:
   - **Title** — short and concrete.
   - **Context** — what repo, what team, what problem domain.
   - **Problem** — what were you trying to figure out?
   - **Steps** — the exact `tokopt` commands you ran.
   - **Outcome** — measured numbers wherever possible.
   - **Lessons** — what would you tell a future reader?
3. Open a PR adding the new file. Link to your source issue with
   `Closes #N`.

## Reporting a bug in the binary

Please include:

- `tokopt --version` output.
- OS (`uname -s` or Windows build).
- Architecture (`uname -m`).
- Install method (install script, manual download, other).
- Exact reproduction — commands, input files, expected vs actual output.

The **Bug report** issue template asks for all of this.

## Style

- GitHub-flavoured markdown.
- 80–100 character soft wrap when reasonable.
- One H1 per file (the title); use H2/H3 for structure.
- Prefer short, scannable sections over long prose.
- Code blocks with explicit language (` ```bash `, ` ```go `, ` ```json `).
- Internal links should be relative (`[…](docs/quickstart.md)`), not
  absolute URLs.

## Code of Conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md).
By participating you agree to uphold it.

## Questions about contributing?

Open a **Question** issue or start a thread in
[Discussions](https://github.com/shinyay/tokopt/discussions).
