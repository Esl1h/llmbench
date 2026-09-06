// llmbench measures LLM endpoints from your own connection: time to
// first token, sustained generation rate, and error rate, streamed
// through vai.Provider.stream() against whatever's actually configured.
module main

pub struct Target {
pub:
	name        string
	kind        string // "anthropic" or "openai"
	base_url    string
	model       string
	api_key_env string // empty means no key is required
}

// RunResult is one request's measurements. ttft_ms stays -1 if no content
// ever arrived (a total failure, not "instant").
pub struct RunResult {
pub mut:
	ttft_ms       i64 = -1
	total_ms      i64
	out_chars     int
	output_tokens int
	has_tokens    bool
	ok            bool
	err           string
}

pub struct TargetSummary {
pub:
	target       Target
	model_used   string
	runs         int
	errors       int
	ttft_p50_ms  i64
	ttft_p95_ms  i64
	total_p50_ms i64
	chars_per_s  f64
	has_tokens   bool
	cost_total   f64
}
