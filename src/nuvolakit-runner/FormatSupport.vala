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

public class FormatSupport: GLib.Object
{
	public uint n_flash_plugins { get; private set; default = 0;}
	public bool mp3_supported { get; private set; default = false;}
	private List<WebPlugin?> web_plugins = null;
	private string mp3_file;
	
	public FormatSupport(string mp3_file)
	{
		this.mp3_file = mp3_file;
	}
	
	public async void check() throws GLib.Error
	{
		yield collect_web_plugins();
		mp3_supported = yield check_mp3(mp3_file, true);
	}
	
	public unowned List<WebPlugin?> list_web_plugins()
	{
		return web_plugins;
	}
	
	private async void collect_web_plugins() throws GLib.Error
	{
		if (web_plugins != null)
			return;
		
		var wc = WebKit.WebContext.get_default();
		var plugins = yield wc.get_plugins(null);
		uint n_flash_plugins = 0;
		foreach (var plugin in plugins)
		{
			var name = plugin.get_name();
			var is_flash = name.down().strip() == "shockwave flash";
			web_plugins.append({name, plugin.get_path(), plugin.get_description(), true, is_flash});
			if (is_flash)
				n_flash_plugins++;
		}
		this.n_flash_plugins = n_flash_plugins;
	}
	
	private async bool check_mp3(string audio_file, bool silent)
	{
		var pipeline = new AudioPipeline(audio_file);
		return yield pipeline.check(silent);
	}
}

public struct WebPlugin
{
	public string name;
	public string path;
	public string description;
	public bool enabled;
	public bool is_flash;
}

public class AudioPipeline : GLib.Object
{
	private Gst.Pipeline? pipeline = null;
	private SourceFunc? resume_async = null;
	private bool result = false;
	private string audio_file;
	private bool silent = true;
	
	public AudioPipeline(string audio_file)
	{
		this.audio_file = audio_file;
	}
	
	public async bool check(bool silent=true)
	{
		init_gstreamer();
		this.silent = silent;
		var source = Gst.ElementFactory.make ("filesrc", "source");
		var decoder = Gst.ElementFactory.make ("decodebin", "decoder");
		pipeline = new Gst.Pipeline ("test-pipeline");
		if (source == null || decoder == null || pipeline == null)
		{
			warning("Error: source, decoder or pipeline is null");
			return false;
		}
		pipeline.add_many (source, decoder);
		if (!source.link(decoder))
		{
			warning("Failed to link source -> decoder");
			return false;
		}
		
		var bus = pipeline.get_bus();
		bus.message.connect(on_bus_message);
		bus.add_signal_watch();
		decoder.pad_added.connect(on_pad_added);
		source.@set("location", audio_file);
		
		switch (pipeline.set_state(Gst.State.PLAYING))
		{
		case Gst.StateChangeReturn.SUCCESS:
			pipeline.set_state(Gst.State.NULL);
			return true;
		case Gst.StateChangeReturn.ASYNC:
			resume_async = check.callback;
			yield;
			return result;
		default:
			pipeline.set_state(Gst.State.NULL);
			warning("Unable to change %s pipeline status (sync)", Gst.version_string());
			return false;
		}
	}
	
	public bool stop()
	{
		if (pipeline != null)
		{
			pipeline.set_state(Gst.State.NULL);
			pipeline = null;
		}
		if (resume_async != null)
		{
			resume_async();
			resume_async = null;
		}
		return result;
	}
	
	private void init_gstreamer()
	{
		string[] a = {};
		unowned string[] b = a;
		try
		{
			Gst.init_check(ref b);
		}
		catch(Error e)
		{
			warning("Unable to init %s: %s", Gst.version_string(), e.message);
		}
	}
	
	private void quit(bool result)
	{
		this.result = result;
		stop();
	}
	
	private void on_pad_added (Gst.Element element, Gst.Pad pad)
	{
		if (silent)
		{
			var sink = Gst.ElementFactory.make ("fakesink", "sink");
			pipeline.add(sink);
			if (pad.link(sink.get_static_pad("sink")) != Gst.PadLinkReturn.OK)
				warning("Failed to link pad to sink.");
			sink.sync_state_with_parent();
		}
		else
		{
			var conv = Gst.ElementFactory.make("audioconvert",  "converter");
			var sink = Gst.ElementFactory.make("autoaudiosink", "sink");
			pipeline.add_many(conv, sink);
			if (!conv.link(sink))
				warning("Failed to link conv to sink.");
			if (pad.link(conv.get_static_pad("sink")) != Gst.PadLinkReturn.OK)
				warning("Failed to link pad to conv.");
			conv.sync_state_with_parent();
			sink.sync_state_with_parent();
		}
	}
	
	private void on_bus_message(Gst.Message msg)
	{
		GLib.Error msg_error;
		string msg_debug;
		switch (msg.type)
		{
		case Gst.MessageType.STATE_CHANGED:
			if (msg.src == pipeline)
			{
				Gst.State old_state;
				Gst.State new_state;
				Gst.State pending_state;
				msg.parse_state_changed (out old_state, out new_state, out pending_state);
				debug("Pipeline state changed from %s to %s pending %s:\n",
					Gst.Element.state_get_name(old_state),
					Gst.Element.state_get_name(new_state),
					Gst.Element.state_get_name(pending_state));
				
				if (new_state == Gst.State.PLAYING)
					result = true;
			}
			break;
		case Gst.MessageType.EOS:
			debug("End of stream: %s", audio_file);
			pipeline.set_state(Gst.State.NULL);
			quit(true);
			break;
		case Gst.MessageType.ERROR:
			msg.parse_error(out msg_error, out msg_debug);
			warning("Gst error: %s, %s", msg_error.message, msg_debug);
			quit(false);
			break;
		case Gst.MessageType.WARNING:
			msg.parse_warning(out msg_error, out msg_debug);
			warning("Gst warning: %s, %s", msg_error.message, msg_debug);
			break;
		case Gst.MessageType.INFO:
			msg.parse_info(out msg_error, out msg_debug);
			debug("Gst info: %s, %s", msg_error.message, msg_debug);
			break;
		}
	}
}

} // namespace Nuvola