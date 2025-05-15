import http from '@ohos.net.http';
import router from '@ohos.router';
import prompt from '@ohos.prompt';
import common from '@ohos.app.ability.common';
import { UserStore } from '../common/UserStore';

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

// 评论类型
interface CommentItem {
  comment_id: number;
  content: string;
  like_count: number;
  reply_count: number;
  create_time: string;
  user_name: string;
  parent_id?: number;
  status: number;
  is_deleted: number;
}

interface CommentStatusResult {
  comment_status: number;
  name: string;
}

interface FetchResult {
  result: string | object;
}

interface RelicStatus {
  is_liked: boolean;
  is_favorited: boolean;
  like_count: number;
  favorite_count: number;
}

interface LikeCountResult {
  like_count: number;
}

// 评论树类型
class CommentTreeItem {
  comment: CommentItem;
  replies: CommentItem[];
  constructor(comment: CommentItem, replies: CommentItem[]) {
    this.comment = comment;
    this.replies = replies;
  }
}

@Entry
@Preview
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
  @State comments: CommentItem[] = [];
  @State commentTree: CommentTreeItem[] = [];
  @State commentContent: string = '';
  @State replyParentId: number | null = null;
  @State toastMessage: string = '';
  @State likeCount: number = 0;
  @State favoriteCount: number = 0;
  @State isLiked: boolean = false;
  @State isFavorited: boolean = false;

  aboutToAppear() {
    const params = router.getParams() as RouterParams;
    const relicId: number = params?.id ? parseInt(params.id.toString()) : 0;
    console.log('aboutToAppear被调用，relicId:', relicId);
    if (relicId > 0) {
      this.fetchAntiqueDetail(relicId);
      this.fetchComments(relicId);
      this.checkLikeAndFavoriteStatus();
    }
  }

  showToast(message: string) {
    this.toastMessage = message;
    setTimeout(() => {
      prompt.showToast({ message: this.toastMessage });
    }, 0);
  }

  fetchAntiqueDetail(id: number): void {
    const httpRequest = http.createHttp();
    const url = `http://localhost:3000/api/antique/detail/${id}`;
    console.log('请求的URL:', url);

    httpRequest.request(
      url,
      {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.OBJECT
      },
      (err: Error | undefined, data: FetchResult) => {
        if (err) {
          console.error('请求失败:', JSON.stringify(err));
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

  fetchComments(id: number): void {
    console.log('fetchComments被调用，id:', id);
    const httpRequest = http.createHttp();
    const url = `http://localhost:3000/api/antique/comments/${id}`;
    httpRequest.request(
      url,
      { method: http.RequestMethod.GET, expectDataType: http.HttpDataType.OBJECT },
      (err: Error | undefined, data: FetchResult) => {
        if (err) {
          console.error('请求评论失败:', JSON.stringify(err));
          return;
        }
        console.log('评论接口返回:', JSON.stringify(data.result));
        let commentArr: CommentItem[] = [];
        if (typeof data.result === 'string') {
          commentArr = JSON.parse(data.result) as CommentItem[];
        } else if (typeof data.result === 'object') {
          commentArr = data.result as CommentItem[];
        }
        // 只保留 status=1 且 is_deleted=0 的评论
        commentArr = commentArr.filter(c => c.status === 1 && c.is_deleted === 0);
        setTimeout(() => {
          this.comments = commentArr;
          // 构建评论树
          const topLevel = this.comments.filter((c: CommentItem) => c.parent_id == null || c.parent_id === 0);
          this.commentTree = topLevel.map((parent: CommentItem) => {
            return new CommentTreeItem(
              parent,
              this.comments.filter((c: CommentItem) => c.parent_id === parent.comment_id)
            );
          });
        }, 0);
      }
    );
  }

  submitComment(): void {
    const params = router.getParams() as RouterParams;
    const relicId: number = params?.id ? parseInt(params.id.toString()) : 0;
    const userId = UserStore.userId;

    if (!userId) {
      this.showToast('请先登录');
      return;
    }

    // 1. 先查评论状态
    const httpRequest = http.createHttp();
    httpRequest.request(
      `http://localhost:3000/api/user/comment_status/${userId}`,
      { method: http.RequestMethod.GET, expectDataType: http.HttpDataType.OBJECT },
      (err: Error | undefined, data: FetchResult) => {
        let resultObj: CommentStatusResult | null = null;
        if (err) {
          this.showToast('查询评论状态失败');
          return;
        }
        if (typeof data.result === 'string') {
          resultObj = JSON.parse(data.result) as CommentStatusResult;
        } else if (typeof data.result === 'object') {
          resultObj = data.result as CommentStatusResult;
        }
        if (!resultObj || resultObj.comment_status !== 1) {
          this.showToast('您已被禁止评论');
          return;
        }
        // 2. 允许评论，提交评论
        if (relicId > 0 && this.commentContent) {
          const httpRequest2 = http.createHttp();
          const url = `http://localhost:3000/api/antique/comments/${relicId}`;
          httpRequest2.request(
            url,
            {
              method: http.RequestMethod.POST,
              header: { 'Content-Type': 'application/json' },
              expectDataType: http.HttpDataType.OBJECT,
              extraData: JSON.stringify({
                user_id: userId,
                content: this.commentContent,
                parent_id: this.replyParentId || null
              })
            },
            (err2: Error | undefined, data2: FetchResult) => {
              if (err2) {
                this.showToast('提交评论失败');
                return;
              }
              this.showToast('评论已提交，审核通过后将显示');
              this.commentContent = '';
              this.replyParentId = null;
            }
          );
        }
      }
    );
  }

  likeComment(comment_id: number): void {
    const httpRequest = http.createHttp();
    const url = `http://localhost:3000/api/antique/comments/like/${comment_id}`;
    httpRequest.request(
      url,
      {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json'
        },
        expectDataType: http.HttpDataType.OBJECT,
        extraData: JSON.stringify({
          user_id: 1 // 这里需要替换为实际的用户ID
        })
      },
      (err: Error | undefined, data: FetchResult) => {
        if (err) {
          console.error('点赞评论失败:', JSON.stringify(err));
          return;
        }
        this.fetchComments(this.antique.relic_id);
      }
    );
  }

  likeAntique(): void {
    const params = router.getParams() as RouterParams;
    const relicId: number = params?.id ? parseInt(params.id.toString()) : 0;
    const userId = 1; // 替换为实际登录用户ID

    console.log('准备发送点赞请求，relicId:', relicId, 'userId:', userId);

    const httpRequest = http.createHttp();
    httpRequest.request(
      `http://localhost:3000/api/antique/like/${relicId}`,
      {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        expectDataType: http.HttpDataType.OBJECT,
        extraData: JSON.stringify({ user_id: userId })
      },
      (err: Error | undefined, data: FetchResult) => {
        if (err) {
          console.error('点赞请求失败:', JSON.stringify(err));
          this.showToast('点赞失败');
          return;
        }
        console.log('点赞接口返回原始数据:', JSON.stringify(data));
        let likeCount = 0;
        if (typeof data.result === 'string') {
          const parsed = JSON.parse(data.result) as LikeCountResult;
          likeCount = parsed.like_count;
        } else if (typeof data.result === 'object') {
          likeCount = (data.result as LikeCountResult).like_count;
        }
        console.log('点赞接口解析后 like_count:', likeCount);
        this.likeCount = likeCount;
        // 点赞后立即刷新状态，确保 isLiked 状态同步
        this.checkLikeAndFavoriteStatus();
      }
    );
  }

  favoriteAntique(): void {
    const params = router.getParams() as RouterParams;
    const relicId: number = params?.id ? parseInt(params.id.toString()) : 0;
    const userId = 1; // 替换为实际登录用户ID

    const httpRequest = http.createHttp();
    httpRequest.request(
      `http://localhost:3000/api/antique/favorite/${relicId}`,
      {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        expectDataType: http.HttpDataType.OBJECT,
        extraData: JSON.stringify({ user_id: userId })
      },
      (err: Error | undefined, data: FetchResult) => {
        if (err) {
          this.showToast('收藏失败');
          return;
        }
        if (typeof data.result === 'string') {
          const result: RelicStatus = JSON.parse(data.result as string);
          this.favoriteCount = result.favorite_count;
          this.isFavorited = !this.isFavorited;
          this.showToast(this.isFavorited ? '收藏成功' : '取消收藏成功');
        }
      }
    );
  }

  checkLikeAndFavoriteStatus(): void {
    const params = router.getParams() as RouterParams;
    const relicId: number = params?.id ? parseInt(params.id.toString()) : 0;
    const userId = 1; // 替换为实际登录用户ID

    const httpRequest = http.createHttp();
    httpRequest.request(
      `http://localhost:3000/api/antique/status/${relicId}?user_id=${userId}`,
      { method: http.RequestMethod.GET, expectDataType: http.HttpDataType.OBJECT },
      (err: Error | undefined, data: FetchResult) => {
        if (err) {
          console.error('获取状态失败:', err);
          return;
        }
        let result: RelicStatus;
        if (typeof data.result === 'string') {
          result = JSON.parse(data.result) as RelicStatus;
        } else if (typeof data.result === 'object') {
          result = data.result as RelicStatus;
        } else {
          console.error('接口返回格式异常:', data.result);
          return;
        }
        this.isLiked = result.is_liked;
        this.isFavorited = result.is_favorited;
        this.likeCount = result.like_count;
        this.favoriteCount = result.favorite_count;
        console.log('接口返回like_count:', result.like_count, '赋值后 this.likeCount:', this.likeCount);
      }
    );
  }

  build() {
    Stack() {
      Stack() {
          Column() {
            // 返回按钮
            Row() {
              Image($r('app.media.ic_back'))
                .width(24)
                .height(24)
                .margin({ left: 16 })
                .onClick(() => {
                  router.back();
                })
              Text('文物详情')
                .fontSize(20)
                .fontWeight(FontWeight.Medium)
                .margin({ left: 16 })
            }
            .width('100%')
            .height(56)
            .backgroundColor('#FFFFFF')

                Scroll() {
                  Column() {
                    // 图片和视频区域
                    if (this.antique.images.length > 0 || this.antique.videos.length > 0) {
                      Scroll() {
                        Row() {
                          // 显示所有图片
                          ForEach(this.antique.images, (img: string) => {
                            Image(img)
                              .width(250)
                              .height(180)
                              .margin({ left: 10, right: 10 })
                              .objectFit(ImageFit.Cover)
                              .borderRadius(10);
                          }, (img: string) => img);

                          // 显示所有视频
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
                        .padding({ bottom: 4 });
                      }
                      .scrollable(ScrollDirection.Horizontal)
                      .width('100%');
                    }

                    // 信息区
                    Column() {
                      // 文物名称（居中显示）
                      Text(this.antique.name)
                        .fontSize(20)
                        .fontWeight(FontWeight.Bold)
                        .margin({ top: 16, bottom: 12 })
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
                              .flexShrink(1)// 允许收缩
                              .textAlign(TextAlign.Start)
                              .margin({ left: 8 })
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
                              .flexShrink(1)// 允许收缩
                              .textAlign(TextAlign.Start)
                              .margin({ left: 8 })
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
                              .flexShrink(1)// 允许收缩
                              .textAlign(TextAlign.Start)
                              .margin({ left: 8 })
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
                              .flexShrink(1)// 允许收缩
                              .textAlign(TextAlign.Start)
                              .margin({ left: 8 })
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
                            .flexShrink(1)
                            .textAlign(TextAlign.Start)
                            .margin({ left: 8 })
                        }
                        .margin({ bottom: 10 })
                        .width('100%')
                      }
                      .width('100%')
                      .padding({
                        left: 12,
                        right: 16,
                        top: 16,
                        bottom: 16
                      })
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
                            .fontSize(12)
                            .lineHeight(20)
                            .fontColor('#444444')
                            .width('100%')
                        }
                        .width('100%')
                        .padding(12)
                        .backgroundColor('#FFFFFF')
                        .borderRadius(10)
                      }
                      .width('100%')
                      .padding(10)
                      .backgroundColor('#FFFFFF')
                      .borderRadius(10)
                      .margin({
                        top: 10,
                        bottom: 20,
                        left: 10,
                        right: 10
                      })

                      // 评论区域
                      Column() {
                        Text('评论')
                          .fontSize(16)
                          .fontWeight(FontWeight.Bold)
                          .margin({ top: 12, left: 12, bottom: 4 })

                        // 评论列表容器
                        Column() {
                          ForEach(this.commentTree, (item: CommentTreeItem) => {
                            // 父评论
                            Row() {
                              // 头像
                              Image($r('app.media.avatar_default'))
                                .width(36).height(36)
                                .borderRadius(18)
                                .backgroundColor('#FFF')
                                .margin({ right: 8 })
                              // 右侧内容
                              Column() {
                                Row() {
                                  Text(item.comment.user_name)
                                    .fontWeight(FontWeight.Bold)
                                    .fontSize(15)
                                    .fontColor('#222')
                                  Text(item.comment.create_time.split('T')[0])
                                    .fontSize(11)
                                    .fontColor('#999')
                                    .margin({ left: 8 })
                                }
                                Text(item.comment.content)
                                  .fontSize(14)
                                  .fontColor('#222')
                                  .margin({ top: 2, bottom: 2 })
                                Row() {
                                  Button('回复')
                                    .onClick(() => {
                                      this.replyParentId = item.comment.comment_id;
                                      this.commentContent = `@${item.comment.user_name} `;
                                    })
                                    .fontSize(12)
                                    .fontColor('#999')
                                    .backgroundColor('transparent')
                                    .margin({ right: 8 })
                                  // 展开回复
                                  if (item.replies.length > 0) {
                                    Button(`展开${item.replies.length}条回复`)
                                      .onClick(() => { /* 展开逻辑 */ })
                                      .fontSize(12)
                                      .fontColor('#1E90FF')
                                      .backgroundColor('transparent')
                                  }
                                }
                              }
                              .flexGrow(1)
                              // 点赞
                              Column() {
                                Button({ type: ButtonType.Circle }) {
                                  Image($r('app.media.like'))
                                    .width(20).height(20)
                                }
                                .onClick(() => this.likeComment(item.comment.comment_id))
                                Text(item.comment.like_count.toString())
                                  .fontSize(12)
                                  .fontColor('#999')
                              }
                              .margin({ left: 8 })
                            }
                            .margin({ bottom: 12 })

                            // 子评论
                            ForEach(item.replies, (reply: CommentItem) => {
                              Row() {
                                // 头像
                                Image($r('app.media.avatar_default'))
                                  .width(28).height(28)
                                  .borderRadius(14)
                                  .backgroundColor('#FFF')
                                  .margin({ right: 8 })
                                // 右侧内容
                                Column() {
                                  Row() {
                                    Text(reply.user_name)
                                      .fontWeight(FontWeight.Bold)
                                      .fontSize(13)
                                      .fontColor('#222')
                                    Text(reply.create_time.split('T')[0])
                                      .fontSize(10)
                                      .fontColor('#999')
                                      .margin({ left: 8 })
                                  }
                                  Text(reply.content)
                                    .fontSize(13)
                                    .fontColor('#222')
                                    .margin({ top: 2, bottom: 2 })
                                  Button('回复')
                                    .onClick(() => {
                                      this.replyParentId = reply.comment_id;
                                      this.commentContent = `@${reply.user_name} `;
                                    })
                                    .fontSize(12)
                                    .fontColor('#999')
                                    .backgroundColor('transparent')
                                }
                                .flexGrow(1)
                                // 点赞
                                Column() {
                                  Button({ type: ButtonType.Circle }) {
                                    Image($r('app.media.like'))
                                      .width(18).height(18)
                                  }
                                  .onClick(() => this.likeComment(reply.comment_id))
                                  Text(reply.like_count.toString())
                                    .fontSize(11)
                                    .fontColor('#999')
                                }
                                .margin({ left: 8 })
                              }
                              .margin({ left: 44, bottom: 8 }) // 子评论缩进
                            })
                          })
                        }
                        .backgroundColor('#FFF')
                        .padding({ left: 12, right: 12, top: 8, bottom: 8 })

                        // 新增：所有评论过此文物的用户及内容
                        Text('所有评论过此文物的用户及内容如下：')
                          .fontSize(14)
                          .fontWeight(FontWeight.Bold)
                          .margin({ top: 16, left: 12, bottom: 4 })
                        Column() {
                          ForEach(this.comments, (comment: CommentItem) => {
                            Row() {
                              Text(comment.user_name)
                                .fontSize(12)
                                .fontWeight(FontWeight.Bold)
                                .margin({ right: 8 })
                              Text(comment.content)
                                .fontSize(12)
                                .fontColor('#444444')
                            }
                            .margin({ bottom: 6, left: 16 })
                          })
                        }
                        .width('100%')
                        .backgroundColor('#F9F9F9')
                        .padding(8)
                      }
                    }
                  }
                }
                .padding({ bottom: 70 }) // 让出底部空间，避免内容被底栏遮住
              }

              // 固定底部栏
              Row({ space: 8 }) {
                // 输入框
                TextInput({ placeholder: '说点什么...' })
                  .onChange((v: string) => { this.commentContent = v })
                  .borderRadius(20)
                  .backgroundColor('#F5F5F5')
                  .padding({ left: 12, right: 12 })
                  .width('50%')

                // 发送按钮
                Button('发送')
                  .onClick(() => this.submitComment())
                  .backgroundColor('#DAA520')
                  .borderRadius(20)
                  .fontColor('#FFF')
                  .width(60)
                  .height(36)
                  .margin({ right: 4, left: 4 })

                // 点赞按钮+数字
                Row() {
                  Button({ type: ButtonType.Circle }) {
                    Image(this.isLiked ? $r('app.media.like_filled') : $r('app.media.like'))
                      .width(24).height(24)
                  }
                  .onClick(() => this.likeAntique())
                  .width(40)
                  .height(40)
                  .backgroundColor('#F5F5F5')
                  Text(this.likeCount.toString())
                    .fontSize(14)
                    .fontColor('#666')
                    .margin({ left: 2 })
                }
                .margin({ right: 8 })
              }
              .width('100%')
              .height(56)
              .backgroundColor('#FFF')
              .position({ x: 0, y: '100%' })
              .translate({ y: -56 })
              .shadow({ radius: 8, color: '#EEE' })
            }
            .width('100%')
            .height('100%')
            .backgroundColor('#F7F8FA')
          }
        }

