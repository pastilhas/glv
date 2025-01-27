module gemini

import arrays
import net.urllib
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

pub fn Response.from(resp &C.Response) Response {
	return Response{
		code: resp.code
		meta: unsafe { cstring_to_vstring(resp.meta) }
		body: unsafe { arrays.carray_to_varray[u8](resp.body, resp.body_len) }
	}
}

pub fn Certificate.from(info &C.CertificateInfo) !Certificate {
	expiry_str := unsafe { cstring_to_vstring(info.expiry) }
	return Certificate{
		hostname:    unsafe { cstring_to_vstring(info.hostname) }
		fingerprint: unsafe { arrays.carray_to_varray[u8](info.fingerprint, 32).hex() }
		expiry:      time.parse_format(expiry_str, 'YYYYMMDDHHmmssZ')!
	}
}

pub fn fetch(url string) !Response {
	url_obj := urllib.parse(url) or { return error('Error parsing url ${err}') }

	mut conn := &C.Connection{}
	mut cres := &C.Response{}
	mut ccert := &C.CertificateInfo{}

	defer {
		C.free_connection(conn)
		C.free_reponse(cres)
	}

	mut res := C.setup_connect(url_obj.hostname().str, conn)
	if res == -1 {
		return error('Error connecting to server')
	}

	res = C.get_server_cert_info(conn, ccert)
	if res == -1 {
		return error('Error getting server certificate')
	}

	mut new := Certificate.from(ccert) or { return error('Error parsing url ${err}') }
	if old := get_certificate(url_obj.hostname()) {
		res = cmp_certificates(old, new)
		if res < 0 {
			return error('Error comparing certificates')
		}
		if res > 0 {
			set_certificate(new) or { return error('Error replacing certificate') }
		}
	} else {
		add_certificate(url_obj.hostname(), new) or { return error('Error adding new certificate') }
	}

	res = C.write_request(conn, url_obj.str().str)
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
	return resp
}
