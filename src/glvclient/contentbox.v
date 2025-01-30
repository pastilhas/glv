module glvclient

import iui as ui
import gx
import math { clip, min }

type Window = ui.Window

pub struct ContentBox {
	ui.Component_A
pub mut:
	ctx           &ui.GraphicsContext
	fg            ?gx.Color
	bg            ?gx.Color
	text          string
	lines         []string
	justify       bool
	px            int = 5
	py            int = 5
	scroll_y      int
	font_size     int
	max_scroll    int
	max_font_size int
}

@[params]
pub struct ContentBoxConfig {
pub:
	ctx           &ui.GraphicsContext
	text          string
	font_size     int
	max_font_size int
	justify       bool
}

pub fn ContentBox.new(c ContentBoxConfig) &ContentBox {
	mut this := &ContentBox{
		ctx:           c.ctx
		text:          c.text
		justify:       c.justify
		font_size:     c.font_size
		max_font_size: c.max_font_size
	}
	return this
}

pub fn (mut this ContentBox) set_text(text string) {
	this.text = text
	this.scroll_y = 0
	this.update_text()
}

fn (mut this ContentBox) zoom(inc int) {
	if (this.max_scroll == 0 && inc < 0) || (this.font_size == this.max_font_size && inc > 0) {
		return
	}

	old_scroll_ratio := if this.max_scroll != 0 {
		f32(this.scroll_y) / f32(this.max_scroll)
	} else {
		0
	}
	this.font_size = min(this.font_size + inc, this.max_font_size)

	this.update_text()
	this.scroll_y = int(old_scroll_ratio * this.max_scroll)
}

fn (mut this ContentBox) update_text() {
	this.lines.clear()
	dy := this.font_size
	mw := this.width - 2 * this.px
	mut y := 2 * this.py

	cfg_sans := gx.TextCfg{
		size: this.font_size
	}
	cfg_mono := gx.TextCfg{
		size: this.font_size
		mono: true
	}

	this.ctx.set_cfg(cfg_sans)
	mut sans := true

	for line in this.text.split_into_lines() {
		if line.is_blank() {
			this.lines << ''
			y += dy
			continue
		}

		if line.starts_with('```') {
			if sans {
				this.ctx.set_cfg(cfg_mono)
			} else {
				this.ctx.set_cfg(cfg_sans)
			}
			sans = !sans
			this.lines << '```'
			continue
		}

		if sans {
			words := line.trim_space().split(' ')
			mut current_line := words[0]
			for i := 1; i < words.len; i++ {
				w := '${current_line} ${words[i]}'
				if this.ctx.text_width(w) <= mw {
					current_line = w
					continue
				}

				this.lines << current_line
				y += dy
				current_line = words[i]
			}

			if current_line.len > 0 {
				this.lines << current_line
				y += dy
			}
		} else {
			this.lines << line
			y += dy
		}
	}

	y += dy - (y % dy)
	this.max_scroll = if y > this.height {
		(y - this.height) * -1
	} else {
		0
	}
}

fn (mut this ContentBox) draw_bg(ctx &ui.GraphicsContext) {
	bg := this.bg or { ctx.theme.textbox_background }
	ctx.gg.draw_rect_filled(this.x, this.ry, this.width, this.height, bg)
	ctx.gg.draw_rect_empty(this.x, this.y, this.width, this.height, ctx.theme.button_border_normal)
}

fn (mut this ContentBox) draw(ctx &ui.GraphicsContext) {
	mut cfg_sans := gx.TextCfg{
		color: this.fg or { ctx.theme.text_color }
		size:  this.font_size
	}
	mut cfg_mono := gx.TextCfg{
		color: this.fg or { ctx.theme.text_color }
		size:  this.font_size
		mono:  true
	}
	mut cfg := cfg_sans

	ctx.gg.scissor_rect(this.x, this.y, this.width, this.height)
	this.draw_bg(ctx)

	dy := this.font_size
	mut y := this.y + this.scroll_y + this.py
	x := this.x + this.px

	for line in this.lines {
		if line.starts_with('```') {
			cfg = if cfg.mono {
				cfg_sans
			} else {
				cfg_mono
			}
			ctx.set_cfg(cfg)
			continue
		}

		if line.is_blank() {
			y += dy
			continue
		}

		ctx.draw_text(x, y, line, ctx.font, cfg)
		y += dy
	}
}

fn (mut this ContentBox) on_key_down(e ui.WindowKeyEvent) {
	match e.key {
		.up, .page_up {
			this.scroll_y = clip(this.scroll_y + this.font_size, this.max_scroll, 0)
		}
		.down, .page_down {
			this.scroll_y = clip(this.scroll_y - this.font_size, this.max_scroll, 0)
		}
		.home {
			this.scroll_y = 0
		}
		.end {
			this.scroll_y = this.max_scroll
		}
		.left_bracket {
			this.zoom(2)
		}
		.right_bracket {
			this.zoom(-2)
		}
		else {
			return
		}
	}
}
