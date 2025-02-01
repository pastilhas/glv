module glvclient

import gemini

@[params]
pub struct HistoryCfg {
	cap int = -1
}

pub struct History {
mut:
	cap     int               = -1
	pointer int               = -1
	cache   []gemini.Response = []gemini.Response{}
}

pub fn History.new(cfg HistoryCfg) History {
	return History{
		cap:     cfg.cap
		pointer: -1
		cache:   []gemini.Response{}
	}
}

pub fn (mut this History) add(response gemini.Response) {
	if this.cap == 0 {
		return
	}

	if this.cap > 0 && this.cache.len == this.cap {
		this.cache.drop(1)
	}

	if this.pointer != this.cache.len - 1 {
		this.cache.trim(this.pointer + 1)
	}

	this.cache << response
	dump(this.cache.last())
	this.pointer = this.cache.len - 1
}

pub fn (mut this History) back() !gemini.Response {
	return this.move_get(-1)!
}

pub fn (mut this History) frwd() !gemini.Response {
	return this.move_get(1)!
}

fn (mut this History) move_get(inc int) !gemini.Response {
	if this.pointer + inc >= 0 && this.pointer + inc < this.cache.len {
		this.pointer += inc
		return this.cache[this.pointer]
	}

	return error('empty cache')
}
