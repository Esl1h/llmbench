module main

import math
import vai

// percentile expects a non-empty slice; the caller (summarize) only calls
// it with the successful runs, guarded by results.len == 0. The index
// rounds up, so with few runs a percentile never reports a faster value
// than the data supports (p50 of {100, 120} is 120, not 100); the first
// version truncated, and its own test caught it only once the test could
// run outside the sibling-directory compiler bug.
fn percentile(values []i64, p f64) i64 {
	mut sorted := values.clone()
	sorted.sort()
	idx := int(math.ceil(f64(sorted.len - 1) * p))
	return sorted[idx]
}

// summarize aggregates one target's runs. Errored runs count toward
// `errors` but are excluded from the latency/throughput statistics: a
// failed request has no TTFT to rank against a successful one.
pub fn summarize(t Target, model_used string, results []RunResult) TargetSummary {
	mut ttfts := []i64{}
	mut totals := []i64{}
	mut errors := 0
	mut total_chars := 0
	mut total_gen_ms := i64(0)
	mut total_tokens := 0
	mut has_tokens := false

	for r in results {
		if !r.ok {
			errors++
			continue
		}
		ttfts << r.ttft_ms
		totals << r.total_ms
		total_chars += r.out_chars
		if r.ttft_ms >= 0 && r.total_ms > r.ttft_ms {
			total_gen_ms += r.total_ms - r.ttft_ms
		}
		if r.has_tokens {
			total_tokens += r.output_tokens
			has_tokens = true
		}
	}

	mut chars_per_s := 0.0
	if total_gen_ms > 0 {
		chars_per_s = f64(total_chars) / (f64(total_gen_ms) / 1000.0)
	}

	mut cost_total := 0.0
	mut cost_known := false
	if has_tokens {
		c := vai.cost(model_used, vai.Usage{
			output_tokens: total_tokens
		})
		if !c.unknown {
			cost_total = c.output
			cost_known = true
		}
	}

	mut ttft_p50 := i64(-1)
	mut ttft_p95 := i64(-1)
	mut total_p50 := i64(-1)
	if ttfts.len > 0 {
		ttft_p50 = percentile(ttfts, 0.5)
		ttft_p95 = percentile(ttfts, 0.95)
		total_p50 = percentile(totals, 0.5)
	}

	return TargetSummary{
		target: t
		model_used: model_used
		runs: results.len
		errors: errors
		ttft_p50_ms: ttft_p50
		ttft_p95_ms: ttft_p95
		total_p50_ms: total_p50
		chars_per_s: chars_per_s
		has_tokens: has_tokens
		cost_known: cost_known
		cost_total: cost_total
	}
}
