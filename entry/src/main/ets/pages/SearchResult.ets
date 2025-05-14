import http from '@ohos.net.http';
import router from '@ohos.router';
import type { BusinessError } from '@ohos.base';

interface AntiqueItem {
  id: number;
  name: string;
  image: string;
  category: string;
}

@Entry
@Component
struct SearchResult {
  @State similarAntiques: Array<AntiqueItem> = [];
  @State isLoading: boolean = true;
  @State errorMessage: string = '';

  aboutToAppear() {
    // 从路由参数中获取相似文物的ID列表
    const params = router.getParams() as Record<string, Array<number>>;
    const similarIds = params['similarIds'];
    if (similarIds && similarIds.length > 0) {
      this.fetchAntiqueDetails(similarIds);
    } else {
      this.errorMessage = '未找到相似文物';
      this.isLoading = false;
    }
  }

  async fetchAntiqueDetails(ids: Array<number>) {
    try {
      let httpRequest = http.createHttp();
      const response = await httpRequest.request(
        'http://10.4.59.196:3000/api/antique/list',
        { method: http.RequestMethod.GET }
      );

      if (response.responseCode === 200 && typeof response.result === 'string') {
        const allAntiques: Array<AntiqueItem> = JSON.parse(response.result);
        // 过滤出相似文物的详细信息
        this.similarAntiques = allAntiques.filter(antique => ids.includes(antique.id));
      } else {
        this.errorMessage = '获取文物详情失败';
      }
    } catch (error) {
      console.error('请求失败:', error);
      this.errorMessage = '网络请求失败';
    } finally {
      this.isLoading = false;
    }
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
        Text('相似文物')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 16 })
      }
      .width('100%')
      .height(56)
      .backgroundColor('#FFFFFF')

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(50)
            .height(50)
          Text('正在搜索相似文物...')
            .fontSize(16)
            .margin({ top: 16 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.errorMessage) {
        Column() {
          Text(this.errorMessage)
            .fontSize(16)
            .fontColor('#666666')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
            ForEach(this.similarAntiques, (item: AntiqueItem) => {
              Column() {
                Image(item.image)
                  .width('100%')
                  .aspectRatio(1)
                  .objectFit(ImageFit.Cover)
                  .borderRadius(10)

                Text(item.name)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .margin({ top: 6, bottom: 6 })
              }
              .width('48%')
              .padding(10)
              .backgroundColor('#FFFFFF')
              .borderRadius(10)
              .shadow({ radius: 3, color: '#cccccc', offsetX: 0, offsetY: 2 })
              .onClick(() => {
                router.pushUrl({
                  url: 'pages/AntiqueDetail',
                  params: { id: item.id.toString() }
                }).catch((err: BusinessError) => {
                  console.error(`跳转失败: ${err.message}`);
                });
              })
            }, (item: AntiqueItem) => item.id.toString())
          }
          .width('100%')
          .padding(16)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F8FA')
  }
} 