export type NativeHeaders = Record<string, Array<string>>;

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

export class RcpNativeHttpEngine implements NativeHttpEngine {
  async execute(_request: NativeRequest): Promise<NativeResponse> {
    throw new NativeNetworkError(
      NativeNetworkErrorCode.TRANSPORT_FAILURE,
      'RCP engine wiring is pending DevEco/Hvigor verification',
    );
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

  get(url: string, headers: NativeHeaders = {}): Promise<NativeResponse> {
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
