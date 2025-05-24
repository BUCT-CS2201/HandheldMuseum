import http from '@ohos.net.http';
import router from '@ohos.router';
import { BusinessError } from '@ohos.base';

interface MuseumRankingInfo {
  museum_id: number;
  museum_name: string;
  address: string;
  relic_count: number;
  museum_image: string;
}

@Entry
@Component
struct MuseumRanking {
  @State museums: MuseumRankingInfo[] = [];
  @State message: string = '加载中...';

  aboutToAppear() {
    this.fetchMuseumRanking();
  }

  fetchMuseumRanking() {
    let httpRequest = http.createHttp();
    httpRequest.request(
      'http://10.4.11.183:3000/api/museum/ranking',
      {
        method: http.RequestMethod.GET,
      },
      (err: BusinessError<void> | undefined, data: http.HttpResponse) => {
        if (!err) {
          try {
            let result: MuseumRankingInfo[] = [];
            if (typeof data.result === 'string') {
              result = JSON.parse(data.result) as MuseumRankingInfo[];
            } else if (Array.isArray(data.result)) {
              result = data.result as MuseumRankingInfo[];
            }
            this.museums = result;
            this.message = '加载成功';
          } catch (e) {
            this.message = '数据解析失败';
            console.error('解析异常:', JSON.stringify(e));
          }
        } else {
          this.message = '获取数据失败';
          console.error(JSON.stringify(err));
        }
        httpRequest.destroy();
      }
    );
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Image($r('app.media.ic_back'))
          .width(24)
          .height(24)
          .margin({ left: 16 })
          .onClick(() => {
            router.back();
          })
        Text('博物馆排行榜')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 16 })
      }
      .width('100%')
      .height(56)
      .backgroundColor('#FFFFFF')
      .shadow({
        radius: 6,
        color: '#1A000000',
        offsetX: 0,
        offsetY: 2
      })

      if (this.museums.length > 0) {
        Column() {
          // 参数说明行
          Row() {
            Text('排名')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333333')
              .width(60)
              .textAlign(TextAlign.Center)
            Text('博物馆信息')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333333')
              .layoutWeight(1)
            Text('藏品数量')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333333')
              .margin({ left: 16 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .backgroundColor('#F0F5FF')
          .borderRadius(8)
          .margin({ bottom: 1 })
          .shadow({
            radius: 4,
            color: '#1A000000',
            offsetX: 0,
            offsetY: 2
          })

          List() {
            ForEach(this.museums, (item: MuseumRankingInfo, index: number) => {
              ListItem() {
                Row() {
                  // 排名
                  Column() {
                    if (index < 3) {
                      Image($r('app.media.medal_' + (index + 1)))
                        .width(32)
                        .height(32)
                    } else {
                      Text((index + 1).toString())
                        .fontSize(24)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#666666')
                    }
                  }
                  .width(40)
                  .height(40)
                  .justifyContent(FlexAlign.Center)
                  .alignItems(HorizontalAlign.Center)

                  // 博物馆信息
                  Column() {
                    Text(item.museum_name)
                      .fontSize(18)
                      .fontWeight(FontWeight.Medium)
                      .width('100%')
                    Text(item.address)
                      .fontSize(14)
                      .fontColor('#666666')
                      .width('100%')
                      .margin({ top: 4 })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  // 藏品数量
                  Column() {
                    Text(item.relic_count.toString())
                      .fontSize(20)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#4A90E2')
                    Text('件')
                      .fontSize(14)
                      .fontColor('#666666')
                  }
                  .margin({ left: 16 })
                  .alignItems(HorizontalAlign.End)
                }
                .width('100%')
                .padding(16)
                .backgroundColor('#FFFFFF')
                .borderRadius(12)
                .margin({ bottom: 8 })
                .shadow({
                  radius: 8,
                  color: '#1A000000',
                  offsetX: 0,
                  offsetY: 2
                })
                .onClick(() => {
                  router.pushUrl({
                    url: 'pages/MuseumDetail',
                    params: {
                      museumId: item.museum_id,
                      museumImage: item.museum_image
                    }
                  });
                })
              }
            })
          }
          .width('100%')
          .layoutWeight(1)
          .padding(16)
        }
      } else {
        Text(this.message)
          .fontSize(16)
          .fontColor('#666666')
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 20 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
} 