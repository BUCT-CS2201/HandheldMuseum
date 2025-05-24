import http from '@ohos.net.http';
import router from '@ohos.router';
import { BusinessError } from '@ohos.base';
import { notice } from '../common/types';

@Entry
@Component
export default struct Museum {
  @State message: string = 'Hello World';
  @State notices: Array<notice> = [];
  @State currentIndex: number = 0;
  private swiperController: SwiperController = new SwiperController();
  private readonly swiperImages: Resource[] = [
    $r('app.media.museum_banner1'),
    $r('app.media.museum_banner2'),
    $r('app.media.museum_banner3')
  ];

  aboutToAppear() {
    let httpRequest = http.createHttp();

    httpRequest.request(
      'http://10.4.11.183:3000/api/museum/list',
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
            // 在前端处理每个公告的 notice_content
            result.forEach(notice => {
              // 按段落分割 notice_content
              notice.content = notice.notice_content.split('\r\n'); // 按换行符分割
              notice.content.push(" ") ;
              notice.content.push(" ") ;
            });
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
      // 轮播图组件
      Swiper(this.swiperController) {
        ForEach(this.swiperImages, (image: Resource) => {
          Image(image)
            .width('100%')
            .height(200)
            .objectFit(ImageFit.Cover)
            .borderRadius(16)
        })
      }
      .width('100%')
      .height(200)
      .margin({ top: 0, bottom: 0 })
      .autoPlay(true)
      .interval(5000)
      .indicator(true)
      .loop(true)
      .backgroundColor('#F5E6D3')
      .shadow({
        radius: 6,
        color: '#1A000000',
        offsetX: 0,
        offsetY: 2
      })
      .onChange((index: number) => {
        this.currentIndex = index;
      })

      // 带背景的内容区域
      Stack() {
        // 背景图片
        Image($r('app.media.notice_sbk'))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .opacity(0.3)

        // 主要内容
        Column() {
          Row() {
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

            Button() {
              Column() {
                Image($r('app.media.museum_sort'))
                  .width(32)
                  .height(32)
                  .margin({ bottom: 8 })
                Text('博物馆排行')
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
                url: 'pages/MuseumRanking'
              });
            })
          }
          .width('150%')
          .justifyContent(FlexAlign.SpaceEvenly)
          .padding({ left: 20, right: 20 })
          .margin({ top: 0 })
          .backgroundColor('#F5E6D3')
          .shadow({
            radius: 6,
            color: '#1A000000',
            offsetX: 0,
            offsetY: 2
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

                  Row() {
                    Text(item.notice_author)
                      .fontSize(20)
                      .fontColor('#666666')
                    Blank()
                    Text(new Date(item.notice_time).toLocaleDateString())
                      .fontSize(20)
                      .fontColor('#666666')
                      .margin({ left: 16 })
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
        .padding({ left: 20, right: 20, bottom: 20 })
      }
      .layoutWeight(1)
    }
    .height('100%')
    .width('100%')
    .backgroundColor('#F5F5F5')
    .margin(0)
  }
}