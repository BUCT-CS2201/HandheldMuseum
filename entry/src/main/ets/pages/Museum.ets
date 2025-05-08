import http from '@ohos.net.http';
import router from '@ohos.router';
import { BusinessError } from '@ohos.base';
import { notice } from '../common/types';

@Entry
@Component
export default struct Museum {
  @State message: string = 'Hello World';
  @State notices: Array<notice> = [];

  aboutToAppear() {
    let httpRequest = http.createHttp();

    httpRequest.request(
      'http://localhost:3000/api/museum/list',
      {
        method: http.RequestMethod.GET,
      },
      (err: BusinessError<void> | undefined, data: http.HttpResponse) => {
        if (!err) {
          try {
            let result: Array<notice> = [];
            if (typeof data.result === 'string') {
              result = JSON.parse(data.result) as Array<notice>;
            } else if (Array.isArray(data.result)) {
              result = data.result as Array<notice>;
            } else if (typeof data.result === 'object' && data.result !== null) {
              result = [data.result as notice];
            }
            this.notices = result;
            this.message = '公告加载成功';
          } catch (e) {
            this.message = '数据解析失败';
            console.error('解析异常:', JSON.stringify(e));
          }
        } else {
          this.message = '公告获取失败';
          console.error(JSON.stringify(err));
        }
        httpRequest.destroy();
      }
    );
  }

  build() {
    Column() {
      Text(this.message)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 20 })

      Image($r('app.media.notice_sbk'))
        .width('100%')
        .height('100%')
        .position({ x: 0, y: 0 })
        .objectFit(ImageFit.Cover)
        .opacity(0.3)  // 设置透明度，使背景不会影响文字可读性

      Button() {
        Column() {
          Image($r('app.media.museum_information'))
            .width(32)
            .height(32)
            .margin({ bottom: 8 })
          Text('博物馆信息')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#333333')
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
      .width(80)
      .height(80)
      .backgroundColor('transparent')
      .borderRadius(8)
      .margin({ bottom: 20 })
      .onClick(() => {
        router.pushUrl({
          url: 'pages/MuseumInfo'
        });
      })

      Text("公告")
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .textAlign(TextAlign.Start)
      List() {
        ForEach(this.notices, (item: notice) => {
          ListItem() {
            Column() {
              Text(item.notice_title)
                .fontSize(30)
                .fontWeight(FontWeight.Medium)
                .width('100%')
                .textAlign(TextAlign.Start)

              // 作者和时间信息放在同一行
              Row() {
                Text(item.notice_author)
                  .fontSize(20)
                  .fontColor('#666666')  // 使用灰色显示作者
                Blank()  // 添加空白占位，将时间推到右边
                Text(new Date(item.notice_time).toLocaleDateString())  // 添加时间
                  .fontSize(20)
                  .fontColor('#666666')  // 使用灰色显示时间
                  .margin({ left: 16 })  // 作者和时间之间的间距
              }
              .width('100%')
              .margin({ bottom: 10 })
            }
            .width('100%')
            .backgroundColor('#FFFFFF')
            .borderRadius(8)
            .padding(16)
            .alignItems(HorizontalAlign.Start)
            .opacity(0.8)
            .shadow({
              radius: 6,
              color: '#1A000000',
              offsetX: 2,
              offsetY: 4
            })
            .onClick(() => {
              router.pushUrl({
                url: 'pages/NoticeDetail',
                params: {
                  notice: item
                }
              });
            })
          }
        }, (item: notice) => item.notice_id.toString())
      }
      .width('100%')
      .layoutWeight(1)
    }
    .height('100%')
    .width('100%')
    .padding(20)
    .backgroundColor('#F5F5F5')
  }
}