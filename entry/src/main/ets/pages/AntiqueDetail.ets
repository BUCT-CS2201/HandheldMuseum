import http from '@ohos.net.http';
import router from '@ohos.router';

// 定义路由参数类型
interface RouterParams {
  id?: string | number;
}

// 定义文物详情类型
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
  images: string[];  // 明确为字符串数组
  videos: string[];  // 明确为字符串数组
}

// 定义更灵活的服务器响应类型
interface AntiqueResponse {
  relic_id?: number;
  name?: string;
  type?: string;
  size?: string;
  materials?: string;
  matrials?: string; // 兼容可能的拼写错误
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
    const url = `http://192.168.198.1:3000/api/antique/detail/${id}`;
    console.log('请求的URL:', url);

    httpRequest.request(
      url,
      {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.OBJECT
      },
      (err, data) => {
        if (err) {
          console.error('请求失败:', err);
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
            console.warn('返回格式异常，既不是字符串也不是对象:', typeof data.result);
          }

          console.log('解析后的数据对象:', parsed);

          // 处理 images 字段
          let images: string[] = [];
          if (typeof parsed.images === 'string') {
            images = parsed.images.split(',').map(item => item.trim()).filter(item => item !== '');
          } else if (Array.isArray(parsed.images)) {
            images = parsed.images.filter((item: string) => typeof item === 'string');
          }

          // 处理 videos 字段
          let videos: string[] = [];
          if (typeof parsed.videos === 'string') {
            videos = parsed.videos.split(',').map(item => item.trim()).filter(item => item !== '');
          } else if (Array.isArray(parsed.videos)) {
            videos = parsed.videos.filter((item: string) => typeof item === 'string');
          }

          // 打印每一个字段以确认是否成功赋值
          console.log('字段详情:');
          console.log('relic_id:', parsed.relic_id);
          console.log('name:', parsed.name);
          console.log('type:', parsed.type);
          console.log('size:', parsed.size);
          console.log('materials:', parsed.materials || parsed.matrials);
          console.log('dynasty:', parsed.dynasty);
          console.log('author:', parsed.author);
          console.log('entry_time:', parsed.entry_time);
          console.log('description:', parsed.description);
          console.log('images:', images);
          console.log('videos:', videos);

          // 更新状态
          this.antique = {
            relic_id: parsed.relic_id || 0,
            name: parsed.name || '',
            type: parsed.type || '',
            size: parsed.size || '',
            materials: parsed.materials || parsed.matrials || '',
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
            router.back();  // 返回上一页
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
          // 图片展示区域
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

          // 视频展示区域
          if (this.antique.videos.length > 0) {
            Text('视频')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .margin({ top: 16, left: 16, bottom: 6 });

            Scroll() {
              Row() {
                ForEach(this.antique.videos, (video: string) => {
                  Video({
                    src: video
                  })
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

          // 文物详细信息
          Column() {
            Text(this.antique.name)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .margin({ top: 20, bottom: 12 });

            this.infoText('类型', this.antique.type);
            this.infoText('尺寸', this.antique.size);
            this.infoText('材料', this.antique.materials);
            this.infoText('朝代', this.antique.dynasty);
            this.infoText('作者', this.antique.author);
            this.infoText('入藏时间', this.antique.entry_time);

            Text('文物简介')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .margin({ top: 16, bottom: 8 });

            Text(this.antique.description)
              .fontSize(14)
              .lineHeight(22)
              .fontColor('#444444');
          }
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .margin({ top: 12, bottom: 30, left: 12, right: 12 });
        }
      }
      .backgroundColor('#F5F5F5');
    }
  }

  @Builder
  infoText(label: string, value: string) {
    Row() {
      Text(`${label}：`)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .width(80);

      Text(value || '未知')
        .fontSize(14)
        .fontColor('#666666');
    }
    .margin({ bottom: 6 });
  }
}
