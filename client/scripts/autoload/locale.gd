extends Node

## Localization manager for Japanese/English support.

signal language_changed

var _current_lang: String = "ja"
var _translations: Dictionary = {}

func _ready() -> void:
	_load_translations()
	# Try to detect browser language
	if OS.has_feature("web"):
		var lang = JavaScriptBridge.eval("navigator.language || navigator.userLanguage || 'ja'")
		if lang and str(lang).begins_with("en"):
			_current_lang = "en"

func _load_translations() -> void:
	_translations = {
		# General
		"app_title": {"ja": "モダンアート", "en": "Modern Art"},
		"ok": {"ja": "OK", "en": "OK"},
		"cancel": {"ja": "キャンセル", "en": "Cancel"},
		"back": {"ja": "戻る", "en": "Back"},
		"close": {"ja": "閉じる", "en": "Close"},

		# Title screen
		"title_play": {"ja": "プレイ", "en": "Play"},
		"title_settings": {"ja": "設定", "en": "Settings"},
		"title_language": {"ja": "Language / 言語", "en": "Language / 言語"},
		"settings_title": {"ja": "設定", "en": "Settings"},
		"settings_language": {"ja": "言語", "en": "Language"},
		"settings_bg_color": {"ja": "背景色", "en": "Background"},

		# Lobby
		"lobby_title": {"ja": "ロビー", "en": "Lobby"},
		"lobby_create": {"ja": "部屋を作成", "en": "Create Room"},
		"lobby_join": {"ja": "参加", "en": "Join"},
		"lobby_room_id": {"ja": "部屋ID", "en": "Room ID"},
		"lobby_player_name": {"ja": "プレイヤー名", "en": "Player Name"},
		"lobby_waiting": {"ja": "プレイヤーを待っています...", "en": "Waiting for players..."},
		"lobby_start": {"ja": "ゲーム開始", "en": "Start Game"},
		"lobby_players": {"ja": "プレイヤー", "en": "Players"},
		"lobby_room_list": {"ja": "部屋一覧", "en": "Room List"},
		"lobby_no_rooms": {"ja": "部屋がありません", "en": "No rooms available"},
		"lobby_refresh": {"ja": "更新", "en": "Refresh"},
		"lobby_enter_name": {"ja": "名前を入力してください", "en": "Please enter your name"},

		# Artists
		"Orange Tarou": {"ja": "オレンジ太郎", "en": "Orange Tarou"},
		"Green Tarou": {"ja": "グリーン太郎", "en": "Green Tarou"},
		"Blue Tarou": {"ja": "ブルー太郎", "en": "Blue Tarou"},
		"Yellow Tarou": {"ja": "イエロー太郎", "en": "Yellow Tarou"},
		"Red Tarou": {"ja": "レッド太郎", "en": "Red Tarou"},

		# Auction types
		"auction_open": {"ja": "公開競り", "en": "Open Auction"},
		"auction_once_around": {"ja": "順競り", "en": "Once Around"},
		"auction_sealed": {"ja": "入札", "en": "Sealed Bid"},
		"auction_fixed_price": {"ja": "指値", "en": "Fixed Price"},
		"auction_double": {"ja": "ダブル", "en": "Double"},

		# Game
		"game_round": {"ja": "ラウンド", "en": "Round"},
		"game_your_turn": {"ja": "あなたの番です", "en": "Your Turn"},
		"game_waiting_turn": {"ja": "%s の番です", "en": "%s's turn"},
		"game_money": {"ja": "所持金", "en": "Money"},
		"game_hand": {"ja": "手札", "en": "Hand"},
		"game_play_card": {"ja": "カードを出す", "en": "Play Card"},
		"game_market": {"ja": "相場", "en": "Market"},
		"game_paintings": {"ja": "絵画", "en": "Paintings"},
		"market_value": {"ja": "価値", "en": "Val"},
		"market_count": {"ja": "枚数", "en": "Cnt"},
		"market_bid": {"ja": "出品", "en": "Bid"},

		# Auction
		"auction_title": {"ja": "オークション", "en": "Auction"},
		"auction_your_turn": {"ja": "▶ あなたの番です ◀", "en": "▶ YOUR TURN ◀"},
		"auction_price_display": {"ja": "提示価格: %s", "en": "Price: %s"},
		"auction_waiting_others": {"ja": "他プレイヤーの行動待ち...", "en": "Waiting for others..."},
		"auction_bid": {"ja": "入札", "en": "Bid"},
		"auction_pass": {"ja": "パス", "en": "Pass"},
		"auction_accept": {"ja": "購入", "en": "Accept"},
		"auction_decline": {"ja": "見送り", "en": "Decline"},
		"auction_current_bid": {"ja": "現在の入札額", "en": "Current Bid"},
		"auction_set_price": {"ja": "価格を設定", "en": "Set Price"},
		"auction_seller": {"ja": "出品者", "en": "Seller"},
		"auction_winner": {"ja": "%s が %s で落札", "en": "%s won for %s"},
		"auction_no_buyer": {"ja": "買い手なし - 出品者が取得", "en": "No buyer - seller keeps"},
		"auction_select_double": {"ja": "ダブルするカードを選択", "en": "Select card for double"},
		"auction_enter_bid": {"ja": "入札額を入力", "en": "Enter bid amount"},

		# Round/Game end
		"round_end_title": {"ja": "ラウンド終了", "en": "Round Over"},
		"round_end_values": {"ja": "今ラウンドの価値", "en": "Round Values"},
		"round_end_cumulative": {"ja": "累積価値", "en": "Cumulative Values"},
		"round_end_earnings": {"ja": "売却収入", "en": "Earnings"},
		"game_end_title": {"ja": "ゲーム終了", "en": "Game Over"},
		"game_end_winner": {"ja": "%s の勝利!", "en": "%s wins!"},
		"game_end_final": {"ja": "最終結果", "en": "Final Results"},
		"game_end_back_lobby": {"ja": "ロビーに戻る", "en": "Back to Lobby"},

		# AI
		"ai_add": {"ja": "+ AI追加", "en": "+ Add AI"},
		"ai_remove": {"ja": "- AI削除", "en": "- Remove AI"},
		"ai_difficulty": {"ja": "AI難易度", "en": "AI Difficulty"},
		"ai_easy": {"ja": "かんたん", "en": "Easy"},
		"ai_normal": {"ja": "ふつう", "en": "Normal"},
		"ai_hard": {"ja": "むずかしい", "en": "Hard"},

		# Log & Paintings
		"log_button": {"ja": "ログ", "en": "Log"},
		"log_title": {"ja": "取引ログ", "en": "Auction Log"},
		"paintings_button": {"ja": "絵画", "en": "Art"},
		"paintings_title": {"ja": "所持絵画一覧", "en": "Owned Paintings"},
		"log_empty": {"ja": "取引記録はまだありません", "en": "No transactions yet"},
		"double_play": {"ja": "x2 ダブル", "en": "x2 Double"},

		# Misc
		"connecting": {"ja": "接続中...", "en": "Connecting..."},
		"disconnected": {"ja": "切断されました", "en": "Disconnected"},
		"reconnecting": {"ja": "再接続中...", "en": "Reconnecting..."},
	}

func t(key: String) -> String:
	if _translations.has(key):
		var entry: Dictionary = _translations[key]
		return entry.get(_current_lang, entry.get("ja", key))
	return key

func tf(key: String, args: Array = []) -> String:
	var template := t(key)
	if args.size() == 0:
		return template
	# Simple %s replacement (one at a time)
	var result := template
	for arg in args:
		var pos := result.find("%s")
		if pos >= 0:
			result = result.substr(0, pos) + str(arg) + result.substr(pos + 2)
	return result

func get_language() -> String:
	return _current_lang

func set_language(lang: String) -> void:
	if lang in ["ja", "en"]:
		_current_lang = lang
		language_changed.emit()

func toggle_language() -> void:
	if _current_lang == "ja":
		set_language("en")
	else:
		set_language("ja")

func format_money(amount: int) -> String:
	# Format with K suffix
	if amount >= 1000:
		if amount % 1000 == 0:
			return "%dK" % (amount / 1000)
		else:
			return "%.1fK" % (amount / 1000.0)
	return str(amount)
