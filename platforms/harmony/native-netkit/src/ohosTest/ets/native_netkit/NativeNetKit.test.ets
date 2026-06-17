import { describe, expect, it } from '@ohos/hypium';
import {
  MockNativeHttpEngine,
  NativeNetClient,
  NativeNetworkError,
  NativeNetworkErrorCode,
} from '../../../main/ets/native_netkit/NativeNetKit';

export default function nativeNetKitTest() {
  describe('NativeNetKit', () => {
    it('forwards requests to injected engine', 0, async () => {
      const client = new NativeNetClient(new MockNativeHttpEngine(async (request) => {
        expect(request.method).assertEqual('GET');
        expect(request.url).assertEqual('https://example.com/status');
        return {
          statusCode: 204,
          headers: {},
          body: new ArrayBuffer(0),
          elapsedMilliseconds: 12,
        };
      }));

      const response = await client.get('https://example.com/status');

      expect(response.statusCode).assertEqual(204);
      expect(response.elapsedMilliseconds).assertEqual(12);
    });

    it('propagates native network errors', 0, async () => {
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
        expect((error as NativeNetworkError).code).assertEqual(NativeNetworkErrorCode.TRANSPORT_FAILURE);
      }
    });
  });
}
