module main

import os

fn main() {
	mut runs := 3
	mut max_tokens := 150
	mut want_json := false

	mut i := 1
	for i < os.args.len {
		arg := os.args[i]
		match arg {
			'-n' {
				i++
				if i >= os.args.len {
					eprintln('-n needs a value')
					exit(1)
				}
				runs = os.args[i].int()
			}
			'--max-tokens' {
				i++
				if i >= os.args.len {
					eprintln('--max-tokens needs a value')
					exit(1)
				}
				max_tokens = os.args[i].int()
			}
			'--json' {
				want_json = true
			}
			else {
				eprintln('unknown argument: ${arg}')
				exit(1)
			}
		}
		i++
	}
	if runs < 1 {
		eprintln('runs must be at least 1')
		exit(1)
	}

	mut targets := []Target{}

	if model := ollama_first_model() {
		targets << Target{
			name:     'ollama'
			kind:     'openai'
			base_url: 'http://localhost:11434/v1'
			model:    model
		}
	} else {
		eprintln('note: Ollama not usable (${err}), skipping')
	}

	anthropic_key := os.getenv('ANTHROPIC_API_KEY')
	if anthropic_key != '' {
		targets << Target{
			name:        'anthropic'
			kind:        'anthropic'
			model:       'claude-sonnet-5'
			api_key_env: 'ANTHROPIC_API_KEY'
		}
	}

	if targets.len == 0 {
		eprintln('no usable target: pull an Ollama model or set ANTHROPIC_API_KEY')
		exit(1)
	}

	mut summaries := []TargetSummary{}
	for t in targets {
		eprintln('benchmarking ${t.name} (${t.model}), ${runs} run(s)...')
		mut results := []RunResult{}
		for _ in 0 .. runs {
			results << run_one(t, t.model, max_tokens)
		}
		summaries << summarize(t, t.model, results)
	}

	if want_json {
		println(format_json(summaries))
	} else {
		println(format_table(summaries))
	}
}
