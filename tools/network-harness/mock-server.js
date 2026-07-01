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

function collectRequestBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (chunk) => chunks.push(chunk));
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", reject);
  });
}

function writeSseEvent(res, event, data) {
  res.write(`event: ${event}\n`);
  res.write(`data: ${JSON.stringify(data)}\n\n`);
}

async function sendMockModelSse(req, res) {
  const body = await collectRequestBody(req);
  const authorization = req.headers.authorization || "";

  if (req.method !== "POST") {
    send(res, 405, "method-not-allowed", { "Allow": "POST" });
    return;
  }

  if (authorization !== "Bearer loopback-token") {
    send(res, 401, "unauthorized");
    return;
  }

  if (!body.includes('"stream":true')) {
    send(res, 400, "stream-required");
    return;
  }

  res.writeHead(200, {
    "Content-Type": "text/event-stream; charset=utf-8",
    "Cache-Control": "no-cache",
    "Connection": "keep-alive",
    "X-NativeNetKit-Harness": "mock-model-sse",
  });

  const events = [
    [
      "response.created",
      {
        id: "resp_mock_1",
        object: "response",
        model: "native-netkit-mock-model",
      },
    ],
    [
      "response.output_text.delta",
      {
        delta: "Hel",
      },
    ],
    [
      "response.output_text.delta",
      {
        delta: "lo",
      },
    ],
    [
      "response.completed",
      {
        id: "resp_mock_1",
        output_text: "Hello",
      },
    ],
  ];

  let index = 0;
  const writeNext = () => {
    if (index >= events.length) {
      res.end();
      return;
    }

    const [event, data] = events[index];
    writeSseEvent(res, event, data);
    index += 1;
    setTimeout(writeNext, 25);
  };
  writeNext();
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

  if (url.pathname === "/v1/chat/completions") {
    sendMockModelSse(req, res).catch((error) => {
      send(res, 500, `mock-model-error: ${error.message}`);
    });
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
