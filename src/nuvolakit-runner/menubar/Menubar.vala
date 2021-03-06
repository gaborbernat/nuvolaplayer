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

public class MenuBar: GLib.Object, MenuBarInterface
{
	private Diorite.ActionsRegistry actions_reg;
	private HashTable<string, SubMenu> menus;
	private Menu? menubar = null;
	private Menu? app_menu = null;
	
	public MenuBar(Diorite.ActionsRegistry actions_reg)
	{
		this.actions_reg = actions_reg;
		this.menus = new HashTable<string, SubMenu>(str_hash, str_equal);
		menubar = new Menu();
		app_menu = actions_reg.build_menu({
			Actions.KEYBINDINGS, Actions.FORMAT_SUPPORT,
			Actions.PREFERENCES, Actions.HELP, Actions.ABOUT, Actions.QUIT}, true, false);
	}
	
	public void set_menus(Gtk.Application app)
	{
		app.set_menubar(menubar);
		if (app.app_menu == null)
			app.set_app_menu(app_menu);
	}
	
	public void update()
	{
		menubar.remove_all();
		menubar.append_submenu("_Go", actions_reg.build_menu({Actions.GO_HOME, Actions.GO_RELOAD, Actions.GO_BACK, Actions.GO_FORWARD}, true, false));
		menubar.append_submenu("_View", actions_reg.build_menu({Actions.ZOOM_IN, Actions.ZOOM_OUT, Actions.ZOOM_RESET, "|", Actions.TOGGLE_SIDEBAR}, true, false));
		var submenus = menus.get_values();
		foreach (var submenu in submenus)
			submenu.append_to_menu(actions_reg, menubar);
	}
	
	public void set_submenu(string id, SubMenu submenu)
	{
		menus[id] = submenu;
	}
	
	public bool set_menu(string id, string label, string[] actions)
	{
		set_submenu(id, new SubMenu(label, actions));
		update();
		return !Binding.CONTINUE;
	}
}

public class SubMenu
{
	public string label {get; private set;}
	private string[] actions;
	
	public SubMenu(string label, string[] actions)
	{
		this.label = label;
		this.actions = actions;
	}
	
	public void append_to_menu(Diorite.ActionsRegistry actions_reg, Menu menu)
	{
		menu.append_submenu(label, actions_reg.build_menu(actions, true, false));
	}
}

} // namespace Nuvola
