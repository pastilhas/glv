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
	fingerprint []u8
	expiry      time.Time
}

pub fn Response.from(resp &C.Response) Response {
	code := resp.code
	meta := unsafe { cstring_to_vstring(resp.meta) }
	body := unsafe { arrays.carray_to_varray[u8](resp.body, resp.body_len) }
	return Response{
		code: code
		meta: meta
		body: body
	}
}

pub fn Certificate.from(hostname string, info &C.CertificateInfo) !Certificate {
	fingerprint := unsafe { arrays.carray_to_varray[u8](info.fingerprint, 32) }
	expiry_str := unsafe { cstring_to_vstring(info.expiry) }
	expiry := time.parse_format(expiry_str, 'YYYYMMDDHHmmssZ')!
	return Certificate{
		hostname:    hostname
		fingerprint: fingerprint
		expiry:      expiry
	}
}

pub fn fetch(url string) ?Response {
	url_obj := urllib.parse(url) or { return none }

	mut conn := &C.Connection{}
	mut cres := &C.Response{}
	mut ccert := &C.CertificateInfo{}

	defer {
		C.free_connection(conn)
		C.free_reponse(cres)
	}

	mut res := C.setup_connect(url_obj.hostname().str, conn)
	if res == -1 {
		return none
	}

	res = C.get_server_cert_info(conn, ccert)
	if res == -1 {
		return none
	}

	res = C.write_request(conn, url_obj.str().str)
	if res == -1 {
		return none
	}

	res = C.read_header(conn, cres)
	if res == -1 {
		return none
	}

	if cres.code / 10 == 2 {
		res = C.read_body(conn, cres)
		if res == -1 {
			return none
		}
	}

	resp := Response.from(cres)

	return resp
}
