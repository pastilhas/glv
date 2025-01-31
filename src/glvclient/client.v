module glvclient

import iui as ui
import gemini
import time

pub struct App {
	ui.Window
mut:
	content    &TextBox
	search_bar &ui.TextField = unsafe { nil }
}

pub fn App.new(cfg &ui.WindowConfig) &App {
	return &App(ui.Window.new(cfg))
}

pub fn (mut app App) main() {
	w_width := 1280
	w_height := 720

	mut main_panel := ui.Panel.new(layout: ui.FlowLayout.new(ui.FlowLayoutConfig{0, 0}))
	main_panel.set_bounds(0, 0, w_width, w_height)
	mut header := ui.Panel.new(layout: ui.FlowLayout.new(ui.FlowLayoutConfig{0, 0}))
	header.set_bounds(main_panel.x, main_panel.y, main_panel.width, 30)
	mut lbtn := ui.Button.new(
		text:   'C'
		bounds: ui.Bounds{header.x, header.y, header.height, header.height}
	)
	mut rbtn := ui.Button.new(
		text:   'A'
		bounds: ui.Bounds{header.x, header.y, header.height, header.height}
	)
	mut search_bar := ui.TextField.new(
		bounds: ui.Bounds{header.x, header.y, header.width - lbtn.width - rbtn.width, header.height}
	)

	header.add_child(lbtn)
	header.add_child(search_bar)
	header.add_child(rbtn)

	mut footer := ui.Panel.new(layout: ui.FlowLayout.new(ui.FlowLayoutConfig{0, 0}))
	footer.set_bounds(main_panel.x, main_panel.y, main_panel.width, header.height)

	footer_buttons := ['<', '>', 'H', 'B', 'S']
	for btn_text in footer_buttons {
		mut btn := ui.Button.new(text: btn_text)
		btn.set_bounds(footer.x, footer.y, footer.height, footer.height)
		footer.add_child(btn)
	}

	mut content := ui.Panel.new()
	content.set_bounds(main_panel.x, main_panel.y, main_panel.width, main_panel.height - header.height - footer.height)
	mut content_box := TextBox.new(app.graphics_context, 5, 5,
		x:      content.x
		y:      content.y - 5
		width:  content.width
		height: content.height
	)
	content.add_child(content_box)

	main_panel.add_child(header)
	main_panel.add_child(content)
	main_panel.add_child(footer)

	app.add_child(main_panel)

	app.search_bar = search_bar
	app.content = content_box

	app.subscribe_event('key_down', fn [mut app, mut content_box] (e &ui.WindowKeyEvent) {
		app.on_key_down(e)
		content_box.on_key_down(e)
	})
	content_box.subscribe_event('mouse_up', fn [mut content_box] (e &ui.MouseEvent) {
		content_box.on_mouse_up(e)
	})
	rbtn.subscribe_event('mouse_up', fn [mut app] (e &ui.MouseEvent) {
		app.on_mouse_up(e)
	})

	app.gg.run()
}

fn (mut app App) on_mouse_up(e &ui.MouseEvent) {
	app.goto()
}

fn (mut app App) on_key_down(e &ui.WindowKeyEvent) {
	if e.key == .enter || e.key == .kp_enter {
		app.goto()
	}
}

fn (mut app App) goto() {
	app.search_bar.is_selected = false
	url := app.search_bar.text
	url_obj := gemini.parse_url(url) or {
		println(err)
		return
	}
	resp, cert := gemini.fetch(url_obj) or {
		println(err)
		return
	}

	domain := if cert.hostname == url_obj.hostname() {
		'✓ Domain matches'
	} else {
		'✗ Domain does not match'
	}
	expire := if time.since(cert.expiry) < 0 {
		'✓ Certificate not expired ${cert.expiry}'
	} else {
		'✗ Certificate expired ${cert.expiry.ymmdd()}'
	}

	println('${resp.code} ${resp.meta} ${resp.body.len >> 10}KB')
	println(domain)
	println(expire)

	if resp.meta.starts_with('text') {
		app.content.set_text(resp.body.bytestr())
	}
}
