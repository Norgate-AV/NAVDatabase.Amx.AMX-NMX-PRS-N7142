MODULE_NAME='mAMX-NMX-PRS-N7142-Direct' 	(
                                                dev vdvObject,
                                                dev dvDevice
                                            )

(***********************************************************)
#include 'NAVFoundation.ModuleBase.axi'
#include 'NAVFoundation.SocketUtils.axi'

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

constant integer CHANNELS[] = { 01, 02, 03, 04 }

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
volatile integer iLoop

volatile integer iCurrentInput[MAX_OUTPUTS]
volatile integer iPending[MAX_OUTPUTS]

volatile char cIPAddress[NAV_MAX_CHARS]
volatile integer iClientConnected

volatile integer iCurrentVolume[3]

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
    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_TO, dvDevice, cPayload))
    send_string dvDevice, "cPayload"
    wait 1 iCommandBusy = false
}


define_function char[NAV_MAX_CHARS] BuildSwitch(integer iInput, integer iOutput) {
    return "'set: ', itoa(iOutput), ',', itoa(iInput), NAV_CR"
}


define_function char[NAV_MAX_CHARS] BuildVolume(integer iOutput, integer iVolume) {
    return "'audio:mixOutVolume:', itoa(iOutput), ',', itoa(iVolume), NAV_CR"
}


define_function Drive() {
    iLoop++
    switch (iLoop) {
	case 5: {
	    Send("'getStatus', NAV_CR")
	    iLoop = 0
	}
	default: {
	    stack_var integer x

	    if (iCommandBusy) return

	    for (x = 1; x <= MAX_OUTPUTS; x++) {
		if (iPending[x] && !iCommandBusy) {
		    iPending[x] = false
		    iCommandBusy = true
		    Send(BuildSwitch(iCurrentInput[x], x))
		}
	    }
	}
    }
}


define_function MaintainIPClient() {
    if (!iClientConnected && length_array(cIPAddress)) {
	NAVClientSocketOpen(dvDevice.PORT, cIPAddress, IP_PORT, IP_TCP)
    }
}

define_function Process() {
    stack_var char cTemp[NAV_MAX_BUFFER]
    iSemaphore = true
    while (length_array(cRxBuffer) && NAVContains(cRxBuffer, "NAV_CR")) {
	cTemp = remove_string(cRxBuffer, "NAV_CR", 1)
	if (length_array(cTemp)) {
	    stack_var char cCmd[NAV_MAX_CHARS]
	    cTemp = NAVStripCharsFromRight(cTemp, 1)
	    cCmd = NAVStripCharsFromRight(remove_string(cTemp, ':', 1), 1)
	    switch (cCmd) {
		case 'outSel1': {
		    send_string vdvObject, "'SWITCH-', cTemp, ',1,', NAV_SWITCH_LEVELS[NAV_SWITCH_LEVEL_VID]"
		    send_string vdvObject, "'SWITCH-', cTemp, ',1,', NAV_SWITCH_LEVELS[NAV_SWITCH_LEVEL_AUD]"
		    send_level vdvObject, 50, atoi(cTemp)
		    send_level vdvObject, 51, atoi(cTemp)
		}
		case 'outSel2': {
		    send_string vdvObject, "'SWITCH-', cTemp, ',2,', NAV_SWITCH_LEVELS[NAV_SWITCH_LEVEL_VID]"
		    send_string vdvObject, "'SWITCH-', cTemp, ',2,', NAV_SWITCH_LEVELS[NAV_SWITCH_LEVEL_AUD]"
		    send_level vdvObject.NUMBER:2:0, 50, atoi(cTemp)
		    send_level vdvObject.NUMBER:2:0, 51, atoi(cTemp)
		}
		case 'gpio_1_state': {
		    switch (cTemp) {
			case 'on': {
			    [vdvObject.NUMBER:22:0, 101] = true
			}
			case 'off': {
			    [vdvObject.NUMBER:22:0, 101] = false
			}
		    }
		}
		case 'gpio_2_state': {
		    switch (cTemp) {
			case 'on': {
			    [vdvObject.NUMBER:22:0, 102] = true
			}
			case 'off': {
			    [vdvObject.NUMBER:22:0, 102] = false
			}
		    }
		}
		case 'gpio_3_state': {
		    switch (cTemp) {
			case 'on': {
			    [vdvObject.NUMBER:22:0, 103] = true
			}
			case 'off': {
			    [vdvObject.NUMBER:22:0, 103] = false
			}
		    }
		}
		case 'gpio_4_state': {
		    switch (cTemp) {
			case 'on': {
			    [vdvObject.NUMBER:22:0, 104] = true
			}
			case 'off': {
			    [vdvObject.NUMBER:22:0, 104] = false
			}
		    }
		}
		case 'relay_1_state': {
		    switch (cTemp) {
			case 'on': {
			    [vdvObject.NUMBER:21:0, 101] = true
			}
			case 'off': {
			    [vdvObject.NUMBER:21:0, 101] = false
			}
		    }
		}
		case 'relay_2_state': {
		    switch (cTemp) {
			case 'on': {
			    [vdvObject.NUMBER:21:0, 102] = true
			}
			case 'off': {
			    [vdvObject.NUMBER:21:0, 102] = false
			}
		    }
		}
		case 'relay_3_state': {
		    switch (cTemp) {
			case 'on': {
			    [vdvObject.NUMBER:21:0, 103] = true
			}
			case 'off': {
			    [vdvObject.NUMBER:21:0, 103] = false
			}
		    }
		}
		case 'relay_4_state': {
		    switch (cTemp) {
			case 'on': {
			    [vdvObject.NUMBER:21:0, 104] = true
			}
			case 'off': {
			    [vdvObject.NUMBER:21:0, 104] = false
			}
		    }
		}
		case 'Mix': {
		    stack_var integer iOutput
		    stack_var integer iVolume

		    iOutput = atoi(NAVStripCharsFromRight(remove_string(cTemp, ':', 1), 1))
		    iVolume = atoi(NAVStripCharsFromRight(remove_string(cTemp, '.', 1), 1))

		    if (iCurrentVolume[iOutput] != iVolume) {
			iCurrentVolume[iOutput] = iVolume
			send_level vdvObject.NUMBER:iOutput + 1:0, VOL_LVL, iCurrentVolume[iOutput]
		    }
		}
	    }
	}
    }

    iSemaphore = false
}

(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START {
    create_buffer dvDevice, cRxBuffer
}

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT
data_event[dvDevice] {
    online: {
	iClientConnected = true
	if (!timeline_active(TL_DRIVE)) {
	    NAVTimelineStart(TL_DRIVE, ltDrive, TIMELINE_ABSOLUTE, TIMELINE_REPEAT)
	}

	NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "NAVStringSurroundWith(NAVDeviceToString(data.device), '[', ']'), '-[', 'IP Client Online', ']'")

	//Send("'getStatus', NAV_CR")
    }
    string: {
	[vdvObject, DEVICE_COMMUNICATING] = true
	[vdvObject, DATA_INITIALIZED] = true
	NAVErrorLog(NAV_LOG_LEVEL_DEBUG, NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_FROM, data.device, data.text))
	if (!iSemaphore) {
	    Process()
	}
    }
    offline: {
	iClientConnected = false
	NAVClientSocketClose(data.device.port)
	NAVTimelineStop(TL_DRIVE)

	NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "NAVStringSurroundWith(NAVDeviceToString(data.device), '[', ']'), '-[', 'IP Client Offline', ']'")
    }
    onerror: {
	iClientConnected = false
	NAVTimelineStop(TL_DRIVE)

	NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "NAVStringSurroundWith(NAVDeviceToString(data.device), '[', ']'), '-[', 'IP Client OnError', ']'")
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
	NAVErrorLog(NAV_LOG_LEVEL_DEBUG, NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_COMMAND_FROM, data.device, data.text))
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
		stack_var integer iOutput
		stack_var integer iInput
		iOutput = atoi(cCmdParam[2])
		iInput = atoi(cCmdParam[1])
		iCurrentInput[iOutput] = iInput
		iPending[iOutput] = true
	    }
	    case 'VOLUME': {
		switch (cCmdParam[1]) {
		    case 'ABS': {
			stack_var integer iOutput
			stack_var integer iVolume

			iOutput = atoi(cCmdParam[2])
			iVolume = atoi(cCmdParam[3])

			Send(BuildVolume(iOutput, iVolume))
		    }
		    default: {
			stack_var integer iOutput
			stack_var integer iVolume

			iOutput = atoi(cCmdParam[1])
			iVolume = atoi(cCmdParam[2]) * 100 / 255

			Send(BuildVolume(iOutput, iVolume))
		    }
		}
	    }
	}
    }
}

timeline_event[TL_DRIVE] { Drive() }

timeline_event[TL_IP_CHECK] { MaintainIPClient() }

channel_event[vdvObject.NUMBER:22:0, CHANNELS] {
    on: {
	Send("'gpoOn:', itoa(channel.channel), NAV_CR")
    }
    off: {
	Send("'gpoOff:', itoa(channel.channel), NAV_CR")
    }
}

channel_event[vdvObject.NUMBER:21:0, CHANNELS] {
    on: {
	Send("'relayClose:', itoa(channel.channel), NAV_CR")
    }
    off: {
	Send("'relayOpen:', itoa(channel.channel), NAV_CR")
    }
}

(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)
