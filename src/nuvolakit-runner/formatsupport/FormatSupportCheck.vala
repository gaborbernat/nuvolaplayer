/*
 * Copyright 2014 Jiří Janoušek <janousek.jiri@gmail.com>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met: 
 * 
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer. 
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution. 
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

namespace Nuvola
{

public class FormatSupportCheck : GLib.Object
{
	private static const string WARN_FLASH_KEY = "format_support.warn_flash";
	private static const string WARN_MP3_KEY = "format_support.warn_mp3";
	private FormatSupport format_support;
	private Diorite.Storage storage;
	private Diorite.ApplicationWindow window;
	private Config config;
	private FormatSupportDialog format_support_dialog = null;
	private Gtk.InfoBar? flash_bar = null;
	private Gtk.InfoBar? mp3_bar = null;
	
	public FormatSupportCheck(FormatSupport format_support, Diorite.ApplicationWindow window, Diorite.Storage storage,
	Config config)
	{
		this.format_support = format_support;
		this.window = window;
		this.storage = storage;
		this.config = config;
		config.set_default_value(WARN_FLASH_KEY, true);
		config.set_default_value(WARN_MP3_KEY, true);
	}
	
	public void check()
	{
		format_support.check.begin(format_support_check_done);
	}
	
	public void show_dialog(FormatSupportDialog.Tab tab=FormatSupportDialog.Tab.DEFAULT)
	{
		if (format_support_dialog == null)
		{
			format_support_dialog = new FormatSupportDialog(format_support, storage, window);
			format_support_dialog.flash_warning_switch.active = config.get_bool(WARN_FLASH_KEY);
			format_support_dialog.mp3_warning_switch.active = config.get_bool(WARN_MP3_KEY);
			Idle.add(() => {
				format_support_dialog.flash_warning_switch.notify["active"].connect_after(on_flash_warning_switched);
				format_support_dialog.mp3_warning_switch.notify["active"].connect_after(on_mp3_warning_switched);
				format_support_dialog.run();
				format_support_dialog.flash_warning_switch.notify["active"].disconnect(on_flash_warning_switched);
				format_support_dialog.mp3_warning_switch.notify["active"].disconnect(on_mp3_warning_switched);
				format_support_dialog.destroy();
				format_support_dialog = null;
				return false;
			});
		}
		format_support_dialog.show_tab(tab);
	}
	
	public void show_flash_warning(string text)
	{
		if (flash_bar != null || !config.get_bool(WARN_FLASH_KEY))
			return;
		flash_bar = new Gtk.InfoBar();
		flash_bar.show_close_button = true;
		flash_bar.message_type = Gtk.MessageType.WARNING;
		var label = new Gtk.Label(text);
		label.use_markup = true;
		label.set_line_wrap(true);
		label.hexpand = false;
		flash_bar.get_content_area().add(label);
		flash_bar.add_button("Details", Gtk.ResponseType.ACCEPT);
		flash_bar.response.connect(on_flash_response);
		flash_bar.show_all();
		window.info_bars.add(flash_bar);
	}
	
	public void show_mp3_warning(string text)
	{
		if (mp3_bar != null || !config.get_bool(WARN_MP3_KEY))
			return;
		mp3_bar = new Gtk.InfoBar();
		mp3_bar.show_close_button = true;
		mp3_bar.message_type = Gtk.MessageType.WARNING;
		var label = new Gtk.Label(text);
		label.use_markup = true;
		label.set_line_wrap(true);
		label.hexpand = false;
		mp3_bar.get_content_area().add(label);
		mp3_bar.add_button("Details", Gtk.ResponseType.ACCEPT);
		mp3_bar.response.connect(on_mp3_response);
		mp3_bar.show_all();
		window.info_bars.add(mp3_bar);
	}
	
	private void format_support_check_done(GLib.Object? source_object, GLib.AsyncResult result)
	{
		try
		{
			var format_support = source_object as FormatSupport;
			assert(format_support != null);
			format_support.check.end(result);
			unowned List<WebPlugin?> plugins = format_support.list_web_plugins();
			foreach (unowned WebPlugin plugin in plugins)
				debug("Nuvola.WebPlugin: %s (%s, %s) at %s: %s", plugin.name, plugin.enabled ? "enabled" : "disabled",
					plugin.is_flash ? "flash" : "not flash", plugin.path, plugin.description);
			var flash_plugins = format_support.n_flash_plugins;
			if (flash_plugins == 0)
			{
				show_flash_warning(
					"<b>Format support issue:</b> No Flash Player plugin has been found. Music playback may fail.");
				warning("No Flash plugin has been found.");
			}
			else if (flash_plugins > 1)
			{
				show_flash_warning(
					"<b>Format support issue:</b> More Flash Player plugins have been found. Wrong version may be in use.");
				warning("Too many Flash plugins have been found: %u", flash_plugins);
			}
			if (!format_support.mp3_supported)
			{
				show_mp3_warning(
					"<b>Format support issue:</b> No GStreamer MP3 Audio decoder has been found. Music playback may fail.");
				warning("MP3 Audio not supported.");
			}
			// TODO: Show infobar warning
		}
		catch (GLib.Error e)
		{
			warning("Plugin listing error: %s", e.message);
		}
	}
	
	private void on_flash_response(int response)
	{
		flash_bar.response.disconnect(on_flash_response);
		if (response == Gtk.ResponseType.ACCEPT)
			show_dialog(FormatSupportDialog.Tab.FLASH);
		window.info_bars.remove(flash_bar);
		flash_bar = null;
	}
	
	private void on_mp3_response(int response)
	{
		mp3_bar.response.disconnect(on_flash_response);
		if (response == Gtk.ResponseType.ACCEPT)
			show_dialog(FormatSupportDialog.Tab.MP3);
		window.info_bars.remove(mp3_bar);
		mp3_bar = null;
	}
	
	private void on_flash_warning_switched(GLib.Object o, ParamSpec p)
	{
		config.set_bool(WARN_FLASH_KEY, (o as Gtk.Switch).active);
	}
	
	private void on_mp3_warning_switched(GLib.Object o, ParamSpec p)
	{
		config.set_bool(WARN_MP3_KEY, (o as Gtk.Switch).active);
	}
}

} // namespace Nuvola
