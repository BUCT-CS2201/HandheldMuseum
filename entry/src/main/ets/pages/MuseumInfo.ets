import http from '@ohos.net.http';
import router from '@ohos.router';
import { BusinessError } from '@ohos.base';

interface museumInfo {
  museum_id: number;
  museum_name: string;
  museum_image: string;
}

@Entry
@Component
struct MuseumInfo {
  @State museums: Array<museumInfo> = [];
  @State message: string = '加载中...';

  aboutToAppear() {
    this.fetchMuseumData();
  }

  fetchMuseumData() {
    let httpRequest = http.createHttp();
    httpRequest.request(
      'http://10.4.100.140:3000/api/museum/info',
      {
        method: http.RequestMethod.GET,
      },
      (err: BusinessError<void> | undefined, data: http.HttpResponse) => {
        if (!err) {
          try {
            let result: Array<museumInfo> = [];
            if (typeof data.result === 'string') {
              result = JSON.parse(data.result) as Array<museumInfo>;
            } else if (Array.isArray(data.result)) {
              result = data.result as Array<museumInfo>;
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
        Text('博物馆信息')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 16 })
      }
      .width('100%')
      .height(56)
      .backgroundColor('#FFFFFF')

      // 博物馆列表
      List() {
        ForEach(this.museums, (item: museumInfo) => {
          ListItem() {
            Row() {
              Image(item.museum_image)
                .width(120)
                .height(120)
                .objectFit(ImageFit.Cover)
                .borderRadius(8)
                .alt($r('app.media.image_error'))
                .onError(() => {
                  console.error('图片加载失败:', item.museum_image);
                })

              Column() {
                Text(item.museum_name)
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .width('100%')
                  .textAlign(TextAlign.Start)
                  .margin({ bottom: 8 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              .justifyContent(FlexAlign.Center)
              .margin({ left: 16 })
            }
            .width('100%')
            .backgroundColor('#FFFFFF')
            .borderRadius(8)
            .padding(16)
            .margin({ bottom: 16 })
            .shadow({
              radius: 6,
              color: '#1A000000',
              offsetX: 2,
              offsetY: 4
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
        }, (item: museumInfo) => item.museum_id.toString())
      }
      .width('100%')
      .layoutWeight(1)
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
} 