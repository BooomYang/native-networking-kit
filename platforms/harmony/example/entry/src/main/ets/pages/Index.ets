import { NativeNetClient } from '@aifirst/native-netkit';

@Entry
@Component
struct Index {
  @State private urlText: string = 'https://example.com';
  @State private resultText: string = 'Ready';
  @State private loading: boolean = false;

  private client: NativeNetClient = new NativeNetClient();

  build() {
    Column({ space: 12 }) {
      Text('NativeNetKit')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)

      TextInput({ text: this.urlText, placeholder: 'URL' })
        .onChange((value: string) => {
          this.urlText = value;
        })

      Button(this.loading ? 'Loading...' : 'GET')
        .enabled(!this.loading)
        .onClick(() => {
          this.fetch();
        })

      Text(this.resultText)
        .fontSize(14)
        .fontFamily('monospace')
        .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }

  private async fetch(): Promise<void> {
    this.loading = true;
    this.resultText = 'Requesting...';

    try {
      const response = await this.client.get(this.urlText);
      this.resultText = `Status: ${response.statusCode}\nBytes: ${response.body.byteLength}\nElapsed: ${response.elapsedMilliseconds ?? -1} ms`;
    } catch (error) {
      this.resultText = `Error: ${(error as Error).message}`;
    } finally {
      this.loading = false;
    }
  }
}
