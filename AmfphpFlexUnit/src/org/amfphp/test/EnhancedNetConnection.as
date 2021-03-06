package org.amfphp.test
{
	import flash.events.AsyncErrorEvent;
	import flash.events.IOErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.NetConnection;
	import flash.net.ObjectEncoding;
	import flash.net.Responder;
	import flash.utils.ByteArray;
	
	import flexUnitTests.TestConfig;
	
	
	/**
	 * better class for tests, with extra events, traces, and no responder
	 * */
	public class EnhancedNetConnection extends NetConnection
	{
		/**
		 * extra events for the nc. there are no events for onResult and onStatus, so create some here. 
		 * We need these events for async testing
		 * */ 
		static public const EVENT_ONRESULT:String = "onResult";
		static public const EVENT_ONSTATUS:String = "onStatus";
		
		
		static private var requestCounter:uint = 0;
		
		private var testMeta:String;
		
		public function EnhancedNetConnection()
		{
			super();
			addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);	
			addEventListener(AsyncErrorEvent.ASYNC_ERROR, onAsyncError);	
			addEventListener(IOErrorEvent.IO_ERROR, onIoError);	
			addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);	
		}
		
		public function setTestMeta(testClassName:String, testMethodName:String):void{
			//hackish, todo
			testMeta = testClassName.replace('flexUnitTests::', '').replace('flexUnitTests.voTests::', '') + "_" + testMethodName;
		}
		
		private function onNetStatus(event:NetStatusEvent):void{
			trace(event.toString() + "\r info code : " + event.info.code + "\r info description : " + event.info.description + "\r info details : " + event.info.details + "\r info level :" +  event.info.level );
			
		}
		
		private function onAsyncError(event:AsyncErrorEvent):void{
			trace(event.toString());
		}
		
		private function onIoError(event:IOErrorEvent):void{
			trace(event.toString());
			
		}
		
		private function onSecurityError(event:SecurityErrorEvent):void{
			trace(event.toString());
			
		}
		
		private function onResult(res:Object):void{
			dispatchEvent(new ObjEvent(EVENT_ONRESULT, res)); 
		}
		
		private function onStatus(statusObj:Object):void{
			//trace("onStatus. faultcode :" + statusObj.faultCode + "\r faultDetail : " + statusObj.faultDetail + "\r faultString : " + statusObj.faultString);
			dispatchEvent(new ObjEvent(EVENT_ONSTATUS, statusObj)); 
		}
		
		/**
		 * like call, but with out responder, and events instead. necessary for use with flex unit
		 * support for doing without server added
		 * */
		public function callWithEvents(command:String, ... args):void{
			trace("call for " +testMeta);
			requestCounter++;
			if(!TestConfig.gateway.substr(0, 4) == "http"){
				var callArgs:Array = new Array(command, new Responder(onResult, onStatus));
				for each(var arg:* in args){
					callArgs.push(arg);
					
				}	
				call.apply(this, callArgs);
				
			}else{
				//local php exe
				var data:ByteArray = new ByteArray();
				data.objectEncoding = objectEncoding;	// Set the AMF encoding
				
				data.writeByte(0x00);
				data.writeByte(0x03);	// Set the Flash Player type (in this case, Flash Player 9+)
				
				//Write the headers
				data.writeByte(0x00);	
				data.writeByte(0x00);	// Set the number of headers

				//Write one body
				data.writeByte(0x00);
				data.writeByte(0x01);
				
				//Write the target (null)
				data.writeByte(0x00);
				data.writeByte(command.length);
				data.writeUTFBytes(command);
				
				//Now write the response handler
				data.writeByte(0x00);
				data.writeByte(0x02);
				data.writeUTFBytes("/1");
				
				//Write the number of bytes in the body
				data.writeByte(0x00);
				data.writeByte(0x00);
				data.writeByte(0x00);
				data.writeByte(0x00); //amfphp doesn't read this, so no matter
				
				
				//Write the AMF3 bytecode
				if (objectEncoding == ObjectEncoding.AMF3)
				{
					data.writeByte(0x11);
				}
				//Then the object
				data.writeObject(args);
				
				//needs AIR  (with extendedDesktop profile)
				/*
				//write message to file
				var fs : FileStream = new FileStream();
				var amfRequestFile : File = File.applicationStorageDirectory.resolvePath(requestCounter + "_" + testMeta + 'request.amf');
				fs.open(amfRequestFile, FileMode.WRITE);
				fs.writeBytes(data);
				fs.close();
				
				//send to php
				var nativeProcessStartupInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
				var file:File = File.applicationDirectory.resolvePath(TestConfig.gateway);
				nativeProcessStartupInfo.executable = file;
				
				//find path to test.php
				var scriptFile:File = File.applicationDirectory.resolvePath('test.php');
				
				var processArgs:Vector.<String> = new Vector.<String>();
				
				processArgs[0] = scriptFile.nativePath;
				processArgs[1] = amfRequestFile.nativePath;
//				processArgs[1] = "'file_put_contents(\"zer\",\"eeee\");'";
				nativeProcessStartupInfo.arguments = processArgs;
				
				process = new NativeProcess();
				process.start(nativeProcessStartupInfo);
				process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onOutputData);
				process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onErrorData);
				process.addEventListener(NativeProcessExitEvent.EXIT, onExit);
				process.addEventListener(IOErrorEvent.STANDARD_OUTPUT_IO_ERROR, onIOError);
				process.addEventListener(IOErrorEvent.STANDARD_ERROR_IO_ERROR, onIOError);
				*/
			}				
			
		}
		/*
		public function onOutputData(event:ProgressEvent):void
		{
			trace('bytes ' + process.standardOutput.bytesAvailable);
			//trace("got : " + process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable));
			var rawData:ByteArray = new ByteArray();
			
			process.standardOutput.readBytes(rawData);
			
			//save to file
			var fs : FileStream = new FileStream();
			var responseAmfFile : File = File.applicationStorageDirectory.resolvePath(requestCounter + "_" + testMeta + 'response.amf');
			trace("response stored at " + responseAmfFile.nativePath);
			fs.open(responseAmfFile, FileMode.WRITE);
			fs.writeBytes(rawData);
			//reset byte array, just in case
			rawData.position = 0;
			trace(rawData.readUTFBytes(rawData.bytesAvailable));
			rawData.position = 0;
			fs.close();
			
//			rawData.objectEncoding = ObjectEncoding.AMF3;
			
			var sendEvent:ObjEvent;
			
			//Determine if data is valid
			try{
				
				
				if (rawData[0] == 0x00)
				{
					var numHeaders:uint = rawData[2] * 256 + rawData[3];
					rawData.position = 4;
					for (var i:int = 0; i < numHeaders; i++)
					{
						var strlen:int = rawData.readUnsignedShort();
						var key:String = rawData.readUTFBytes(strlen);
						var required:Boolean = rawData.readByte() == 1;
						var len:int = rawData.readUnsignedInt();
						rawData.position += len; //Just skip for now
					}
					var numBodies:uint = rawData.readUnsignedShort();
					for (var i:int = 0; i < numBodies; i++)
					{
						var strlen:int = rawData.readUnsignedShort();
						var target:String = rawData.readUTFBytes(strlen);
						
						strlen = rawData.readUnsignedShort();
						var response:String = rawData.readUTFBytes(strlen);
						
						var bodyLen:uint = rawData.readUnsignedInt();
						
						//var key:String = rawData.readUTFBytes(strlen);
						//var required:Boolean = rawData.readByte() == 1;
						//var len:int = rawData.readUnsignedInt();
						
						
						if (objectEncoding == ObjectEncoding.AMF3)
						{
							var amf3Byte:uint = rawData.readUnsignedByte();
							rawData.objectEncoding = ObjectEncoding.AMF3;
						}
						
						var bodyVal:Object = rawData.readObject();
						rawData.objectEncoding = ObjectEncoding.AMF0;
						
						if (target == '/1/onDebugEvents')
						{
							//Look at the bodyVal
							for (var j:uint = 0; j < bodyVal[0].length; j++)
							{
								if (bodyVal[0][j].EventType == 'trace')
								{
									//Bingo, we got trace
	//								traceMessages = bodyVal[0][j].messages;
								}
								else if (bodyVal[0][j].EventType == 'profiling')
								{
									//Bingo, we got trace
		//							profiling = bodyVal[0][j];
								}
							}
						}
						else if (target == '/1/onResult')
						{
							sendEvent = new ObjEvent(EVENT_ONRESULT, bodyVal);
							
						}
						else if (target == '/1/onStatus')
						{
							if(bodyVal){
								trace("onStatus. faultcode :" + bodyVal.faultCode + "\r faultDetail : " + bodyVal.faultDetail + "\r faultString : " + bodyVal.faultString);
							}
							sendEvent = new ObjEvent(EVENT_ONSTATUS, bodyVal); 
							//dispatchEvent(fe);
						}
					}
				}
				else
				{
					//Create a new Fault event
					rawData.position = 0;
					var errorMessage:String = rawData.readUTFBytes(rawData.length);
					sendEvent = new ObjEvent(EVENT_ONSTATUS, "Invalid AMF message" +  errorMessage);
					//dispatchEvent(fe);
				}
				
				var totalTime:uint = 0;
				if (rawData.bytesAvailable == 2)
				{
					totalTime = rawData.readUnsignedShort();
				}
				else
				{
				}
				
			}catch(e:Error){
				trace(e.message);				
				sendEvent = new ObjEvent(EVENT_ONSTATUS, "error parsing" +  e.message);
			}
			dispatchEvent(sendEvent);
		}
		
		public function onErrorData(event:ProgressEvent):void
		{
			trace("ERROR -", process.standardError.readUTFBytes(process.standardError.bytesAvailable)); 
		}
		/*
		public function onExit(event:NativeProcessExitEvent):void
		{
			//trace("Process exited with ", event.exitCode);
		}
		*/
		public function onIOError(event:IOErrorEvent):void
		{
			trace(event.toString());
			
		}				
		
	}
}