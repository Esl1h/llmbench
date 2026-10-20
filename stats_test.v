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
			ok:       true
			ttft_ms:  100
			total_ms: 500
		},
		RunResult{
			ok:  false
			err: 'boom'
		},
		RunResult{
			ok:       true
			ttft_ms:  120
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
			ok:  false
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
			ok:        true
			ttft_ms:   100
			total_ms:  600
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
			ok:       true
			ttft_ms:  100
			total_ms: 200
		},
	])
	assert !without_tokens.has_tokens
	assert without_tokens.cost_total == 0.0

	with_tokens := summarize(target, 'claude-sonnet-5', [
		RunResult{
			ok:            true
			ttft_ms:       100
			total_ms:      200
			output_tokens: 1_000_000
			has_tokens:    true
		},
	])
	assert with_tokens.has_tokens
	assert with_tokens.cost_known
	assert with_tokens.cost_total == 10.0 // claude-sonnet-5 output: $10/1M
}

fn test_summarize_unpriced_model_with_tokens_has_no_cost() {
	// An Ollama/OpenRouter model has usage but no entry in vai's price
	// table; that must read as "not priced", never as $0.
	target := Target{
		name: 'x'
		kind: 'openai'
	}
	s := summarize(target, 'qwen2.5-coder:7b', [
		RunResult{
			ok:            true
			ttft_ms:       100
			total_ms:      200
			output_tokens: 1000
			has_tokens:    true
		},
	])
	assert s.has_tokens
	assert !s.cost_known
	assert s.cost_total == 0.0
	table := format_table([s])
	assert table.contains('n/a')
	assert !table.contains('\$0.000000')
}
