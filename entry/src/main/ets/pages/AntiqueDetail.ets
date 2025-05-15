import http from '@ohos.net.http';
import router from '@ohos.router';
import prompt from '@ohos.prompt';
import common from '@ohos.app.ability.common';
import { UserStore } from '../common/UserStore';
import preferences from '@ohos.data.preferences';
import picker from '@ohos.file.picker'
import fs from '@ohos.file.fs'

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

interface CommentID {
  comment_id: number;
}

interface CommentResult {
  result:CommentID;
}

// 定义 FetchResult 接口
interface FetchResult {
    result: string | object; // 结果可以是字符串或对象
    comment_id?: number; // 可选属性
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

interface GeneratedTypeLiteralInterface_1 {
  name: string;
  contentType: string;
  filePath: string;
  remoteFileName: string;
}

interface GeneratedTypeLiteralInterface_2 {
  comment_id: number;
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
  @State selectedImages: string[] = []; // 用于存储选择的图片URI
  private userPreferences: preferences.Preferences | null = null;

  aboutToAppear() {
    this.initPreferences();
    const params = router.getParams() as RouterParams;
    const relicId: number = params?.id ? parseInt(params.id.toString()) : 0;
    console.log('aboutToAppear被调用，relicId:', relicId);
    if (relicId > 0) {
      this.fetchAntiqueDetail(relicId);
      this.fetchComments(relicId);
      this.checkLikeAndFavoriteStatus();
    }
  }

  async initPreferences() {
    try {
      this.userPreferences = await preferences.getPreferences(getContext(), 'userInfo');
    } catch (error) {
      console.error('初始化偏好设置失败:', error);
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
    const url = `http://10.4.77.43:3000/api/antique/comments/${id}`;
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

  async getUserId(): Promise<number> {
    if( !this.userPreferences )
      return 0 ;
    try {
      const userId: number = await this.userPreferences.get('userId', 0) as number;
      return userId; // 返回用户ID
    } catch (error) {
      console.error('获取用户ID失败:', error);
      return 0; // 返回0表示未获取到用户ID
    }
  }

  // 处理图片选择
  async handleImageSearch(): Promise<void> {
    try {
      const photoPicker: picker.PhotoViewPicker = new picker.PhotoViewPicker();
      const options: picker.PhotoSelectOptions = {
        MIMEType: picker.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 9 // 最多选择9张图片
      };
      const result: picker.PhotoSelectResult = await photoPicker.select(options);

      if (result && result.photoUris && result.photoUris.length > 0) {
        this.selectedImages = result.photoUris; // 存储选择的图片URI
        console.info('选择的图片:', this.selectedImages);
      } else {
        console.info('没有选择任何图片');
      }
    } catch (error) {
      console.error('选择图片失败:', error);
    }
  }

  // 提交评论
  async submitComment(): Promise<void> {
    const userId = await this.getUserId(); // 获取用户ID
    if (!userId) {
        this.showToast('请先登录'); // 提示用户登录
        return; // 退出函数
    }

    const params = router.getParams() as RouterParams;
    const relicId: number = params?.id ? parseInt(params.id.toString()) : 0;
    if (relicId > 0 && this.commentContent) {
        const httpRequest2 = http.createHttp();
        const url = `http://10.4.77.43:3000/api/antique/upload_comments/${relicId}`; // 确保包含 relicId
        const response: FetchResult = await httpRequest2.request(url, {
            method: http.RequestMethod.POST,
            header: { 'Content-Type': 'application/json' },
            expectDataType: http.HttpDataType.OBJECT,
            extraData: JSON.stringify({
                user_id: userId,
                content: this.commentContent,
                parent_id: this.replyParentId || null
            })
        }) as FetchResult;

        // 确保 response.result 是一个对象并包含 comment_id
        if (response && response.result && typeof response.result === 'object') {
            const commentId = (response.result as GeneratedTypeLiteralInterface_2).comment_id; // 使用类型断言
            // 上传图片并与评论ID关联
            await this.uploadImagesWithCommentId(commentId);
            this.showToast('评论已提交，审核通过后将显示');
            this.commentContent = '';
            this.replyParentId = null;
            this.selectedImages = []; // 清空选择的图片
            console.info(commentId.toString());
        } else {
            this.showToast('提交评论失败');
        }
    }
  }

  // 上传图片并与评论ID关联
  async uploadImagesWithCommentId(commentId: number): Promise<void> {
    const userId = await this.getUserId(); // 获取用户ID
    if (this.selectedImages.length === 0) {
        return; // 没有选择图片
    }

    const uploadUrl: string = 'http://10.4.77.43:5000/upload_image'; // 假设这是上传图片的接口
    const httpRequest: http.HttpRequest = http.createHttp();

    this.selectedImages.map( async (imageUri) => {
        let resultPhoto = fs.openSync(imageUri, fs.OpenMode.READ_ONLY);
        let fileTemp = fs.openSync(getContext().filesDir + resultPhoto.name, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
        let imageUri_1: string = fileTemp.path;
        fs.copyFileSync(resultPhoto.fd, fileTemp.fd);
        fs.closeSync(resultPhoto);
        fs.closeSync(fileTemp)
        console.info('开始上传图片，图片URI:', imageUri_1);

        const response: http.HttpResponse = await httpRequest.request(uploadUrl, {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'multipart/form-data',
            'Connection': 'keep-alive',
            'user_id': userId.toString(), // 将 userId 添加到请求头
            'comment_id': commentId.toString() // 将 commentId 添加到请求头
          },
          expectDataType: http.HttpDataType.ARRAY_BUFFER,
          multiFormDataList: [
            {
              name: 'image',  // 确保字段名为 'image'
              contentType: 'image/jpeg',
              filePath: imageUri_1,
              remoteFileName: 'file.jpg'
            },
          ],
        });

    });
  }

  async likeComment(comment_id: number): Promise<void> {
    const userId = await this.getUserId(); // 获取用户ID
    if (!userId) {
      this.showToast('请先登录'); // 提示用户登录
      return; // 退出函数
    }
    const httpRequest = http.createHttp();
    const url = `http://10.4.77.43:3000/api/antique/comments/like/${comment_id}`;
    httpRequest.request(
      url,
      {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json'
        },
        expectDataType: http.HttpDataType.OBJECT,
        extraData: JSON.stringify({
          user_id: userId
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

  async likeAntique(): Promise<void> {
    const userId = await this.getUserId(); // 获取用户ID
    if (!userId) {
      this.showToast('请先登录'); // 提示用户登录
      return; // 退出函数
    }
    const params = router.getParams() as RouterParams;
    const relicId: number = params?.id ? parseInt(params.id.toString()) : 0;

    console.log('准备发送点赞请求，relicId:', relicId, 'userId:', userId);

    const httpRequest = http.createHttp();
    httpRequest.request(
      `http://10.4.77.43:3000/api/antique/like/${relicId}`,
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
    const userId = this.getUserId(); // 获取用户ID
    if (!userId) {
      this.showToast('请先登录'); // 提示用户登录
      return; // 退出函数
    }

    const httpRequest = http.createHttp();
    httpRequest.request(
      `http://10.4.77.43:3000/api/antique/favorite/${relicId}`,
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
    const userId = this.getUserId(); // 获取用户ID
    if (!userId) {
      this.showToast('请先登录'); // 提示用户登录
      return; // 退出函数
    }

    const httpRequest = http.createHttp();
    httpRequest.request(
      `http://10.4.77.43:3000/api/antique/status/${relicId}?user_id=${userId}`,
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
                          .fontSize(20)
                          .fontWeight(FontWeight.Bold)
                          .margin({ top: 12, left: 12, bottom: 8 })
                          .fontColor('#333333');

                        // 评论列表容器
                        Column() {
                          ForEach(this.commentTree, (item: CommentTreeItem) => {
                            Column() {
                              // 父评论
                              Row() {
                                Column() {
                                  Text(item.comment.user_name)
                                    .fontSize(14)
                                    .fontWeight(FontWeight.Bold)
                                    .fontColor('#007BFF');
                                  Text(item.comment.create_time)
                                    .fontSize(12)
                                    .fontColor('#666666');
                                }
                                .flexGrow(1)

                                // 点赞区域
                                Row() {
                                  Text(item.comment.like_count.toString())
                                    .fontSize(12)
                                    .margin({ right: 4 });
                                  Button('点赞')
                                    .onClick(() => {
                                      this.likeComment(item.comment.comment_id);
                                    })
                                    .width(60)
                                    .height(30)
                                    .backgroundColor('#F5F5F5')
                                    .borderRadius(15)
                                    .fontSize(12)
                                    .fontColor('#666666');
                                }
                              }
                              .margin({ bottom: 8 })
                              .padding(10)
                              .backgroundColor('#FFFFFF')
                              .borderRadius(10)

                              // 评论内容
                              Text(item.comment.content)
                                .fontSize(14)
                                .lineHeight(20)
                                .fontColor('#444444')
                                .margin({ top: 4, left: 12, right: 12 });

                              // 回复按钮
                              Button('回复')
                                .onClick(() => {
                                  this.replyParentId = item.comment.comment_id;
                                  this.commentContent = `@${item.comment.user_name} `;
                                })
                                .width(60)
                                .height(30)
                                .backgroundColor('#F5F5F5')
                                .borderRadius(15)
                                .fontSize(12)
                                .fontColor('#666666')
                                .margin({ left: 12, top: 4 });
                            }
                            .margin({ bottom: 12 })
                            .backgroundColor('#F9F9F9')
                            .borderRadius(10)
                            .padding(10);
                            
                            // 子评论
                            ForEach(item.replies, (reply: CommentItem) => {
                              Column() {
                                Row() {
                                  Column() {
                                    Text(reply.user_name)
                                      .fontSize(12)
                                      .fontWeight(FontWeight.Bold)
                                      .fontColor('#007BFF');
                                    Text(reply.create_time)
                                      .fontSize(10)
                                      .fontColor('#666666');
                                  }
                                  .flexGrow(1)

                                  // 点赞区域
                                  Row() {
                                    Text(reply.like_count.toString())
                                      .fontSize(12)
                                      .margin({ right: 4 });
                                    Button('点赞')
                                      .onClick(() => {
                                        this.likeComment(reply.comment_id);
                                      })
                                      .width(60)
                                      .height(30)
                                      .backgroundColor('#F5F5F5')
                                      .borderRadius(15)
                                      .fontSize(12)
                                      .fontColor('#666666');
                                  }
                                }
                                .margin({ bottom: 8 })
                                .padding(10)
                                .backgroundColor('#FFFFFF')
                                .borderRadius(10)

                                // 评论内容
                                Text(reply.content)
                                  .fontSize(12)
                                  .lineHeight(20)
                                  .fontColor('#444444')
                                  .margin({ top: 4, left: 12, right: 12 });
                              }
                              .margin({ bottom: 12, left: 30 })
                              .backgroundColor('#F9F9F9')
                              .borderRadius(10)
                              .padding(10);
                            });
                          })
                        }
                        .width('100%')
                        .backgroundColor('#F5F5F5')
                        .padding(12);
                      }
                    }
                  }
                }
                .padding({ bottom: 70 }) // 让出底部空间，避免内容被底栏遮住
              }

              // 固定底部栏
              Row({ space: 8 }) {
                // 选择图片按钮
                Button('选择图片')
                  .onClick(() => {
                    this.handleImageSearch(); // 处理图片选择
                  })
                  .width(80)
                  .height(40)
                  .backgroundColor('#DAA520')
                  .borderRadius(20)
                  .fontSize(14)
                  .fontColor('#FFFFFF');

                // 评论输入框
                TextInput({ placeholder: '发表评论...' })
                  .onChange((value: string) => {
                    this.commentContent = value;
                  })
                  .type(InputType.Normal)
                  .height(40)
                  .borderRadius(20)
                  .padding({ left: 12 })
                  .backgroundColor('#FFFFFF')
                  .margin({ left: 12 })
                  .width('200.00vp');

                // 评论按钮
                Button('评论')
                  .onClick(() => {
                    this.submitComment();
                  })
                  .width(60)
                  .height(40)
                  .backgroundColor('#DAA520')
                  .borderRadius(20)
                  .fontSize(14)
                  .fontColor('#FFFFFF');

                // 点赞按钮+数字
                Row({ space: 4 }) {
                  Button({ type: ButtonType.Circle }) {
                    Image(this.isLiked ? $r('app.media.like_filled') : $r('app.media.like'))
                      .width(24)
                      .height(24);
                  }
                  .onClick(() => this.likeAntique())
                  .width(40)
                  .height(40)
                  .backgroundColor('#F5F5F5');

                  Text(this.likeCount.toString())
                    .fontSize(16)
                    .fontColor('#666666')
                    .width(32)
                    .textAlign(TextAlign.Center);
                }
                .padding({ right: 12 });
              }
              .width('100%')
              .height(56)
              .backgroundColor('#F5F5F5')
              .position({ x: 0, y: '100%' })
              .translate({ y: -56 })
            }
            .width('100%')
            .height('100%')
            .backgroundColor('#F7F8FA')
          }
        }
