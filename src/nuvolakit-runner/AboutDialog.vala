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

public class AboutDialog: Gtk.Dialog
{
	public AboutDialog(Gtk.Window? parent, WebAppMeta? web_app)
	{
		GLib.Object(title: "About", transient_for: parent);
		resizable = false;
		add_button("_Close", Gtk.ResponseType.CLOSE);
		var box = get_content_area();
		Pango.AttrList attributes = null;
		Gtk.Grid grid, title;
		Gtk.Label label;
		Gtk.Image? img;
		
		if (web_app != null)
		{
			grid = new Gtk.Grid();
			grid.margin = 10;
			grid.halign = Gtk.Align.FILL;
			grid.hexpand = true;
			title = new Gtk.Grid();
			title.column_spacing = 10;
			title.margin = 10;
			img = load_icon_image(64, web_app.icon, Nuvola.get_app_icon());
			if (img != null)
			{
				img.valign = img.halign = Gtk.Align.CENTER;
				title.attach(img, 0, 0, 1, 2);
			}
			label = new Gtk.Label(web_app.name);
			attributes = new Pango.AttrList() ;
			attributes.insert(new Pango.AttrSize(18*1000));
			attributes.insert(new Pango.AttrFontDesc(Pango.FontDescription.from_string("bold")));
			label.attributes = (owned) attributes;
			title.attach(label, 1, 0, 1, 1);
			title.attach(new Gtk.Label("Web App Integration Script"), 1, 1, 1, 1);
			grid.attach(title, 0, 0, 2, 1);
			grid.attach(new Gtk.Label("Version"), 0, 2, 1, 1);
			grid.attach(new Gtk.Label("%u.%u".printf(web_app.version_major, web_app.version_minor)), 1, 2, 1, 1);
			grid.attach(new Gtk.Label("Maintainer"), 0, 3, 1, 1);
			label = new Gtk.Label(Markup.printf_escaped("<a href=\"%s\">%s</a>", web_app.maintainer_link, web_app.maintainer_name));
			label.use_markup = true;
			grid.attach(label, 1, 3, 1, 1);
			grid.show_all();
			box.add(grid);
			
			grid = new Gtk.Grid();
			var separator = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
			separator.hexpand = true;
			grid.add(separator);
			label = new Gtk.Label("Powered by");
			label.margin = 10;
			grid.add(label);
			separator = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
			separator.hexpand = true;
			grid.add(separator);
			grid.show_all();
			box.add(grid);
		}
		
		grid = new Gtk.Grid();
		grid.margin = 10;
		grid.halign = Gtk.Align.FILL;
		grid.hexpand = true;
		title = new Gtk.Grid();
		title.column_spacing = 10;
		title.margin = 10;
		img = load_icon_image(64, null, Nuvola.get_app_icon());
		if (img != null)
		{
			img.valign = img.halign = Gtk.Align.CENTER;
			title.attach(img, 0, 0, 1, 2);
		}
		label = new Gtk.Label(Nuvola.get_app_name());
		attributes = new Pango.AttrList() ;
		attributes.insert(new Pango.AttrSize(18*1000));
		attributes.insert(new Pango.AttrFontDesc(Pango.FontDescription.from_string("bold")));
		label.attributes = (owned) attributes;
		title.attach(label, 1, 0, 1, 1);
		title.attach(new Gtk.Label("Web App Integration Runtime"), 1, 1, 1, 1);
		grid.attach(title, 0, 0, 2, 1);
		grid.attach(new Gtk.Label("Version"), 0, 2, 1, 1);
		label = new Gtk.Label(Nuvola.get_version());
		label.selectable = true;
		grid.attach(label, 1, 2, 1, 1);
		grid.attach(new Gtk.Label("Revision"), 0, 3, 1, 1);
		var revision = Nuvola.get_revision();
		if (revision.length > 20)
			revision = revision[0:20];
		label = new Gtk.Label(revision);
		label.selectable = true;
		grid.attach(label, 1, 3, 1, 1);
		grid.attach(new Gtk.Label("Copyright"), 0, 4, 1, 1);
		label = new Gtk.Label(Markup.printf_escaped("© 2011-2014 <a href=\"%s\">%s</a>", "http://gratipay.com/fenryxo", "Jiří Janoušek"));
		label.use_markup = true;
		grid.attach(label, 1, 4, 1, 1);
		grid.show_all();
		box.add(grid);
	}
	
	private Gtk.Image? load_icon_image(int size, string? path, string fallback_icon)
	{
		var pixbuf = load_icon_pixbuf(size, path, fallback_icon);
		if (pixbuf == null)
			return null;
		return new Gtk.Image.from_pixbuf(pixbuf);
	}
	
	private static Gdk.Pixbuf? load_icon_pixbuf(int size, string? path, string fallback_icon)
	{
		if (path != null)
		{
			try
			{
				return new Gdk.Pixbuf.from_file_at_size(path, size, size);
			}
			catch(GLib.Error e)
			{
				warning("Failde to load icon '%s': %s", path, e.message);
			}
		}
		try
		{
			return Gtk.IconTheme.get_default().load_icon(fallback_icon, size, 0);
		}
		catch (Error e)
		{
			var fallback2 = fallback_icon[0:fallback_icon.length - 1];
			warning("Unable to load fallback icon '%s'. %s. Trying '%s' instead.", fallback_icon, e.message, fallback2);
			
			try
			{
				return Gtk.IconTheme.get_default().load_icon(fallback2, size, 0);
			}
			catch (Error e)
			{
				warning("Unable to load fallback icon '%s'. %s", fallback2, e.message);
			}
		}
		return null;
	}
}

} // namespace Nuvola
