from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
import os

ROOT = r"C:\Users\nitra\.codex\worktrees\7fb4\ldjam59-out-of-signal\dist\out-of-signal_html5_0_1_0"

class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()

ThreadingHTTPServer(("127.0.0.1", 8080), Handler).serve_forever()
