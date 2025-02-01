module glvclient

import iui as ui
import gemini
import time

pub struct App {
	ui.Window
mut:
	content    &TextBox
	history    History
	search_bar &ui.TextField = unsafe { nil }
}

pub fn App.new(cfg &ui.WindowConfig) &App {
	mut app := &App(ui.Window.new(cfg))
	app.history = History.new()
	return app
}

pub fn (mut app App) main() {
	w_width := 1280
	w_height := 720
	unit := 30

	mut main_panel := ui.Panel.new(layout: ui.FlowLayout.new(ui.FlowLayoutConfig{0, 0}))
	main_panel.set_bounds(0, 0, w_width, w_height)
	mut header := ui.Panel.new(layout: ui.FlowLayout.new(ui.FlowLayoutConfig{0, 0}))
	header.set_bounds(0, 0, w_width, unit)
	mut lbtn := ui.Button.new(text: 'C')
	lbtn.set_bounds(0, 0, unit, unit)
	mut rbtn := ui.Button.new(text: 'A')
	rbtn.set_bounds(0, 0, unit, unit)
	mut search_bar := ui.TextField.new()
	search_bar.set_bounds(0, 0, w_width - 2 * unit, unit)

	header.add_child(lbtn)
	header.add_child(search_bar)
	header.add_child(rbtn)

	mut footer := ui.Panel.new(layout: ui.FlowLayout.new(ui.FlowLayoutConfig{0, 0}))
	footer.set_bounds(0, 0, w_width, unit)

	mut back_btn := ui.Button.new(text: '<')
	back_btn.set_bounds(0, 0, unit, unit)
	mut frwd_btn := ui.Button.new(text: '>')
	frwd_btn.set_bounds(0, 0, unit, unit)
	// mut back_btn := ui.Button.new(text: '<')
	// back_btn.set_bounds(0, 0, unit, unit)
	// mut back_btn := ui.Button.new(text: '<')
	// back_btn.set_bounds(0, 0, unit, unit)
	// mut back_btn := ui.Button.new(text: '<')
	// back_btn.set_bounds(0, 0, unit, unit)

	footer.add_child(back_btn)
	footer.add_child(frwd_btn)

	mut content := ui.Panel.new()
	content.set_bounds(0, 0, w_width, w_height - 2 * unit)
	mut content_box := TextBox.new(app.graphics_context, 5, 10 + 2 * unit)
	content_box.set_bounds(0, 0, w_width, content.height)

	content_box.emojier = EmojiDrawer.new('assets/NotoEmoji-VariableFont_wght.ttf')
	content_box.on_link_click = fn [mut app] (link string) {
		if link.starts_with('gemini://') {
			app.search_bar.text = link
			app.goto()
			return
		}

		if link.contains('://') {
			println('No support for other protocols')
			return
		}

		app.search_bar.text = app.search_bar.text.trim_right('/') + '/' + link.trim_left('/')
		println('goto: ${app.search_bar.text}')
		app.goto()
	}

	content.add_child(content_box)

	main_panel.add_child(header)
	main_panel.add_child(footer)
	main_panel.add_child(content)

	app.add_child(main_panel)

	app.search_bar = search_bar
	app.content = content_box

	app.subscribe_event('key_down', fn [mut app, mut content_box] (e &ui.WindowKeyEvent) {
		app.on_key_down(e)
		content_box.on_key_down(e)
	})
	content_box.subscribe_event('mouse_down', fn [mut content_box] (e &ui.MouseEvent) {
		content_box.on_mouse_down(e)
	})
	content_box.subscribe_event('mouse_up', fn [mut content_box] (e &ui.MouseEvent) {
		content_box.on_mouse_up(e)
	})
	rbtn.subscribe_event('mouse_up', fn [mut app] (e &ui.MouseEvent) {
		app.on_mouse_up(e)
	})

	back_btn.subscribe_event('mouse_up', fn [mut app] (e &ui.MouseEvent) {
		resp := app.history.back() or { return }
		app.load(resp)
	})

	frwd_btn.subscribe_event('mouse_up', fn [mut app] (e &ui.MouseEvent) {
		resp := app.history.frwd() or { return }
		app.load(resp)
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
	app.search_bar.blinked = false
	app.search_bar.carrot_left = app.search_bar.text.len
	url := app.search_bar.text
	url_obj := gemini.parse_url(url) or {
		println(err)
		return
	}
	resp := gemini.fetch(url_obj) or {
		println(err)
		return
	}

	domain := if resp.certificate.hostname == url_obj.hostname() {
		'✓ Domain matches ${url_obj.hostname()}'
	} else {
		'✗ Domain does not match ${resp.certificate.hostname} ${url_obj.hostname()}'
	}
	expire := if time.since(resp.certificate.expiry) < 0 {
		'✓ Certificate not expired ${resp.certificate.expiry.ymmdd()}'
	} else {
		'✗ Certificate expired ${resp.certificate.expiry.ymmdd()}'
	}

	println('${resp.code} ${resp.meta} ${resp.body.len >> 10}KB')
	println(domain)
	println(expire)

	match resp.code / 10 {
		2 {
			app.history.add(resp)
			app.load(resp)
		}
		else {}
	}
}

fn (mut app App) load(resp gemini.Response) {
	app.search_bar.text = resp.request.str()
	app.search_bar.carrot_left = app.search_bar.text.len

	if resp.meta.starts_with('text') {
		app.content.set_text(resp.body.bytestr())
	}
}
