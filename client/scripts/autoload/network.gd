extends Node

## WebSocket connection manager for communicating with the game server.

signal connected
signal disconnected
signal message_received(data: Dictionary)
signal connection_error(reason: String)

# 本番: Render のサーバーURL（デプロイ後に更新する）
# ローカル開発: ws://127.0.0.1:8080/ws
@export var server_url: String = "wss://modern-art-server.onrender.com/ws"

var _socket: WebSocketPeer = WebSocketPeer.new()
var _connected: bool = false
var _reconnect_timer: float = 0.0
var _reconnect_delay: float = 1.0
var _should_reconnect: bool = false

func _ready() -> void:
	# ローカル開発時はlocalhostに接続
	if not OS.has_feature("web"):
		server_url = "ws://127.0.0.1:8080/ws"

func connect_to_server(url: String = "") -> void:
	if url != "":
		server_url = url
	var state := _socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN or state == WebSocketPeer.STATE_CONNECTING:
		return
	var err := _socket.connect_to_url(server_url)
	if err != OK:
		connection_error.emit("Failed to initiate connection: %s" % error_string(err))
		return
	_should_reconnect = true

func disconnect_from_server() -> void:
	_should_reconnect = false
	_connected = false
	_socket.close()

func send_message(data: Dictionary) -> void:
	if _connected:
		var json_str := JSON.stringify(data)
		_socket.send_text(json_str)

func is_connected_to_server() -> bool:
	return _connected

func _process(delta: float) -> void:
	_socket.poll()

	var state := _socket.get_ready_state()

	match state:
		WebSocketPeer.STATE_OPEN:
			if not _connected:
				_connected = true
				_reconnect_timer = 0.0
				connected.emit()
			while _socket.get_available_packet_count() > 0:
				var packet := _socket.get_packet()
				var text := packet.get_string_from_utf8()
				var json := JSON.new()
				var parse_result := json.parse(text)
				if parse_result == OK:
					var data: Dictionary = json.data
					message_received.emit(data)
				else:
					push_warning("Failed to parse server message: %s" % text)
		WebSocketPeer.STATE_CLOSING:
			pass
		WebSocketPeer.STATE_CLOSED:
			if _connected:
				_connected = false
				disconnected.emit()
			if _should_reconnect:
				_reconnect_timer += delta
				if _reconnect_timer >= _reconnect_delay:
					_reconnect_timer = 0.0
					connect_to_server()

# --- Convenience methods for sending specific message types ---

func send_create_room(player_name: String) -> void:
	send_message({"type": "create_room", "player_name": player_name})

func send_join_room(room_id: String, player_name: String) -> void:
	send_message({"type": "join_room", "room_id": room_id, "player_name": player_name})

func send_start_game() -> void:
	send_message({"type": "start_game"})

func send_play_card(card_index: int, double_card_index: int = -1) -> void:
	var msg := {"type": "play_card", "card_index": card_index}
	if double_card_index >= 0:
		msg["double_card_index"] = double_card_index
	send_message(msg)

func send_bid(amount: int) -> void:
	send_message({"type": "bid", "amount": amount})

func send_pass() -> void:
	send_message({"type": "pass"})

func send_accept() -> void:
	send_message({"type": "accept"})

func send_set_price(amount: int) -> void:
	send_message({"type": "set_price", "amount": amount})

func send_list_rooms() -> void:
	send_message({"type": "list_rooms"})

func send_add_ai(difficulty: String = "normal") -> void:
	send_message({"type": "add_ai", "difficulty": difficulty})

func send_remove_ai() -> void:
	send_message({"type": "remove_ai"})
