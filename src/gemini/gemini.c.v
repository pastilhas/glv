module gemini

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

fn C.setup_connect(hostname charptr, conn &C.Connection) int

fn C.write_request(conn &C.Connection, url charptr) int

fn C.get_server_cert_info(conn &C.Connection, info &C.CertificateInfo) int

fn C.read_header(conn &C.Connection, response &C.Response) int

fn C.read_body(conn &C.Connection, response &C.Response) int

fn C.free_connection(conn &C.Connection)

fn C.free_reponse(response &C.Response)
