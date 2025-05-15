// DynamicPage.ets
import router from '@ohos.router';
import http from '@ohos.net.http';
import { ImageItem, CommentItem, DynamicItem, APIDynamicResponse, APICommentItem } from '../common/types/DynamicTypes';
import EventHub from '../common/utils/EventHub';

// 本地图片存储配置
const LOCAL_IMAGE_BASE = 'file:///data/storage/el2/base/cache/uploads/';
const BACKEND_IMAGE_BASE = 'http://localhost:3000/uploads/';

// 在文件开头的import语句后添加接口定义
interface LikeResponse {
  newLikeCount: number;
  isLiked: boolean;
}

interface CommentCountResponse {
  total_count: number;
}

interface CommentResponse {
  comment_id: number;
  message: string;
}

interface ErrorResponse {
  error: string;
}

@Component
struct DynamicItemComponent {
  @Prop item: DynamicItem;
  @State isLiked: boolean = false;
  @State showComments: boolean = false;
  @State commentText: string = '';
  @State showFullImage: boolean = false;
  @State selectedImage: string = '';
  @State comments: CommentItem[] = [];
  @State replyTo: string = '';
  @State replyToId: number | undefined = undefined;
  @State loadingComments: boolean = false;
  @State currentUserId: number = 1; // TODO: 从用户状态获取
  @State currentUsername: string = '当前用户'; // TODO: 从用户状态获取
  @State showCommentInput: boolean = false;

  aboutToAppear() {
    if (this.showComments) {
      this.loadComments();
    }
  }

  async loadComments() {
    if (!this.showComments) return;

    this.loadingComments = true;
    try {
      let httpRequest = http.createHttp();
      let response = await httpRequest.request(
        `http://localhost:3000/api/dynamic/comments/${this.item.id}`,
        {
          method: http.RequestMethod.GET,
          header: {
            'Content-Type': 'application/json'
          }
        }
      );

      if (response.responseCode === 200) {
        const commentsData: APICommentItem[] = JSON.parse(response.result as string);
        // 处理评论数据，构建评论树
        const commentMap = new Map<number, CommentItem>();
        const rootComments: CommentItem[] = [];

        // 首先创建所有评论对象
        commentsData.forEach(c => {
          const comment = new CommentItem(
            c.comment_id,
            c.username,
            c.content,
            c.create_time,
            c.parent_id,
            c.reply_count
          );
          commentMap.set(c.comment_id, comment);
        });

        // 构建评论树
        commentsData.forEach(c => {
          const comment = commentMap.get(c.comment_id);
          if (!comment) return; // 跳过不存在的评论

          if (c.parent_id === this.item.id) {
            // 这是对动态的评论
            rootComments.push(comment);
          } else if (c.parent_id) {
            // 这是对评论的回复
            const parentComment = commentMap.get(c.parent_id);
            if (parentComment) {
              parentComment.replies.push(comment);
            }
          }
        });

        // 按时间排序
        rootComments.sort((a, b) => new Date(a.time).getTime() - new Date(b.time).getTime());
        rootComments.forEach(comment => {
          comment.replies.sort((a, b) => new Date(a.time).getTime() - new Date(b.time).getTime());
        });

        this.comments = rootComments;
      } else {
        const errorData: ErrorResponse = JSON.parse(response.result as string);
        console.error('加载评论失败:', errorData.error);
      }
    } catch (error) {
      console.error('加载评论失败:', error instanceof Error ? error.message : '未知错误');
    } finally {
      this.loadingComments = false;
    }
  }

  async submitComment() {
    if (!this.commentText.trim()) return;

    try {
      let httpRequest = http.createHttp();
      let response = await httpRequest.request(
        "http://localhost:3000/api/dynamic/comment",
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json'
          },
          extraData: JSON.stringify({
            dynamic_id: this.item.id,
            user_id: this.currentUserId,
            content: this.commentText,
            parent_id: this.replyToId
          })
        }
      );

      if (response.responseCode === 200) {
        const result: CommentResponse = JSON.parse(response.result as string);
        // 添加新评论
        const newComment = new CommentItem(
          result.comment_id,
          this.currentUsername,
          this.commentText,
          new Date().toISOString(),
          this.replyToId,
          0
        );

        if (this.replyToId) {
          // 如果是回复，找到父评论并添加回复
          const parentComment = this.comments.find(c => c.id === this.replyToId);
          if (parentComment) {
            parentComment.replies.push(newComment);
            parentComment.reply_count++;
          }
        } else {
          // 如果是新评论，添加到根评论列表
          this.comments.push(newComment);
        }
        
        this.commentText = '';
        this.replyTo = '';
        this.replyToId = undefined;
        this.showCommentInput = false;
      } else {
        const errorData: ErrorResponse = JSON.parse(response.result as string);
        console.error('发表评论失败:', errorData.error);
      }
    } catch (error) {
      console.error('发表评论失败:', error instanceof Error ? error.message : '未知错误');
    }
  }

  async deleteComment(commentId: number) {
    try {
      let httpRequest = http.createHttp();
      let response = await httpRequest.request(
        `http://localhost:3000/api/dynamic/comment/${commentId}`,
        {
          method: http.RequestMethod.DELETE,
          header: {
            'Content-Type': 'application/json'
          },
          extraData: JSON.stringify({
            user_id: this.currentUserId
          })
        }
      );

      if (response.responseCode === 200) {
        await this.loadComments();
      }
    } catch (error) {
      console.error('删除评论失败:', error);
    }
  }

  build() {
    Column() {
      // 卡片容器
      Column() {
        // 用户信息
        Row() {
          Image(this.item.avatar)
            .width(56)
            .height(56)
            .borderRadius(28)
            .margin({ right: 16 })
            .shadow({ radius: 4, color: '#20000000', offsetX: 0, offsetY: 2 })

          Column() {
            Text(this.item.username)
              .fontSize(18)
              .fontColor('#333333')
              .fontWeight(FontWeight.Medium)
              .margin({ bottom: 4 })

            Text(this.item.time)
              .fontSize(14)
              .fontColor('#999999')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 16, bottom: 16 })

        // 动态内容
        Text(this.item.content)
          .fontSize(16)
          .fontColor('#333333')
          .lineHeight(24)
          .margin({ bottom: 16 })
          .width('100%')

        // 图片展示
        if (this.item.images && this.item.images.length > 0) {
          Grid() {
            ForEach(this.item.images, (imgPath: string) => {
              GridItem() {
                Image(imgPath)
                  .width('100%')
                  .aspectRatio(1)
                  .objectFit(ImageFit.Cover)
                  .borderRadius(12)
                  .onClick(() => {
                    this.selectedImage = imgPath;
                    this.showFullImage = true;
                  })
              }
            })
          }
          .columnsTemplate('1fr 1fr 1fr')
          .rowsGap(8)
          .columnsGap(8)
          .margin({ bottom: 16 })
        }

        // 互动按钮
        Row() {
          // 点赞按钮
          Button({ type: ButtonType.Normal }) {
            Row() {
              Image($r('app.media.ic_like'))
                .width(24)
                .height(24)
                .fillColor(this.isLiked ? '#FF3A30' : '#666666')
                .margin({ right: 6 })

              Text(this.item.likes.toString())
                .fontSize(16)
                .fontColor(this.isLiked ? '#FF3A30' : '#666666')
            }
          }
          .onClick(() => {
            this.isLiked = !this.isLiked;
            EventHub.emit('dynamic:like', this.item);
          })
          .backgroundColor(Color.Transparent)
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .borderRadius(20)
          .margin({ right: 24 })

          // 评论按钮
          Button({ type: ButtonType.Normal }) {
            Row() {
              Image($r('app.media.ic_comment'))
                .width(24)
                .height(24)
                .fillColor('#666666')
                .margin({ right: 6 })

              Text(`评论 ${this.item.reply_count}`)
                .fontSize(16)
                .fontColor('#666666')
            }
          }
          .onClick(() => {
            this.showComments = !this.showComments;
            if (this.showComments) {
              this.loadComments();
            }
          })
          .backgroundColor(Color.Transparent)
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .borderRadius(20)
        }
        .margin({ bottom: 16 })

        // 评论列表
        if (this.showComments) {
          Column() {
            if (this.loadingComments) {
              LoadingProgress()
                .width(24)
                .height(24)
                .margin({ top: 16, bottom: 16 })
            } else if (this.comments.length === 0) {
              Text('暂无评论')
                .fontSize(14)
                .fontColor('#999999')
                .margin({ top: 16, bottom: 16 })
            } else {
              Column() {
                ForEach(this.comments, (comment: CommentItem) => {
                  Column() {
                    // 主评论
                    Row() {
                      Image($r('app.media.default_avatar'))
                        .width(32)
                        .height(32)
                        .borderRadius(16)
                        .margin({ right: 8 })

                      Column() {
                        Row() {
                          Text(comment.user)
                            .fontColor('#007AFF')
                            .fontSize(14)
                            .fontWeight(FontWeight.Medium)

                          Text(comment.content)
                            .fontColor('#333333')
                            .fontSize(14)
                            .margin({ left: 4 })
                            .layoutWeight(1)
                        }
                        .width('100%')

                        Row() {
                          Text(comment.time)
                            .fontSize(12)
                            .fontColor('#999999')

                          if (comment.reply_count > 0) {
                            Text(`${comment.reply_count}条回复`)
                              .fontSize(12)
                              .fontColor('#007AFF')
                              .margin({ left: 16 })
                              .onClick(() => {
                                this.replyTo = comment.user;
                                this.replyToId = comment.id;
                                this.showCommentInput = true;
                              })
                          }

                          Text('回复')
                            .fontSize(12)
                            .fontColor('#007AFF')
                            .margin({ left: 16 })
                            .onClick(() => {
                              this.replyTo = comment.user;
                              this.replyToId = comment.id;
                              this.showCommentInput = true;
                            })

                          if (comment.user === this.currentUsername) {
                            Text('删除')
                              .fontSize(12)
                              .fontColor('#FF3A30')
                              .margin({ left: 16 })
                              .onClick(() => {
                                this.deleteComment(comment.id);
                              })
                          }
                        }
                        .margin({ top: 4 })
                      }
                      .layoutWeight(1)
                    }
                    .width('100%')
                    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                    .backgroundColor('#F8F8F8')
                    .borderRadius(8)
                    .margin({ bottom: 8 })

                    // 回复列表
                    if (comment.replies && comment.replies.length > 0) {
                      Column() {
                        ForEach(comment.replies, (reply: CommentItem) => {
                          Row() {
                            Image($r('app.media.default_avatar'))
                              .width(24)
                              .height(24)
                              .borderRadius(12)
                              .margin({ right: 8 })

                            Column() {
                              Row() {
                                Text(reply.user)
                                  .fontColor('#007AFF')
                                  .fontSize(12)
                                  .fontWeight(FontWeight.Medium)

                                Text(reply.content)
                                  .fontColor('#333333')
                                  .fontSize(12)
                                  .margin({ left: 4 })
                                  .layoutWeight(1)
                              }
                              .width('100%')

                              Row() {
                                Text(reply.time)
                                  .fontSize(10)
                                  .fontColor('#999999')

                                Text('回复')
                                  .fontSize(10)
                                  .fontColor('#007AFF')
                                  .margin({ left: 16 })
                                  .onClick(() => {
                                    this.replyTo = reply.user;
                                    this.replyToId = reply.id;
                                    this.showCommentInput = true;
                                  })

                                if (reply.user === this.currentUsername) {
                                  Text('删除')
                                    .fontSize(10)
                                    .fontColor('#FF3A30')
                                    .margin({ left: 16 })
                                    .onClick(() => {
                                      this.deleteComment(reply.id);
                                    })
                              }
                              }
                              .margin({ top: 2 })
                            }
                            .layoutWeight(1)
                          }
                          .width('100%')
                          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                          .backgroundColor('#F0F0F0')
                          .borderRadius(6)
                          .margin({ bottom: 4 })
                        })
                      }
                      .margin({ left: 40 })
                    }
                  }
                })
              }
              .width('100%')
              .animation({
                duration: 300,
                curve: Curve.EaseInOut
              })
            }

            // 添加评论按钮
            Button({ type: ButtonType.Normal }) {
              Row() {
                Image($r('app.media.ic_comment'))
                  .width(20)
                  .height(20)
                  .fillColor('#666666')
                  .margin({ right: 8 })

                Text('添加评论...')
                  .fontSize(14)
                  .fontColor('#666666')
              }
            }
            .width('100%')
            .height(40)
            .backgroundColor('#F0F0F0')
            .borderRadius(20)
            .onClick(() => {
              this.replyTo = '';
              this.replyToId = undefined;
              this.showCommentInput = true;
            })
          }
          .margin({ top: 8 })
          .animation({
            duration: 300,
            curve: Curve.EaseInOut
          })
        }
      }
      .padding({ left: 20, right: 20 })
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
      .shadow({ radius: 12, color: '#10000000', offsetX: 0, offsetY: 4 })

      // 评论输入框
      if (this.showCommentInput) {
        Column() {
          if (this.replyTo) {
            Row() {
              Text(`回复 ${this.replyTo}:`)
                .fontSize(14)
                .fontColor('#666666')
                .margin({ left: 12, bottom: 8 })
            }
            .width('100%')
          }

          Row() {
            TextInput({
              placeholder: this.replyTo ? `回复 ${this.replyTo}...` : '添加评论...',
              text: this.commentText
            })
              .height(40)
              .layoutWeight(1)
              .fontSize(16)
              .backgroundColor('#FFFFFF')
              .padding(8)
              .borderRadius(20)
              .onChange((value: string) => {
                this.commentText = value;
              })
              .onSubmit(() => {
                this.submitComment();
              })

            Button('发送')
              .width(60)
              .height(40)
              .fontSize(14)
              .fontColor('#FFFFFF')
              .backgroundColor(this.commentText.trim() ? '#007AFF' : '#CCCCCC')
              .borderRadius(20)
              .margin({ left: 8 })
              .enabled(this.commentText.trim().length > 0)
              .onClick(() => this.submitComment())
          }
          .width('100%')
          .padding({ left: 12, right: 12, bottom: 8 })
        }
        .width('100%')
        .backgroundColor('#F5F5F5')
        .padding({ top: 8, bottom: 12 })
        .position({ x: 0, y: 0 })
        .zIndex(10000)
      }

      // 全屏图片预览
      if (this.showFullImage) {
        Stack({ alignContent: Alignment.Center }) {
          // 半透明黑色遮罩
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#000000')
            .opacity(0.9)
            .onClick(() => {
              this.showFullImage = false;
            })
            .zIndex(9999)

          // 图片展示容器
          Swiper() {
            ForEach(this.item.images, (imgPath: string) => {
              Image(imgPath)
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Contain)
                .onClick(() => {
                  this.showFullImage = false;
                })
            })
          }
          .indicator(false)
          .loop(false)
          .width('100%')
          .height('80%')
          .zIndex(10000)
        }
      }
    }
    .padding(12)
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
    EventHub.on('dynamic:like', this.handleLike.bind(this));
  }

  aboutToDisappear() {
    EventHub.off('dynamic:like', this.handleLike.bind(this));
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
            this.processComments(item.comments || []),
            false,
            $r("app.media.default_avatar"),
            false,
            item.reply_count
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

      // 先更新UI状态
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

      // 调用后端API
      let httpRequest = http.createHttp();
      console.log('发送点赞请求:', {
        dynamic_id: item.id,
        action: item.isLiked ? 'unlike' : 'like'
      });

      let response = await httpRequest.request(
        "http://localhost:3000/api/dynamic/like",
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

      console.log('收到点赞响应:', {
        statusCode: response.responseCode,
        responseBody: response.result
      });

      if (response.responseCode === 200) {
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
        throw new Error(`点赞操作失败: ${response.responseCode} - ${response.result}`);
      }
    } catch (error) {
      console.error('点赞操作失败:', error);
      const index = this.dynamics.findIndex(d => d.id === item.id);
      if (index === -1) return;

      // 发生错误时回滚UI状态
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
      this.errorMessage = `操作失败: ${error.message}`;
      setTimeout(() => this.errorMessage = '', 2000);
    }
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
    Stack({ alignContent: Alignment.Top }) {
      Column() {
        // 标题栏
        Row() {
          Text('用户动态')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)

          Button('+ 发布')
            .width(100)
            .height(56)
            .fontSize(18)
            .fontColor('#FFFFFF')
            .backgroundColor('#ff080809')
            .fontWeight(FontWeight.Bold)
            .borderRadius(28)
            .onClick(() => {
              router.pushUrl({ url: 'pages/DynamicPublish' });
            })
        }
        .padding(16)
        .width('100%')
        .backgroundColor('#FFFFFF')
        .shadow({ radius: 4, color: '#10000000', offsetX: 0, offsetY: 2 })

        if (this.loading) {
          Column() {
            LoadingProgress()
              .width(60)
              .height(60)
            Text('加载中...')
              .margin({ top: 16 })
              .fontSize(16)
              .fontColor('#666666')
          }
          .justifyContent(FlexAlign.Center)
          .layoutWeight(1)
        } else if (this.errorMessage) {
          Column() {
            Image($r('app.media.ic_error'))
              .width(120)
              .height(120)
            Text(this.errorMessage)
              .margin({ top: 16 })
              .fontSize(16)
              .fontColor('#666666')
            Button('重试')
              .margin({ top: 16 })
              .width(120)
              .height(40)
              .fontSize(16)
              .fontColor('#FFFFFF')
              .backgroundColor('#007AFF')
              .borderRadius(20)
              .onClick(() => this.loadData())
          }
          .justifyContent(FlexAlign.Center)
          .layoutWeight(1)
        } else {
          Refresh({ refreshing: $$this.refreshing }) {
            List({ space: 12 }) {
              ForEach(this.dynamics, (item: DynamicItem) => {
                ListItem() {
                  DynamicItemComponent({ item: item })
                }
              })
            }
            .width('100%')
            .layoutWeight(1)
            .scrollBar(BarState.Auto)
            .edgeEffect(EdgeEffect.Spring)
          }
          .onRefreshing(() => {
            this.refreshing = true;
            this.loadData();
          })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F5')
    }
    .width('100%')
    .height('100%')
  }
}

export default UserDynamic;