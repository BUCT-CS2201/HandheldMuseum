import router from '@ohos.router';
import http from '@ohos.net.http';
import { BusinessError } from '@ohos.base';
import common from '@ohos.app.ability.common';
import pasteboard from '@ohos.pasteboard';
import prompt from '@ohos.prompt';

interface MuseumDetailInfo {
  museum_id: number;
  museum_name: string;
  description: string;
  address: string;
  website_url: string;
  booking_url: string;
}

interface RouteParams {
  museumId: number;
  museumImage: string;
}

interface RelicInfo {
  relic_id: number;
  relic_name: string;
  relic_image: string;
}

class RelicDataSource implements IDataSource {
  private relics: RelicInfo[] = [];
  private listeners: DataChangeListener[] = [];

  constructor(relics: RelicInfo[]) {
    this.relics = relics;
  }

  totalCount(): number {
    return this.relics.length;
  }

  getData(index: number): RelicInfo {
    return this.relics[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index = this.listeners.indexOf(listener);
    if (index >= 0) {
      this.listeners.splice(index, 1);
    }
  }

  notifyDataChange(index: number): void {
    for (let listener of this.listeners) {
      listener.onDataChanged(index);
    }
  }

  notifyDataAdd(index: number): void {
    for (let listener of this.listeners) {
      listener.onDataAdded(index);
    }
  }

  notifyDataDelete(index: number): void {
    for (let listener of this.listeners) {
      listener.onDataDeleted(index);
    }
  }

  notifyDataReload(): void {
    for (let listener of this.listeners) {
      listener.onDataReloaded();
    }
  }
}

interface Mywant {
  "action": string;
  "entities": string[];
  "uri": string;
  "type": string;
}

@Entry
@Component
struct MuseumDetail {
  @State museumInfo: MuseumDetailInfo | null = null;
  @State message: string = '加载中...';
  @State museumImage: string = '';
  @State relics: RelicInfo[] = [];

  aboutToAppear() {
    const params = router.getParams() as RouteParams;
    if (params) {
      if (params.museumImage) {
        this.museumImage = params.museumImage;
      }
      if (params.museumId) {
        this.fetchMuseumDetail(params.museumId);
        this.fetchMuseumRelics(params.museumId);
      }
    }
  }

  fetchMuseumDetail(museumId: number) {
    let httpRequest = http.createHttp();
    httpRequest.request(
      `http://10.4.100.140:3000/api/museum/detail/${museumId}`,
      {
        method: http.RequestMethod.GET,
      },
      (err: BusinessError<void> | undefined, data: http.HttpResponse) => {
        if (!err) {
          try {
            let result: MuseumDetailInfo;
            if (typeof data.result === 'string') {
              result = JSON.parse(data.result) as MuseumDetailInfo;
            } else {
              result = data.result as MuseumDetailInfo;
            }
            this.museumInfo = result;
            this.message = '加载成功';
          } catch (e) {
            this.message = '数据解析失败';
            console.error('解析异常:', JSON.stringify(e));
            console.error('返回数据:', JSON.stringify(data.result));
          }
        } else {
          this.message = '获取数据失败';
          console.error(JSON.stringify(err));
        }
        httpRequest.destroy();
      }
    );
  }

  fetchMuseumRelics(museumId: number) {
    let httpRequest = http.createHttp();
    httpRequest.request(
      `http://10.4.100.140:3000/api/museum/relics/${museumId}`,
      {
        method: http.RequestMethod.GET,
      },
      (err: BusinessError<void> | undefined, data: http.HttpResponse) => {
        if (!err) {
          try {
            let result: RelicInfo[] = [];
            if (typeof data.result === 'string') {
              result = JSON.parse(data.result) as RelicInfo[];
            } else if (Array.isArray(data.result)) {
              result = data.result as RelicInfo[];
            }
            this.relics = result;
          } catch (e) {
            console.error('解析异常:', JSON.stringify(e));
          }
        } else {
          console.error(JSON.stringify(err));
        }
        httpRequest.destroy();
      }
    );
  }

  showToast(message: string) {
    let toastMessage = message;
    setTimeout(() => {
      prompt.showToast({ message: toastMessage });
    }, 0);
  }

  async implicitStartAbility( url : string ) {
    // 获取系统剪贴板对象
    let text = url ;
    // 创建一条纯文本类型的剪贴板内容对象
    let pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    // 将数据写入系统剪贴板
    let systemPasteboard = pasteboard.getSystemPasteboard();
    await systemPasteboard.setData(pasteData);
    this.showToast('已复制到粘贴板');

    try {
      let want: Mywant = {
        "action": "ohos.want.action.viewData",
        "entities": [ "entity.system.browsable" ],
        "uri": url,
        "type": "text/plain"
      }
      let context = getContext(this) as common.UIAbilityContext;
      await context.startAbility(want)
      console.info(`explicit start ability succeed`)
    } catch (error) {
      console.info(`explicit start ability failed with ${error.code}`)
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
        Text('博物馆详情')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 16 })
      }
      .width('100%')
      .height(56)
      .backgroundColor('#FFFFFF')

      if (this.museumInfo) {
        Scroll() {
          Column() {
            // 顶部大图
            Image(this.museumImage)
              .width('100%')
              .height(250)
              .objectFit(ImageFit.Cover)
              .alt($r('app.media.background'))
              .onError(() => {
                console.error('图片加载失败:', this.museumImage);
              })

            // 博物馆信息卡片
            Column() {
              // 博物馆名称
              Text(this.museumInfo.museum_name)
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .width('100%')
                .margin({ bottom: 16 })

              // 博物馆地址
              if (this.museumInfo.address) {
                Row() {
                  Image($r('app.media.location'))
                    .width(20)
                    .height(20)
                    .margin({ right: 8 })
                  Text(this.museumInfo.address)
                    .fontSize(16)
                    .fontColor('#666666')
                }
                .width('100%')
                .margin({ bottom: 12 })
              }

              // 博物馆官网
              if (this.museumInfo.website_url) {
                Row() {
                  Image($r('app.media.website'))
                    .width(20)
                    .height(20)
                    .margin({ right: 8 })
                  Text(this.museumInfo.website_url)
                    .fontSize(16)
                    .fontColor('#4A90E2')
                    .onClick(() => {
                      // 处理网址点击
                      if( !this.museumInfo ) return ;
                      this.implicitStartAbility( this.museumInfo.website_url ) ;
                    })
                }
                .width('100%')
                .margin({ bottom: 12 })
              }

              // 博物馆描述
              if (this.museumInfo.description) {
                Text('博物馆介绍')
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .width('100%')
                  .margin({ top: 16, bottom: 8 })
                Text(this.museumInfo.description)
                  .fontSize(16)
                  .fontColor('#333333')
                  .width('100%')
                  .margin({ bottom: 16 })
              }

              // 预约链接
              if (this.museumInfo.booking_url) {
                Row() {
                  Image($r('app.media.booking'))
                    .width(20)
                    .height(20)
                    .margin({ right: 8 })
                  Text('预约参观')
                    .fontSize(16)
                    .fontColor('#4A90E2')
                    .onClick(() => {
                      // 处理预约链接点击
                      if( !this.museumInfo ) return ;
                      this.implicitStartAbility( this.museumInfo.booking_url) ;
                    })
                }
                .width('100%')
                .margin({ top: 16 })
              }
            }
            .width('100%')
            .padding(20)
            .backgroundColor('#FFFFFF')
            .borderRadius(16)
            .margin({ top: -20 })

            // 藏品展示
            if (this.relics.length > 0) {
              Column() {
                Text('馆藏精品')
                  .fontSize(20)
                  .fontWeight(FontWeight.Medium)
                  .width('100%')
                  .margin({ top: 20, bottom: 16 })

                List({space:5}) {
                  LazyForEach(new RelicDataSource(this.relics), (item: RelicInfo) => {
                    ListItem() {
                      Column() {
                        Image(item.relic_image)
                          .width(120)
                          .height(120)
                          .objectFit(ImageFit.Contain)
                          .borderRadius(8)
                          .alt($r('app.media.image_error'))
                          .onError(() => {
                            console.error('图片加载失败:', item.relic_image);
                          })
                        Text(item.relic_name)
                          .fontSize(14)
                          .fontColor('#333333')
                          .width(120)
                          .textAlign(TextAlign.Center)
                          .margin({ top: 8 })
                      }
                      .width(120)
                      .onClick(() => {
                        router.pushUrl({
                          url: 'pages/AntiqueDetail',
                          params: { id: item.relic_id.toString() }
                        }).catch((err: BusinessError) => {
                          console.error(`跳转失败: ${err.message}`)
                        })
                      })
                    }
                  }, (item: RelicInfo): string => item.relic_id.toString())
                }
                .width('100%')
                .padding({ bottom: 20 })
                .listDirection(Axis.Horizontal)
                .cachedCount(5)
              }
              .width('100%')
              .backgroundColor('#FFFFFF')
              .borderRadius(16)
              .margin({ top: 16 })
            }
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
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