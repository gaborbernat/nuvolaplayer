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

struct Args
{
	static bool debug = false;
	static bool verbose = false;
	static bool version;
	static string? app;
	static string? log_file;
	[CCode (array_length = false, array_null_terminated = true)]
	static string?[] command;
	
	public static const OptionEntry[] main_options =
	{
		{ "app", 'a', 0, GLib.OptionArg.FILENAME, ref Args.app, "Web app to control.", "ID" },
		{ "verbose", 'v', 0, OptionArg.NONE, ref Args.verbose, "Print informational messages", null },
		{ "debug", 'D', 0, OptionArg.NONE, ref Args.debug, "Print debugging messages", null },
		{ "version", 'V', 0, OptionArg.NONE, ref Args.version, "Print version and exit", null },
		{ "log-file", 'L', 0, OptionArg.FILENAME, ref Args.log_file, "Log to file", "FILE" },
		{ "", 0, 0, GLib.OptionArg.STRING_ARRAY, ref Args.command, "Command.", "COMMAND PARAMS..."},
		{ null }
	};
}

[PrintfFormat]
private static int quit(int code, string format, ...)
{
	stderr.vprintf(format, va_list());
	return code;
}

/*
  TODO: Nuvola Player 2 interface
  status    print current status (playback state, song info)
  play      start playback
  pause     pause playback
  toggle    toggle play/pause
  next      skip to next song
  prev      skip to previous song
  raise     raise Nuvola Player window
  quit      quit Nuvola Player
 */
const string DESCRIPTION = """Commands:

  list-actions
    - list available actions
  
  action NAME [STATE]
    - invoke action with name NAME
    - STATE parameter is used to select option of a radio action
  
  action-state NAME
    - get state of radio or toggle action with name NAME
    - does nothing for simple actions
    - you can set state actions with `action` command
  
  track-info [KEY]
   - prints track information
   - KEY can be 'all' (default), 'title', 'artist', 'album', 'state',
     'artwork_location' or 'artwork_file'
""";

public int main(string[] args)
{
	try
	{
		var opt_context = new OptionContext("- Control %s".printf(Nuvola.get_app_name()));
		opt_context.set_help_enabled(true);
		opt_context.add_main_entries(Args.main_options, null);
		opt_context.set_ignore_unknown_options(false);
		opt_context.set_description(DESCRIPTION);
		opt_context.parse(ref args);
	}
	catch (OptionError e)
	{
		stderr.printf("Error: Option parsing failed: %s\n", e.message);
		return 1;
	}
	
	if (Args.version)
	{
		stdout.printf("%s %s\n", Nuvola.get_app_name(), Nuvola.get_version());
		return 0;
	}
	
	FileStream? log = null;
	if (Args.log_file != null)
	{
		log = FileStream.open(Args.log_file, "w");
		if (log == null)
		{
			stderr.printf("Error: Cannot open log file '%s' for writing.\n", Args.log_file);
			return 1;
		}
	}
	
	Diorite.Logger.init(log != null ? log : stderr, Args.debug ? GLib.LogLevelFlags.LEVEL_DEBUG
	  : (Args.verbose ? GLib.LogLevelFlags.LEVEL_INFO: GLib.LogLevelFlags.LEVEL_WARNING),
	  "Control");
	
	if (Args.app == null)
	{
		try
		{
			var master = new Diorite.Ipc.MessageClient(build_master_ipc_id(), 500);
			if (!master.wait_for_echo(500))
				return quit(2, "Error: Failed to connect to %s master instance.\n", Nuvola.get_app_name());
			
			var response = master.send_message("get_top_runner");
			Diorite.Ipc.MessageServer.check_type_str(response, "ms");
			response.get("ms", out Args.app);
			
			if (Args.app == null || Args.app == "")
				return quit(1, "Error: No %s instance is running.\n", Nuvola.get_app_name());
			
			message("Using '%s' as web app id.", Args.app);
		}
		catch (Diorite.Ipc.MessageError e)
		{
			return quit(2, "Error: Communication with %s master instance failed: %s\n", Nuvola.get_app_name(), e.message);
		}
	}
	
	if (Args.command.length < 1)
		return quit(1, "Error: No command specified.\n");
	
	var client = new Diorite.Ipc.MessageClient(build_ui_runner_ipc_id(Args.app), 500);
	if (!client.wait_for_echo(500))
		return quit(2, "Error: Failed to connect to %s instance for %s.\n", Nuvola.get_app_name(), Args.app);
	
	var command = Args.command[0];
	var control = new Control(client);
	try
	{
		switch (command)
		{
		case "action":
			if (Args.command.length < 2)
				return quit(1, "Error: No action specified.\n");
			return control.activate_action(Args.command[1], Args.command.length == 2 ? null : Args.command[2]);
		case "list-actions":
			if (Args.command.length > 1)
				return quit(1, "Error: Too many arguments.\n");
			return control.list_actions();
		case "action-state":
			if (Args.command.length < 2)
				return quit(1, "Error: No action specified.\n");
			return control.action_state(Args.command[1]);
		case "track-info":
			if (Args.command.length > 2)
				return quit(1, "Error: Too many arguments.\n");
			return control.track_info(Args.command.length == 2 ? Args.command[1] : null);
		default:
			return quit(1, "Error: Unknown command '%s'.\n", command);
		}
	}
	catch (Diorite.Ipc.MessageError e)
	{
		return quit(2, "Error: Communication with %s instance failed: %s\n", Nuvola.get_app_name(), e.message);
	}
}

class Control
{
	private Diorite.Ipc.MessageClient conn;
	
	public Control(Diorite.Ipc.MessageClient conn)
	{
		this.conn = conn;
	}
	
	public int list_actions() throws Diorite.Ipc.MessageError
	{
		var response = conn.send_message("Nuvola.Actions.listGroups");
		stdout.printf("Available actions\n\nFormat: NAME (is enabled?) - label\n");
		var iter = response.iterator();
		string group_name = null;
		while (iter.next("s", out group_name))
		{
			stdout.printf("\nGroup: %s\n\n", group_name);
			var actions = conn.send_message("Nuvola.Actions.listGroupActions", new Variant("(s)", group_name));
			Variant action = null;
			var actions_iter = actions.iterator();
			while (actions_iter.next("@*", out action))
			{
				string name = null;
				string label = null;
				bool enabled = false;
				Variant options = null;
				assert(action.lookup("name", "s", out name));
				assert(action.lookup("label", "s", out label));
				assert(action.lookup("enabled", "b", out enabled));
				if (action.lookup("options", "@*", out options))
				{
					stdout.printf(" *  %s (%s) - %s\n", name, enabled ? "enabled" : "disabled", "invoke with following parameters:");
					Variant option = null;
					var options_iter = options.iterator();
					while (options_iter.next("@*", out option))
					{
						Variant parameter = null;
						assert(option.lookup("param", "@*", out parameter));
						assert(option.lookup("label", "s", out label));
						stdout.printf("    %s %s - %s\n", name, parameter.print(false), label != "" ? label : "(No label specified.)");
					}
				}
				else
				{
					stdout.printf(" *  %s (%s) - %s\n", name, enabled ? "enabled" : "disabled", label != "" ? label : "(No label specified.)");
				}
			}
		}
		return 0;
	}
	
	public int activate_action(string name, string? parameter_str) throws Diorite.Ipc.MessageError
	{
		Variant parameter;
		try
		{
			parameter =  parameter_str == null
			? new Variant.maybe(VariantType.BYTE, null)
			:  Variant.parse(null, parameter_str);
			
		}
		catch (VariantParseError e)
		{
			return quit(1,
				"Failed to parse Variant from string %s: %s\n\n"
				+ "See https://developer.gnome.org/glib/stable/gvariant-text.html for format specification.\n",
				parameter_str, e.message);
		}
		
		var response = conn.send_message("Nuvola.Actions.activate",
			new Variant.tuple({new Variant.string(name), parameter}));
		bool handled = false;
		if (!Diorite.variant_bool(response, ref handled))
			return quit(2, "Got invalid response from %s instance: %s\n", Nuvola.get_app_name(),
				response == null ? "null" : response.print(true));
		if (!handled)
			return quit(3, "%s instance doesn't understand requested action '%s'.\n", Nuvola.get_app_name(), name);
		
		message("Action %s %s was successful.", name, parameter_str);
		return 0;
	}
	
	public int action_state(string name) throws Diorite.Ipc.MessageError
	{
		var response = conn.send_message("Nuvola.Actions.getState", new Variant("(s)", name));
		if (response != null)
			stdout.printf("%s\n", response.print(false));
		return 0;
	}
	
	public int track_info(string? key=null) throws Diorite.Ipc.MessageError
	{
		var response = conn.send_message("Nuvola.MediaPlayer.getTrackInfo");
		var title = Diorite.variant_dict_str(response, "title");
		var artist = Diorite.variant_dict_str(response, "artist");
		var album = Diorite.variant_dict_str(response, "album");
		var state = Diorite.variant_dict_str(response, "state");
		var artwork_location = Diorite.variant_dict_str(response, "artworkLocation");
		var artwork_file = Diorite.variant_dict_str(response, "artworkFile");
		
		if (key == null || key == "all")
		{
			if (title != null)
				stdout.printf("Title: %s\n", title);
			if (artist != null )
				stdout.printf("Artist: %s\n", artist);
			if (album != null )
				stdout.printf("Album: %s\n", album);
			if (state != null )
				stdout.printf("State: %s\n", state);
			if (artwork_location != null )
				stdout.printf("Artwork location: %s\n", artwork_location);
			if (artwork_file != null )
				stdout.printf("Artwork file: %s\n", artwork_file);
		}
		else
		{
			switch (key)
			{
			case "title":
				if (title != null)
					stdout.printf("%s\n", title);
				break;
			case "artist":
				if (artist != null)
					stdout.printf("%s\n", artist);
				break;
			case "album":
				if (album != null)
					stdout.printf("%s\n", album);
				break;
			case "state":
				if (state != null)
					stdout.printf("%s\n", state);
				break;
			case "artwork_location":
				if (artwork_location != null)
					stdout.printf("%s\n", artwork_location);
				break;
			case "artwork_file":
				if (artwork_file != null)
					stdout.printf("%s\n", artwork_file);
				break;
			default:
				return quit(3, "Unknown key '%s'.\n", key);
			}
		}
		return 0;
	}
}

} // namespace Nuvola

