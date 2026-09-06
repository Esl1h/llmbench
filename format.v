module main

import json2

const reset = '\x1b[0m'
const bold = '\x1b[1m'
const green = '\x1b[32m'
const yellow = '\x1b[33m'
const red = '\x1b[31m'
const max_i64 = i64(9223372036854775807)

// rank_color flags a target by how many of its runs failed, not by speed:
// a fast target that errors half the time is not a good result.
fn rank_color(s TargetSummary) string {
	if s.errors == 0 {
		return green
	}
	if s.errors < s.runs {
		return yellow
	}
	return red
}

fn ttft_sort_key(s TargetSummary) i64 {
	if s.ttft_p50_ms < 0 {
		return max_i64
	}
	return s.ttft_p50_ms
}

// sorted_by_ttft ranks by median TTFT ascending, with every target that
// has no successful run (ttft_p50_ms == -1) pushed to the bottom rather
// than sorted as if -1ms were the fastest result.
pub fn sorted_by_ttft(summaries []TargetSummary) []TargetSummary {
	mut out := summaries.clone()
	out.sort_with_compare(fn (a &TargetSummary, b &TargetSummary) int {
		ka := ttft_sort_key(*a)
		kb := ttft_sort_key(*b)
		if ka < kb {
			return -1
		}
		if ka > kb {
			return 1
		}
		return 0
	})
	return out
}

// format_table renders a ranked, color-coded text table.
pub fn format_table(summaries []TargetSummary) string {
	ranked := sorted_by_ttft(summaries)
	mut lines := []string{}
	lines << '${bold}${'target':-16} ${'model':-20} ${'ttft p50':-10} ${'ttft p95':-10} ${'chars/s':-9} ${'errors':-8} cost${reset}'
	for s in ranked {
		color := rank_color(s)
		ttft_p50 := if s.ttft_p50_ms < 0 { 'n/a' } else { '${s.ttft_p50_ms}ms' }
		ttft_p95 := if s.ttft_p95_ms < 0 { 'n/a' } else { '${s.ttft_p95_ms}ms' }
		chars_per_s := if s.chars_per_s > 0 { '${s.chars_per_s:.0f}' } else { 'n/a' }
		errors := '${s.errors}/${s.runs}'
		cost := if s.cost_known { '\$${s.cost_total:.6f}' } else { 'n/a' }
		lines << '${color}${s.target.name:-16} ${s.model_used:-20} ${ttft_p50:-10} ${ttft_p95:-10} ${chars_per_s:-9} ${errors:-8} ${cost}${reset}'
	}
	return lines.join('\n')
}

// format_json renders the same ranked list as compact JSON.
pub fn format_json(summaries []TargetSummary) string {
	return json2.encode(sorted_by_ttft(summaries))
}
