/*
 * Copyright 2011-2014 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class Connection : GLib.Object
{
	public Soup.SessionAsync session {get; construct set;}
	public File cache_dir {get; construct set;}
	
	public Connection(Soup.SessionAsync session, File cache_dir)
	{
		Object(session: session, cache_dir: cache_dir);
	}
	
	public async bool download_file(string uri, File local_file, out Soup.Message msg=null)
	{
		msg = new Soup.Message("GET", uri);
		SourceFunc resume = download_file.callback;
		session.queue_message(msg, (session, msg) => {resume();});
		yield;
		
		if (msg.status_code < 200 && msg.status_code >= 300)
			return false;
		
		unowned Soup.MessageBody body = msg.response_body;
		var dir = local_file.get_parent();
		if (!dir.query_exists(null))
		{
			try
			{
				dir.make_directory_with_parents(null);
			}
			catch (GLib.Error e)
			{
				critical("Unable to create directory: %s", e.message);
			}
		}
		
		FileOutputStream stream;
		try
		{
			stream = local_file.replace(null, false, FileCreateFlags.REPLACE_DESTINATION, null);
		}
		catch (GLib.Error e)
		{
			critical("Unable to create local file: %s", e.message);
			return false;
		}
		
		try
		{
			stream.write_all(body.data, null, null);
		}
		catch (IOError e)
		{
			critical("Unable to store remote file: %s", e.message);
			return false;
		}
		try
		{
			stream.close();
		}
		catch (IOError e)
		{
			warning("Unable to close stream: %s", e.message);
		}
		return true;
	}
}



} // namespace Nuvola
