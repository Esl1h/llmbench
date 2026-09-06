module main

fn test_percentile_basic() {
	values := [i64(10), 20, 30, 40, 50]
	assert percentile(values, 0.0) == 10
	assert percentile(values, 1.0) == 50
}

fn test_summarize_counts_errors_separately() {
	target := Target{
		name: 'x'
		kind: 'openai'
	}
	results := [
		RunResult{
			ok: true
			ttft_ms: 100
			total_ms: 500
		},
		RunResult{
			ok: false
			err: 'boom'
		},
		RunResult{
			ok: true
			ttft_ms: 120
			total_ms: 600
		},
	]
	s := summarize(target, 'model-x', results)
	assert s.runs == 3
	assert s.errors == 1
	assert s.ttft_p50_ms == 120
}

fn test_summarize_all_errors_has_no_latency() {
	target := Target{
		name: 'x'
		kind: 'openai'
	}
	results := [
		RunResult{
			ok: false
			err: 'boom'
		},
	]
	s := summarize(target, 'model-x', results)
	assert s.errors == 1
	assert s.ttft_p50_ms == -1
}

fn test_summarize_computes_chars_per_second() {
	target := Target{
		name: 'x'
		kind: 'openai'
	}
	results := [
		RunResult{
			ok: true
			ttft_ms: 100
			total_ms: 600
			out_chars: 250
		},
	]
	s := summarize(target, 'model-x', results)
	// 250 chars over (600-100)ms = 500 chars/s
	assert s.chars_per_s == 500.0
}

fn test_summarize_cost_only_when_tokens_known() {
	target := Target{
		name: 'x'
		kind: 'anthropic'
	}
	without_tokens := summarize(target, 'claude-sonnet-5', [
		RunResult{
			ok: true
			ttft_ms: 100
			total_ms: 200
		},
	])
	assert !without_tokens.has_tokens
	assert without_tokens.cost_total == 0.0

	with_tokens := summarize(target, 'claude-sonnet-5', [
		RunResult{
			ok: true
			ttft_ms: 100
			total_ms: 200
			output_tokens: 1_000_000
			has_tokens: true
		},
	])
	assert with_tokens.has_tokens
	assert with_tokens.cost_total == 10.0 // claude-sonnet-5 output: $10/1M
	
}
