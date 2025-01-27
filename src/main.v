module main

import gemini

fn main() {
	if resp := gemini.fetch('gemini://midnight.pub/') {
		println('Status: ${resp.code}')
		println('Meta: ${resp.meta}')
		println('Body:\n${resp.body.bytestr()}')
	} else {
		println('Fetch failed')
	}
}
