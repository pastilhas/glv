module gemini

import os
import time

const hosts_path = '/home/joao/.gemini_hosts'

fn get_certificate(hostname string) ?Certificate {
	lines := os.read_lines(hosts_path) or { return none }

	for line in lines {
		if !line.starts_with(hostname) {
			continue
		}

		args := line.split(' ')
		fingerprint := args[1]
		expiry := time.parse_format(args[2]#[..-1], 'YYYYMMDDHHmmss') or { return none }

		return Certificate{hostname, fingerprint, expiry}
	}

	return none
}

fn cmp_certificates(old Certificate, new Certificate) int {
	duration := time.since(old.expiry)
	if duration.seconds() > 0 {
		return 1
	}
	if old.fingerprint != new.fingerprint {
		return -1
	}
	return 0
}

fn set_certificate(cert Certificate) ! {
	mut lines := os.read_lines(hosts_path)!
	for i, line in lines {
		if line.starts_with(cert.hostname) {
			lines[i] = cert.str()
			break
		}
	}
	os.write_file(hosts_path, lines.join('\n'))!
}

fn add_certificate(hostname string, cert Certificate) ! {
	mut lines := os.read_lines(hosts_path)!
	lines << cert.str()
	os.write_file(hosts_path, lines.join('\n'))!
}
