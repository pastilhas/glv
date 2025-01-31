module glvclient

import iui as ui
import math { clip }

pub struct ViewBox {
	ui.Component_A
pub mut:
	ctx        &ui.GraphicsContext
	zoom       f32 = 0.5
	zoom_inc   f32 = 0.1
	scroll     f32
	scroll_inc f32
	update     ?fn ()
}

fn (mut this ViewBox) scroll(scroll f32) {
	this.scroll = clip(this.scroll + scroll, -0.01, 1.01)
}

fn (mut this ViewBox) zoom(zoom f32) {
	this.zoom = clip(this.zoom + zoom, 0.1, 2.0)
	if update := this.update {
		update()
	}
}

fn (mut this ViewBox) on_key_down(e ui.WindowKeyEvent) {
	match e.key {
		.up, .page_up {
			this.scroll(-this.scroll_inc)
		}
		.down, .page_down {
			this.scroll(this.scroll_inc)
		}
		.home {
			this.scroll(-this.scroll)
		}
		.end {
			this.scroll(1 - this.scroll)
		}
		.left_bracket {
			this.zoom(this.zoom_inc)
		}
		.right_bracket {
			this.zoom(-this.zoom_inc)
		}
		else {
			return
		}
	}
}
