import router from '@ohos.router';

// 定义路由参数类型
interface RouterParams {
  item?: string;
}

// 定义文物项类型
interface AntiqueItem {
  id: number;
  name: string;
  image: string | string[];
  category: string;
  video?: string;
  description?: string;
}

@Component
export default struct AntiqueDetail {
  private item: AntiqueItem = {
    id: 0,
    name: '',
    image: [],
    category: '',
    description: ''
  };

  private swiperController: SwiperController = new SwiperController();
  private videoController: VideoController = new VideoController();

  aboutToAppear() {
    const params = router.getParams() as RouterParams;
    if (params?.item) {
      this.item = JSON.parse(params.item) as AntiqueItem;
    }
  }

  build() {
    Scroll() {
      Column() {
        // 图片/视频滑动区
        Swiper(this.swiperController) {
          // 处理图片（单张或多张）
          if (Array.isArray(this.item.image)) {
            ForEach(this.item.image, (img: string) => {
              Image(img)
                .width('100%')
                .aspectRatio(1.5)
                .objectFit(ImageFit.Cover);
            });
          } else {
            Image(this.item.image)
              .width('100%')
              .aspectRatio(1.5)
              .objectFit(ImageFit.Cover);
          }

          // 处理视频
          if (this.item.video) {
            Video({
              src: this.item.video,
              controller: this.videoController
            })
              .width('100%')
              .aspectRatio(1.5)
              .controls(true);
          }
        }
        .height('40%')
        .margin({ bottom: 20 })

        // 文物信息区
        Column() {
          // 文物标题
          Text(this.item.name)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .margin({ bottom: 10 });

          // 文物介绍
          Text(this.item.description || '暂无详细介绍')
            .fontSize(16)
            .textAlign(TextAlign.Start);
        }
        .width('100%')
        .padding(16)
      }
      .width('100%')
    }
    .scrollable(ScrollDirection.Vertical)
  }
}