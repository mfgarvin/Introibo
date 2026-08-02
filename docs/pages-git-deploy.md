# Site deploys — Cloudflare Pages, Git-connected

**Status: done (2026-08-02).** The `parishfinder` Pages project is now connected
to `mfgarvin/Introibo`. Pushes to `main` build and publish to
`https://parishfinder.app` automatically. **Do not run `wrangler pages deploy`
anymore** — a hand upload would fight the Git integration.

## Current state (verified 2026-08-02)

| | |
|---|---|
| Project | `parishfinder` (Git Provider: Yes) |
| Repository | `mfgarvin/Introibo`, production branch `main` |
| Build output directory | `site` |
| Hostnames | `parishfinder.pages.dev`, `parishfinder.app`, `www.parishfinder.app` |

The project **kept its name, its `*.pages.dev` hostname, and both custom
domains** through the switch — the feared migration (new project + detach/attach
the apex, which would have briefly unpointed it) did not have to happen. Anything
elsewhere that references `parishfinder.pages.dev` is still correct.

Most recent production deployment at time of writing: source commit `31e4b79`,
serving 200 on `/`, `/privacy`, and `www`.

Wrangler needs `CLOUDFLARE_ACCOUNT_ID` set explicitly — two accounts are on the
login, so it fails non-interactively without one. Get the id from
`npx wrangler whoami`, which lists both:

```bash
CLOUDFLARE_ACCOUNT_ID=… npx wrangler pages deployment list --project-name=parishfinder
```

## Why Pages Git and not a Worker

The original ask was "a new worker that watches the repo." **A Worker is the
wrong tool, and none was written.** Polling the GitHub API into KV, or proxying
`raw.githubusercontent.com` per request, would both be slower than Pages' edge
storage, put GitHub in the path of every page view, cost a subrequest per asset,
and need cache-invalidation logic to maintain. Pages does this natively.

## Don't forget

- `site/_headers` (see `docs/security-hardening.md` item 4) is **still not
  written.** When it lands, it must sit at `site/_headers` — `_headers` is read
  from the build output directory, not the repo root — and it now ships via a
  push rather than an upload.
- Pages 308-redirects `/privacy.html` → `/privacy`. The canonical URL for the
  Play listing is `https://parishfinder.app/privacy`.
- Optional tidying not applied: a build watch path of `site/*` so commits that
  only touch the Flutter app don't trigger a rebuild. Harmless either way —
  builds are free and there is no build command.
