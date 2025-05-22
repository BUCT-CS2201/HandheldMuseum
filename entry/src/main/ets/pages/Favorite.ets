import http from '@ohos.net.http';
import router from '@ohos.router';
import preferences from '@ohos.data.preferences';

interface FavoriteItem {
  id: number;
  name: string;
  imageUrl: string;
  createTime: string;
}

function formatDateTime(isoString: string): string {
  const date = new Date(isoString);
  const year = date.getFullYear();
  const month = (date.getMonth() + 1).toString().padStart(2, '0');
  const day = date.getDate().toString().padStart(2, '0');
  const hour = date.getHours().toString().padStart(2, '0');
  const minute = date.getMinutes().toString().padStart(2, '0');
  const second = date.getSeconds().toString().padStart(2, '0');
  return `${year}-${month}-${day} ${hour}:${minute}:${second}`;
}

@Entry
@Component
struct Favorite {
  @State favoriteList: Array<FavoriteItem> = [];

  async aboutToAppear() {
    console.info('[Favorite] 页面即将显示');
    try {
      const pref = await preferences.getPreferences(getContext(), 'userInfo');
      console.info('[Favorite] Preferences 初始化成功');

      const userId = await pref.get('userId', 0) as number;
      console.info(`[Favorite] 读取到 userId: ${userId}`);

      if (userId && userId > 0) {
        this.fetchFavorites(userId);
      } else {
        console.warn('[Favorite] userId 无效，无法获取收藏记录');
      }
    } catch (err) {
      console.error('[Favorite] 初始化或读取userId失败:', JSON.stringify(err));
    }
  }

  fetchFavorites(userId: number): void {
    console.info('[Favorite] fetchFavorites 调用，userId:', userId);
    let httpRequest = http.createHttp();
    httpRequest.request(
      `http://192.168.1.107:3000/api/antique/favorites/${userId}`,
      { method: http.RequestMethod.GET },
      (err, data) => {
        console.info('[Favorite] HTTP 请求回调触发');
        if (err) {
          console.error('[Favorite] HTTP 请求错误:', JSON.stringify(err));
          return;
        }
        if (!data || typeof data.result !== 'string') {
          console.error('[Favorite] 响应数据无效:', JSON.stringify(data));
          return;
        }

        console.info('[Favorite] 原始响应数据:', data.result);

        try {
          const parsedData: FavoriteItem[] = JSON.parse(data.result);
          console.info(`[Favorite] 解析后的收藏记录条数: ${parsedData.length}`);
          this.favoriteList = parsedData;
          console.info('[Favorite] favoriteList 赋值完成');
        } catch (parseErr) {
          console.error('[Favorite] 解析JSON失败:', JSON.stringify(parseErr));
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
        Text('收藏记录')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 16 });
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#F5F5F5');

      // 空状态提示
      if (this.favoriteList.length === 0) {
        Text('暂无收藏记录')
          .fontSize(16)
          .fontColor('#999999')
          .padding(32);
      } else {
        // 收藏记录列表
        List() {
          ForEach(this.favoriteList, (item: FavoriteItem) => {
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
                    .flexShrink(1)
                    .textAlign(TextAlign.Start)
                    .maxLines(null)
                    .textOverflow({ overflow: TextOverflow.None })
                    .width('100%')
                    .margin({ bottom: 4 });

                  Text(formatDateTime(item.createTime))
                    .fontSize(12)
                    .fontColor('#666666');
                }
                .width('100%')
                .flexGrow(1)
                .flexShrink(1)
                .alignItems(HorizontalAlign.Start)
                .margin({ left: 16, right: 10 })
                .alignSelf(ItemAlign.Center);
              }
              .width('100%')
              .padding(16)
              .onClick(() => {
                console.info(`[Favorite] 点击收藏项 id=${item.id}`);
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
