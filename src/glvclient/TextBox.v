module glvclient

import iui as ui
import gx
import math { clip }

pub struct TextBox {
	ViewBox
pub mut:
	ctx       &ui.GraphicsContext
	px        int
	py        int
	text      string
	lines     []Line = []Line{}
	font_size int    = 60
}

struct Line {
	x     int
	y     int
	text  string
	font  string
	mono  bool
	size  int
	color gx.Color = gx.black
}

pub fn TextBox.new(ctx &ui.GraphicsContext, px int, py int, bounds ui.Bounds) &TextBox {
	mut this := &TextBox{
		ctx:    ctx
		px:     px
		py:     py
		x:      bounds.x
		y:      bounds.y
		width:  bounds.width
		height: bounds.height
	}
	this.update = fn [mut this] () {
		this.update_view()
	}
	return this
}

pub fn (mut this TextBox) set_text(text string) {
	this.scroll = 0
	this.text = text
	this.form_text()
}

fn (mut this TextBox) update_view() {
	this.form_text()
}

fn (mut this TextBox) form_text() {
	this.lines.clear()

	size := int(this.font_size * this.zoom)

	x := this.x + this.px
	mut y := this.y + this.py

	mut mono := false

	for line in this.text.split_into_lines() {
		if line.is_blank() {
			this.lines << Line{x, y, '', this.ctx.font, mono, size, gx.black}
			y += size
			continue
		}

		if line.starts_with('```') {
			mono = !mono
			continue
		}

		if mono {
			this.lines << Line{x, y, line, this.ctx.font, mono, size, gx.black}
			y += size
			continue
		}

		words := line.trim_space().split(' ')
		mut current_line := words[0]
		for i := 1; i < words.len; i++ {
			w := '${current_line} ${words[i]}'
			this.ctx.set_cfg(size: size, mono: mono)
			if this.ctx.text_width(w) <= this.width - 2 * this.px {
				current_line = w
				continue
			}

			this.lines << Line{x, y, current_line, this.ctx.font, mono, size, gx.black}
			y += size
			current_line = words[i]
		}

		if current_line.len > 0 {
			this.lines << Line{x, y, current_line, this.ctx.font, mono, size, gx.black}
			y += size
		}
	}

	this.scroll_inc = clip(f32(size) / f32(y - this.y - this.py), 0, 1)
}

fn (mut this TextBox) draw_bg(ctx &ui.GraphicsContext) {
	bg := ctx.theme.textbox_background
	ctx.gg.draw_rect_filled(this.x, this.y, this.width, this.height, bg)
	ctx.gg.draw_rect_empty(this.x, this.y, this.width, this.height, ctx.theme.button_border_normal)
}

fn (mut this TextBox) draw_text(line Line, ctx &ui.GraphicsContext) {
	total_height := this.lines.len * line.size
	scroll_offset := int(this.scroll * (total_height - this.height))
	y_pos := line.y - scroll_offset

	if y_pos < this.y || y_pos > this.y + this.height {
		return
	}

	ctx.set_cfg(size: line.size, mono: line.mono)
	ctx.draw_text(line.x, y_pos, line.text, line.font,
		color: line.color
		size:  line.size
		mono:  line.mono
	)
}

fn (mut this TextBox) draw(ctx &ui.GraphicsContext) {
	ctx.gg.scissor_rect(this.x, this.y, this.width, this.height)
	this.draw_bg(ctx)

	for line in this.lines {
		this.draw_text(line, ctx)
	}
}

fn (mut this TextBox) on_mouse_up(e &ui.MouseEvent) {
}
