module glvclient

import iui as ui
import math { clip }

pub struct TextBox {
	ViewBox
pub mut:
	ctx           &ui.GraphicsContext
	px            int
	py            int
	font_size     int = 60
	text_height   int
	text          string
	lines         []GemLine = []GemLine{}
	emojier       ?&EmojiDrawer
	on_link_click ?fn (string)
}

pub fn TextBox.new(ctx &ui.GraphicsContext, px int, py int) &TextBox {
	mut this := &TextBox{
		ctx: ctx
		px:  px
		py:  py
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
	size := int(this.font_size * this.zoom)
	lines, height := from_gemtext(this.text, size, this.width - 2 * this.px, 30, this.ctx)
	this.lines = lines
	this.text_height = height
	this.scroll_inc = clip(size / f32(height), 0, 1.0)
}

fn (mut this TextBox) draw_bg(ctx &ui.GraphicsContext) {
	bg := ctx.theme.textbox_background
	ctx.gg.draw_rect_filled(this.x, this.y, this.width, this.height, bg)
	ctx.gg.draw_rect_empty(this.x, this.y, this.width, this.height, ctx.theme.button_border_normal)
}

fn (mut this TextBox) draw(ctx &ui.GraphicsContext) {
	ctx.gg.scissor_rect(this.x, this.y, this.width, this.height)
	this.draw_bg(ctx)

	hover_id := this.get_hovered_line(ctx.gg.mouse_pos_x, ctx.gg.mouse_pos_y - this.py)

	offset := int(this.scroll * this.text_height) - this.height / 2
	draw_lines(this.x, this.y - offset, this.lines, ctx.gg.height, hover_id, ctx)

	// this.emojier.draw_emoji(ctx.gg, '🥰', 100, 100, this.font_size)
}

fn (mut this TextBox) get_hovered_line(mouse_x int, mouse_y int) int {
	if mouse_x < 0 || mouse_x > this.width {
		return -1
	}

	my := mouse_y + int(this.scroll * this.text_height) - this.height / 2
	for i, line in this.lines {
		if line.y < my && line.y + line.size > my {
			return i
		}
	}
	return -1
}

fn (mut this TextBox) on_mouse_down(e &ui.MouseEvent) {
	id := this.get_hovered_line(e.ctx.gg.mouse_pos_x, e.ctx.gg.mouse_pos_y - this.py)
	if id >= 0 {
		mut line := this.lines[id]

		if mut line is LinkLine {
			line.pressed = true
			this.lines[id] = line
		}
	}
}

fn (mut this TextBox) on_mouse_up(e &ui.MouseEvent) {
	id := this.get_hovered_line(e.ctx.gg.mouse_pos_x, e.ctx.gg.mouse_pos_y - this.py)
	if id >= 0 {
		mut line := this.lines[id]

		if mut line is LinkLine {
			line.pressed = false
			line.visited = true
			this.lines[id] = line
			if click := this.on_link_click {
				click(line.link)
			}
		}
	}
}
