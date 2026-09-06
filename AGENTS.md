# AGENTS.md

Instructions for coding agents working in this repository.

## What this project is

`llmbench` is a V CLI: it streams the same short prompt to whichever LLM
targets are actually available (Ollama's first pulled model, and
Anthropic if `ANTHROPIC_API_KEY` is set) via `vai`'s `Provider.stream()`,
measures TTFT and generation rate per run, and prints a ranked table. It
exists to stress `vai`'s streaming path (`CurlTransport`) against real
providers, the way `toklen` stress-tested `Provider.complete()`.

## V is under-represented in your training data — verify, never guess

Same standing rule as `vai`, `redact`, `vjsonrpc`, `ccstat`, `toklen`.
Compile after every meaningful change. For this repo, "compile" means
`make build` (`v -o llmbench .`) — see the `v test .` caveat below before
trusting a test failure.

## The same sibling-directory V compiler bug as `toklen` — read there first

**`v test .` fails here for the same reason it fails in `toklen`, fully
diagnosed and reproduced there**: this repo's `v.mod` depends on `vai` via
VPM install, and a real checkout of `vai` (with its own `v.mod`) happens
to sit right next to this repo on disk (`~/GIT/vai` next to
`~/GIT/llmbench`). V's per-`_test.v`-file compilation gets confused
between the VPM-installed copy and the sibling, and silently fails to
resolve `vai.anthropic`/`vai.openai` (submodule imports) while `import
vai` itself (the root) keeps working fine. `make build` is unaffected —
only `v test .` is.

Read `toklen`'s `AGENTS.md` for the full reproduction; it isn't repeated
here. The practical fallout for this repo: `stats_test.v` and
`ollama_test.v` should compile cleanly on their own (neither touches
`vai.anthropic`/`vai.openai`), but running `v test .` together with
`bench.v` and `main.v` in the same directory pulls those files' imports
into the same failing compilation unit, so the whole `v test .` run fails
even though the actual test logic in `stats_test.v`/`ollama_test.v` is
fine. Verified correct by `make build` succeeding and a live run
producing sane numbers, not by `v test .` passing.

**Do not** try to "fix" this by restructuring imports, merging files, or
removing the `vai.anthropic`/`vai.openai` usage from `bench.v`. It's
filesystem-layout-dependent, not code-shape-dependent — see `toklen` for
the proof.

## Gotchas found in this codebase

- **`arr.sort(a.field < b.field)` only accepts direct field access on `a`
  and `b`** — `arr.sort(some_fn(a) < some_fn(b))` is a compile error
  ("`.sort()` can only use `a` or `b` as argument"). For a derived sort
  key (here, treating `ttft_p50_ms == -1` as "sort last" instead of
  "sort first"), use `arr.sort_with_compare(fn (a &T, b &T) int {...})`
  instead — see `sorted_by_ttft` in `format.v`.
- **There is no `.ljust()`/`.rjust()` string method in V.** Column padding
  in string interpolation uses a width specifier instead: `${s:-10}`
  left-aligns (pads right) to 10 chars, `${s:10}` right-aligns (pads
  left). Confirmed by probe before writing `format.v` — don't reach for a
  Python-shaped padding method that doesn't exist here.
- `time.new_stopwatch()` (no args needed, auto-starts) +
  `.elapsed().milliseconds()` is the measurement primitive, matching
  `dnsbench`'s own usage — not a hand-rolled `time.now()` subtraction.

## Design decisions worth knowing before changing scope

- **No token-per-second metric, `chars/s` instead.** A stream's per-token
  timing isn't reliably available without a provider-sent usage event,
  which most OpenAI-compatible servers don't send by default. Estimating
  a token count from character count would be exactly the kind of
  fabricated precision this whole family of tools avoids — see `vai`'s
  and `toklen`'s own AGENTS.md for the same principle applied elsewhere.
  If `vai.openai` starts requesting `stream_options.include_usage` and
  reliably gets it back, revisit this; don't fake it in the meantime.
- **Cost is `n/a`, not `0` or an estimate, when no usage event arrived.**
  Same reasoning: a hidden zero reads as "this is free," which is false
  for Ollama-vs-Anthropic-pricing comparisons.
- **No config file.** Targets are exactly two, auto-detected, matching
  what `toklen` already does for provider selection (duplicated, not
  shared — these are two small, independent CLIs, not a case for a
  shared internal package). A TOML-driven target list (mirroring
  `dnsbench`'s `data/providers.toml` + `toml.parse_text` pattern) is a
  reasonable v2 if more than two targets are ever needed, not before.
- **Errors are tracked separately from latency stats, never blended in.**
  A target with a fast median but a high error rate should read as
  unreliable, not fast — see `rank_color` and the `errors` column, and
  `summarize`'s exclusion of failed runs from the TTFT/chars-per-s math.

## Build and test

```sh
make build   # v -o llmbench .   — the real verification for this repo
make check   # fmt-check + vet + test — test step may fail, see above
make fmt     # v fmt -w .
```

## Do not

- Add a dependency beyond `vai`.
- Add a token-per-second number without a real usage event backing it.
- Build provider auto-detection beyond Ollama + Anthropic without an
  actual need for a third target.
