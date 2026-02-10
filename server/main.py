"""Modern Art game server - HTTP static file serving + WebSocket game server."""

import os
import asyncio
import argparse
import logging
from pathlib import Path

from aiohttp import web
import aiohttp

from lobby import Lobby
from protocol import parse_message

# --- Logging setup ---
LOG_DIR = os.path.dirname(__file__)
LOG_FILE = os.path.join(LOG_DIR, "server.log")

logging.basicConfig(
    level=logging.DEBUG,
    format="%(asctime)s [%(name)-6s] %(levelname)-5s %(message)s",
    datefmt="%H:%M:%S",
    handlers=[
        logging.FileHandler(LOG_FILE, encoding="utf-8", mode="w"),
        logging.StreamHandler(),
    ],
)
# Suppress noisy aiohttp access logs
logging.getLogger("aiohttp").setLevel(logging.WARNING)
logging.getLogger("aiohttp.access").setLevel(logging.WARNING)

log = logging.getLogger("server")

lobby = Lobby()


async def websocket_handler(request: web.Request) -> web.WebSocketResponse:
    """Handle WebSocket connections for game communication."""
    ws = web.WebSocketResponse()
    await ws.prepare(request)

    log.info("Client connected: %s", request.remote)

    try:
        async for msg in ws:
            if msg.type == aiohttp.WSMsgType.TEXT:
                data = parse_message(msg.data)
                await lobby.handle_message(ws, data)
            elif msg.type == aiohttp.WSMsgType.ERROR:
                log.error("WS error: %s", ws.exception())
    except Exception as e:
        log.exception("WS exception: %s", e)
    finally:
        await lobby.handle_disconnect(ws)
        log.info("Client disconnected: %s", request.remote)

    return ws


def create_app(static_dir: str = None) -> web.Application:
    """Create the aiohttp application."""
    app = web.Application()

    # WebSocket endpoint
    app.router.add_get("/ws", websocket_handler)

    # Static file serving (Godot web export)
    if static_dir and os.path.isdir(static_dir):
        # Serve index.html at root
        async def index_handler(request: web.Request) -> web.FileResponse:
            index_path = os.path.join(static_dir, "index.html")
            if os.path.exists(index_path):
                headers = {
                    "Cross-Origin-Opener-Policy": "same-origin",
                    "Cross-Origin-Embedder-Policy": "require-corp",
                }
                return web.FileResponse(index_path, headers=headers)
            return web.Response(text="Modern Art Server Running", status=200)

        app.router.add_get("/", index_handler)

        # Serve all static files with required headers for SharedArrayBuffer
        async def static_handler(request: web.Request) -> web.Response:
            file_path = os.path.join(static_dir, request.match_info["path"])
            if os.path.isfile(file_path):
                headers = {
                    "Cross-Origin-Opener-Policy": "same-origin",
                    "Cross-Origin-Embedder-Policy": "require-corp",
                }
                # Set correct content types
                if file_path.endswith(".wasm"):
                    headers["Content-Type"] = "application/wasm"
                elif file_path.endswith(".js"):
                    headers["Content-Type"] = "application/javascript"
                elif file_path.endswith(".html"):
                    headers["Content-Type"] = "text/html"
                elif file_path.endswith(".png"):
                    headers["Content-Type"] = "image/png"
                elif file_path.endswith(".ico"):
                    headers["Content-Type"] = "image/x-icon"
                return web.FileResponse(file_path, headers=headers)
            return web.Response(status=404)

        app.router.add_get("/{path:.*}", static_handler)

    else:
        async def default_handler(request: web.Request) -> web.Response:
            return web.Response(
                text="Modern Art Server Running. Static files not configured.",
                status=200,
            )
        app.router.add_get("/", default_handler)

    return app


def main():
    parser = argparse.ArgumentParser(description="Modern Art Game Server")
    parser.add_argument("--host", default="0.0.0.0", help="Host to bind to")
    parser.add_argument("--port", type=int,
                        default=int(os.environ.get("PORT", "8080")),
                        help="Port to listen on")
    parser.add_argument("--static", default=None,
                        help="Path to static files (Godot web export directory)")
    args = parser.parse_args()

    # Default static dir: ../export
    static_dir = args.static
    if static_dir is None:
        default_export = os.path.join(os.path.dirname(__file__), "..", "export")
        if os.path.isdir(default_export):
            static_dir = os.path.abspath(default_export)

    if static_dir:
        log.info("Serving static files from: %s", static_dir)
    else:
        log.info("No static directory found. Only WebSocket available.")

    app = create_app(static_dir)
    log.info("Starting on http://%s:%d  (log file: %s)", args.host, args.port, LOG_FILE)
    web.run_app(app, host=args.host, port=args.port)


if __name__ == "__main__":
    main()
