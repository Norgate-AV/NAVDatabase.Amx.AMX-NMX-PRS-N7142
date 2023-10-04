MODULE_NAME='mAMX-NMX-PRS-N7142' 	(
                                        dev vdvObject,
                                        dev dvPort
                                    )

(***********************************************************)
#include 'NAVFoundation.ModuleBase.axi'

/*
 _   _                       _          ___     __
| \ | | ___  _ __ __ _  __ _| |_ ___   / \ \   / /
|  \| |/ _ \| '__/ _` |/ _` | __/ _ \ / _ \ \ / /
| |\  | (_) | | | (_| | (_| | ||  __// ___ \ V /
|_| \_|\___/|_|  \__, |\__,_|\__\___/_/   \_\_/
                 |___/

MIT License

Copyright (c) 2023 Norgate AV Services Limited

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

(***********************************************************)
(*          DEVICE NUMBER DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_DEVICE

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

constant long TL_DRIVE	= 1
constant long TL_IP_CHECK = 2

constant integer MAX_OUTPUTS = 2

constant integer IP_PORT = 50002

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile long ltDrive[] = { 200 }
volatile long ltIPCheck[] = { 3000 }

volatile integer iSemaphore
volatile char cRxBuffer[NAV_MAX_BUFFER]

volatile integer iCommandBusy

volatile integer iOutput[MAX_OUTPUTS]
volatile integer iPending[MAX_OUTPUTS]

volatile char cIPAddress[NAV_MAX_CHARS]
volatile integer iClientConnected

(***********************************************************)
(*               LATCHING DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_LATCHING

(***********************************************************)
(*       MUTUALLY EXCLUSIVE DEFINITIONS GO BELOW           *)
(***********************************************************)
DEFINE_MUTUALLY_EXCLUSIVE

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)
(* EXAMPLE: DEFINE_FUNCTION <RETURN_TYPE> <NAME> (<PARAMETERS>) *)
(* EXAMPLE: DEFINE_CALL '<NAME>' (<PARAMETERS>) *)
define_function Send(char cPayload[]) {
    NAVLog(NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_TO, dvPort, cPayload))
    send_string dvPort, "cPayload"
    wait 1 iCommandBusy = false
}


define_function char[NAV_MAX_CHARS] Build(integer iInput, integer iOutput) {
    return "'set: ', itoa(iInput), ',', itoa(iOutput), NAV_CR"
}


define_function Drive() {
    stack_var integer x
    if (!iCommandBusy) {
	for (x = 1; x <= MAX_OUTPUTS; x++) {
	    if (iPending[x] && !iCommandBusy) {
		iPending[x] = false
		iCommandBusy = true
		Send(Build(iOutput[x], x))
	    }
	}
    }
}


define_function MaintainIPClient() {
    if (!iClientConnected && length_array(cIPAddress)) {
	NAVClientSocketOpen(dvPort.PORT, cIPAddress, IP_PORT, IP_TCP)
    }
}

(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START {

}

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT
data_event[dvPort] {
    online: {
	iClientConnected = true
	if (!timeline_active(TL_DRIVE)) {
	    NAVTimelineStart(TL_DRIVE, ltDrive, TIMELINE_ABSOLUTE, TIMELINE_REPEAT)
	}

	NAVLog("NAVStringSurroundWith(NAVDeviceToString(data.device), '[', ']'), '-[', 'IP Client Online', ']'")
    }
    string: {
	[vdvObject, DEVICE_COMMUNICATING] = true
	[vdvObject, DATA_INITIALIZED] = true
	NAVLog(NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_FROM, dvPort, data.text))
    }
    offline: {
	iClientConnected = false
	NAVClientSocketClose(data.device.port)
	NAVTimelineStop(TL_DRIVE)

	NAVLog("NAVStringSurroundWith(NAVDeviceToString(data.device), '[', ']'), '-[', 'IP Client Offline', ']'")
    }
    onerror: {
	iClientConnected = false
	NAVTimelineStop(TL_DRIVE)

	NAVLog("NAVStringSurroundWith(NAVDeviceToString(data.device), '[', ']'), '-[', 'IP Client OnError', ']'")
    }
}

data_event[vdvObject] {
    online: {
	NAVCommand(data.device,"'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_DESCRIPTION,Presentation Switcher'")
	NAVCommand(data.device,"'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_MANUFACTURER_URL,www.amx.com'")
	NAVCommand(data.device,"'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_MANUFACTURER_NAME,AMX'")
    }
    command: {
	stack_var char cCmdHeader[NAV_MAX_CHARS]
	stack_var char cCmdParam[3][NAV_MAX_CHARS]
	NAVLog(NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_COMMAND_FROM, data.device, data.text))
	cCmdHeader = DuetParseCmdHeader(data.text)
	cCmdParam[1] = DuetParseCmdParam(data.text)
	cCmdParam[2] = DuetParseCmdParam(data.text)
	cCmdParam[3] = DuetParseCmdParam(data.text)
	switch (cCmdHeader) {
	    case 'PROPERTY': {
		switch (cCmdParam[1]) {
		    case 'IP_ADDRESS': {
			cIPAddress = cCmdParam[2]
			NAVTimelineStart(TL_IP_CHECK, ltIPCheck, TIMELINE_ABSOLUTE, TIMELINE_REPEAT)
		    }
		}
	    }
	    case 'PASSTHRU': { Send("cCmdParam[1], NAV_CR") }
	    case 'SWITCH': {
		stack_var integer iOutputIndex
		stack_var integer iInput
		iOutputIndex = atoi(cCmdParam[2])
		iInput = atoi(cCmdParam[1])
		iOutput[iOutputIndex] = iInput
		iPending[iOutputIndex] = true
	    }
	}
    }
}

timeline_event[TL_DRIVE] { Drive() }

timeline_event[TL_IP_CHECK] { MaintainIPClient() }

channel_event[vdvObject,0] {
    on: {
	//Place holder so get_last works...
    }
}


(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)
