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
	pressed   ?&Line
}

@[params]
struct Line {
mut:
	x       int
	y       int
	mono    bool
	size    int
	color   gx.Color = gx.black
	text    string
	font    string
	link    string
	pressed bool
	visited bool
}

const link_none = gx.hex(0x0024ff)
const link_hover = gx.hex(0x003383)
const link_pressed = gx.hex(0x00c5ff)
const link_visited = gx.hex(0x5b00ff)

pub fn TextBox.new(ctx &ui.GraphicsContext, font string, px int, py int, bounds ui.Bounds) &TextBox {
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

fn (mut this TextBox) line(l Line) &Line {
	return &Line{
		x:     l.x
		y:     l.y
		mono:  l.mono
		size:  l.size
		color: l.color
		text:  l.text
		font:  l.font
		link:  l.link
	}
}

fn (mut this TextBox) update_view() {
	this.form_text()
}

fn (mut this TextBox) wrap_line(line string, x int, y &int, size int) {
	words := line.trim_space().split(' ')
	mut current_line := words[0]
	mut ry := *y

	for i := 1; i < words.len; i++ {
		w := '${current_line} ${words[i]}'
		this.ctx.set_cfg(size: size, mono: false)
		if this.ctx.text_width(w) <= this.width - 2 * this.px {
			current_line = w
			continue
		}

		this.lines << this.line(
			x:    x
			y:    ry
			size: size
			text: current_line
			font: this.ctx.font
		)
		ry += size
		current_line = words[i]
	}

	if current_line.len > 0 {
		this.lines << this.line(
			x:    x
			y:    ry
			size: size
			text: current_line
			font: this.ctx.font
		)
		ry += size
	}

	unsafe {
		*y = ry
	}
}

fn (mut this TextBox) form_text() {
	this.lines.clear()

	size := int(this.font_size * this.zoom)

	x := this.x + this.px
	mut y := this.y

	mut mono := false

	for line in this.text.split_into_lines() {
		if line.is_blank() {
			this.lines << this.line(
				x:    x
				y:    y
				size: size
				font: this.ctx.font
			)
			y += size
			continue
		}

		if line.starts_with('```') {
			mono = !mono
			continue
		}

		if mono {
			this.lines << this.line(
				x:    x
				y:    y
				mono: true
				size: size
				text: line
				font: this.ctx.font
			)
			y += size
			continue
		}

		if line.starts_with('=>') {
			_, l := line.split_once(' ') or { panic('malformed link') }
			link, meta := l.split_once(' ') or { panic('malformed link') }
			this.lines << this.line(
				x:     x
				y:     y
				size:  size
				color: link_none
				text:  meta
				font:  this.ctx.font
				link:  link
			)
			y += size
			continue
		}

		this.wrap_line(line, x, &y, size)
	}

	this.scroll_inc = clip(f32(size) / f32(y - this.y), 0, 1)
}

fn (mut this TextBox) draw_bg(ctx &ui.GraphicsContext) {
	bg := ctx.theme.textbox_background
	ctx.gg.draw_rect_filled(this.x, this.y, this.width, this.height, bg)
	ctx.gg.draw_rect_empty(this.x, this.y, this.width, this.height, ctx.theme.button_border_normal)
}

fn (mut this TextBox) draw_text(line Line, ctx &ui.GraphicsContext) {
	total_height := this.lines.len * line.size
	scroll_offset := int((this.scroll * 1.1 - 0.05) * (total_height - this.height))
	y_pos := line.y - scroll_offset

	if y_pos < 0 || y_pos > ctx.win.gg.height {
		return
	}

	ctx.draw_text(line.x, y_pos, line.text, line.font,
		color: line.color
		size:  line.size
		mono:  line.mono
	)
}

fn (mut this TextBox) draw(ctx &ui.GraphicsContext) {
	ctx.gg.scissor_rect(this.x, this.y, this.width, this.height)
	this.draw_bg(ctx)

	hover := this.get_hovered_line(ctx.gg.mouse_pos_y + 40)

	if mut line := hover {
		if mut press := this.pressed {
			press.pressed = false
			line.pressed = line.link.len > 0
			this.pressed = line
		}

		if line.link.len > 0 {
			line.color = if line.pressed {
				link_pressed
			} else {
				link_hover
			}
		}
	}

	for line in this.lines {
		this.draw_text(line, ctx)
	}

	if mut line := hover {
		if line.link.len > 0 {
			line.color = if line.visited {
				link_visited
			} else {
				link_none
			}
		}
	}
}

fn (mut this TextBox) get_hovered_line(mouse_y int) ?&Line {
	line_height := this.font_size * this.zoom

	total_height := this.lines.len * line_height
	scroll_offset := int((this.scroll * 1.1 - 0.05) * (total_height - this.height))
	actual_y := mouse_y + scroll_offset - this.y
	line_index := int(actual_y / line_height)

	if line_index >= 0 && line_index < this.lines.len {
		return &this.lines[line_index]
	}

	return none
}

fn (mut this TextBox) on_mouse_down(e &ui.MouseEvent) {
	if mut line := this.get_hovered_line(e.ctx.gg.mouse_pos_y) {
		if line.link.len > 0 {
			this.pressed = line
			line.pressed = true
		}
	}
}

fn (mut this TextBox) on_mouse_up(e &ui.MouseEvent) {
	if mut line := this.get_hovered_line(e.ctx.gg.mouse_pos_y) {
		if line.link.len > 0 {
			line.pressed = false
			line.visited = true
			this.pressed = none
		}
	}
}
