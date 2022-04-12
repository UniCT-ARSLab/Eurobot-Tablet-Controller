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

#changeIpWindow
onready var changeIpWindow = $ChangeIPView
onready var inputIp = $ChangeIPView/Panel/VBoxContainer/Input


#webSockets

var wsPiccolo : WebSocketClient
var wsGrande : WebSocketClient
var portPiccolo = 9998
var portGrande = 9998


var wsPiccoloConnected = false

var scalePosizion = 1000
var posPiccolo = Vector3()

# Called when the node enters the scene tree for the first time.
func _ready():
	labelTeam1.set_bbcode("[center]Team Color: [color="+teamColor+"]"+teamColor.capitalize()+"[/color][/center]")
	labelTeam2.set_bbcode("[center]Team Color: [color="+teamColor+"]"+teamColor.capitalize()+"[/color][/center]")
	labelRobotPiccolo.text="Connecting to Piccolo ("+IP_PICCOLO+")"
	labelRobotGrande.text="Connecting to Grande ("+IP_GRANDE+")"

	connectSocketPiccolo()
	changeIpWindow.visible = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if wsPiccolo:
		wsPiccolo.poll()
	if wsGrande and wsGrande.get_connected_host():
		wsGrande.poll()
#	pass


func connectSocketPiccolo(port=""):
	
	wsPiccolo = WebSocketClient.new()
	wsPiccolo.verify_ssl = false
	wsPiccolo.connect("connection_closed", self, "_wsPiccoloClosed")
	wsPiccolo.connect("connection_error", self, "_wsPiccoloClosed")
	wsPiccolo.connect("connection_established", self, "_wsPiccoloConnected")
	wsPiccolo.connect("data_received", self, "_wsPiccoloOnData")
	
	labelRobotPiccolo.text="Connecting to Piccolo ("+IP_PICCOLO+")"
	
	if port.length() == 0:
		port = 9998
	portPiccolo = port
	var url = "ws://"+IP_PICCOLO+":"+str(port)+"/ws"
	
	print("Connecting to Piccolo ", url)
	
	var err = wsPiccolo.connect_to_url(url)
	print(err)
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
	yield(get_tree().create_timer(1.5), "timeout")
	connectSocketPiccolo()

	
func _wsPiccoloConnected(proto = ""):
	wsPiccoloConnected = true
	labelRobotPiccolo.text="Piccolo Connected ("+IP_PICCOLO+")"
	$VBoxContainer/BottomBar/LeftPanel/VBoxContainer/ChangeIpPiccolo.visible = false
	$LeftSide.visible = true
	
	$VBoxContainer/BottomBar/LeftPanel/AnimationPlayer.play("OpenPanelLeft")
	wsPiccolo.get_peer(1).put_packet("Test packet".to_utf8())


func _wsPiccoloOnData():
	var jsonResult = JSON.parse(wsPiccolo.get_peer(1).get_packet().get_string_from_utf8())
	if jsonResult.error == OK :
		var jsonData = jsonResult.result
		if  jsonData["command"] == "position":
			posPiccolo.z = deg2rad(jsonData["data"]["Angle"] ) 
			posPiccolo.x = jsonData["data"]["X"]/scalePosizion
			posPiccolo.y = -jsonData["data"]["Y"]/scalePosizion
			labelPositionPiccolo.text="Position:\n (X:"+str(jsonData["data"]["X"])+", Y:"+str(jsonData["data"]["Y"])+", A:"+str(jsonData["data"]["Angle"])+")"
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
	changeIpWindow.visible = false


func _on_BtnAlignPiccolo_pressed():
	
	var body = {"color" : 1}
	var http_request = HTTPRequest.new()
	add_child(http_request)
	var error = http_request.request("http://"+IP_PICCOLO+":"+str(portPiccolo)+"/api/robot/st/align", ["Content-Type:application/json"], false, HTTPClient.METHOD_POST, JSON.print(body))
	if error != OK:
		push_error("An error occurred in the HTTP request.")

