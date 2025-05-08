import http from '@ohos.net.http';
import router from '@ohos.router';

// 路由参数类型
interface RouterParams {
  id?: number;
}

// 文物详情类型
interface AntiqueDetailItem {
  relic_id: number;
  name: string;
  type: string;
  size: string;
  materials: string;
  dynasty: string;
  author: string;
  entry_time: string;
  description: string;
  images: string[];
  videos: string[];
}

// 接口返回类型（数据库字段为 matrials）
interface AntiqueResponse {
  relic_id?: number;
  name?: string;
  type?: string;
  size?: string;
  matrials?: string;
  dynasty?: string;
  author?: string;
  entry_time?: string;
  description?: string;
  images?: string | string[];
  videos?: string | string[];
}

@Entry
@Component
struct AntiqueDetail {
  @State antique: AntiqueDetailItem = {
    relic_id: 0,
    name: '',
    type: '',
    size: '',
    materials: '',
    dynasty: '',
    author: '',
    entry_time: '',
    description: '',
    images: [],
    videos: []
  }

  aboutToAppear() {
    const params = router.getParams() as RouterParams;
    const relicId: number = params?.id ? parseInt(params.id.toString()) : 0;
    if (relicId > 0) {
      this.fetchAntiqueDetail(relicId);
    }
  }

  fetchAntiqueDetail(id: number): void {
    const httpRequest = http.createHttp();
    const url = `http://10.4.72.189:3000/api/antique/detail/${id}`;
    console.log('请求的URL:', url);

    httpRequest.request(
      url,
      {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.OBJECT
      },
      (err, data) => {
        if (err) {
          console.error('请求失败:', err?.code, err?.message, JSON.stringify(err));
          return;
        }

        console.log('请求返回的原始数据:', data);

        let parsed: AntiqueResponse = {};
        try {
          if (typeof data.result === 'string') {
            parsed = JSON.parse(data.result);
          } else if (typeof data.result === 'object') {
            parsed = data.result as AntiqueResponse;
          } else {
            console.warn('返回格式异常:', typeof data.result);
          }

          // 处理 images
          let images: string[] = [];
          if (typeof parsed.images === 'string') {
            images = parsed.images.split(',').map(item => item.trim()).filter(item => item !== '');
          } else if (Array.isArray(parsed.images)) {
            images = parsed.images.filter((item: string) => typeof item === 'string');
          }

          // 处理 videos
          let videos: string[] = [];
          if (typeof parsed.videos === 'string') {
            videos = parsed.videos.split(',').map(item => item.trim()).filter(item => item !== '');
          } else if (Array.isArray(parsed.videos)) {
            videos = parsed.videos.filter((item: string) => typeof item === 'string');
          }

          // 打印字段
          console.log('字段详情:');
          console.log('relic_id:', parsed.relic_id);
          console.log('name:', parsed.name);
          console.log('type:', parsed.type);
          console.log('size:', parsed.size);
          console.log('materials:', parsed.matrials);
          console.log('dynasty:', parsed.dynasty);
          console.log('author:', parsed.author);
          console.log('entry_time:', parsed.entry_time);
          console.log('description:', parsed.description);
          console.log('images:', images);
          console.log('videos:', videos);

          this.antique = {
            relic_id: typeof parsed.relic_id === 'number' ? parsed.relic_id : 0,
            name: parsed.name || '',
            type: parsed.type || '',
            size: parsed.size || '',
            materials: parsed.matrials || '',
            dynasty: parsed.dynasty || '',
            author: parsed.author || '',
            entry_time: parsed.entry_time || '',
            description: parsed.description || '',
            images: images,
            videos: videos
          };
        } catch (e) {
          console.error('解析JSON失败:', e);
        }
      }
    );
  }

  build() {
    Column() {
      // 返回按钮
      Row() {
        Button('返回')
          .onClick(() => {
            router.back();
          })
          .width(80)
          .height(40)
          .backgroundColor('#DAA520')
          .borderRadius(8)
          .fontSize(16)
          .fontColor('#FFFFFF')
      }
      .margin({ top: 20, left: 20, bottom: 10 })

      Scroll() {
        Column() {
          // 图片区域
          if (this.antique.images.length > 0) {
            Text('图片')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .margin({ top: 16, left: 16, bottom: 6 });

            Scroll() {
              Row() {
                ForEach(this.antique.images, (img: string) => {
                  Image(img)
                    .width(250)
                    .height(180)
                    .margin({ left: 10, right: 10 })
                    .objectFit(ImageFit.Cover)
                    .borderRadius(10);
                }, (img: string) => img);
              }
              .padding({ bottom: 8 });
            }
            .scrollable(ScrollDirection.Horizontal)
            .width('100%');
          }

          // 视频区域
          if (this.antique.videos.length > 0) {
            Text('视频')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .margin({ top: 16, left: 16, bottom: 6 });

            Scroll() {
              Row() {
                ForEach(this.antique.videos, (video: string) => {
                  Video({ src: video })
                    .width(250)
                    .height(180)
                    .margin({ left: 10, right: 10 })
                    .borderRadius(10)
                    .muted(true)
                    .autoPlay(false)
                    .controls(true);
                }, (video: string) => video);
              }
              .padding({ bottom: 8 });
            }
            .scrollable(ScrollDirection.Horizontal)
            .width('100%');
          }

          // 信息区
          Column() {
            // 文物名称（居中显示）
            Text(this.antique.name)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .margin({ top: 20, bottom: 16 })
              .width('100%')
              .textAlign(TextAlign.Center)

            // 信息项容器（白色卡片）
            Column() {
              // 类型
              Row() {
                Text('类型：')
                  .fontSize(14)
                  .width(90)
                  .textAlign(TextAlign.End)
                Text(this.antique.type || '未知类型')
                  .fontSize(14)
                  .fontColor('#666666')
                  .flexGrow(1)
                  .textAlign(TextAlign.Start)
              }
              .margin({ bottom: 10 })
              .width('100%')

              // 尺寸
              Row() {
                Text('尺寸：')
                  .fontSize(14)
                  .width(90)
                  .textAlign(TextAlign.End)
                Text(this.antique.size || '未知尺寸')
                  .fontSize(14)
                  .fontColor('#666666')
                  .flexGrow(1)
                  .textAlign(TextAlign.Start)
              }
              .margin({ bottom: 10 })
              .width('100%')

              // 材料
              Row() {
                Text('材料：')
                  .fontSize(14)
                  .width(90)
                  .textAlign(TextAlign.End)
                Text(this.antique.materials || '未知材料')
                  .fontSize(14)
                  .fontColor('#666666')
                  .flexGrow(1)
                  .textAlign(TextAlign.Start)
              }
              .margin({ bottom: 10 })
              .width('100%')

              // 朝代
              Row() {
                Text('朝代：')
                  .fontSize(14)
                  .width(90)
                  .textAlign(TextAlign.End)
                Text(this.antique.dynasty || '未知朝代')
                  .fontSize(14)
                  .fontColor('#666666')
                  .flexGrow(1)
                  .textAlign(TextAlign.Start)
              }
              .margin({ bottom: 10 })
              .width('100%')

              // 作者
              Row() {
                Text('作者：')
                  .fontSize(14)
                  .width(90)
                  .textAlign(TextAlign.End)
                Text(this.antique.author || '未知作者')
                  .fontSize(14)
                  .fontColor('#666666')
                  .flexGrow(1)
                  .textAlign(TextAlign.Start)
              }
              .margin({ bottom: 10 })
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .margin({ bottom: 16, left: 12, right: 12 })

            // 文物简介
            Column() {
              Text('文物简介')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .margin({ bottom: 8 })
                .width('100%')

              Text(this.antique.description || '暂无描述信息')
                .fontSize(14)
                .lineHeight(22)
                .fontColor('#444444')
                .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
          }
          .width('100%')
          .padding(12)
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .margin({ top: 12, bottom: 30, left: 12, right: 12 });
        }
      }
      .backgroundColor('#F5F5F5');
    }
  }
}
