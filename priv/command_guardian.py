#!/usr/bin/env python3
"""Linux port primitive: own a process group, bound output, reap before reply.

An abstract socket (no filesystem entry) is held until reaping. It closes the
BEAM-death/advisory-lock-release race across workers. stdin EOF means owner death.
Only the child group created here is ever signalled. No agent PID is accepted.
"""
import base64
import ctypes
import hashlib
import json
import os
import selectors
import signal
import socket
import subprocess
import sys
import time


def reply(result):
    try:
        print(json.dumps(result), flush=True)
    except BrokenPipeError:
        # The owner is gone; cleanup still runs, but there is nobody to notify.
        with open(os.devnull, "w") as sink:
            os.dup2(sink.fileno(), sys.stdout.fileno())


def reap_group(child):
    try:
        os.killpg(child.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    code = child.wait()
    # Adopt and reap descendants killed with the owned process group as well.
    while True:
        try:
            os.waitpid(-1, 0)
        except ChildProcessError:
            return code


def main():
    if ctypes.CDLL(None, use_errno=True).prctl(36, 1, 0, 0, 0) != 0:
        reply({"error": "unreachable"})
        return
    request = json.loads(sys.stdin.buffer.readline())
    admission = socket.socket(socket.AF_UNIX)
    identity = request.get("identity")
    if identity:
        name = "\0foreman:" + hashlib.sha256(identity.encode()).hexdigest()
        try:
            admission.bind(name)
        except OSError:
            reply({"error": "busy"})
            return
    env = {k: v for k, v in os.environ.items()
           if not k.startswith(("BD_", "BEADS_", "DOLT_", "GIT_", "FLUXON_"))}
    env.update({"BD_NO_TELEMETRY": "1", "GIT_CONFIG_NOSYSTEM": "1",
                "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_TERMINAL_PROMPT": "0",
                "DOLT_METRICS_DISABLED": "1", "BD_METRICS_DISABLED": "true",
                "BD_NO_HOOKS": "true", "BD_DOLT_AUTO_PUSH": "false",
                "BD_BACKUP_ENABLED": "false", "BD_EXPORT_PATH": "issues.jsonl",
                "BD_ROUTING_DEFAULT": request["path"],
                "BD_ROUTING_MAINTAINER": request["path"],
                "BD_ROUTING_CONTRIBUTOR": request["path"]})
    child = None
    try:
        child = subprocess.Popen(request["argv"], cwd=request["path"], env=env,
                                 stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                 stderr=subprocess.DEVNULL, start_new_session=True)
        selector = selectors.DefaultSelector()
        selector.register(sys.stdin.buffer, selectors.EVENT_READ, "owner")
        selector.register(child.stdout, selectors.EVENT_READ, "output")
        deadline = time.monotonic() + request["timeout"] / 1000
        chunks, size, error, eof = [], 0, None, False
        while not (eof and os.waitid(os.P_PID, child.pid, os.WEXITED | os.WNOHANG | os.WNOWAIT) is not None):
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                error = "timeout"
                break
            for key, _ in selector.select(min(remaining, 0.1)):
                data = os.read(key.fd, 65536)
                if key.data == "owner":
                    error = "cancelled"
                    break
                if not data:
                    eof = True
                    selector.unregister(child.stdout)
                else:
                    size += len(data)
                    if size > request["max_bytes"]:
                        error = "output_limit"
                        break
                    chunks.append(data)
            if error:
                break
        code = reap_group(child)
        child = None
        result = {"error": error or "exit"} if error or code else {
            "output": base64.b64encode(b"".join(chunks)).decode()}
        reply(result)
    except (OSError, ValueError):
        reply({"error": "unreachable"})
    finally:
        if child is not None:
            reap_group(child)
        admission.close()


if __name__ == "__main__":
    main()
