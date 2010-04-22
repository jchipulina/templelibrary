/*
 *	 
 *	Temple Library for ActionScript 3.0
 *	Copyright © 2010 MediaMonks B.V.
 *	All rights reserved.
 *	
 *	http://code.google.com/p/templelibrary/
 *	
 *	Redistribution and use in source and binary forms, with or without
 *	modification, are permitted provided that the following conditions are met:
 *	
 *	- Redistributions of source code must retain the above copyright notice,
 *	this list of conditions and the following disclaimer.
 *	
 *	- Redistributions in binary form must reproduce the above copyright notice,
 *	this list of conditions and the following disclaimer in the documentation
 *	and/or other materials provided with the distribution.
 *	
 *	- Neither the name of the Temple Library nor the names of its contributors
 *	may be used to endorse or promote products derived from this software
 *	without specific prior written permission.
 *	
 *	
 *	Temple Library is free software: you can redistribute it and/or modify
 *	it under the terms of the GNU Lesser General Public License as published by
 *	the Free Software Foundation, either version 3 of the License, or
 *	(at your option) any later version.
 *	
 *	Temple Library is distributed in the hope that it will be useful,
 *	but WITHOUT ANY WARRANTY; without even the implied warranty of
 *	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *	GNU Lesser General Public License for more details.
 *	
 *	You should have received a copy of the GNU Lesser General Public License
 *	along with Temple Library.  If not, see <http://www.gnu.org/licenses/>.
 *	
 */

package temple.debug 
{

	/**
	 * This class contains possible values for debugMode. DebugMode is used by the DebugManager.
	 * 
	 * @see temple.debug.DebugManager
	 * 
	 * @date 28 aug 2009 22:15:49
	 * @author Arjan van Wijk (arjan at mediamonks dot com)
	 */
	public final class DebugMode
	{
		/**
		 * Debug will be set to false on all debuggable object. So no debug messages will be logged.
		 */
		public static const NONE:uint = 1;
		
		/**
		 * Debug can be set to each debuggable object individually.
		 */
		public static const CUSTOM:uint = 2;
		
		/**
		 * Debug will be set to true on all debuggable object. So debug messages will be logged.
		 */
		public static const ALL:uint = 4;

		/**
		 * Returns a readable string of the provided DebugMode
		 */
		public static function modeToString(debugMode:uint):String 
		{
			switch (debugMode)
			{
				case DebugMode.NONE: return "none";
				case DebugMode.CUSTOM: return "custom";
				case DebugMode.ALL: return "all";
			}
			return "invalid";
		}
	}
}