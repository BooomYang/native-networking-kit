import { describe, expect, it } from '@ohos/hypium';
import {
  MockNativeHttpEngine,
  NativeHeaders,
  NativeNetClient,
  NativeNetworkError,
  NativeNetworkErrorCode,
  NativeRequest,
  NativeResponse,
  RcpNativeHttpEngine,
  RcpPlatformRequest,
  RcpPlatformResponse,
  RcpSessionLike,
} from '../main/ets/native_netkit/NativeNetKit';

export default function testsuite() {
  nativeNetKitTest();
}

function nativeNetKitTest() {
  describe('NativeNetKit', () => {
    it('clientForwardsRequestToInjectedEngine', 0, async () => {
      // 验证意图：
      // - 场景：调用方通过 `NativeNetClient.get` 发起 GET。
      // - 行为：client 应把 method、url 和 headers 交给 injected engine，并透传 response。
      // - 风险：防止 Harmony client 层破坏三端统一 request/response contract。
      const client = new NativeNetClient(new MockNativeHttpEngine(async (request) => {
        expect(request.method).assertEqual('GET');
        expect(request.url).assertEqual('https://example.com/status');
        expect(request.headers?.get('Accept')?.[0]).assertEqual('application/json');
        const response: NativeResponse = {
          statusCode: 204,
          headers: new Map<string, Array<string>>(),
          body: stringBuffer('ok'),
          elapsedMilliseconds: 12,
        };
        return response;
      }));
      const headers: NativeHeaders = new Map<string, Array<string>>();
      headers.set('Accept', ['application/json']);

      const response = await client.get('https://example.com/status', headers);

      expect(response.statusCode).assertEqual(204);
      expect(bufferText(response.body)).assertEqual('ok');
      expect(response.elapsedMilliseconds).assertEqual(12);
    });

    it('clientPropagatesNativeNetworkErrors', 0, async () => {
      // 验证意图：
      // - 场景：injected engine 抛出 `NativeNetworkError`。
      // - 行为：client 应原样传播统一错误语义。
      // - 风险：防止 Harmony client 层吞掉或重写 `NativeNetworkError`。
      const expected = new NativeNetworkError(
        NativeNetworkErrorCode.TRANSPORT_FAILURE,
        'mock failure',
      );
      const client = new NativeNetClient(new MockNativeHttpEngine(async () => {
        throw expected;
      }));

      try {
        await client.get('https://example.com/fail');
        expect(true).assertFalse();
      } catch (error) {
        expect(error).assertEqual(expected);
      }
    });

    it('rcpEngineBuildsRcpRequestFromNativeRequest', 0, async () => {
      // 验证意图：
      // - 场景：调用方传入 method、headers 和 body。
      // - 行为：RCP adapter 应构造等价 platform request，并返回 platform response。
      // - 风险：防止 Harmony adapter 丢失影响请求语义的字段。
      const session = new FakeRcpSession(async (request: RcpPlatformRequest) => {
        expect(request.method).assertEqual('POST');
        expect(request.url).assertEqual('https://example.com/upload');
        expect(request.headers.get('X-Trace-ID')?.[0]).assertEqual('trace-1');
        expect(bufferText(request.body as ArrayBuffer)).assertEqual('payload');
        return new RcpPlatformResponse(201, new Map<string, Array<string>>());
      });
      const engine = new RcpNativeHttpEngine(session);
      const headers: NativeHeaders = new Map<string, Array<string>>();
      headers.set('X-Trace-ID', ['trace-1']);
      const request: NativeRequest = {
        method: 'POST',
        url: 'https://example.com/upload',
        headers,
        body: stringBuffer('payload'),
      };

      const response = await engine.execute(request);

      expect(response.statusCode).assertEqual(201);
    });

    it('rcpEngineMapsHttpResponseIntoNativeResponse', 0, async () => {
      // 验证意图：
      // - 场景：RCP session 返回 HTTP 503。
      // - 行为：Harmony adapter 应返回 `NativeResponse` 而不是抛 transport error。
      // - 风险：防止业务 HTTP 状态被误分类为网络故障。
      const session = new FakeRcpSession(async () => {
        const headers: NativeHeaders = new Map<string, Array<string>>();
        headers.set('X-NativeNetKit-Test', ['non-2xx']);
        return new RcpPlatformResponse(503, headers, stringBuffer('service-unavailable'));
      });
      const engine = new RcpNativeHttpEngine(session);
      const request: NativeRequest = {
        method: 'GET',
        url: 'https://example.com/status',
        headers: new Map<string, Array<string>>(),
      };

      const response = await engine.execute(request);

      expect(response.statusCode).assertEqual(503);
      expect(response.headers.get('X-NativeNetKit-Test')?.[0]).assertEqual('non-2xx');
      expect(bufferText(response.body)).assertEqual('service-unavailable');
    });

    it('rcpEngineMapsSessionErrorToTransportFailureWithRawDescription', 0, async () => {
      // 验证意图：
      // - 场景：RCP session 抛出底层网络错误。
      // - 行为：Harmony adapter 应映射为 `TRANSPORT_FAILURE` 并保留 raw details。
      // - 风险：防止诊断信息丢失或底层错误越过统一错误模型。
      const session = new FakeRcpSession(async () => {
        throw new Error('offline');
      });
      const engine = new RcpNativeHttpEngine(session);
      const request: NativeRequest = {
        method: 'GET',
        url: 'https://example.com/offline',
        headers: new Map<string, Array<string>>(),
      };

      try {
        await engine.execute(request);
        expect(true).assertFalse();
      } catch (error) {
        const nativeError = error as NativeNetworkError;
        expect(nativeError.code).assertEqual(NativeNetworkErrorCode.TRANSPORT_FAILURE);
        expect(nativeError.message).assertEqual('RCP request failed');
        expect(nativeError.rawDescription?.includes('offline')).assertTrue();
      }
    });
  });
}

class FakeRcpSession implements RcpSessionLike {
  private readonly handler: (request: RcpPlatformRequest) => Promise<RcpPlatformResponse>;

  constructor(handler: (request: RcpPlatformRequest) => Promise<RcpPlatformResponse>) {
    this.handler = handler;
  }

  fetch(request: RcpPlatformRequest): Promise<RcpPlatformResponse> {
    return this.handler(request);
  }
}

function stringBuffer(value: string): ArrayBuffer {
  const buffer = new ArrayBuffer(value.length);
  const view = new Uint8Array(buffer);
  for (let index = 0; index < value.length; index += 1) {
    view[index] = value.charCodeAt(index);
  }
  return buffer;
}

function bufferText(buffer: ArrayBuffer): string {
  const view = new Uint8Array(buffer);
  let text = '';
  for (let index = 0; index < view.length; index += 1) {
    text += String.fromCharCode(view[index]);
  }
  return text;
}
