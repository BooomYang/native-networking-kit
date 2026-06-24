#!/usr/bin/env node

const http = require("http");

const host = "127.0.0.1";
const requestedPort = Number.parseInt(process.env.NATIVE_NET_KIT_MOCK_PORT || "0", 10);

function send(res, statusCode, body, headers = {}) {
  res.writeHead(statusCode, {
    "Content-Type": "text/plain; charset=utf-8",
    "Content-Length": Buffer.byteLength(body),
    ...headers,
  });
  res.end(body);
}

function reserveAndClosePort() {
  return new Promise((resolve, reject) => {
    const server = http.createServer((_, res) => send(res, 500, "reserved"));
    server.on("error", reject);
    server.listen(0, host, () => {
      const address = server.address();
      server.close((error) => {
        if (error) {
          reject(error);
          return;
        }
        resolve(address.port);
      });
    });
  });
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url || "/", `http://${req.headers.host || host}`);

  if (url.pathname === "/success") {
    send(res, 200, "success-body", { "X-NativeNetKit-Harness": "success" });
    return;
  }

  if (url.pathname === "/delay") {
    const delayMilliseconds = Math.min(
      Math.max(Number.parseInt(url.searchParams.get("ms") || "150", 10), 0),
      2_000
    );
    setTimeout(() => {
      send(res, 200, "delayed-body", { "X-NativeNetKit-Harness": "delay" });
    }, delayMilliseconds);
    return;
  }

  if (url.pathname === "/close") {
    req.socket.destroy();
    return;
  }

  send(res, 404, "not-found", { "X-NativeNetKit-Harness": "not-found" });
});

server.on("clientError", (_, socket) => {
  socket.destroy();
});

server.on("error", (error) => {
  console.error(`Mock server error: ${error.message}`);
  process.exit(1);
});

server.listen(requestedPort, host, async () => {
  try {
    const address = server.address();
    const unusedPort = await reserveAndClosePort();
    console.log(`PORT ${address.port}`);
    console.log(`UNUSED_PORT ${unusedPort}`);
  } catch (error) {
    console.error(`Failed to reserve unused port: ${error.message}`);
    process.exitCode = 1;
    server.close();
  }
});

process.on("SIGTERM", () => {
  server.close(() => process.exit(0));
});
