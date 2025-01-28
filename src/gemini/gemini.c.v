module gemini

import time
import arrays

#flag -lssl -lcrypto
#flag -I @VMODROOT/src/gemini/c
#flag @VMODROOT/src/gemini/c/fetch.o
#include "fetch.h"

@[typedef]
struct C.SSLConnection {
	ctx  voidptr
	ssl  voidptr
	sock int
}

@[typedef]
struct C.Response {
	code     int
	body_len int
	meta     charptr
	body     charptr
}

@[typedef]
struct C.CertificateInfo {
	hostname    charptr
	fingerprint charptr
	expiry      charptr
}

fn C.setup_connect(hostname charptr, conn &C.SSLConnection) int

fn C.write_request(conn &C.SSLConnection, url charptr) int

fn C.get_server_cert_info(conn &C.SSLConnection, info &C.CertificateInfo) int

fn C.read_header(conn &C.SSLConnection, response &C.Response) int

fn C.read_body(conn &C.SSLConnection, response &C.Response) int

fn C.free_connection(conn &C.SSLConnection)

fn C.free_reponse(response &C.Response)

fn Response.from(resp &C.Response) Response {
	return Response{
		code: resp.code
		meta: unsafe { cstring_to_vstring(resp.meta) }
		body: unsafe { arrays.carray_to_varray[u8](resp.body, resp.body_len) }
	}
}

fn Certificate.from(info &C.CertificateInfo) !Certificate {
	expiry_str := unsafe { cstring_to_vstring(info.expiry) }
	return Certificate{
		hostname:    unsafe { cstring_to_vstring(info.hostname) }
		fingerprint: unsafe { arrays.carray_to_varray[u8](info.fingerprint, 32).hex() }
		expiry:      time.parse_format(expiry_str, 'YYYYMMDDHHmmssZ')!
	}
}
