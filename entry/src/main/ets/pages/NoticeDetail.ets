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
      .backgroundColor('#F5E6D3')

      // 内容区域
      Column() {
        // 标题
        Text(this.notice.notice_title)
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .width('100%')
          .textAlign(TextAlign.Start)
          .padding({ left: 16, right: 16, top: 16 })
          .backgroundColor('#FAF3E9')

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
        .backgroundColor('#FAF3E9')

        // // 分隔线
        // Divider()
        //   .color('#000000')
        //   .width('100%')
        //   .margin({ top: 8, bottom: 8 })
        //   .backgroundColor('#FAF3E9')

        // 正文内容
        List() {
          ForEach(this.notice.content, (item: string) => {
            if (item.includes("https:")) {
              ListItem() {
                Image(item)
                  .width('100%') // 设置图片宽度为占满整个列表项
                  .margin({ top: 10, bottom: 10 }) // 设置图片的上下外边距
              }
              .backgroundColor('#FCF9F4'); // 设置 List 的背景颜色
            } else {
              ListItem() {
                Text("  " + item)
                  .fontSize(16) // 设置字体大小
                  .fontColor('#333333') // 设置字体颜色
                  .margin({ top: 10, bottom: 10 }) // 设置文本的上下外边距
              }
              .backgroundColor('#FCF9F4');
            }
          })
        }
        .width('100%') // 设置 List 的宽度
        .padding({ left: 16, right: 16, top: 10, bottom: 10 }) // 设置 List 的内边距
        .backgroundColor('#FCF9F4'); // 设置 List 的背景颜色
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#F5F5F5')
    }
    .width('100%')
    .height('100%')
  }
}