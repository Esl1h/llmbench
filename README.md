# llmbench

[![CI](https://github.com/Esl1h/llmbench/actions/workflows/ci.yml/badge.svg)](https://github.com/Esl1h/llmbench/actions/workflows/ci.yml)

A [V](https://vlang.io) CLI that benchmarks LLM endpoints from your own connection: time to first token (TTFT), sustained generation rate, and error rate, ranked side by side. Built on [`vai`](https://github.com/Esl1h/vai)'s real streaming path (`Provider.stream()`, `CurlTransport`), not a simulation.

## Install

```sh
v install https://github.com/Esl1h/vai   # dependency
git clone https://github.com/Esl1h/llmbench
cd llmbench
make build
```

## Usage

```sh
./llmbench                  # 3 runs per target, text table
./llmbench -n 10            # 10 runs per target
./llmbench --max-tokens 300 # longer generation per run
./llmbench --json           # machine-readable output
```

Targets are auto-detected, not configured: the first model Ollama has pulled locally (`http://localhost:11434`), plus Anthropic's `claude-sonnet-5` if `ANTHROPIC_API_KEY` is set. At least one has to be available or there's nothing to benchmark.

```
benchmarking ollama (qwen2.5-coder:7b), 3 run(s)...
target           model                ttft p50   ttft p95   chars/s   errors   cost
ollama           qwen2.5-coder:7b     61ms       61ms       161       0/3      n/a
```

## What's measured, and what isn't

- **TTFT** (`ttft p50`/`ttft p95`): time from request start to the first `content_delta`, in milliseconds, over the run's successful attempts. This is the one number that's fully reliable across any provider, it doesn't depend on the provider sending anything beyond ordinary streamed text.
- **Generation rate** (`chars/s`): output *characters* per second between the first token and the end of the stream, not tokens per second. Getting a real token count out of a stream depends on the provider actually sending a usage event during or after it, which isn't guaranteed, Ollama's OpenAI-compatible endpoint, for one, doesn't by default. Calling it `chars/s` instead of estimating a token count keeps the number honest.
- **Cost** (`cost`): only shown when a usage event actually arrived (Anthropic's `message_delta` reliably includes one; most OpenAI-compatible servers don't, unless the caller opts into `stream_options.include_usage`, which `vai` doesn't request yet). `n/a` means exactly that, not measured, not estimated, not zero; it is also what an unpriced model shows even when it did send usage, since `vai`'s price table covers Anthropic only.
- **Errors**: counted separately from latency. A target that fails half its runs doesn't get to look fast because its two successes were quick, see `errors` in the table.

## Development

```sh
make check   # fmt-check + vet + test
make test
make fmt
```

`v test .` can fail here with confusing `unknown type vai.anthropic.Provider` errors if a checkout of `vai` itself happens to sit next to this repo, a real, reproduced V compiler bug, not a code problem. See AGENTS.md. `make build` is the reliable check either way.

## License

MIT
