module gemini

import arrays
import net.urllib

#flag -lssl -lcrypto
#flag -I @VMODROOT/src/gemini/c
#flag @VMODROOT/src/gemini/c/fetch.o
#include "fetch.h"

@[typedef]
struct C.Connection {
	ctx  voidptr
	ssl  voidptr
	sock int
}

@[typedef]
struct C.Response {
	code     int
	meta_len int
	body_len int
	meta     charptr
	body     charptr
}

@[typedef]
struct C.CertificateInfo {
	fingerprint [32]u8
	expiry      [16]char
}

fn C.setup_connect(hostname charptr, conn &C.Connection) int

fn C.write_request(conn &C.Connection, url charptr) int

fn C.get_server_cert_info(conn &C.Connection, info &C.CertificateInfo) int

fn C.read_header(conn &C.Connection, response &C.Response) int

fn C.read_body(conn &C.Connection, response &C.Response) int

fn C.free_connection(conn &C.Connection)

fn C.free_reponse(response &C.Response)

pub struct Response {
pub:
	code int
	meta string
	body []u8
}

pub fn fetch(url string) ?Response {
	url_obj := urllib.parse(url) or { return none }

	mut conn := &C.Connection{}
	mut cres := &C.Response{}
	mut cert := &C.CertificateInfo{}

	defer {
		C.free_connection(conn)
		C.free_reponse(cres)
	}

	mut res := C.setup_connect(url_obj.hostname().str, conn)
	if res == -1 {
		return none
	}

	res = C.get_server_cert_info(conn, cert)
	if res == -1 {
		return none
	}

	fingerprint := unsafe { arrays.carray_to_varray[u8](cert.fingerprint, 32) }
	expiry := unsafe { arrays.carray_to_varray[u8](cert.expiry, 16) }
	println(fingerprint.hex())
	println(expiry.bytestr())

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

	code := cres.code
	meta := unsafe { arrays.carray_to_varray[u8](cres.meta, cres.meta_len) }
	body := unsafe { arrays.carray_to_varray[u8](cres.body, cres.body_len) }

	return Response{code, meta.bytestr(), body}
}
