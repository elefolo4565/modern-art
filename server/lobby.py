"""Lobby management for room creation, joining, and player management."""

import uuid
import asyncio
from dataclasses import dataclass, field
from typing import Dict, List, Optional
from game import Game, Player
from ai_player import AIPlayerController
from protocol import *


@dataclass
class Room:
    room_id: str
    host_id: str
    players: List[Player] = field(default_factory=list)
    game: Optional[Game] = None
    started: bool = False
    ai_controller: Optional[AIPlayerController] = None

    def to_dict(self) -> Dict:
        return {
            "room_id": self.room_id,
            "host": self.players[0].name if self.players else "",
            "player_count": len(self.players),
            "started": self.started,
        }


class Lobby:
    """Manages game rooms and player connections."""

    def __init__(self):
        self.rooms: Dict[str, Room] = {}
        self.player_room: Dict[str, str] = {}  # player_id -> room_id
        self.ws_to_player: Dict[object, str] = {}  # ws -> player_id

    def _generate_room_id(self) -> str:
        return uuid.uuid4().hex[:6].upper()

    def _generate_player_id(self) -> str:
        return uuid.uuid4().hex[:8]

    def get_room_by_player(self, player_id: str) -> Optional[Room]:
        room_id = self.player_room.get(player_id)
        if room_id:
            return self.rooms.get(room_id)
        return None

    def get_player_index(self, room: Room, player_id: str) -> int:
        for i, p in enumerate(room.players):
            if p.player_id == player_id:
                return i
        return -1

    async def handle_message(self, ws, data: dict) -> None:
        """Route incoming WebSocket messages to appropriate handlers."""
        msg_type = data.get("type", "")

        if msg_type == "create_room":
            await self._handle_create_room(ws, data)
        elif msg_type == "join_room":
            await self._handle_join_room(ws, data)
        elif msg_type == "list_rooms":
            await self._handle_list_rooms(ws)
        elif msg_type == "start_game":
            await self._handle_start_game(ws)
        elif msg_type == "add_ai":
            await self._handle_add_ai(ws, data)
        elif msg_type == "remove_ai":
            await self._handle_remove_ai(ws, data)
        elif msg_type in ("play_card", "bid", "pass", "accept", "set_price",
                          "double_response"):
            await self._handle_game_action(ws, data)
        else:
            await ws.send_str(msg_error(f"Unknown message type: {msg_type}"))

    async def _handle_create_room(self, ws, data: dict) -> None:
        player_name = data.get("player_name", "").strip()
        if not player_name:
            await ws.send_str(msg_error("Player name is required"))
            return

        player_id = self._generate_player_id()
        room_id = self._generate_room_id()

        player = Player(player_id=player_id, name=player_name, ws=ws)
        room = Room(
            room_id=room_id,
            host_id=player_id,
            players=[player],
            ai_controller=AIPlayerController(),
        )

        self.rooms[room_id] = room
        self.player_room[player_id] = room_id
        self.ws_to_player[ws] = player_id

        players_list = [p.to_public_dict() for p in room.players]
        await ws.send_str(msg_room_created(room_id, player_id, players_list))

    async def _handle_join_room(self, ws, data: dict) -> None:
        player_name = data.get("player_name", "").strip()
        room_id = data.get("room_id", "").strip().upper()

        if not player_name:
            await ws.send_str(msg_error("Player name is required"))
            return

        room = self.rooms.get(room_id)
        if not room:
            await ws.send_str(msg_error("Room not found"))
            return

        if room.started:
            await ws.send_str(msg_error("Game already started"))
            return

        if len(room.players) >= 5:
            await ws.send_str(msg_error("Room is full (max 5 players)"))
            return

        player_id = self._generate_player_id()
        player = Player(player_id=player_id, name=player_name, ws=ws)

        room.players.append(player)
        self.player_room[player_id] = room_id
        self.ws_to_player[ws] = player_id

        players_list = [p.to_public_dict() for p in room.players]

        await ws.send_str(msg_room_joined(room_id, player_id, players_list))

        for p in room.players:
            if p.player_id != player_id:
                await self._send_safe(p.ws, msg_player_joined(
                    players_list, player_name
                ))

    def _add_ai_player(self, room: Room) -> str:
        """Add an AI player to the room and return its name."""
        if not room.ai_controller:
            room.ai_controller = AIPlayerController()

        ai_name = room.ai_controller.get_ai_name()
        ai_id = "ai_" + self._generate_player_id()

        ai_player = Player(
            player_id=ai_id,
            name=ai_name,
            ws=None,
            is_ai=True,
        )
        room.players.append(ai_player)
        return ai_name

    async def _handle_add_ai(self, ws, data: dict) -> None:
        """Add an AI player to the room."""
        player_id = self.ws_to_player.get(ws)
        if not player_id:
            await ws.send_str(msg_error("Not in a room"))
            return

        room = self.get_room_by_player(player_id)
        if not room:
            await ws.send_str(msg_error("Room not found"))
            return

        if room.host_id != player_id:
            await ws.send_str(msg_error("Only the host can add AI"))
            return

        if room.started:
            await ws.send_str(msg_error("Game already started"))
            return

        if len(room.players) >= 5:
            await ws.send_str(msg_error("Room is full (max 5 players)"))
            return

        ai_name = self._add_ai_player(room)

        players_list = [p.to_public_dict() for p in room.players]

        # Notify all human players
        for p in room.players:
            if not p.is_ai:
                await self._send_safe(p.ws, msg_player_joined(
                    players_list, ai_name
                ))

    async def _handle_remove_ai(self, ws, data: dict) -> None:
        """Remove an AI player from the room."""
        player_id = self.ws_to_player.get(ws)
        if not player_id:
            await ws.send_str(msg_error("Not in a room"))
            return

        room = self.get_room_by_player(player_id)
        if not room:
            await ws.send_str(msg_error("Room not found"))
            return

        if room.host_id != player_id:
            await ws.send_str(msg_error("Only the host can remove AI"))
            return

        if room.started:
            await ws.send_str(msg_error("Game already started"))
            return

        # Find and remove the last AI player
        ai_index = -1
        ai_name = ""
        for i in range(len(room.players) - 1, -1, -1):
            if room.players[i].is_ai:
                ai_index = i
                ai_name = room.players[i].name
                break

        if ai_index < 0:
            await ws.send_str(msg_error("No AI players to remove"))
            return

        room.players.pop(ai_index)
        players_list = [p.to_public_dict() for p in room.players]

        # Notify all human players
        for p in room.players:
            if not p.is_ai:
                await self._send_safe(p.ws, msg_player_left(
                    players_list, ai_name
                ))

    async def _handle_list_rooms(self, ws) -> None:
        rooms_list = [
            room.to_dict() for room in self.rooms.values()
            if not room.started and len(room.players) < 5
        ]
        await ws.send_str(msg_room_list(rooms_list))

    async def _handle_start_game(self, ws) -> None:
        player_id = self.ws_to_player.get(ws)
        if not player_id:
            await ws.send_str(msg_error("Not in a room"))
            return

        room = self.get_room_by_player(player_id)
        if not room:
            await ws.send_str(msg_error("Room not found"))
            return

        if room.host_id != player_id:
            await ws.send_str(msg_error("Only the host can start the game"))
            return

        if len(room.players) < 3:
            await ws.send_str(msg_error("Need at least 3 players"))
            return

        if room.started:
            await ws.send_str(msg_error("Game already started"))
            return

        # Check if there are any AI players
        has_ai = any(p.is_ai for p in room.players)
        ai_ctrl = room.ai_controller if has_ai else None

        room.started = True
        room.game = Game(room.players, ai_controller=ai_ctrl)
        await room.game.start()

    async def _handle_game_action(self, ws, data: dict) -> None:
        player_id = self.ws_to_player.get(ws)
        if not player_id:
            return

        room = self.get_room_by_player(player_id)
        if not room or not room.game:
            return

        player_index = self.get_player_index(room, player_id)
        if player_index < 0:
            return

        game = room.game
        msg_type = data.get("type", "")

        if msg_type == "play_card":
            card_index = data.get("card_index", -1)
            double_card_index = data.get("double_card_index", -1)
            await game.handle_play_card(player_index, card_index, double_card_index)
        elif msg_type == "bid":
            amount = data.get("amount", 0)
            await game.handle_bid(player_index, amount)
        elif msg_type == "pass":
            await game.handle_pass(player_index)
        elif msg_type == "accept":
            await game.handle_accept(player_index)
        elif msg_type == "set_price":
            amount = data.get("amount", 0)
            await game.handle_set_price(player_index, amount)
        elif msg_type == "double_response":
            second_card_index = data.get("card_index", -1)
            await game.handle_double_response(player_index, second_card_index)

    async def handle_disconnect(self, ws) -> None:
        """Handle a player disconnecting."""
        player_id = self.ws_to_player.pop(ws, None)
        if not player_id:
            return

        room_id = self.player_room.pop(player_id, None)
        if not room_id:
            return

        room = self.rooms.get(room_id)
        if not room:
            return

        player_name = "Unknown"
        for p in room.players:
            if p.player_id == player_id:
                player_name = p.name
                break

        room.players = [p for p in room.players if p.player_id != player_id]

        # If no human players left, remove room
        human_players = [p for p in room.players if not p.is_ai]
        if not human_players:
            del self.rooms[room_id]
            return

        if room.host_id == player_id:
            # Assign new host to first human player
            for p in room.players:
                if not p.is_ai:
                    room.host_id = p.player_id
                    break

        players_list = [p.to_public_dict() for p in room.players]
        for p in room.players:
            if not p.is_ai:
                await self._send_safe(p.ws, msg_player_left(players_list, player_name))

    async def _send_safe(self, ws, message: str) -> None:
        if ws is None:
            return  # AI player
        try:
            await ws.send_str(message)
        except Exception:
            pass
