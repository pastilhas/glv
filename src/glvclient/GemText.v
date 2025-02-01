module glvclient

import gx
import iui as ui

type GemLine = TextLine | LinkLine | PreformatToggle | HeadingLine | ListLine | QuoteLine

struct TextLine {
mut:
	x     int
	y     int
	size  int      = 16
	color gx.Color = gx.black
	text  string
}

struct LinkLine {
	TextLine
mut:
	link    string
	pressed bool
	visited bool
}

struct PreformatToggle {
	TextLine
}

struct HeadingLine {
	TextLine
mut:
	type u8
}

struct ListLine {
	TextLine
}

struct QuoteLine {
	TextLine
}

fn from_gemtext(text string, size int, width int, indent int, ctx &ui.GraphicsContext) ([]GemLine, int) {
	mut res := []GemLine{}
	mut mono := false
	mut y := 0

	for line in text.split_into_lines() {
		if line.is_blank() {
			y += size
			continue
		}

		if line.starts_with('```') {
			mono = !mono
			res << PreformatToggle{}
			continue
		}

		if mono {
			res << TextLine{0, y, size, gx.black, line}
			y += size
			continue
		}

		if line.starts_with('=>') {
			mut link := line[2..].trim_space()
			mut meta := link.clone()

			if link.index_u8(` `) >= 0 {
				link, meta = link.split_once(' ') or { panic('malformed') }
			}

			res << LinkLine{TextLine{0, y, size, gx.blue, meta}, link, false, false}
			y += size
			continue
		}

		if line.starts_with('#') {
			mut l := line[1..]
			mut type := u8(1)
			if line.len > 1 && line[1] == `#` {
				l = l[1..]
				type += 1
			}
			if line.len > 2 && line[2] == `#` {
				l = l[1..]
				type += 1
			}

			l = l.trim_space()
			res << HeadingLine{TextLine{0, y, size + 1 - int(0.25 * f32(type)), gx.dark_blue, l}, type}
			y += size + 1 - int(0.25 * f32(type))
			continue
		}

		if line.starts_with('*') {
			mut w_lines := wrap_line(line[1..].trim_space(), size, width - indent, ctx)
			w_lines[0] = '- ' + w_lines[0]
			for w_line in w_lines {
				res << ListLine{TextLine{indent, y, size, gx.black, w_line}}
				y += size
			}
			continue
		}

		if line.starts_with('>') {
			w_lines := wrap_line(line[1..].trim_space(), size, width - indent, ctx)
			for w_line in w_lines {
				res << QuoteLine{TextLine{indent, y, size, gx.dark_gray, w_line}}
				y += size
			}
			continue
		}

		w_lines := wrap_line(line, size, width - indent, ctx)
		for w_line in w_lines {
			res << TextLine{0, y, size, gx.black, w_line}
			y += size
		}
	}

	return res, y
}

fn wrap_line(line string, size int, width int, ctx &ui.GraphicsContext) []string {
	mut lines := []string{}
	words := line.trim_space().split(' ')
	mut current_line := words[0]

	for i := 1; i < words.len; i++ {
		next_line := '${current_line} ${words[i]}'
		ctx.set_cfg(size: size)
		if ctx.text_width(next_line) < width {
			current_line = next_line
			continue
		}

		lines << current_line
		current_line = words[i]
	}

	if current_line.len > 0 {
		lines << current_line
	}

	return lines
}

fn draw_lines(x int, y int, lines []GemLine, view_height int, hover int, ctx &ui.GraphicsContext) {
	mut mono := false
	mut font := ctx.font

	for i := 0; i < lines.len; i += 1 {
		mut line := lines[i]
		mut color := line.color

		match mut line {
			TextLine {}
			LinkLine {
				if line.pressed && i != hover {
					line.pressed = false
				}

				color = if line.pressed && i == hover {
					gx.light_blue
				} else if line.visited {
					gx.purple
				} else if hover >= 0 && i == hover {
					gx.dark_blue
				} else {
					gx.blue
				}
			}
			PreformatToggle {
				mono = !mono
			}
			HeadingLine {}
			ListLine {}
			QuoteLine {}
		}

		if y + line.y < 0 || y + line.y > view_height {
			continue
		}

		ctx.draw_text(x + line.x, y + line.y, line.text, font, gx.TextCfg{
			color: color
			size:  line.size
			mono:  mono
		})
	}
}
