import rcp from '@hms.collaboration.rcp';

export type NativeHeaders = Map<string, Array<string>>;

export interface NativeRequest {
  method: string;
  url: string;
  headers?: NativeHeaders;
  body?: ArrayBuffer;
}

export interface NativeResponse {
  statusCode: number;
  headers: NativeHeaders;
  body: ArrayBuffer;
  elapsedMilliseconds?: number;
}

export enum NativeNetworkErrorCode {
  INVALID_REQUEST = 'INVALID_REQUEST',
  TRANSPORT_FAILURE = 'TRANSPORT_FAILURE',
  CANCELLED = 'CANCELLED',
  UNKNOWN = 'UNKNOWN',
}

export class NativeNetworkError extends Error {
  public readonly code: NativeNetworkErrorCode;
  public readonly rawDescription?: string;

  constructor(code: NativeNetworkErrorCode, message: string, rawDescription?: string) {
    super(message);
    this.code = code;
    this.rawDescription = rawDescription;
  }
}

export interface NativeHttpEngine {
  execute(request: NativeRequest): Promise<NativeResponse>;
}

export interface RcpSessionLike {
  fetch(request: RcpPlatformRequest): Promise<RcpPlatformResponse>;
}

export class RcpPlatformRequest {
  public readonly method: string;
  public readonly url: string;
  public readonly headers: NativeHeaders;
  public readonly body?: ArrayBuffer;

  constructor(method: string, url: string, headers: NativeHeaders, body?: ArrayBuffer) {
    this.method = method;
    this.url = url;
    this.headers = headers;
    this.body = body;
  }
}

export class RcpPlatformResponse {
  public readonly statusCode: number;
  public readonly headers: NativeHeaders;
  public readonly body: ArrayBuffer;

  constructor(statusCode: number, headers: NativeHeaders, body: ArrayBuffer = new ArrayBuffer(0)) {
    this.statusCode = statusCode;
    this.headers = headers;
    this.body = body;
  }
}

class DefaultRcpSession implements RcpSessionLike {
  private readonly session: rcp.Session = rcp.createSession();

  async fetch(request: RcpPlatformRequest): Promise<RcpPlatformResponse> {
    const response = await this.session.fetch(new rcp.Request(
      request.url,
      request.method,
      rcpHeaders(request.headers),
      request.body,
    ));
    return new RcpPlatformResponse(
      response.statusCode,
      normalizeHeaders(response.headers),
      response.body ?? new ArrayBuffer(0),
    );
  }
}

export class RcpNativeHttpEngine implements NativeHttpEngine {
  private readonly session: RcpSessionLike;

  constructor(session: RcpSessionLike = new DefaultRcpSession()) {
    this.session = session;
  }

  async execute(request: NativeRequest): Promise<NativeResponse> {
    const start = Date.now();
    const rcpRequest = new RcpPlatformRequest(
      request.method,
      request.url,
      request.headers ?? new Map<string, Array<string>>(),
      request.body,
    );

    try {
      const response = await this.session.fetch(rcpRequest);
      return {
        statusCode: response.statusCode,
        headers: response.headers,
        body: response.body,
        elapsedMilliseconds: Date.now() - start,
      };
    } catch (error) {
      throw new NativeNetworkError(
        NativeNetworkErrorCode.TRANSPORT_FAILURE,
        'RCP request failed',
        String(error),
      );
    }
  }
}

export class NativeNetClient {
  private readonly engine: NativeHttpEngine;

  constructor(engine: NativeHttpEngine = new RcpNativeHttpEngine()) {
    this.engine = engine;
  }

  execute(request: NativeRequest): Promise<NativeResponse> {
    return this.engine.execute(request);
  }

  get(url: string, headers: NativeHeaders = new Map<string, Array<string>>()): Promise<NativeResponse> {
    return this.execute({
      method: 'GET',
      url,
      headers,
    });
  }
}

export class MockNativeHttpEngine implements NativeHttpEngine {
  private readonly handler: (request: NativeRequest) => Promise<NativeResponse>;

  constructor(handler: (request: NativeRequest) => Promise<NativeResponse>) {
    this.handler = handler;
  }

  execute(request: NativeRequest): Promise<NativeResponse> {
    return this.handler(request);
  }
}

function normalizeHeaders(headers?: rcp.ResponseHeaders): NativeHeaders {
  const normalized: NativeHeaders = new Map<string, Array<string>>();
  if (!headers) {
    return normalized;
  }

  Object.keys(headers).forEach((name: string) => {
    const value = Reflect.get(headers, name) as string | Array<string> | undefined;
    if (typeof value === 'string') {
      normalized.set(name, [value]);
    } else if (Array.isArray(value)) {
      normalized.set(name, value);
    }
  });
  return normalized;
}

function rcpHeaders(headers: NativeHeaders): rcp.RequestHeaders {
  const platformHeaders = new Object() as rcp.RequestHeaders;
  headers.forEach((values: Array<string>, name: string) => {
    if (values.length === 1) {
      Reflect.set(platformHeaders, name, values[0]);
    } else {
      Reflect.set(platformHeaders, name, values);
    }
  });
  return platformHeaders;
}
