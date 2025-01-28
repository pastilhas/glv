module gemini

import net.urllib { URL }
import time

pub struct Response {
pub:
	code int
	meta string
	body []u8
}

pub struct Certificate {
pub:
	hostname    string
	fingerprint string
	expiry      time.Time
}

pub fn (c Certificate) str() string {
	return '${c.hostname} ${c.fingerprint} ${c.expiry.custom_format('YYYYMMDDHHmmss')}Z'
}

pub fn parse_url(raw string) !URL {
	mut url := urllib.parse(raw)!

	if url.scheme == '' {
		url.scheme = 'gemini'
	} else if url.scheme != 'gemini' {
		return error('Scheme must be gemini:// in ${raw}')
	}

	if '${*url.user}' != '' {
		return error('Gemini does not support user info in URL')
	}

	if url.host == '' {
		return error('No host defined')
	}

	if host, port := url.host.rsplit_once(':') {
		if port.int() == 1965 {
			url.host = host
		}
	}

	if !url.path.starts_with('/') {
		url.path = '/${url.path}'
	}

	url.raw_query = urllib.path_escape(url.raw_query)

	if url.str().len > 1024 {
		return error('URL is too long')
	}

	return url
}

pub fn fetch(url URL) !(Response, Certificate) {
	mut conn := &C.SSLConnection{}
	mut cres := &C.Response{}
	mut ccert := &C.CertificateInfo{}

	defer {
		C.free_connection(conn)
		C.free_reponse(cres)
	}

	mut res := C.setup_connect(url.hostname().str, conn)
	if res == -1 {
		return error('Error connecting to server')
	}

	res = C.get_server_cert_info(conn, ccert)
	if res == -1 {
		return error('Error getting server certificate')
	}

	mut new := Certificate.from(ccert) or { return error('Error parsing url ${err}') }
	if old := get_certificate(url.hostname()) {
		res = cmp_certificates(old, new)
		if res < 0 {
			return error('Error comparing certificates')
		}
		if res > 0 {
			set_certificate(new) or { return error('Error replacing certificate') }
		}
	} else {
		add_certificate(url.hostname(), new) or { return error('Error adding new certificate') }
	}

	res = C.write_request(conn, url.str().str)
	if res == -1 {
		return error('Error writing request to server')
	}

	res = C.read_header(conn, cres)
	if res == -1 {
		return error('Error reading header of response')
	}

	if cres.code / 10 == 2 {
		res = C.read_body(conn, cres)
		if res == -1 {
			return error('Error reading body of response')
		}
	}

	resp := Response.from(cres)
	return resp, new
}
