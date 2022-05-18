extends Control


var teamColor = "yellow"
var changeIp = "piccolo"
var IP_PICCOLO = "192.168.1.102"
var IP_GRANDE = "192.168.1.101"

#labels
onready var labelTeam1 :RichTextLabel= $BottomBar/TeamColorLabel
onready var labelTeam2 :RichTextLabel = $BottomBar/TeamColorLabel2

onready var labelRobotPiccolo = $BottomBar/LeftPanel/VBoxContainer/Title
onready var labelRobotGrande = $BottomBar/RightPanel/VBoxContainer/Title

onready var labelPositionPiccolo = $BottomBar/LeftPanel/VBoxContainer/Position
onready var labelPositionGrande = $BottomBar/RightPanel/VBoxContainer/Position

#changeIpWindow
onready var changeIpWindow = $ChangeIPView
onready var inputIp = $ChangeIPView/Panel/VBoxContainer/Input


#robots
onready var robotPiccolo = $Minimap/Map/PiccoloNav
onready var robotGrande = $Minimap/Map/GrandeNav

#webSockets

var wsPiccolo : WebSocketClient
var wsGrande : WebSocketClient
var portPiccolo = 9998
var portGrande = 9998


var wsPiccoloConnected = false
var wsGrandeConnected = false

var scalePosition = .2
var posPiccolo = Vector3()
var posGrande = Vector3()

var batteryPiccoloTimer : Timer
var batteryGrandeTimer : Timer

var popupLoading : ConfirmationDialog

# Called when the node enters the scene tree for the first time.
func _ready():
	labelTeam1.set_bbcode("[center]Team Color: [color="+teamColor+"]"+teamColor.capitalize()+"[/color][/center]")
	labelTeam2.set_bbcode("[center]Team Color: [color="+teamColor+"]"+teamColor.capitalize()+"[/color][/center]")
	labelRobotPiccolo.text="Connecting to Piccolo ("+IP_PICCOLO+")"
	labelRobotGrande.text="Connecting to Grande ("+IP_GRANDE+")"


	changeIpWindow.visible = false
	robotPiccolo.visible = false
	robotGrande.visible = false
	
	batteryPiccoloTimer = Timer.new()
	batteryGrandeTimer = Timer.new()
	
	batteryPiccoloTimer.connect("timeout", self, "_reqBatteryPiccolo")
	batteryGrandeTimer.connect("timeout", self, "_reqBatteryGrande")
	add_child(batteryPiccoloTimer)
	add_child(batteryGrandeTimer)
	
	popupLoading = ConfirmationDialog.new()
	popupLoading.connect("about_to_show", self, "_on_popup_show")
	popupLoading.connect("hide", self, "_on_popup_hide")
	popupLoading.get_close_button().hide()
	popupLoading.get_cancel().hide()
	popupLoading.get_ok().hide()
	popupLoading.show_on_top = true
	add_child(popupLoading)
	

	
	connectSocketPiccolo()
	connectSocketGrande()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if wsPiccolo:
		wsPiccolo.poll()
	if wsGrande:
		wsGrande.poll()
	
	
	robotPiccolo.rect_rotation = lerp(robotPiccolo.rect_rotation , posPiccolo.z, delta)
	robotPiccolo.rect_position = robotPiccolo.rect_position.linear_interpolate(Vector2(posPiccolo.x - (robotPiccolo.rect_size.x *.5), posPiccolo.y - (robotPiccolo.rect_size.y *.5)), .5)
	robotGrande.rect_rotation = lerp(robotGrande.rect_rotation , posGrande.z, delta*100)
	robotGrande.rect_position = robotGrande.rect_position.linear_interpolate(Vector2(posGrande.x -(robotGrande.rect_size.x * .5), posGrande.y -(robotGrande.rect_size.y * .5)), .5)



func connectSocketPiccolo(port=null):
	
	wsPiccolo = WebSocketClient.new()
	wsPiccolo.verify_ssl = false
	wsPiccolo.connect("connection_closed", self, "_wsPiccoloClosed")
	wsPiccolo.connect("connection_error", self, "_wsPiccoloClosed")
	wsPiccolo.connect("connection_established", self, "_wsPiccoloConnected")
	wsPiccolo.connect("data_received", self, "_wsPiccoloOnData")
	
	labelRobotPiccolo.text="Connecting to Piccolo ("+IP_PICCOLO+")"
	
	if port == null:
		port = 9998
	portPiccolo = port
	var url = "ws://"+IP_PICCOLO+":"+str(port)+"/ws"
	
	
	var err = wsPiccolo.connect_to_url(url)
	if err != OK:
		
		yield(get_tree().create_timer(1.5), "timeout")
		connectSocketPiccolo(port)
	
func _wsPiccoloClosed(was_clean = false):
	wsPiccolo = null
	labelRobotPiccolo.text="Connecting to Piccolo ("+IP_PICCOLO+")"
	if wsPiccoloConnected:
		$BottomBar/LeftPanel/AnimationPlayer.play_backwards("OpenPanelLeft")
	wsPiccoloConnected = false
	$BottomBar/LeftPanel/VBoxContainer/ChangeIpPiccolo.visible = true
	$LeftSide.visible = false
	robotPiccolo.visible = false
	yield(get_tree().create_timer(1.5), "timeout")
	batteryPiccoloTimer.stop()
	connectSocketPiccolo()

func _wsPiccoloConnected(proto = ""):
	wsPiccoloConnected = true
	labelRobotPiccolo.text="Piccolo Connected ("+IP_PICCOLO+")"
	robotPiccolo.visible = true
	$BottomBar/LeftPanel/VBoxContainer/ChangeIpPiccolo.visible = false
	$LeftSide.visible = true
	
	$BottomBar/LeftPanel/AnimationPlayer.play("OpenPanelLeft")
	batteryPiccoloTimer.start(3)
	wsPiccolo.get_peer(1).put_packet("Test packet".to_utf8())

func _wsPiccoloOnData():
	var jsonResult = JSON.parse(wsPiccolo.get_peer(1).get_packet().get_string_from_utf8())
	if jsonResult.error == OK :
		
		var jsonData = jsonResult.result
		if  jsonData["command"] == "position":
			posPiccolo.z = abs(jsonData["data"]["Angle"] - 180)
			posPiccolo.x = jsonData["data"]["X"] * scalePosition
			posPiccolo.y = 400 - (jsonData["data"]["Y"] * scalePosition)
			labelPositionPiccolo.text="Position:\n (X:"+str(jsonData["data"]["X"])+", Y:"+str(jsonData["data"]["Y"])+", A:"+str(jsonData["data"]["Angle"])+")"
			
		elif jsonData["command"] == "battery":
			print("Aggiorno batteria");
			#batteryBar.set_bar_value(int(jsonData["data"]["percent"]))
func _reqBatteryPiccolo():
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", self, "_onBatteryPiccoloData")
	var error = http_request.request("http://"+IP_PICCOLO+":"+str(portPiccolo)+"/api/robot/battery", ["Content-Type:application/json"], false, HTTPClient.METHOD_GET)
	if error != OK:
		push_error("An error occurred in the HTTP request.")

func _onBatteryPiccoloData(result, response_code, headers, body):
	
	var percBattery = parse_json(body.get_string_from_utf8())
	if percBattery != null:
		updatePiccoloBatteryBar(percBattery)
	
func updatePiccoloBatteryBar(perc):
	var val = int(perc*100)
	var elem = $BottomBar/LeftPanel/VBoxContainer/ProgressBar
	elem.value = val
	
	if val > 60:
		elem.get("custom_styles/fg").bg_color=Color("009a05")
	elif val > 20 and val < 59:
		elem.get("custom_styles/fg").bg_color=Color("c8c100")
	else:
		elem.get("custom_styles/fg").bg_color=Color("c80000")
	
func connectSocketGrande(port=null):
	
	wsGrande = WebSocketClient.new()
	wsGrande.verify_ssl = false
	wsGrande.connect("connection_closed", self, "_wsGrandeClosed", [], CONNECT_DEFERRED)
	wsGrande.connect("connection_error", self, "_wsGrandeClosed", [], CONNECT_DEFERRED)
	wsGrande.connect("connection_established", self, "_wsGrandeConnected")
	wsGrande.connect("data_received", self, "_wsGrandeOnData")
	
	labelRobotGrande.text="Connecting to Grande ("+IP_GRANDE+")"
	
	if port == null:
		port = 9998
	portGrande = port
	var url = "ws://"+IP_GRANDE+":"+str(port)+"/ws"
	
	var err = wsGrande.connect_to_url(url)
	if err != OK:
		
		yield(get_tree().create_timer(1.5), "timeout")
		connectSocketGrande(port)

func _wsGrandeClosed(was_clean = false):
	wsGrande = null
	labelRobotGrande.text="Connecting to Grande ("+IP_GRANDE+")"
	if wsGrandeConnected:
		$BottomBar/RightPanel/AnimationPlayer.play_backwards("OpenPanelRight")
	wsGrandeConnected = false
	$BottomBar/RightPanel/VBoxContainer/ChangeIpGrande.visible = true
	$RightSide.visible = false
	robotGrande.visible = false
	batteryGrandeTimer.stop()
	yield(get_tree().create_timer(1.5), "timeout")
	connectSocketGrande()

func _wsGrandeConnected(proto = ""):
	wsGrandeConnected = true
	labelRobotGrande.text="Grande Connected ("+IP_GRANDE+")"
	robotGrande.visible = true
	$BottomBar/RightPanel/VBoxContainer/ChangeIpGrande.visible = false
	$RightSide.visible = true
	$BottomBar/RightPanel/AnimationPlayer.play("OpenPanelRight")
	batteryGrandeTimer.start(3)
	wsGrande.get_peer(1).put_packet("Test packet".to_utf8())

func _wsGrandeOnData():
	var jsonResult = JSON.parse(wsGrande.get_peer(1).get_packet().get_string_from_utf8())
	if jsonResult.error == OK :
		
		var jsonData = jsonResult.result
		if  jsonData["command"] == "position":
			
			posGrande.z = abs(jsonData["data"]["Angle"])
			posGrande.x = jsonData["data"]["X"] * scalePosition
			posGrande.y = 400 - (jsonData["data"]["Y"] * scalePosition)
			
			labelPositionGrande.text="Position:\n (X:"+str(jsonData["data"]["X"])+", Y:"+str(jsonData["data"]["Y"])+", A:"+str(jsonData["data"]["Angle"])+")"
			
		elif jsonData["command"] == "battery":
			print("Aggiorno batteria");
			#batteryBar.set_bar_value(int(jsonData["data"]["percent"]))

func _reqBatteryGrande():
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", self, "_onBatteryGrandeData")
	var error = http_request.request("http://"+IP_GRANDE+":"+str(portGrande)+"/api/robot/battery", ["Content-Type:application/json"], false, HTTPClient.METHOD_GET)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
		
func _onBatteryGrandeData(result, response_code, headers, body):
	var percBattery = parse_json(body.get_string_from_utf8())
	if percBattery != null:
		updateGrandeBatteryBar(percBattery)

func updateGrandeBatteryBar(perc):
	var val = int(perc*100)
	var elem = $BottomBar/RightPanel/VBoxContainer/ProgressBar
	elem.value = val
	
	if val > 60:
		elem.get("custom_styles/fg").bg_color=Color("009a05")
	elif val > 20 and val < 59:
		elem.get("custom_styles/fg").bg_color=Color("c8c100")
	else:
		elem.get("custom_styles/fg").bg_color=Color("c80000")

func _on_BtnChangeColor_pressed():
	teamColor = "yellow" if teamColor == "purple" else "purple"
	labelTeam1.set_bbcode("[center]Team Color: [color="+teamColor+"]"+teamColor.capitalize()+"[/color][/center]")
	labelTeam2.set_bbcode("[center]Team Color: [color="+teamColor+"]"+teamColor.capitalize()+"[/color][/center]")

func _on_ChangeIpPiccolo_pressed():
	changeIp = "piccolo"
	inputIp.text = IP_PICCOLO
	changeIpWindow.visible = true
	pass # Replace with function body.

func _on_ChangeIpGrande_pressed():
	changeIp = "grande"
	inputIp.text = IP_GRANDE
	changeIpWindow.visible = true
	pass # Replace with function body.

func _on_SaveIpButton_pressed():
	if inputIp.text == "":
		return
	
	if changeIp == "piccolo":
		IP_PICCOLO = inputIp.text
		labelRobotPiccolo.text="Connecting to Piccolo ("+IP_PICCOLO+")"
		connectSocketPiccolo()
	else :
		IP_GRANDE = inputIp.text
		labelRobotGrande.text="Connecting to Grande ("+IP_GRANDE+")"
		connectSocketGrande()
	changeIpWindow.visible = false

func _on_BtnAlignPiccolo_pressed():
	
	var body = {"color" : 1 if teamColor == "yellow" else 0}
	

	popupLoading.dialog_text = "Loading, Align Piccolo"
	popupLoading.popup_centered()
	popupLoading.show()
	
	var http_request = HTTPRequest.new()
	http_request.timeout = 10
	http_request.connect("request_completed", self, "on_http_finished")
	add_child(http_request)
	var error = http_request.request("http://"+IP_PICCOLO+":"+str(portPiccolo)+"/api/robot/st/align", ["Content-Type:application/json"], false, HTTPClient.METHOD_POST, JSON.print(body))
	if error != OK:
		push_error("An error occurred in the HTTP request.")

func _on_BtnEnableStarterPiccolo_pressed():
		
	var body = {"enable" : true}
	var http_request = HTTPRequest.new()
	popupLoading.dialog_text = "Loading, Enable Start Piccolo"
	popupLoading.popup_centered()
	popupLoading.show()
	http_request.connect("request_completed", self, "on_http_finished")
	
	add_child(http_request)
	var error = http_request.request("http://"+IP_PICCOLO+":"+str(portPiccolo)+"/api/robot/st/starter", ["Content-Type:application/json"], false, HTTPClient.METHOD_POST, JSON.print(body))
	if error != OK:
		push_error("An error occurred in the HTTP request.")

func _on_BtnDisableStarterPiccolo_pressed():
	var body = {"enable" : false}
	var http_request = HTTPRequest.new()
	popupLoading.dialog_text = "Loading, Disable Start Piccolo"
	popupLoading.popup_centered()
	popupLoading.show()
	http_request.connect("request_completed", self, "on_http_finished")
	add_child(http_request)
	var error = http_request.request("http://"+IP_PICCOLO+":"+str(portPiccolo)+"/api/robot/st/starter", ["Content-Type:application/json"], false, HTTPClient.METHOD_POST, JSON.print(body))
	if error != OK:
		push_error("An error occurred in the HTTP request.")

func _on_BtnAlignGrande_pressed():
	var body = {"color" : 1 if teamColor == "yellow" else 0}
	var http_request = HTTPRequest.new()
	popupLoading.dialog_text = "Loading, Align Grande"
	popupLoading.popup_centered()
	popupLoading.show()
	http_request.connect("request_completed", self, "on_http_finished")
	add_child(http_request)
	var error = http_request.request("http://"+IP_GRANDE+":"+str(portGrande)+"/api/robot/st/align", ["Content-Type:application/json"], false, HTTPClient.METHOD_POST, JSON.print(body))
	if error != OK:
		push_error("An error occurred in the HTTP request.")

func _on_BtnEnableStarterGrande_pressed():
	var body = {"enable" : true}
	var http_request = HTTPRequest.new()
	popupLoading.dialog_text = "Loading, Enable Start Grande"
	popupLoading.popup_centered()
	popupLoading.show()
	http_request.connect("request_completed", self, "on_http_finished")
	add_child(http_request)
	var error = http_request.request("http://"+IP_GRANDE+":"+str(portGrande)+"/api/robot/st/starter", ["Content-Type:application/json"], false, HTTPClient.METHOD_POST, JSON.print(body))
	if error != OK:
		push_error("An error occurred in the HTTP request.")

func _on_BtnDisableStarterGrande_pressed():
	var body = {"enable" : false}
	var http_request = HTTPRequest.new()
	popupLoading.dialog_text = "Loading, Disable Start Grande"
	popupLoading.popup_centered()
	popupLoading.show()
	http_request.connect("request_completed", self, "on_http_finished")
	add_child(http_request)
	var error = http_request.request("http://"+IP_GRANDE+":"+str(portGrande)+"/api/robot/st/starter", ["Content-Type:application/json"], false, HTTPClient.METHOD_POST, JSON.print(body))
	if error != OK:
		push_error("An error occurred in the HTTP request.")

func _on_BtnResetPiccolo_pressed():
	var dialog = ConfirmationDialog.new()
	dialog.connect("about_to_show", self, "_on_popup_show")
	dialog.connect("hide", self, "_on_popup_hide")
	dialog.dialog_text = "Do you want reset the board?"
	add_child(dialog)
	dialog.popup_centered()
	dialog.show()
	
func _on_popup_show():
	$Backdrop.show()
func _on_popup_hide():
	$Backdrop.hide()

func on_http_finished(result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray):
	print("fine")
	popupLoading.hide()
