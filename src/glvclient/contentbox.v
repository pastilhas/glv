module glvclient

import iui as ui
import gx
import math { clip }

type Window = ui.Window

pub struct ContentBox {
	ui.Component_A
pub mut:
	fg        ?gx.Color
	bg        ?gx.Color
	text      string
	justify   bool
	px        int
	scroll_y  int
	font_size int
}

@[params]
pub struct ContentBoxConfig {
pub:
	text    string
	justify bool
}

pub fn ContentBox.new(c ContentBoxConfig) &ContentBox {
	mut this := &ContentBox{
		text:    c.text
		justify: c.justify
	}
	return this
}

fn (mut this ContentBox) draw_bg(ctx &ui.GraphicsContext) {
	bg := this.bg or { ctx.theme.textbox_background }
	ctx.gg.draw_rect_filled(this.x, this.ry, this.width, this.height, bg)
	ctx.gg.draw_rect_empty(this.x, this.y, this.width, this.height, ctx.theme.button_border_normal)
}

fn (mut this ContentBox) draw(ctx &ui.GraphicsContext) {
	cfg := gx.TextCfg{
		color: this.fg or { ctx.theme.text_color }
		size:  ctx.win.font_size + this.font_size
	}
	ctx.gg.set_text_cfg(cfg)

	th := ctx.line_height + 4 + this.font_size
	ctx.gg.scissor_rect(this.x, this.y, this.width, this.height)
	this.draw_bg(ctx)

	mut y := this.y + this.scroll_y
	x := this.x + this.px
	for line in this.text.split_into_lines() {
		if this.parent != unsafe { nil } && y < this.parent.y - th {
			y += th
			continue
		}
		this.draw_text(x, y + 2, line, cfg, ctx)

		y += th
		if y > this.y + this.height
			|| (this.parent != unsafe { nil } && y > this.parent.y + this.parent.height) {
			break
		}
	}
}

fn (mut this ContentBox) draw_text(x int, y int, line string, cfg gx.TextCfg, ctx &ui.GraphicsContext) {
	line.replace_char(`\t`, ` `, 4)
	ctx.draw_text(x, y + 2, line, ctx.font, cfg)
}

fn (mut this ContentBox) on_key_down(e ui.WindowKeyEvent) {
	diff := e.win.graphics_context.line_height
	min_scroll := 0
	max_scroll := this.text.count('\n') * -diff
	min_font_size := -8
	max_font_size := 16

	match e.key {
		.up, .page_up {
			this.scroll_y = clip(this.scroll_y + diff, max_scroll, min_scroll)
		}
		.down, .page_down {
			this.scroll_y = clip(this.scroll_y - diff, max_scroll, min_scroll)
		}
		.home {
			this.scroll_y = min_scroll
		}
		.end {
			this.scroll_y = max_scroll
		}
		.left_bracket {
			this.font_size = clip(this.font_size + 2, min_font_size, max_font_size)
		}
		.right_bracket {
			this.font_size = clip(this.font_size - 2, min_font_size, max_font_size)
		}
		else {
			return
		}
	}
}
