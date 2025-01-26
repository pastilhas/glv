module gemini

import arrays

#flag -lssl -lcrypto
#flag -I @VMODROOT/src/gemini/c
#flag @VMODROOT/src/gemini/c/fetch.o
#include "fetch.h"

@[typedef]
struct C.GeminiResponse {
	status_code int
	meta_length int
	body_length int
	meta        charptr
	body        charptr
}

fn C.fetch(url charptr, response &C.GeminiResponse) int

fn C.free_reponse(response &C.GeminiResponse)

pub struct Response {
pub:
	code int
	meta string
	body []u8
}

pub fn fetch(url string) ?Response {
	mut c_response := &C.GeminiResponse{}
	code := C.fetch(url.str, c_response)

	if code < 0 {
		return none
	}

	mut meta := unsafe { arrays.carray_to_varray[u8](c_response.meta, c_response.meta_length) }
	mut body := unsafe { arrays.carray_to_varray[u8](c_response.body, c_response.body_length) }
	C.free_reponse(c_response)

	return Response{code, meta.bytestr(), body}
}
