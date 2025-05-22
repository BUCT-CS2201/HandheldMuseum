import http from '@ohos.net.http';
import router from '@ohos.router';
import preferences from '@ohos.data.preferences';

interface HistoryItem {
  id: number;
  name: string;
  imageUrl: string;
  browseTime: string;
}
function formatDateTime(isoString: string): string {
  const date = new Date(isoString); // 这里会自动转换成本地时区
  const year = date.getFullYear();
  const month = (date.getMonth() + 1).toString().padStart(2, '0'); // 月份0~11
  const day = date.getDate().toString().padStart(2, '0');
  const hour = date.getHours().toString().padStart(2, '0');
  const minute = date.getMinutes().toString().padStart(2, '0');
  const second = date.getSeconds().toString().padStart(2, '0');
  return `${year}-${month}-${day} ${hour}:${minute}:${second}`;
}

@Entry
@Component
struct BrowsingHistory {
  @State historyList: Array<HistoryItem> = [];

  async aboutToAppear() {
    console.info('[BrowsingHistory] 页面即将显示');
    try {
      // 先初始化 Preferences
      const pref = await preferences.getPreferences(getContext(), 'userInfo');
      console.info('[BrowsingHistory] Preferences 初始化成功');

      // 读取 userId，默认0
      const userId = await pref.get('userId', 0) as number;
      console.info(`[BrowsingHistory] 读取到 userId: ${userId}`);

      if (userId && userId > 0) {
        this.fetchHistory(userId);
      } else {
        console.warn('[BrowsingHistory] userId 无效，无法获取历史记录');
      }
    } catch (err) {
      console.error('[BrowsingHistory] 初始化或读取userId失败:', JSON.stringify(err));
    }
  }

  fetchHistory(userId: number): void {
    console.info('[BrowsingHistory] fetchHistory 调用，userId:', userId);
    let httpRequest = http.createHttp();
    httpRequest.request(
      `http://192.168.1.100:3000/api/antique/history/${userId}`,
      { method: http.RequestMethod.GET },
      (err, data) => {
        console.info('[BrowsingHistory] HTTP 请求回调触发');
        if (err) {
          console.error('[BrowsingHistory] HTTP 请求错误:', JSON.stringify(err));
          return;
        }
        if (!data || typeof data.result !== 'string') {
          console.error('[BrowsingHistory] 响应数据无效:', JSON.stringify(data));
          return;
        }

        console.info('[BrowsingHistory] 原始响应数据:', data.result);

        try {
          const parsedData: HistoryItem[] = JSON.parse(data.result);
          console.info(`[BrowsingHistory] 解析后的历史记录条数: ${parsedData.length}`);
          this.historyList = parsedData;
          console.info('[BrowsingHistory] historyList 赋值完成');
        } catch (parseErr) {
          console.error('[BrowsingHistory] 解析JSON失败:', JSON.stringify(parseErr));
        }
      }
    );
  }

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        Image($r('app.media.back'))
          .width(24)
          .height(24)
          .margin({ left: 16 })
          .onClick(() => {
            router.back();
          });
        Text('浏览历史')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 16 });
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#F5F5F5');

      // 空状态提示
      if (this.historyList.length === 0) {
        Text('暂无浏览记录')
          .fontSize(16)
          .fontColor('#999999')
          .padding(32);
      } else {
        // 历史记录列表
        List() {
          ForEach(this.historyList, (item: HistoryItem) => {
            ListItem() {
              Row() {
                Image(item.imageUrl)
                  .width(80)
                  .height(80)
                  .borderRadius(8)
                  .objectFit(ImageFit.Cover);

                Column() {
                  Text(item.name)
                    .fontSize(16)
                    .flexShrink(1)// 允许收缩
                    .textAlign(TextAlign.Start)
                    .maxLines(null)
                    .textOverflow({ overflow: TextOverflow.None })
                    .width('100%')
                    .margin({ bottom: 4 });

                  Text(formatDateTime(item.browseTime))
                    .fontSize(12)
                    .fontColor('#666666');
                }
                .width('100%')
                .flexGrow(1)
                .flexShrink(1)
                .alignItems(HorizontalAlign.Start)
                .margin({ left: 16, right:10 })
                .alignSelf(ItemAlign.Center);
              }
              .width('100%')
              .padding(16)
              .onClick(() => {
                console.info(`[BrowsingHistory] 点击历史项 id=${item.id}`);
                router.pushUrl({
                  url: 'pages/AntiqueDetail',
                  params: { id: item.id }
                });
              });
            }
          });
        }
        .width('100%')
        .layoutWeight(1);
      }
    }
    .width('100%')
    .height('100%');
  }
}
