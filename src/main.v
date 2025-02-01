module main

import glvclient

fn main() {
	w_width_scaled := int(1280)
	w_height_scaled := int(720)
	mut app := glvclient.App.new(
		width:     w_width_scaled
		height:    w_height_scaled
		font_path: 'assets/NotoSans-Regular.ttf'
	)
	app.main()
}
