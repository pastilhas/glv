module glvclient

import gg
import x.ttf
import sokol.sgl
import os

struct EmojiDrawer {
pub mut:
	tf         ttf.TTF_File
	ttf_render ttf.TTF_render_Sokol
}

fn EmojiDrawer.new(font_path string) &EmojiDrawer {
	mut tf := ttf.TTF_File{}
	tf.buf = os.read_bytes(font_path) or { panic(err) }
	tf.init()

	ttf_render := &ttf.TTF_render_Sokol{
		bmp: &ttf.BitMap{
			tf:       &tf
			buf:      unsafe { malloc(64_000_000) }
			buf_size: (64_000_000)
			color:    0x000000FF
		}
	}

	return &EmojiDrawer{tf, ttf_render}
}

fn (mut this EmojiDrawer) draw_emoji(ctx &gg.Context, text string, x f32, y f32, size int) (int, int) {
	sgl.defaults()
	sgl.matrix_mode_projection()
	sgl.ortho(0.0, f32(ctx.width), f32(ctx.height), 0.0, -1.0, 1.0)

	mut tex := &this.ttf_render
	tex.destroy_texture()

	scale := f32(size) / f32(this.tf.units_per_em)
	width := int((this.tf.x_max - this.tf.x_min) * scale)
	height := f32((this.tf.y_max - this.tf.y_min) * scale)

	tex.create_text(text, size)
	tex.create_texture()

	tex.draw_text_bmp(ctx, x, y + height * 0.8)

	return width, int(height)
}
