extends Control


var teamColor = "yellow"
var changeIp = "piccolo"
var IP_PICCOLO = "192.168.70.20"
var IP_GRANDE = "192.168.70.110"

#labels
onready var labelTeam1 :RichTextLabel= $VBoxContainer/BottomBar/TeamColorLabel
onready var labelTeam2 :RichTextLabel = $VBoxContainer/BottomBar/TeamColorLabel2

onready var labelRobotPiccolo = $VBoxContainer/BottomBar/LeftPanel/VBoxContainer/Title
onready var labelRobotGrande = $VBoxContainer/BottomBar/RightPanel/VBoxContainer/Title

onready var labelPositionPiccolo = $VBoxContainer/BottomBar/LeftPanel/VBoxContainer/Position
onready var labelPositionGrande = $VBoxContainer/BottomBar/RightPanel/VBoxContainer/Position

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

# Called when the node enters the scene tree for the first time.
func _ready():
	labelTeam1.set_bbcode("[center]Team Color: [color="+teamColor+"]"+teamColor.capitalize()+"[/color][/center]")
	labelTeam2.set_bbcode("[center]Team Color: [color="+teamColor+"]"+teamColor.capitalize()+"[/color][/center]")
	labelRobotPiccolo.text="Connecting to Piccolo ("+IP_PICCOLO+")"
	labelRobotGrande.text="Connecting to Grande ("+IP_GRANDE+")"


	changeIpWindow.visible = false
	robotPiccolo.visible = false
	robotGrande.visible = false
	
	connectSocketPiccolo()
	connectSocketGrande()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if wsPiccolo:
		wsPiccolo.poll()
	if wsGrande:
		wsGrande.poll()
	
	
	robotPiccolo.rect_rotation = lerp(robotPiccolo.rect_rotation , posPiccolo.z, delta)
	robotPiccolo.rect_position = robotPiccolo.rect_position.linear_interpolate(Vector2(posPiccolo.x, posPiccolo.y), .5)
	robotGrande.rect_rotation = lerp(robotGrande.rect_rotation , posGrande.z, delta)
	robotGrande.rect_position = robotGrande.rect_position.linear_interpolate(Vector2(posGrande.x, posGrande.y), .5)



func connectSocketPiccolo(port=null):
	
	wsPiccolo = WebSocketClient.new()
	wsPiccolo.set_verify_ssl_enabled(false)
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
		$VBoxContainer/BottomBar/LeftPanel/AnimationPlayer.play("PanelLeftPreOpen")
	wsPiccoloConnected = false
	$VBoxContainer/BottomBar/LeftPanel/VBoxContainer/ChangeIpPiccolo.visible = true
	$LeftSide.visible = false
	robotPiccolo.visible = false
	yield(get_tree().create_timer(1.5), "timeout")
	connectSocketPiccolo()

func _wsPiccoloConnected(proto = ""):
	wsPiccoloConnected = true
	labelRobotPiccolo.text="Piccolo Connected ("+IP_PICCOLO+")"
	robotPiccolo.visible = true
	$VBoxContainer/BottomBar/LeftPanel/VBoxContainer/ChangeIpPiccolo.visible = false
	$LeftSide.visible = true
	
	$VBoxContainer/BottomBar/LeftPanel/AnimationPlayer.play("OpenPanelLeft")
	wsPiccolo.get_peer(1).put_packet("Test packet".to_utf8())

func _wsPiccoloOnData():
	var jsonResult = JSON.parse(wsPiccolo.get_peer(1).get_packet().get_string_from_utf8())
	if jsonResult.error == OK :
		
		var jsonData = jsonResult.result
		if  jsonData["command"] == "position":
			posPiccolo.z = abs(jsonData["data"]["Angle"] - 180)
			posPiccolo.x = jsonData["data"]["X"] * scalePosition
			posPiccolo.y = 400 - (jsonData["data"]["Y"] * scalePosition)
			labelPositionPiccolo.text="Position:\n (X:"+str(posPiccolo.x)+", Y:"+str(posPiccolo.y)+", A:"+str(posPiccolo.z)+")"
			
		elif jsonData["command"] == "battery":
			print("Aggiorno batteria");
			#batteryBar.set_bar_value(int(jsonData["data"]["percent"]))

func connectSocketGrande(port=null):
	
	wsGrande = WebSocketClient.new()
	wsGrande.set_verify_ssl_enabled(false)
	wsGrande.connect("connection_closed", self, "_wsGrandeClosed")
	wsGrande.connect("connection_error", self, "_wsGrandeClosed")
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
		$VBoxContainer/BottomBar/RightPanel/AnimationPlayer.play("PanelRightPreOpen")
	wsGrandeConnected = false
	$VBoxContainer/BottomBar/RightPanel/VBoxContainer/ChangeIpGrande.visible = true
	$RightSide.visible = false
	robotGrande.visible = false
	yield(get_tree().create_timer(1.5), "timeout")
	connectSocketPiccolo()

func _wsGrandeConnected(proto = ""):
	wsGrandeConnected = true
	labelRobotGrande.text="Grande Connected ("+IP_GRANDE+")"
	robotGrande.visible = true
	$VBoxContainer/BottomBar/RightPanel/VBoxContainer/ChangeIpGrande.visible = false
	$RightSide.visible = true
	$VBoxContainer/BottomBar/RightPanel/AnimationPlayer.play("OpenPanelRight")
	wsGrande.get_peer(1).put_packet("Test packet".to_utf8())

func _wsGrandeOnData():
	var jsonResult = JSON.parse(wsGrande.get_peer(1).get_packet().get_string_from_utf8())
	if jsonResult.error == OK :
		
		var jsonData = jsonResult.result
		if  jsonData["command"] == "position":
			
			posGrande.z = abs(jsonData["data"]["Angle"] - 180)
			posGrande.x = jsonData["data"]["X"] * scalePosition
			posGrande.y = 400 - (jsonData["data"]["Y"] * scalePosition)
			
			labelPositionGrande.text="Position:\n (X:"+str(posGrande.x)+", Y:"+str(posGrande.y)+", A:"+str(posGrande.z)+")"
			
		elif jsonData["command"] == "battery":
			print("Aggiorno batteria");
			#batteryBar.set_bar_value(int(jsonData["data"]["percent"]))


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
	var http_request = HTTPRequest.new()
	add_child(http_request)
	var error = http_request.request("http://"+IP_PICCOLO+":"+str(portPiccolo)+"/api/robot/st/align", ["Content-Type:application/json"], false, HTTPClient.METHOD_POST, JSON.print(body))
	if error != OK:
		push_error("An error occurred in the HTTP request.")

