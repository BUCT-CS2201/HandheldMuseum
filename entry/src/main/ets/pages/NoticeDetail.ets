import router from '@ohos.router';
import { BusinessError } from '@ohos.base';
import { notice } from '../common/types';

@Entry
@Component
struct NoticeDetail {
  @State notice: notice = (router.getParams() as Record<string, notice>).notice;

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
        Text('公告详情')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 16 })
      }
      .width('100%')
      .height(56)
      .backgroundColor('#FFFFFF')

      // 内容区域
      Column() {
        // 标题
        Text(this.notice.notice_title)
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .width('100%')
          .textAlign(TextAlign.Start)
          .padding({ left: 16, right: 16, top: 16 })

        // 作者和时间
        Row() {
          Text(this.notice.notice_author)
            .fontSize(16)
            .fontColor('#666666')
          Text(new Date(this.notice.notice_time).toLocaleDateString())
            .fontSize(16)
            .fontColor('#666666')
            .margin({ left: 16 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })

        // 分隔线
        Divider()
          .color('#EEEEEE')
          .width('100%')
          .margin({ top: 8, bottom: 8 })

        // 正文内容
        Text(this.notice.notice_content)
          .fontSize(20)
          .lineHeight(10)
          .width('100%')
          .textAlign(TextAlign.Start)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#F5F5F5')
    }
    .width('100%')
    .height('100%')
  }
}