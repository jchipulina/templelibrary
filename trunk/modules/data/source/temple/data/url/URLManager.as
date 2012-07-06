/*
 *	Temple Library for ActionScript 3.0
 *	Copyright © MediaMonks B.V.
 *	All rights reserved.
 *	
 *	Redistribution and use in source and binary forms, with or without
 *	modification, are permitted provided that the following conditions are met:
 *	1. Redistributions of source code must retain the above copyright
 *	   notice, this list of conditions and the following disclaimer.
 *	2. Redistributions in binary form must reproduce the above copyright
 *	   notice, this list of conditions and the following disclaimer in the
 *	   documentation and/or other materials provided with the distribution.
 *	3. All advertising materials mentioning features or use of this software
 *	   must display the following acknowledgement:
 *	   This product includes software developed by MediaMonks B.V.
 *	4. Neither the name of MediaMonks B.V. nor the
 *	   names of its contributors may be used to endorse or promote products
 *	   derived from this software without specific prior written permission.
 *	
 *	THIS SOFTWARE IS PROVIDED BY MEDIAMONKS B.V. ''AS IS'' AND ANY
 *	EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 *	DISCLAIMED. IN NO EVENT SHALL MEDIAMONKS B.V. BE LIABLE FOR ANY
 *	DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 *	(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 *	LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 *	ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 *	(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 *	SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *	
 *	
 *	Note: This license does not apply to 3rd party classes inside the Temple
 *	repository with their own license!
 */

package temple.data.url 
{
	import temple.utils.types.ArrayUtils;
	import flash.net.URLLoaderDataFormat;
	import temple.core.debug.IDebuggable;
	import temple.core.debug.addToDebugManager;
	import temple.core.errors.TempleArgumentError;
	import temple.core.errors.TempleError;
	import temple.core.errors.throwError;
	import temple.core.events.CoreEventDispatcher;
	import temple.core.net.CoreURLLoader;
	import temple.data.xml.XMLParser;
	import temple.utils.TraceUtils;
	import temple.utils.types.ObjectUtils;
	import temple.utils.types.StringUtils;

	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.external.ExternalInterface;
	import flash.net.URLRequest;
	import flash.net.navigateToURL;
	import flash.utils.escapeMultiByte;
	
	/**
	 * @eventType temple.data.url.URLEvent.OPEN
	 */
	[Event(name = "URLEvent.open", type = "temple.data.url.URLEvent")]

	/**
	 * Dispatched when loading and parsing of urls.xml is complete.
	 * 
	 * @eventType flash.events.Event.COMPLETE
	 */
	[Event(name = "complete", type = "flash.events.Event")]
	
	/**
	 * The URLManager handles all URLs of a project. In most projects the URLs will depend on the environment. The live
	 * application uses different URLs as the development environment. To handle this you can store the urls in an
	 * external XML file, 'urls.xml'. By changing the 'currentgroup' inside the XML you can easily switch between
	 * different URLs.
	 * 
	 * The 'urls.xml' uses the following syntax:
	 * <listing version="3.0">
	 * &lt;?xml version="1.0" encoding="UTF-8"?&gt;
	 * &lt;urls currentgroup="development"&gt;
	 * 	&lt;group id="development"&gt;
	 * 		&lt;url name="link" url="http://www.development_url.com" target="_blank" /&gt;
	 * 		&lt;var name="path" value="http://www.development_path.com" /&gt;
	 * 	&lt;/group&gt;
	 * 	&lt;group id="live"&gt;
	 * 		&lt;url name="link" url="http://www.live_url.com" target="_blank" /&gt;
	 * 		&lt;var name="path" value="http://www.live_path.com" /&gt;
	 * 	&lt;/group&gt;
	 * 	&lt;url name="global" url="http://www.global.com" target="_blank" /&gt;
	 * 	&lt;url name="submit" url="{path}/submit" /&gt;
	 * &lt;/urls&gt;
	 * </listing>
	 * 
	 * <p>Every 'url'-node has a 'name', 'url' and (optional) 'target' attribute. Environment-dependent URLs are place
	 * inside a 'group'-node, global-urls are placed outside a group-node. It is also possible to use variables inside
	 * the urls.xml. You can define a variable by using a 'var'-node, with a 'name' and 'value' attribute. You can use
	 * the variable inside a URL with '{name-of-the-variable}', which will be replaced with the value. By defining the
	 * variable in different 'groups' the actual URL will we different.</p>
	 * 
	 * <p>The 'currentgroup' can be overruled by code. It is possible to supply different groups (comma-separated).</p>
	 * 
	 * <p>The <code>URLManager</code> is no longer a singleton. If you want to have an easy accessible instance of the
	 * <code>URLManager</code> you could use the constants <code>urlManagerInstance</code> inside the
	 * <code>temple.data.url</code> package.</p>
	 * 
	 * <p>By enabling the debug-property more information is logged.</p>
	 * 
	 * @example urls.xml used by the URLManagerExample.as example:
	 * 
	 * @includeExample urls.xml
	 * 
	 * @includeExample URLManagerExample.as
	 * 
	 * @see temple.data.url.#urlManagerInstance
	 * 
	 * @author Thijs Broerse, Arjan van Wijk
	 */
	public class URLManager extends CoreEventDispatcher implements IURLManager, IDebuggable
	{
		private var _urls:Object;
		private var _variables:Object;
		private var _isLoaded:Boolean;
		private var _isLoading:Boolean;
		private var _group:String;
		private var _rawData:XML;
		private var _loader:CoreURLLoader;
		private var _debug:Boolean;

		public function URLManager() 
		{
			this._urls = {};
			this._variables = {};
			
			addToDebugManager(this);
		}
		
		/**
		 * @inheritDoc
		 */
		public function get isLoaded():Boolean
		{
			return this._isLoaded;
		}

		/**
		 * @inheritDoc
		 */
		public function get isLoading():Boolean
		{
			return this._isLoading;
		}
		
		/**
		 * HashMap with name-value pairs for variables inside the url's which should be replaced.
		 * Variables are set as '{var}' and are only replaced onced, when the urls.xml is parsed.
		 * So therefor is only useful to set a variable before the URLManager is complete. 
		 */
		public function get variables():Object
		{
			return this._variables;
		}

		/**
		 * @inheritDoc
		 */
		public function load(url:String = "inc/xml/urls.xml", group:String = null):void 
		{
			if (this._isLoaded) throwError(new TempleError(this, "Data is already loaded"));
			if (this._isLoading) throwError(new TempleError(this, "Data is already loading"));
			
			this._isLoading = true;
			if (group) this._group = group;
			
			if (!this._loader)
			{
				this._loader = new CoreURLLoader();
				this._loader.dataFormat = URLLoaderDataFormat.TEXT;
				this._loader.addEventListener(Event.COMPLETE, this.handleURLLoaderEvent);
				this._loader.addEventListener(IOErrorEvent.IO_ERROR, this.handleURLLoaderEvent);
				this._loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, this.handleURLLoaderEvent);
				this._loader.addEventListener(ProgressEvent.PROGRESS, this.dispatchEvent);
			}
			this._loader.load(new URLRequest(url));
		}

		/**
		 * @inheritDoc
		 */
		public function parse(xml:XML, group:String = null):void
		{
			if (this._isLoaded) throwError(new TempleError(this, "Data is already loaded"));
			if (this._isLoading) throwError(new TempleError(this, "Data is already loading"));
			
			if (group) this._group = group;
			this.processData(xml);
		}

		/**
		 * @inheritDoc
		 */
		public function getData(name:String):URLData 
		{
			if (name == null) throwError(new TempleArgumentError(this, "name can not be null"));
			
			if (!this._isLoaded)
			{
				this.logError("getURLDataByName: URLs are not loaded yet");
				return null;
			}
			
			if (name in this._urls) return this._urls[name];
			
			this.logError("getURLDataByName: url with name '" + name + "' not found. Check urls.xml!");
			this.logError(TraceUtils.stackTrace());
			
			return null;
		}

		/**
		 * @inheritDoc
		 */
		public function get(name:String, variables:Object = null):String 
		{
			if (name == null) throwError(new TempleArgumentError(this, "name can not be null"));
			
			if (!this._isLoaded)
			{
				this.logError("getURLByName: URLs are not loaded yet");
				return null;
			}
			
			if (name in this._urls)
			{
				var url:String = URLData(this._urls[name]).url;
				return variables ? StringUtils.replaceVars(url, variables) : url;
			}
			
			this.logError("getURLByName: url with name '" + name + "' not found. Check urls.xml!");
			return null;
		}
		
		/**
		 * @inheritDoc
		 */
		public function has(name:String):Boolean
		{
			return name in this._urls;
		}

		/**
		 * @inheritDoc
		 */
		public function openByName(name:String, variables:Object = null):void 
		{
			var ud:URLData = this.getData(name);
			if (!ud) return;
			
			var url:String = ud.url;
			
			if (variables) url = StringUtils.replaceVars(url, variables);
			
			this.open(url, ud.target, name, ud.features);
		}

		/**
		 * @inheritDoc
		 */
		public function open(url:String, target:String = null, name:String = null, features:String = null):void
		{
			if (url == null) throwError(new TempleArgumentError(this, "url can not be null"));
			
			// only track before opening if SELF, PARENT of TOP
			if (target == Target.SELF || target == Target.PARENT || target == Target.TOP)
			{
				this.dispatchEvent(new URLEvent(URLEvent.OPEN, url, target, name));
				if (this.debug) this.logDebug("openURL: \"" + url + "\", target=\"" + target + "\"");
			}
			
			if (!ExternalInterface.available)
			{
				navigateToURL(new URLRequest(url), target);
			}
			else
			{
				if (features)
				{
					if (this.debug) this.logDebug("openURL using JavaScript, with features=\"" + features + "\"");
					ExternalInterface.call(String(<script><![CDATA[function(){ window.open("{url}", "{target}", "{features}");}]]></script>).replace("{url}", url).replace("{target}", target).replace("{features}", features));
				}
				else
				{
					var userAgent:String = String(ExternalInterface.call(<script><![CDATA[function(){ return navigator.userAgent; }]]></script>)).toLowerCase();
					
					/**
					 * Use JavaScript to open the URL when the browser is FireFox or Internet Explorer 7 or higher
					 */
					if (userAgent.indexOf("firefox") != -1 || (userAgent.indexOf("msie") != -1 && uint(userAgent.substr(userAgent.indexOf("msie") + 5, 3)) >= 7))
					{
						if (this.debug) this.logDebug("openURL using JavaScript, userAgent=\"" + userAgent + "\"");
						ExternalInterface.call(String(<script><![CDATA[function(){ window.open("{url}", "{target}");}]]></script>).replace("{url}", url).replace("{target}", target));
					}
					else
					{
						navigateToURL(new URLRequest(url), target);
					}
				}
			}
			
			// track afterwards to prevent popup-blocking if not SELF
			if (target != Target.SELF && target != Target.PARENT && target != Target.TOP)
			{
				this.dispatchEvent(new URLEvent(URLEvent.OPEN, url, target, name));
				if (this.debug) this.logDebug("openURL: \"" + url + "\", target=\"" + target + "\"");
			}
		}
		
		/**
		 * @inheritDoc
		 */
		public function get group():String
		{
			return this._group;
		}

		/**
		 * @inheritDoc
		 */
		public function set group(value:String):void
		{
			if (this._group == value) return;
			this._group = value;
			if (this._isLoaded) this.processXml();
		}

		/**
		 * @inheritDoc
		 */
		public function addGroup(group:String):void
		{
			if (this._group)
			{
				var groups:Array = this._group.split(",");
				groups.push(group);
				groups = ArrayUtils.createUniqueCopy(groups);
				this.group = groups.join(",");
			}
			else
			{
				this.group = group;
			}
		}

		/**
		 * @inheritDoc
		 */
		public function removeGroup(group:String):void
		{
			var groups:Array = this._group.split(",");
			ArrayUtils.removeValueFromArray(groups, group);
			this.group = groups.join(",");
		}

		/**
		 * @inheritDoc
		 */
		public function setVariable(name:String, value:String):void
		{
			this._variables[name] = value;
			if (this.isLoaded) this.processXml();
		}
		
		/**
		 * @inheritDoc
		 */
		public function get debug():Boolean
		{
			return this._debug;
		}

		/**
		 * @inheritDoc
		 */
		public function set debug(value:Boolean):void
		{
			this._debug = value;
		}
		
		private function handleURLLoaderEvent(event:Event):void
		{
			switch (event.type)
			{
				case Event.COMPLETE:
				{
					this.processData(XML(this._loader.data));
					break;
				}
				case IOErrorEvent.IO_ERROR:
				case SecurityErrorEvent.SECURITY_ERROR:
				{
					this._isLoaded = false;
					this._isLoading = false;
					this.dispatchEvent(event);
					break;
				}
			}
		}

		/**
		 * @private
		 */
		private function processData(data:XML):void 
		{
			this._rawData = data;
			
			this.processXml();

			this._isLoaded = true;
			this._isLoading = false;
			
			this.dispatchEvent(new Event(Event.COMPLETE));
		}
		
		private function processXml():void
		{
			if (this._group)
			{
				if (this.debug) this.logInfo("processData: group is set to '" + this._group + "'");
			}
			else
			{
				this._group = this._rawData.@currentgroup; 
				if (this.debug) this.logInfo("processData: group is '" + this._group + "'");
			}
			
			var groups:Array = this._group.split(',');
			
			var i:int;
			
			// get grouped variables
			var vars:XMLList= new XMLList();
			for (i = 0; i < groups.length; i++)
			{
				vars += this._rawData.group.(@id == (groups[i])).child('var');
			}
			
			// add ungrouped variables
			vars += this._rawData.child('var');
			
			var key:String, node:XML;
			
			for (i = 0;i < vars.length(); i++)
			{
				node = XML(vars[i]);
				
				if (!node.hasOwnProperty('@name'))
				{
					this.logError("variable has no name attribute: " + node.toXMLString());
				}
				else
				{
					if (!node.hasOwnProperty('@value')) this.logWarn("variable '" + node.@name + "' has no value attribute: " + node.toXMLString());
					if (!this._variables.hasOwnProperty(node.@name))
					{
						var value:String = node.@value;
						if (node.hasOwnProperty('@escape') && node.@escape == "true") value = escape(value);
						if (node.hasOwnProperty('@escapemultibyte') && node.@escapemultibyte == "true") value = escapeMultiByte(value);
						this._variables[node.@name] = value;
					}
				}
			}
			
			// parse vars in vars
			if (ObjectUtils.hasValues(this._variables))
			{
				do
				{
					var changed:Boolean = false;
					for (var key1:String in this._variables)
					{
						for (var key2:String in this._variables)
						{
							var prevValue:String = this._variables[key1]; 
							this._variables[key1] = this._variables[key1].split('{' + key2 + '}').join(this._variables[key2]);
							if (prevValue != this._variables[key1]) changed = true;
						}
					}
				}
				while (changed);
			}
			
			if (this.debug)
			{
				var s:String = "";
				for (key in this._variables)
				{
					s += "\n\t" + key + ": " + this._variables[key];
				}
				this.logDebug("Current vars in URLManager: " + s);
			}

			
			this._urls = {};
			var urls:XMLList = new XMLList();
			
			// get grouped urls
			for (i = 0; i < groups.length; i++)
			{
				// check if currentgroup is valid
				if (groups[i] && this._rawData.group.(@id == (groups[i])) == undefined)
				{
					this.logError("processData: group '" + groups[i] + "' not found, check urls.xml");
				}
				else
				{
					urls += this._rawData.group.(@id == (groups[i])).url;
				}
			}

			// add ungrouped urls
			urls += this._rawData.url;
			
			var ud:URLData;
			
			for each (ud in XMLParser.parseList(urls, URLData, false, this.debug))
			{
				if (ud.name in this._urls)
				{
					this.logError("Duplicate URL name '" + ud.name + "'");
				}
				else
				{
					this._urls[ud.name] = ud;
				}
			}
			
			if (this.debug)
			{
				s = "";
				for each (ud in this._urls)
				{
					s += "\n\t" + ud.name + ": " + ud.url;
				}
				this.logDebug("Current urls in XML: " + s);
			}
			
			// replace vars in urls
			if (ObjectUtils.hasValues(this._variables))
			{
				for each (ud in this._urls)
				{
					for (key in this._variables)
					{
						ud.url = ud.url.split('{' + key + '}').join(this._variables[key]);
					}
				}
			}
			
			if (this.debug)
			{
				s = "";
				for each (ud in this._urls)
				{
					s += "\n\t" + ud.name + ": " + ud.url;
				}
				this.logDebug("Current urls in URLManager: " + s);
			}
		}

		/**
		 * Destructs the URLManager
		 */
		override public function destruct():void
		{
			if (this._loader)
			{
				this._loader.destruct();
			}
			this._loader = null;
			this._urls = null;
			this._rawData = null;
			this._group = null;
			
			super.destruct();
		}
	}
}
