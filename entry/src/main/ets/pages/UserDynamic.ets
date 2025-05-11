// DynamicPage.ets
import router from '@ohos.router';
import http from '@ohos.net.http';
import { ImageItem, CommentItem, DynamicItem, APIDynamicResponse, APICommentItem } from '../common/types/DynamicTypes';
import EventHub from '../common/utils/EventHub';

// 本地图片存储配置
const LOCAL_IMAGE_BASE = 'file:///data/storage/el2/base/cache/uploads/';
const BACKEND_IMAGE_BASE = 'http://localhost:3000/uploads/';

@Component
struct DynamicItemComponent {
  @Prop item: DynamicItem;
  @State isLiked: boolean = false;
  @State showComments: boolean = false;

  build() {
    Column() {
      Column() {
        // 用户信息
        Row() {
          Image(this.item.avatar)
            .width(48)
            .height(48)
            .borderRadius(24)
            .margin({ right: 12 })
          Column() {
            Text(this.item.username)
              .fontSize(16)
            Text(this.item.time)
              .fontSize(12)
              .fontColor('#999999')
          }
        }

        // 动态内容
        Text(this.item.content)
          .margin({ top: 12, bottom: 12 })

        // 图片展示
        if (this.item.images.length > 0) {
          Grid() {
            ForEach(this.item.images, (imgPath: string) => {
              GridItem() {
                Image(imgPath)
                  .width('100%')
                  .aspectRatio(1)
                  .objectFit(ImageFit.Cover)
                  .borderRadius(8)
                  .onError(() => {
                    console.error('图片加载失败:', imgPath);
                  })
              }
            })
          }
          .columnsTemplate('1fr 1fr')
          .rowsGap(8)
        }

        // 互动按钮
        Row() {
          Button(this.isLiked ? `已赞 ${this.item.likes}` : `点赞 ${this.item.likes}`)
            .onClick(() => {
              this.isLiked = !this.isLiked;
              // 触发点赞事件
              EventHub.emit('dynamic:like', this.item);
            })
          Button(`评论 ${this.item.comments.length}`)
            .margin({ left: 16 })
            .onClick(() => {
              this.showComments = !this.showComments;
              // 触发显示评论事件
              EventHub.emit('dynamic:showComments', this.item);
            })
        }
        .margin({ top: 12 })

        // 评论列表
        if (this.showComments) {
          Column() {
            ForEach(this.item.comments, (comment: CommentItem) => {
              Column() {
                Row() {
                  Text(comment.user)
                    .fontColor('#007AFF')
                  Text(comment.content)
                    .margin({ left: 8 })
                }
                Text(comment.time)
                  .fontSize(12)
                  .fontColor('#999999')
              }
              .padding(8)
              .backgroundColor('#F8F8F8')
              .borderRadius(8)
              .margin({ top: 8 })
            })
          }
          .margin({ top: 12 })
        }

        if (this.item.comments.length > 0 && !this.showComments) {
          Text(`查看全部${this.item.comments.length}条评论`)
            .fontColor('#007AFF')
            .onClick(() => {
              this.showComments = true;
              // 触发显示评论事件
              EventHub.emit('dynamic:showComments', this.item);
            })
        }
      }
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .shadow({ radius: 6, color: '#10000000' })
    }
  }
}

@Entry
@Component
struct UserDynamic {
  @StorageLink('dynamics') dynamics: DynamicItem[] = [];
  @State loading: boolean = true;
  @State errorMessage: string = '';
  @State refreshing: boolean = false;

  aboutToAppear() {
    this.loadData();
    // 注册事件监听
    EventHub.on('dynamic:like', this.handleLike.bind(this));
    EventHub.on('dynamic:showComments', this.showComments.bind(this));
  }

  aboutToDisappear() {
    // 移除事件监听
    EventHub.off('dynamic:like', this.handleLike.bind(this));
    EventHub.off('dynamic:showComments', this.showComments.bind(this));
  }

  async loadData(): Promise<void> {
    let httpRequest = http.createHttp();
    try {
      console.log('开始加载动态数据');

      let response = await httpRequest.request(
        "http://localhost:3000/api/dynamic/list",
        {
          method: http.RequestMethod.GET,
          header: {
            'Content-Type': 'application/json'
          }
        }
      );

      console.log('收到响应:', response.responseCode);
      if (response.responseCode === 200) {
        const responseData = JSON.parse(response.result as string) as APIDynamicResponse[];
        console.log('解析后的数据:', responseData);

        if (!Array.isArray(responseData)) {
          console.error('返回数据不是数组:', responseData);
          throw new Error('返回数据格式错误');
        }

        const dynamics = responseData.map(item => {
          console.log('处理动态项:', item);
          return new DynamicItem(
            item.dynamic_id,
            item.username,
            item.content,
            item.create_time,
            item.like_count,
            this.processImages(item.images || []),
            this.processComments(item.comments || [])
          );
        });

        console.log('处理后的动态列表:', dynamics);
        AppStorage.setOrCreate('dynamics', dynamics);
        this.loading = false;
        this.refreshing = false;
      } else {
        console.error('请求失败，状态码:', response.responseCode);
        let errorMessage = '请求失败';
        switch (response.responseCode) {
          case 404:
            errorMessage = '接口不存在，请检查API地址';
            break;
          case 500:
            errorMessage = '服务器内部错误';
            break;
          default:
            errorMessage = `请求失败: ${response.responseCode}`;
        }
        throw new Error(errorMessage);
      }
    } catch (error) {
      console.error('数据加载失败:', error);
      this.errorMessage = error.message || '数据加载失败，下拉重试';
      this.loading = false;
      this.refreshing = false;
    } finally {
      // 释放HTTP请求
      httpRequest.destroy();
    }
  }

  private async handleLike(item: DynamicItem): Promise<void> {
    let originalLikes: number = item.likes;
    let originalIsLiked: boolean = item.isLiked;

    try {
      const index = this.dynamics.findIndex(d => d.id === item.id);
      if (index === -1) return;

      const updatedItem = new DynamicItem(
        item.id,
        item.username,
        item.content,
        item.time,
        item.isLiked ? item.likes - 1 : item.likes + 1,
        item.images,
        item.comments,
        !item.isLiked,
        item.avatar,
        item.showComments
      );

      this.dynamics.splice(index, 1, updatedItem);

      let httpRequest = http.createHttp();
      let response = await httpRequest.request(
        "http://your-api-domain/api/like",
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json'
          },
          extraData: JSON.stringify({
            dynamic_id: item.id,
            action: item.isLiked ? 'unlike' : 'like'
          })
        }
      );

      if (response.responseCode === 200) {
        interface LikeResponse {
          newLikeCount: number;
          isLiked: boolean;
        }
        const result: LikeResponse = JSON.parse(response.result as string) as LikeResponse;
        const finalItem = new DynamicItem(
          item.id,
          item.username,
          item.content,
          item.time,
          result.newLikeCount,
          item.images,
          item.comments,
          result.isLiked,
          item.avatar,
          item.showComments
        );

        this.dynamics.splice(index, 1, finalItem);
      } else {
        throw new Error('点赞操作失败');
      }
    } catch (error) {
      console.error('点赞操作失败:', error);
      const index = this.dynamics.findIndex(d => d.id === item.id);
      if (index === -1) return;

      const rollbackItem = new DynamicItem(
        item.id,
        item.username,
        item.content,
        item.time,
        originalLikes,
        item.images,
        item.comments,
        originalIsLiked,
        item.avatar,
        item.showComments
      );

      this.dynamics.splice(index, 1, rollbackItem);
      this.errorMessage = '操作失败，请检查网络';
      setTimeout(() => this.errorMessage = '', 2000);
    }
  }

  private showComments(item: DynamicItem): void {
    const index = this.dynamics.findIndex(d => d.id === item.id);
    if (index === -1) return;

    const updatedItem = new DynamicItem(
      item.id,
      item.username,
      item.content,
      item.time,
      item.likes,
      item.images,
      item.comments,
      item.isLiked,
      item.avatar,
      !item.showComments
    );

    this.dynamics.splice(index, 1, updatedItem);
  }

  private processImages(images: ImageItem[]): string[] {
    console.log('开始处理图片数据:', images);
    if (!Array.isArray(images)) {
      console.log('返回空数组');
      return [];
    }
    return images.map(img => {
      console.log(`处理图片: image_id=${img.image_id}, suffix=${img.suffix}`);
      if (img?.status === 1) {
        const suffix = img.suffix.startsWith('.') ? img.suffix.slice(1) : img.suffix;
        const imageUrl = `${BACKEND_IMAGE_BASE}${img.image_id}.${suffix}`;
        console.log(`生成图片URL: ${imageUrl}`);
        return imageUrl;
      }
      console.log('返回占位图');
      return $r('app.media.image_pending').toString();
    });
  }

  private processComments(comments: APICommentItem[]): CommentItem[] {
    if (!Array.isArray(comments)) {
      return [];
    }
    return comments.map(c =>
    new CommentItem(c.comment_id, c.username, c.content, c.create_time)
    );
  }

  build() {
    Column() {
      Row() {
        Text('用户动态')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)

        Button('+ 发布')
          .width(100)
          .height(56)
          .fontColor('#FFFFFF')
          .backgroundColor('#007AFF')
          .onClick(() => {
            router.pushUrl({ url: 'pages/DynamicPublish' });
          })
      }
      .padding(16)

      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(60)
            .height(60)
          Text('加载中...')
            .margin({ top: 16 })
        }
        .justifyContent(FlexAlign.Center)
      } else if (this.errorMessage) {
        Column() {
          Image($r('app.media.ic_error'))
            .width(120)
            .height(120)
          Text(this.errorMessage)
            .margin({ top: 16 })
          Button('重试')
            .margin({ top: 16 })
            .onClick(() => this.loadData())
        }
        .justifyContent(FlexAlign.Center)
      } else {
        Refresh({ refreshing: $$this.refreshing }) {
          List({ space: 12 }) {
            ForEach(this.dynamics, (item: DynamicItem) => {
              ListItem() {
                DynamicItemComponent({ item: item })
              }
            })
          }
        }
        .onRefreshing(() => {
          this.refreshing = true;
          this.loadData();
        })
      }
    }
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}

export default UserDynamic;