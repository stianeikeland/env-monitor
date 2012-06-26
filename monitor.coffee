SerialPort = (require "serialport").SerialPort
Parsers = (require "serialport").parsers
net = require 'net'
http = require 'http'
fs = require 'fs'

port = null
reconnectTimer = null
failcounter = 0

# Log and timestamp to screen
log = (logstring) ->
	date = new Date()
	console.log "[#{date.toUTCString()}] - #{logstring}" if logstring?

# Post sensor data to pachube.com
pachube = (dataobj) ->
	p = {
		"version": "1.0.0",
		"datastreams": [
			{ "id": "0", "current_value": "#{dataobj.soverom.temperature}"},
			{ "id": "3", "current_value": "#{dataobj.soverom.light}" }
		]}

	pstring = JSON.stringify p

	options = {
		host: 'api.pachube.com',
		port: 80,
		method: 'PUT',
		path: config.feed,
		headers: {
			"Content-Length": pstring.length,
			"X-PachubeApiKey": config.apikey
		}}

	log "Pachube: posting data.."
	req = http.request options, (res) ->
		log "Pachube: " + res.statusCode

	req.write pstring
	req.end()

# Check if dataobj has required fields
validateData = (data) ->
	try
		return false if not (data.soverom or data.soverom.temperature or data.soverom.light or
			typeof data.soverom.temperature == "number" or
			typeof data.soverom.light == "number")
	catch error
		return false
	return true

# Request data over serial port
doRequest = () ->
	log "Arduino: Requesting data.."
	setTimeout (() -> port.write "getdata"), 2000
	reconnectTimer = setTimeout reconnect, 20000

# Handle incoming data (parse to json),
# retry if corrupt data
datahandler = (data) ->
	dataobj = null
	try
		dataobj = JSON.parse(data)
	catch error
		dataobj = false

	clearTimeout reconnectTimer if dataobj
	log JSON.stringify dataobj if dataobj

	if (not dataobj or dataobj.error or not (validateData dataobj))
		log "Arduino: Data not received OK.. retrying.."
		doRequest()
	else
		log "Arduino: Data received OK.. sleeping"
		pachube dataobj
		setTimeout doRequest, 60000

connect = (ttyport) ->
	port = new SerialPort ttyport, { parser: Parsers.readline "\n" }
	port.on "data", datahandler
	port.on "error", log
	port.on "close", log
	port.on "end", log
	doRequest()

# (re)connect to serial port
reconnect = () ->
	process.exit 1 if failcounter++ > 5

	log "Arduino: (Re)connecting.."
	port.close() if port
	port.end() if port
	delete port

	# Sometimes the arduino usb will reset, and is given a new port :(
	setTimeout (() ->
		try
			connect "/dev/ttyUSB0"
		catch e
			connect "/dev/ttyUSB1"
		), 2000


# Read config (api-key and feed) from file
config = JSON.parse fs.readFileSync 'config.json', 'utf8'

reconnect()



