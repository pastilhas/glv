module gemini

import arrays

#flag -lssl -lcrypto
#flag -I @VMODROOT/src/gemini/c
#flag @VMODROOT/src/gemini/c/fetch.o
#include "fetch.h"

@[typedef]
struct C.Response {
	code     int
	meta_len int
	body_len int
	meta     charptr
	body     charptr
}

fn C.fetch(url charptr, response &C.Response) int

fn C.free_reponse(response &C.Response)

pub struct Response {
pub:
	code int
	meta string
	body []u8
}

pub fn fetch(url string) ?Response {
	mut cres := &C.Response{}
	code := C.fetch(url.str, cres)

	if code < 0 {
		C.free_reponse(cres)
		return none
	}

	mut meta := unsafe { arrays.carray_to_varray[u8](cres.meta, cres.meta_len) }
	mut body := unsafe { arrays.carray_to_varray[u8](cres.body, cres.body_len) }

	return Response{code, meta.bytestr(), body}
}
