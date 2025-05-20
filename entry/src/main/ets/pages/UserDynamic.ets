// DynamicPage.ets
import router from '@ohos.router';
import http from '@ohos.net.http';
import { ImageItem, CommentItem, DynamicItem, APIDynamicResponse, APICommentItem } from '../common/types/DynamicTypes';
import EventHub from '../common/utils/EventHub';
import { UserStore } from '../common/UserStore';
import preferences from '@ohos.data.preferences';
import prompt from '@ohos.prompt';

// 本地图片存储配置
const LOCAL_IMAGE_BASE = 'file:///data/storage/el2/base/cache/uploads/';
const BACKEND_IMAGE_BASE = 'http://10.4.52.124:3000/uploads/DynamicUploads/';

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
  @State currentUserId: number = 0;
  @State currentUsername: string = '';
  @State showCommentInput: boolean = false;
  @State expandedReplies: Set<number> = new Set();
  private userPreferences: preferences.Preferences | null = null;

  async aboutToAppear() {
    await this.initPreferences();
    if (this.showComments) {
      this.loadComments();
    }
  }

  async initPreferences() {
    try {
      this.userPreferences = await preferences.getPreferences(getContext(), 'userInfo');
      const userId = await this.userPreferences.get('userId', 0) as number;
      const username = await this.userPreferences.get('username', '') as string;
      this.currentUserId = userId;
      this.currentUsername = username;
    } catch (error) {
      console.error('初始化偏好设置失败:', error);
    }
  }

  showToast(message: string) {
    prompt.showToast({ message: message });
  }

  async checkLogin(): Promise<boolean> {
    if (!this.currentUserId) {
      this.showToast('请先登录');
      router.pushUrl({ url: 'pages/Login' });
      return false;
    }
    return true;
  }

  async loadComments() {
    if (!this.showComments) return;

    this.loadingComments = true;
    try {
      console.log('开始加载评论，动态ID:', this.item.id);
      let httpRequest = http.createHttp();
      let response = await httpRequest.request(
        `http://10.4.52.124:3000/api/dynamic/comments/${this.item.id}`,
        {
          method: http.RequestMethod.GET,
          header: {
            'Content-Type': 'application/json'
          }
        }
      );

      console.log('评论API响应状态码:', response.responseCode);
      console.log('评论API响应数据:', response.result);

      if (response.responseCode === 200) {
        const commentsData: APICommentItem[] = JSON.parse(response.result as string);
        console.log('解析后的评论数据:', commentsData);

        // 直接使用后端返回的评论树结构
        const rootComments = commentsData.map(c => {
          console.log('处理评论项:', c);
          const comment = new CommentItem(
            c.comment_id,
            c.username,
            c.content,
            c.create_time,
            c.parent_id,
            c.reply_count
          );

          // 递归处理子评论
          if (c.replies && c.replies.length > 0) {
            comment.replies = c.replies.map(reply => {
              const replyComment = new CommentItem(
                reply.comment_id,
                reply.username,
                reply.content,
                reply.create_time,
                reply.parent_id,
                reply.reply_count
              );
              // 递归处理更深层级的回复
              if (reply.replies && reply.replies.length > 0) {
                replyComment.replies = reply.replies.map(subReply => {
                  return new CommentItem(
                    subReply.comment_id,
                    subReply.username,
                    subReply.content,
                    subReply.create_time,
                    subReply.parent_id,
                    subReply.reply_count
                  );
                });
              } else {
                replyComment.replies = [];
              }
              return replyComment;
            });
          } else {
            comment.replies = [];
          }

          console.log('创建评论对象:', comment);
          return comment;
        });

        console.log('最终构建的评论树:', rootComments);
        this.comments = rootComments;

        // 强制更新视图
        this.comments = [...this.comments];
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
    console.log('submitComment 被调用');
    
    if (!await this.checkLogin()) {
      console.log('用户未登录，退出评论提交');
      return;
    }
    
    if (!this.commentText.trim()) {
      console.log('评论内容为空，退出评论提交');
      return;
    }

    try {
      console.log('开始提交评论，参数:', {
        dynamic_id: this.item.id,
        user_id: this.currentUserId,
        content: this.commentText,
        parent_id: this.replyToId
      });

      let httpRequest = http.createHttp();
      let response = await httpRequest.request(
        "http://10.4.52.124:3000/api/dynamic/comment",
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

      console.log('评论提交响应:', {
        statusCode: response.responseCode,
        responseBody: response.result
      });

      if (response.responseCode === 200) {
        const result: CommentResponse = JSON.parse(response.result as string);
        console.log('评论提交成功，返回数据:', result);

        // 重新加载评论列表
        await this.loadComments();

        this.commentText = '';
        this.replyTo = '';
        this.replyToId = undefined;
        this.showCommentInput = false;
        this.showToast('评论成功');
      } else {
        const errorData: ErrorResponse = JSON.parse(response.result as string);
        console.error('评论提交失败:', errorData);
        this.showToast('发表评论失败: ' + errorData.error);
      }
    } catch (error) {
      console.error('发表评论失败:', error);
      this.showToast('发表评论失败');
    }
  }

  async deleteComment(commentId: number) {
    try {
      let httpRequest = http.createHttp();
      let response = await httpRequest.request(
        `http://10.4.52.124:3000/api/dynamic/comment/${commentId}`,
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

  @Builder
  renderComment(comment: CommentItem, level: number = 0) {
    Column() {
      // 主体评论内容
      Row() {
        Image($r('app.media.default_avatar'))
          .width(level === 0 ? 32 : 24)
          .height(level === 0 ? 32 : 24)
          .borderRadius(level === 0 ? 16 : 12)
          .margin({ right: 8 })

        Column() {
          Row() {
            Text(comment.user)
              .fontColor('#007AFF')
              .fontSize(level === 0 ? 14 : 12)
              .fontWeight(FontWeight.Medium)

            Text(comment.content)
              .fontColor('#333333')
              .fontSize(level === 0 ? 14 : 12)
              .margin({ left: 4 })
              .layoutWeight(1)
          }
          .width('100%')

          Row() {
            Text(comment.time)
              .fontSize(level === 0 ? 12 : 10)
              .fontColor('#999999')

            if (comment.reply_count > 0) {
              Text(`${comment.reply_count}条回复`)
                .fontSize(level === 0 ? 12 : 10)
                .fontColor('#007AFF')
                .margin({ left: 16 })
                .onClick(() => {
                  console.log('点击了X条回复', comment.id, 'expandedReplies:', this.expandedReplies);
                  console.log('当前评论的replies:', comment.replies);
                  if (this.expandedReplies.has(comment.id)) {
                    const newSet = new Set(this.expandedReplies);
                    newSet.delete(comment.id);
                    this.expandedReplies = newSet;
                    console.log('收起评论，新的expandedReplies:', this.expandedReplies);
                  } else {
                    this.expandedReplies = new Set(this.expandedReplies).add(comment.id);
                    console.log('展开评论，新的expandedReplies:', this.expandedReplies);
                  }
                  // 强制更新视图
                  this.comments = [...this.comments];
                })
            }

            Text('回复')
              .fontSize(level === 0 ? 12 : 10)
              .fontColor('#007AFF')
              .margin({ left: 16 })
              .onClick(async () => {
                if (!await this.checkLogin()) return;
                if (this.replyToId === comment.id) {
                  this.replyTo = '';
                  this.replyToId = undefined;
                  this.showCommentInput = false;
                } else {
                  this.replyTo = comment.user;
                  this.replyToId = comment.id;
                  this.showCommentInput = true;
                }
              })

            if (comment.user === this.currentUsername) {
              Text('删除')
                .fontSize(level === 0 ? 12 : 10)
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
      .padding({ left: level === 0 ? 16 : 12, right: 16, top: 12, bottom: 12 })
      .backgroundColor(level === 0 ? '#F8F8F8' : '#F0F0F0')
      .borderRadius(level === 0 ? 8 : 6)
      .margin({ bottom: 8 })

      // 子评论递归渲染
      if (comment.replies && comment.replies.length > 0) {
        Column() {
          if (this.expandedReplies.has(comment.id)) {
            ForEach(comment.replies, (reply: CommentItem) => {
              this.renderComment(reply, level + 1)
            }, (reply: CommentItem) => reply.id.toString())
          }
        }
        .margin({ left: 28 })
        .animation({
          duration: 300,
          curve: Curve.EaseInOut
        })
        .opacity(this.expandedReplies.has(comment.id) ? 1 : 0)
        .height(this.expandedReplies.has(comment.id) ? 'auto' : 0)
        .visibility(this.expandedReplies.has(comment.id) ? Visibility.Visible : Visibility.None)
      }
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
          .onClick(async () => {

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
                  this.renderComment(comment, 0)
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
            .onClick(async () => {
              if (!await this.checkLogin()) return;
              if (this.showCommentInput) {
                this.showCommentInput = false;
                this.replyTo = '';
                this.replyToId = undefined;
              } else {
                this.showCommentInput = true;
                this.replyTo = '';
                this.replyToId = undefined;
              }
            })
            .margin({ bottom: 16 })

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
                      console.log('评论内容变化:', value);
                      this.commentText = value;
                    })
                    .onSubmit(() => {
                      console.log('触发表单提交');
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
                    .onClick(() => {
                      console.log('点击发送按钮，当前评论内容:', this.commentText);
                      this.submitComment();
                    })
                }
                .width('100%')
                .padding({ left: 12, right: 12, bottom: 8 })
              }
              .width('100%')
              .backgroundColor('#F5F5F5')
              .padding({ top: 8, bottom: 12 })
            }
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
  private userPreferences: preferences.Preferences | null = null;
  @State currentUserId: number = 0;

  async aboutToAppear() {
    await this.initPreferences();
    this.loadData();
    EventHub.on('dynamic:like', this.handleLike.bind(this));
  }

  async initPreferences() {
    try {
      this.userPreferences = await preferences.getPreferences(getContext(), 'userInfo');
      const userId = await this.userPreferences.get('userId', 0) as number;
      this.currentUserId = userId;
    } catch (error) {
      console.error('初始化偏好设置失败:', error);
    }
  }

  showToast(message: string) {
    prompt.showToast({ message: message });
  }

  async checkLogin(): Promise<boolean> {
    if (!this.currentUserId) {
      this.showToast('请先登录');
      router.pushUrl({ url: 'pages/Login' });
      return false;
    }
    return true;
  }

  async loadData(): Promise<void> {
    let httpRequest = http.createHttp();
    try {
      console.log('开始加载动态数据');

      let response = await httpRequest.request(
        "http://10.4.52.124:3000/api/dynamic/list",
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
        "http://10.4.52.124:3000/api/dynamic/like",
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
            .onClick(async () => {
               if (!await this.checkLogin()) return;
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
            .padding({ bottom: 72 }) // 增加底部padding，为导航栏预留空间
            .listDirection(Axis.Vertical)
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