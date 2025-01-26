module main

import gemini

fn main() {
	if result := gemini.fetch('gemini://midnight.pub/') {
		println('Status: ${result.code}')
		println('Meta: ${result.meta}')
		println('Body:\n${result.body.bytestr()}')
	} else {
		println('Fetch failed')
	}
}
