module main

import glvclient

fn main() {
	w_width_scaled := int(1280 * 1.5)
	w_height_scaled := int(720 * 1.5)
	mut app := glvclient.App.new(
		width:  w_width_scaled
		height: w_height_scaled
	)
	app.main()
}
