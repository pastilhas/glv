module glvclient

import iui as ui
import gx
import math { clip }

type Window = ui.Window

pub struct ContentBox {
	ui.Component_A
pub mut:
	fg            ?gx.Color
	bg            ?gx.Color
	text          string
	justify       bool
	px            int
	scroll_y      int
	font_size     int
	max_scroll    int
	max_font_size int
}

@[params]
pub struct ContentBoxConfig {
pub:
	text          string
	font_size     int
	max_font_size int
	justify       bool
}

pub fn ContentBox.new(c ContentBoxConfig) &ContentBox {
	mut this := &ContentBox{
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
	this.update_max_scroll()
}

fn (mut this ContentBox) update_max_scroll() {
	total_height := this.text.count('\n') * this.font_size
	this.max_scroll = if total_height > this.height {
		(total_height - this.height) * -1
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

	th := this.font_size
	ctx.gg.scissor_rect(this.x, this.y, this.width, this.height)
	this.draw_bg(ctx)

	mut y := this.y + this.scroll_y
	x := this.x + this.px
	for line in this.text.split_into_lines() {
		if line.starts_with('```') {
			cfg = if cfg.mono {
				cfg_sans
			} else {
				cfg_mono
			}
			continue
		}

		this.draw_text(x, y + 2, line, cfg, ctx)
		y += th
	}
}

fn (mut this ContentBox) draw_text(x int, y int, line string, cfg gx.TextCfg, ctx &ui.GraphicsContext) {
	line.replace_char(`\t`, ` `, 4)
	ctx.draw_text(x, y + 2, line, ctx.font, cfg)
}

fn (mut this ContentBox) on_key_down(e ui.WindowKeyEvent) {
	old_scroll_ratio := if this.max_scroll != 0 {
		f32(this.scroll_y) / f32(this.max_scroll)
	} else {
		0
	}

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
			this.font_size = clip(this.font_size + 2, 0, this.max_font_size)
			this.update_max_scroll()
			if this.max_scroll != 0 {
				this.scroll_y = int(old_scroll_ratio * this.max_scroll)
			}
		}
		.right_bracket {
			this.font_size = clip(this.font_size - 2, 0, this.max_font_size)
			this.update_max_scroll()
			if this.max_scroll != 0 {
				this.scroll_y = int(old_scroll_ratio * this.max_scroll)
			}
		}
		else {
			return
		}
	}
}
