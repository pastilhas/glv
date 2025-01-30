module glvclient

import iui as ui
import gemini
import time

pub struct App {
	ui.Window
mut:
	content    &ContentBox
	search_bar &ui.TextField = unsafe { nil }
}

pub fn App.new(cfg &ui.WindowConfig) &App {
	return &App(ui.Window.new(cfg))
}

pub fn (mut app App) main() {
	w_width := 1280
	w_height := 720
	btn_side := 30
	z_gap := 0
	s_gap := 5

	mut main_panel := ui.Panel.new(layout: ui.BorderLayout.new(hgap: z_gap, vgap: z_gap))

	mut header := ui.Panel.new(layout: ui.BoxLayout.new(hgap: s_gap, vgap: s_gap))

	mut cert_btn := ui.Button.new(text: 'C')
	cert_btn.set_bounds(0, 0, btn_side, btn_side)

	mut search_bar := ui.text_field()
	search_bar.set_bounds(0, 0, w_width - 2 * btn_side - 4 * s_gap, btn_side)
	app.search_bar = search_bar

	mut action_btn := ui.Button.new(text: 'A')
	action_btn.set_bounds(0, 0, btn_side, btn_side)

	header.add_child(cert_btn)
	header.add_child(search_bar)
	header.add_child(action_btn)

	mut content := ui.panel()
	content.set_bounds(0, 0, w_width - 2 * s_gap, w_height - 2 * btn_side - 6 * s_gap)
	mut content_box := ContentBox.new(
		ctx:           app.graphics_context
		justify:       true
		font_size:     app.graphics_context.font_size
		max_font_size: 2 * app.graphics_context.font_size
	)
	content_box.set_bounds(0, 0, w_width - 2 * s_gap, w_height - 2 * btn_side - 6 * s_gap)

	content.add_child(content_box)
	app.content = content_box

	mut footer := ui.Panel.new(layout: ui.FlowLayout.new(hgap: s_gap, vgap: s_gap))
	footer.set_bounds(0, 0, 0, btn_side + 2 * s_gap)

	footer_buttons := ['<', '>', 'H', 'B', 'S']
	for btn_text in footer_buttons {
		mut btn := ui.Button.new(text: btn_text)
		btn.set_bounds(0, 0, btn_side, btn_side)
		footer.add_child(btn)
	}

	main_panel.add_child_with_flag(header, ui.borderlayout_north)
	main_panel.add_child_with_flag(content, ui.borderlayout_center)
	main_panel.add_child_with_flag(footer, ui.borderlayout_south)

	app.add_child(main_panel)

	app.subscribe_event('key_down', fn [mut app, mut content_box] (e &ui.WindowKeyEvent) {
		app.on_key_down(e)
		content_box.on_key_down(e)
	})
	action_btn.subscribe_event('mouse_up', fn [mut app] (e &ui.MouseEvent) {
		app.goto_mouse(e)
	})

	app.gg.run()
}

fn (mut app App) goto_mouse(e &ui.MouseEvent) {
	app.goto()
}

fn (mut app App) on_key_down(e &ui.WindowKeyEvent) {
	if e.key == .enter || e.key == .kp_enter {
		app.goto()
	}
}

fn (mut app App) goto() {
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
		'✗ Certificate expired ${cert.expiry}'
	}

	println('${resp.code} ${resp.meta} ${resp.body.len >> 10}KB')
	println(domain)
	println(expire)

	if resp.meta.starts_with('text') {
		app.content.set_text(resp.body.bytestr())
	}
}
