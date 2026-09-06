module main

import os
import time
import vai
import vai.anthropic
import vai.openai

const bench_prompt = 'Explain, in a few sentences, why the sky is blue.'

// run_one streams one request against t and measures it. ttft_ms is set
// on the first content_delta or thinking_delta; output_tokens only comes
// from a usage event actually arriving on the stream, which is not
// guaranteed by every provider — has_tokens says whether it did.
pub fn run_one(t Target, model string, max_tokens int) RunResult {
	req := vai.Request{
		model: model
		messages: [vai.user(bench_prompt)]
		max_tokens: max_tokens
		stream: true
	}

	sw := time.new_stopwatch()

	ch := match t.kind {
		'anthropic' {
			p := anthropic.Provider{
				api_key: os.getenv(t.api_key_env)
				transport: vai.Transport(vai.CurlTransport{})
			}
			p.stream(req) or {
				return RunResult{
					ok: false
					err: err.msg()
				}
			}
		}
		else {
			mut key := ''
			if t.api_key_env != '' {
				key = os.getenv(t.api_key_env)
			}
			p := openai.Provider{
				base_url: t.base_url
				api_key: key
				transport: vai.Transport(vai.CurlTransport{})
			}
			p.stream(req) or {
				return RunResult{
					ok: false
					err: err.msg()
				}
			}
		}
	}

	mut result := RunResult{
		ok: true
	}
	mut got_first := false
	for {
		ev := <-ch or { break }
		match ev.kind {
			.content_delta, .thinking_delta {
				if !got_first {
					result.ttft_ms = sw.elapsed().milliseconds()
					got_first = true
				}
				result.out_chars += ev.text.len
			}
			.usage {
				result.output_tokens = ev.usage.output_tokens
				result.has_tokens = true
			}
			.error {
				result.ok = false
				result.err = ev.err
			}
			.done {}
		}
	}
	result.total_ms = sw.elapsed().milliseconds()
	if !got_first && result.err == '' {
		result.ok = false
		result.err = 'no content received'
	}
	return result
}
