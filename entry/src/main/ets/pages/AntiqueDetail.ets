import http from '@ohos.net.http';
import router from '@ohos.router';
import prompt from '@ohos.prompt';
import { UserStore } from '../common/UserStore';
import preferences from '@ohos.data.preferences';
import picker from '@ohos.file.picker'
import fs from '@ohos.file.fs'
import { BusinessError } from '@kit.BasicServicesKit';
import emitter from '@ohos.events.emitter';
import { ImageItem } from '../common/types/DynamicTypes'
import { matrix4 } from '@kit.ArkUI';

const BACKEND_IMAGE_BASE = 'http://192.168.1.100:3000/comment_image/';

// 路由参数类型
interface RouterParams {
  id?: number;
}

interface LikeResponse {
  like_count: number;
}
interface CLikeResponse {
  like_count: number;
}
interface FavoriteResponse {
  favorite_count: number;
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
  like_count: number;
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
  parent_id: number | null;
  status: number;
  is_deleted: number;
  is_liked?: boolean;
  images: Array<string>;
}

interface CommentID {
  comment_id: number;
}

interface CommentResult {
  result: CommentID;
}

// 定义 FetchResult 接口
interface FetchResult {
  result: string | object; // 结果可以是字符串或对象
  comment_id?: number; // 可选属性
}

interface LikeCountResult {
  like_count: number;
}

// 定义 RelicStatus 接口并导出
export interface RelicStatus {
  is_liked: boolean;
  like_count: number;
}

// 收藏相关
export interface RelicFavorite {
  is_favorited: boolean;
  favorite_count: number;
}

export interface CStatus {
  is_liked: boolean;
  like_count: number;
}

// 评论树类型
class CommentTreeItem {
  comment: CommentItem;
  replies: CommentTreeItem[];

  constructor(comment: CommentItem, replies: CommentTreeItem[]) {
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

// 在合适位置添加类型定义：

interface BackendErrorResponse {
  error: string;
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
    videos: [],
    like_count: 0
  }
  @State comments: CommentItem[] = []
  @State comment: CommentItem = {
    comment_id: 0,
    content: '',
    like_count: 0,
    reply_count: 0,
    create_time: '',
    user_name: '',
    parent_id: 0,
    status: 0,
    is_deleted: 0,
    is_liked: false,
    images:[]
  };
  @State commentTree: CommentTreeItem[] = [];
  @State commentContent: string = '';
  @State replyParentId: number | null = null;
  @State toastMessage: string = '';
  @State likeCount: number = 0;
  @State isLiked: boolean = false;
  @State favoriteCount: number = 0;
  @State isFavorited: boolean = false;
  @State selectedImages: string[] = []; // 用于存储选择的图片URI
  @State showInput: boolean = false;
  private userPreferences: preferences.Preferences | null = null;
  private inputRef = new TextInputController();
  @State matrix: matrix4.Matrix4Transit = matrix4.identity().copy();

  // 每次页面显示时，自动初始化和加载所有页面需要的数据和状态，确保用户看到的是最新的内容。
  async aboutToAppear() {
    await this.initPreferences(); // 等待初始化完成

    const params = router.getParams() as RouterParams;
    const relicId: number = params?.id ? parseInt(params.id.toString()) : 0;

    console.log('aboutToAppear被调用，relicId:', relicId);
    // 在这里立即更新this.antique的relic_id
    this.antique.relic_id = relicId;

    if (relicId > 0) { // 如果文物id有效
      // 调用获取详情，并在成功回调中调用状态检查
      this.fetchAntiqueDetail(relicId);
      this.fetchComments(relicId); // 获取该文物下的评论
    } else {
      // 如果relicId无效，可能需要一些默认状态或提示
      console.warn('未获取到有效文物ID，无法加载详情和状态');
      // 可以在这里设置默认的点赞/收藏状态，或者等待用户登录后手动刷新
      this.isLiked = false;
      this.likeCount = 0;
      this.isFavorited = false;
      this.favoriteCount = 0;
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
    const url = `http://192.168.1.100:3000/api/antique/detail/${id}`;
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

          // fetchAntiqueDetail会更新this.antique的属性，除了relic_id (已经在aboutToAppear中设置)
          this.antique.name = parsed.name || '';
          this.antique.type = parsed.type || '';
          this.antique.size = parsed.size || '';
          this.antique.materials = parsed.matrials || '';
          this.antique.dynasty = parsed.dynasty || '';
          this.antique.author = parsed.author || '';
          this.antique.entry_time = parsed.entry_time || '';
          this.antique.description = parsed.description || '';
          this.antique.images = images;
          this.antique.videos = videos;

          // 在获取详情成功后，调用状态检查函数
          this.checkLikeAndFavoriteStatus();
          this.checkCLikeStatus();
          this.checkFavoriteStatus();

        } catch (e) {
          console.error('解析JSON失败:', e);
        }
      }
    );
  }
  async fetchComments(id: number): Promise<void> {
    console.log('fetchComments被调用，id:', id);
    const httpRequest = http.createHttp();
    const userId = await this.getUserId();
    console.log('当前userId:', userId);
    const url = `http://192.168.1.100:3000/api/antique/comments/${id}?user_id=${userId}`;
    console.log('[fetchComments] 请求URL:', url);

    httpRequest.request(
      url,
      { method: http.RequestMethod.GET, expectDataType: http.HttpDataType.OBJECT },
      (err: Error | undefined, data: FetchResult) => {
        if (err) {
          console.error('[fetchComments]请求评论失败:', JSON.stringify(err));
          return;
        }

        // 添加调试日志
        console.log('[fetchComments] 原始返回数据:', JSON.stringify(data.result));

        let commentArr: CommentItem[] = [];
        if (typeof data.result === 'string') {
          try {
             commentArr = JSON.parse(data.result) as CommentItem[];
             console.log('[fetchComments] 解析后的评论数组:', JSON.stringify(commentArr));
          } catch(e) {
            console.error('[fetchComments]解析评论列表 JSON 失败:', e);
            return;
          }
        } else if (typeof data.result === 'object') {
           if (Array.isArray(data.result)) {
             commentArr = data.result as CommentItem[];
             console.log('[fetchComments] 直接获取到的评论数组:', JSON.stringify(commentArr));
           } else {
             console.error('[fetchComments]评论接口返回数据结构异常，不是数组:', data.result);
             return;
           }
        } else {
           console.error('[fetchComments]评论接口返回未知数据类型:', typeof data.result);
           return;
        }

        // 检查每个评论的 is_liked 状态
        console.log('[fetchComments] 评论点赞状态检查:');
        commentArr.forEach((comment: CommentItem) => {
          console.log(`[fetchComments]评论ID: ${comment.comment_id}, is_liked: ${comment.is_liked}, like_count: ${comment.like_count}`);
        });

        // 只保留 status=1 且 is_deleted=0 的评论，并确保每个评论都有 is_liked 属性
        commentArr = commentArr.filter(c => c.status === 1 && c.is_deleted === 0).map(comment => {
          const updatedComment: CommentItem = {
            comment_id: comment.comment_id,
            content: comment.content,
            like_count: comment.like_count,
            reply_count: comment.reply_count,
            create_time: comment.create_time,
            user_name: comment.user_name,
            parent_id: comment.parent_id,
            status: comment.status,
            is_deleted: comment.is_deleted,
            is_liked: comment.is_liked == true,
            images:comment.images
          };
          console.log(`[fetchComments] 处理后的评论 ${updatedComment.comment_id} 状态:`,
            `is_liked=${updatedComment.is_liked}, like_count=${updatedComment.like_count}`);
          return updatedComment;
        });

        // 更新状态
        this.comments = commentArr;
        this.commentTree = buildCommentTree(this.comments, null);

        // 验证更新后的状态
        console.log('[fetchComments] 更新后的评论树状态:');
        this.commentTree.forEach((item: CommentTreeItem) => {
          console.log(`[fetchComments]评论树节点 ${item.comment.comment_id} 状态:`,
            `is_liked=${item.comment.is_liked}, like_count=${item.comment.like_count}`);
        });
      }
    );
  }

  async getUserId(): Promise<number> {
    if (!this.userPreferences) {
      return 0;
    }
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

  // 修改回复按钮点击处理函数
  handleReplyClick(comment: CommentItem) {
    this.replyParentId = comment.comment_id;
  }

  // 修改提交评论函数
  async submitComment(): Promise<void> {
    const userId = await this.getUserId();
    if (!userId) {
      this.showToast('请先登录');
      return;
    }

    if (!this.commentContent.trim()) {
      this.showToast('评论内容不能为空');
      return;
    }

    const params = router.getParams() as RouterParams;
    const relicId: number = params?.id ? parseInt(params.id.toString()) : 0;
    if (relicId > 0) {
      const httpRequest2 = http.createHttp();
      const url = `http://192.168.1.100:3000/api/antique/upload_comments/${relicId}`;
      try {
        const response: FetchResult = await httpRequest2.request(url, {
          method: http.RequestMethod.POST,
          header: { 'Content-Type': 'application/json' },
          expectDataType: http.HttpDataType.OBJECT,
          extraData: JSON.stringify({
            user_id: userId,
            content: this.commentContent,
            parent_id: this.replyParentId
          })
        }) as FetchResult;

        if (response && response.result && typeof response.result === 'object') {
          const commentId = (response.result as GeneratedTypeLiteralInterface_2).comment_id;
          // 上传图片并与评论ID关联
          await this.uploadImagesWithCommentId(commentId);
          this.showToast('评论已提交，审核通过后将显示');
          // 重置状态（无论是评论还是回复，提交后都清空输入框和父ID）
          this.commentContent = '';
          this.replyParentId = null;
          this.selectedImages = [];

          // 显示审核提示
          this.showToast('评论已提交，审核通过后将显示');

          // 刷新评论列表
          this.fetchComments(relicId);
        } else {
          this.showToast('提交评论失败');
        }
      } catch (error) {
        console.error('提交评论失败:', error);
        this.showToast('提交评论失败，请重试');
      }
    }
  }

  // 上传图片并与评论ID关联
  async uploadImagesWithCommentId(commentId: number): Promise<void> {
    const userId = await this.getUserId(); // 获取用户ID
    if (this.selectedImages.length === 0) {
      return; // 没有选择图片
    }

    const uploadUrl: string = 'http://192.168.1.100:5000/upload_image'; // 假设这是上传图片的接口
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

  //评论点赞
  async likeComment(): Promise<void> {
    const userId = await this.getUserId();
    console.info('[likeComment] 获取到 userId:', userId);
    if (!userId) {
      this.showToast('请先登录');
      console.warn('[likeComment] 用户未登录，终止点赞');
      return;
    }

    // 找到当前评论在comments数组中的索引
    const commentIndex = this.comments.findIndex(c => c.comment_id === this.comment.comment_id);
    if (commentIndex === -1) {
      console.error('[likeComment] 未找到要点赞的评论');
      return;
    }

    // 保存当前状态用于回滚
    const currentComment = this.comments[commentIndex];
    const currentLikeCount = currentComment.like_count;
    const currentIsLiked = currentComment.is_liked;

    // 1. 本地乐观更新
    const updatedComment: CommentItem = {
      comment_id: currentComment.comment_id,
      content: currentComment.content,
      like_count: currentIsLiked ? Math.max(0, currentLikeCount - 1) : currentLikeCount + 1,
      reply_count: currentComment.reply_count,
      create_time: currentComment.create_time,
      user_name: currentComment.user_name,
      parent_id: currentComment.parent_id,
      status: currentComment.status,
      is_deleted: currentComment.is_deleted,
      is_liked: !currentIsLiked,
      images:currentComment.images
    };
    this.comments[commentIndex] = updatedComment;
    this.commentTree = buildCommentTree(this.comments, null);

    const maxRetries = 3;
    let retryCount = 0;
    const tryLike = () => {
      let httpRequest = http.createHttp();
      const url = 'http://192.168.1.100:3000/api/antique/comments/like/' + this.comment.comment_id;
      httpRequest.request(
        url,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Connection': 'keep-alive'
          },
          extraData: JSON.stringify({ user_id: userId }),
          connectTimeout: 15000,
          readTimeout: 15000,
          usingProtocol: http.HttpProtocol.HTTP1_1,
          usingCache: false,
        },
        (err: BusinessError | undefined, data: http.HttpResponse | undefined) => {
          if (err) {
            console.error(`[likeComment] 请求错误详情:`, JSON.stringify({
              code: err.code,
              message: err.message,
              data: err.data
            }));
            if (retryCount < maxRetries) {
              retryCount++;
              const delay = Math.min(1000 * Math.pow(2, retryCount), 8000);
              setTimeout(tryLike, delay);
            } else {
              // 所有重试都失败，回滚状态
              const rollbackComment: CommentItem = {
                comment_id: currentComment.comment_id,
                content: currentComment.content,
                like_count: currentLikeCount,
                reply_count: currentComment.reply_count,
                create_time: currentComment.create_time,
                user_name: currentComment.user_name,
                parent_id: currentComment.parent_id,
                status: currentComment.status,
                is_deleted: currentComment.is_deleted,
                is_liked: currentIsLiked,
                images:currentComment.images
              };
              this.comments[commentIndex] = rollbackComment;
              this.commentTree = buildCommentTree(this.comments, null);
              this.showToast('操作失败，请重试');
            }
            return;
          }
          // 后端成功返回，更新点赞数和状态（如果后端有返回 is_liked 字段可以用，否则用本地状态）
          let response: CLikeResponse | null = null;
          interface LikeResponseWithStatus extends CLikeResponse {
            is_liked?: boolean;
          }
          if (data) {
            if (typeof data.result === 'string') {
              try {
                const trimmed = data.result.trim();
                if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
                  response = JSON.parse(trimmed) as LikeResponseWithStatus;
                }
              } catch (e) {}
            } else if (typeof data.result === 'object') {
              response = data.result as LikeResponseWithStatus;
            }
          }
          if (response && typeof response.like_count === 'number') {
            // 用后端返回的最新点赞数和状态（如果有）
            const updatedComment: CommentItem = {
              comment_id: this.comments[commentIndex].comment_id,
              content: this.comments[commentIndex].content,
              like_count: response.like_count,
              reply_count: this.comments[commentIndex].reply_count,
              create_time: this.comments[commentIndex].create_time,
              user_name: this.comments[commentIndex].user_name,
              parent_id: this.comments[commentIndex].parent_id,
              status: this.comments[commentIndex].status,
              is_deleted: this.comments[commentIndex].is_deleted,
              is_liked: (response as LikeResponseWithStatus).is_liked ?? this.comments[commentIndex].is_liked,
              images:this.comments[commentIndex].images
            };
            this.comments[commentIndex] = updatedComment;
            this.commentTree = buildCommentTree(this.comments, null);
          }
        }
      );
    };
    tryLike();
  }

  checkCLikeStatus(): void {
    this.getUserId().then((userId: number) => {
      const httpRequest = http.createHttp();
      httpRequest.request(
        `http://192.168.1.100:3000/api/antique/cstatus/${this.comment.comment_id}?user_id=${userId}`,
        { method: http.RequestMethod.GET, expectDataType: http.HttpDataType.OBJECT },
        (err: Error | undefined, data: FetchResult) => {
          if (err) {
            console.error('获取状态失败:', JSON.stringify(err));
            return;
          }
          let result: CStatus;
          try {
            if (typeof data.result === 'string') {
              // 尝试解析，并处理可能的空字符串或其他非JSON内容
              const trimmed = data.result.trim();
              if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
                result = JSON.parse(trimmed) as CStatus;
              } else {
                console.error('状态接口返回内容不是JSON格式:', data.result);
                return; // 解析失败，退出
              }
            } else if (typeof data.result === 'object' && data.result !== null) { // 确保不是null
              result = data.result as CStatus;
            } else {
              console.error('状态接口返回格式或内容异常:', data.result);
              return; // 格式异常或null，退出
            }
          } catch (e) {
            console.error('解析状态接口JSON失败:', e, '原始数据:', data.result);
            return; // 解析失败，退出
          }
          // 确保result对象及属性存在
          if (result && typeof result.is_liked !== 'undefined' && typeof result.like_count !== 'undefined') {
            this.comment.is_liked = result.is_liked;
            this.comment.like_count = result.like_count;
            console.log('状态接口返回like_count:', result.like_count, '赋值后 this.likeCount:', this.comment.like_count);
          } else {
            console.error('状态接口返回数据结构异常或缺少关键字段:', result);
          }
        }
      );
    }).catch((error: BusinessError) => {
      const typedError = error as Error;
      console.error('获取用户ID失败 (checkLikeAndFavoriteStatus):', typedError);
    });
  }

  // 添加文物点赞处理函数
  private async likeAntique(): Promise<void> {
    const pref = await preferences.getPreferences(getContext(), 'userInfo');
    const userId = await pref.get('userId', 0) as number;

    if (!userId) {
      this.showToast('请先登录'); // 提示用户登录
      return; // 退出函数
    }

    // 在乐观更新前记录当前点赞数，用于失败时回滚
    const currentLikeCount = this.likeCount;
    const currentIsLiked = this.isLiked;

    // 1. 乐观更新底部显示的likeCount和isLiked状态
    // 根据当前isLiked状态进行增减
    if (this.isLiked) {
      this.likeCount = Math.max(0, this.likeCount - 1); // 点赞状态为true，表示取消点赞
    } else {
      this.likeCount += 1; // 点赞状态为false，表示点赞
    }
    this.isLiked = !this.isLiked; // 切换点赞状态

    const maxRetries = 3;
    let retryCount = 0;

    const tryLike = () => {
      let httpRequest = http.createHttp();
      // 使用this.antique.relic_id 来构建请求URL
      console.info(`[like]开始第${retryCount + 1}次点赞请求，用户ID: ${userId}, 文物ID: ${this.antique.relic_id}`);

      // 使用更可靠的服务器地址 (根据浏览量功能确认可达)
      const serverUrl = 'http://localhost:3000/api/antique/like/' + this.antique.relic_id;
      console.info('[like]请求URL:', serverUrl);

      httpRequest.request(
        serverUrl,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Connection': 'keep-alive'
          },
          extraData: JSON.stringify({ user_id: userId }),
          connectTimeout: 15000,
          readTimeout: 15000,
          usingProtocol: http.HttpProtocol.HTTP1_1,
          usingCache: false, // 禁用缓存
        },
        (err: BusinessError | undefined, data: http.HttpResponse | undefined) => {
          if (err) {
            console.error(`[like]请求错误详情:`, JSON.stringify({
              code: err.code,
              message: err.message,
              data: err.data
            }));

            // 检查是否是网络相关错误
            if (err.code === 2300028) { // 超时错误
              console.error('[like]网络请求超时，可能是服务器响应慢或网络不稳定');
            }
          }

          let response: LikeResponse | null = null
          // Assuming backend response might also include 'is_liked'
          interface LikeResponseWithStatus extends LikeResponse {
            is_liked?: boolean;
          }

          if (!err && data) {
            console.info(`[like]收到响应:`, JSON.stringify({
              responseCode: data.responseCode,
              header: data.header,
              resultType: typeof data.result
            }));

            if (typeof data.result === 'string') {
              try {
                const trimmed = data.result.trim()
                if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
                  response = JSON.parse(trimmed) as LikeResponseWithStatus // 使用trimmed进行解析
                  console.info('[like]成功解析响应数据:', JSON.stringify(response));
                } else {
                  console.error('[like]响应内容不是JSON格式:', data.result)
                }
              } catch (e) {
                console.error('[like]JSON解析失败:', e, '原始数据:', data.result)
              }
            } else if (typeof data.result === 'object') {
              response = data.result as LikeResponseWithStatus
              console.info('[like]直接获取到对象响应:', JSON.stringify(response));
            }
          }

          if (response && typeof response.like_count === 'number') {
            // 请求成功，使用后端返回的最新点赞数更新底部显示
            this.likeCount = response.like_count;

            // **使用后端返回的 is_liked 状态（如果存在）**
            // If backend provides is_liked (boolean), use it. Otherwise, keep the current state.
            this.isLiked = (response as LikeResponseWithStatus).is_liked ?? this.isLiked;
            console.info('[like] 使用后端返回的 is_liked 状态 (或保留原状态):', this.isLiked);

            console.info('[like]点赞操作成功，点赞数更新为:', this.likeCount, '点赞状态:', this.isLiked);
            emitter.emit('relicLikeChanged');
          } else {
            // 请求失败或响应数据异常，尝试重试
            if (retryCount < maxRetries) {
              retryCount++;
              console.info(`[like]点赞请求失败，第${retryCount}次重试...`);
              // 使用指数退避策略
              const delay = Math.min(1000 * Math.pow(2, retryCount), 8000);
              console.info(`[like]将在${delay}ms后重试`);
              setTimeout(tryLike, delay);
            } else {
              // 所有重试都失败，回滚底部显示的点赞数和isLiked状态
              this.likeCount = currentLikeCount;
              this.isLiked = currentIsLiked;
              console.error('[like]所有重试均失败，已回滚点赞数和状态');
              this.showToast('操作失败，请重试');
            }
          }
        }
      )
    };

    tryLike();
  }

  // 添加收藏处理函数
  private async favoriteAntique(): Promise<void> {
    const pref = await preferences.getPreferences(getContext(), 'userInfo');
    const userId = await pref.get('userId', 0) as number;

    if (!userId) {
      this.showToast('请先登录'); // 提示用户登录
      return; // 退出函数
    }

    // 在乐观更新前记录当前收藏数，用于失败时回滚
    const currentFavoriteCount = this.favoriteCount;
    const currentIsFavorite = this.isFavorited;

    if (this.isFavorited) {
      this.favoriteCount = Math.max(0, this.favoriteCount - 1);
    } else {
      this.favoriteCount += 1;
    }
    this.isFavorited = !this.isFavorited;
    const maxRetries = 3;
    let retryCount = 0;

    const tryLike = () => {
      let httpRequest = http.createHttp();
      // 使用this.antique.relic_id 来构建请求URL
      console.info(`[favorite]开始第${retryCount + 1}次收藏请求，用户ID: ${userId}, 文物ID: ${this.antique.relic_id}`);

      // 使用更可靠的服务器地址 (根据浏览量功能确认可达)
      const serverUrl = 'http://192.168.1.100:3000/api/antique/favorite/' + this.antique.relic_id;
      console.info('[favorite]请求URL:', serverUrl);

      httpRequest.request(
        serverUrl,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Connection': 'keep-alive'
          },
          extraData: JSON.stringify({ user_id: userId }),
          connectTimeout: 15000,
          readTimeout: 15000,
          usingProtocol: http.HttpProtocol.HTTP1_1,
          usingCache: false, // 禁用缓存
        },
        (err: BusinessError | undefined, data: http.HttpResponse | undefined) => {
          if (err) {
            console.error(`[favorite]请求错误详情:`, JSON.stringify({
              code: err.code,
              message: err.message,
              data: err.data
            }));

            // 检查是否是网络相关错误
            if (err.code === 2300028) { // 超时错误
              console.error('[favorite]网络请求超时，可能是服务器响应慢或网络不稳定');
            }
          }

          let response: FavoriteResponse | null = null
          if (!err && data) {
            console.info(`[favorite]收到响应:`, JSON.stringify({
              responseCode: data.responseCode,
              header: data.header,
              resultType: typeof data.result
            }));

            if (typeof data.result === 'string') {
              try {
                const trimmed = data.result.trim()
                if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
                  response = JSON.parse(trimmed) as FavoriteResponse // 使用trimmed进行解析
                  console.info('[favorite]成功解析响应数据:', JSON.stringify(response));
                } else {
                  console.error('[favorite]响应内容不是JSON格式:', data.result)
                }
              } catch (e) {
                console.error('[favorite]JSON解析失败:', e, '原始数据:', data.result)
              }
            } else if (typeof data.result === 'object') {
              response = data.result as FavoriteResponse
              console.info('[favorite]直接获取到对象响应:', JSON.stringify(response));
            }
          }

          if (response && typeof response.favorite_count === 'number') {
            this.favoriteCount = response.favorite_count;
            this.isFavorited = response.favorite_count > currentFavoriteCount;
            console.info('[favorite]收藏操作成功，收藏数更新为:', this.favoriteCount, '收藏状态:', this.isFavorited);
          } else {
            // 请求失败或响应数据异常，尝试重试
            if (retryCount < maxRetries) {
              retryCount++;
              console.info(`[favorite]收藏请求失败，第${retryCount}次重试...`);
              // 使用指数退避策略
              const delay = Math.min(1000 * Math.pow(2, retryCount), 8000);
              console.info(`[favorite]将在${delay}ms后重试`);
              setTimeout(tryLike, delay);
            } else {
              // 所有重试都失败，回滚
              this.favoriteCount = currentFavoriteCount;
              this.isFavorited = currentIsFavorite;
              console.error('[favorite]所有重试均失败，已回滚点赞数和状态');
              this.showToast('操作失败，请重试');
            }
          }
        }
      )
    };

    tryLike();
  }

  checkLikeAndFavoriteStatus(): void {
    const params = router.getParams() as RouterParams;
    const relicId: number = params?.id ? parseInt(params.id.toString()) : 0;
    // 获取用户ID，即使未登录也继续发送请求
    this.getUserId().then((userId: number) => {
      const httpRequest = http.createHttp();
      // 使用this.antique.relic_id 构建URL，确保和likeAntique使用一致的ID
      // userId即使为0也会发送给后端
      httpRequest.request(
        `http://192.168.1.100:3000/api/antique/status/${this.antique.relic_id}?user_id=${userId}`,
        { method: http.RequestMethod.GET, expectDataType: http.HttpDataType.OBJECT },
        (err: Error | undefined, data: FetchResult) => {
          if (err) {
            console.error('获取状态失败:', JSON.stringify(err));
            return;
          }
          let result: RelicStatus;
          try {
            if (typeof data.result === 'string') {
              // 尝试解析，并处理可能的空字符串或其他非JSON内容
              const trimmed = data.result.trim();
              if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
                result = JSON.parse(trimmed) as RelicStatus;
              } else {
                console.error('状态接口返回内容不是JSON格式:', data.result);
                return; // 解析失败，退出
              }
            } else if (typeof data.result === 'object' && data.result !== null) { // 确保不是null
              result = data.result as RelicStatus;
            } else {
              console.error('状态接口返回格式或内容异常:', data.result);
              return; // 格式异常或null，退出
            }
          } catch (e) {
            console.error('解析状态接口JSON失败:', e, '原始数据:', data.result);
            return; // 解析失败，退出
          }

          // 确保result对象及属性存在
          if (result && typeof result.is_liked !== 'undefined' && typeof result.like_count !== 'undefined') {
            this.isLiked = result.is_liked;
            this.likeCount = result.like_count;
            console.log('状态接口返回like_count:', result.like_count, '赋值后 this.likeCount:', this.likeCount);
          } else {
            console.error('状态接口返回数据结构异常或缺少关键字段:', result);
          }
        }
      );
    }).catch((error: BusinessError) => {
      const typedError = error as Error;
      console.error('获取用户ID失败 (checkLikeAndFavoriteStatus):', typedError);
    });
  }

  checkFavoriteStatus(): void {
    const params = router.getParams() as RouterParams;
    const relicId: number = params?.id ? parseInt(params.id.toString()) : 0;
    // 获取用户ID，即使未登录也继续发送请求
    this.getUserId().then((userId: number) => {
      const httpRequest = http.createHttp();
      // 使用this.antique.relic_id 构建URL，确保和likeAntique使用一致的ID
      // userId即使为0也会发送给后端
      httpRequest.request(
        `http://192.168.1.100:3000/api/antique/fstatus/${this.antique.relic_id}?user_id=${userId}`,
        { method: http.RequestMethod.GET, expectDataType: http.HttpDataType.OBJECT },
        (err: Error | undefined, data: FetchResult) => {
          if (err) {
            console.error('获取状态失败:', JSON.stringify(err));
            return;
          }
          let result: RelicFavorite;
          try {
            if (typeof data.result === 'string') {
              // 尝试解析，并处理可能的空字符串或其他非JSON内容
              const trimmed = data.result.trim();
              if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
                result = JSON.parse(trimmed) as RelicFavorite;
              } else {
                console.error('状态接口返回内容不是JSON格式:', data.result);
                return; // 解析失败，退出
              }
            } else if (typeof data.result === 'object' && data.result !== null) { // 确保不是null
              result = data.result as RelicFavorite;
            } else {
              console.error('状态接口返回格式或内容异常:', data.result);
              return; // 格式异常或null，退出
            }
          } catch(e) {
            console.error('解析状态接口JSON失败:', e, '原始数据:', data.result);
            return; // 解析失败，退出
          }
          // 确保result对象及属性存在
          if (result && typeof result.is_favorited !== 'undefined' && typeof result.favorite_count !== 'undefined') {
            this.isFavorited = result.is_favorited;
            this.favoriteCount = result.favorite_count;
            console.log('状态接口返回like_count:', result.favorite_count, '赋值后 this.likeCount:', this.favoriteCount);
          } else {
            console.error('状态接口返回数据结构异常或缺少关键字段:', result);
          }
        }
      );
    }).catch((error: BusinessError) => {
      const typedError = error as Error;
      console.error('获取用户ID失败 (checkFavoriteStatus):', typedError);
    });
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
              Scroll() {
                Column() {
                  Text('评论')
                    .fontSize(20)
                    .fontWeight(FontWeight.Bold)
                    .margin({ top: 12, left: 0, bottom: 8 })
                    .fontColor('#333333');

                  // 评论列表容器
                  Column() {
                    ForEach(this.commentTree, (item: CommentTreeItem) => {
                      // 父评论
                      Row() {
                        // 头像
                        Image($r('app.media.avatar_default'))
                          .width(32)
                          .height(32)
                          .borderRadius(18)
                          .backgroundColor('#FFF')
                          .margin({
                            right: 0,
                            left: 0,
                            top: 0,
                            bottom: 0
                          })
                        // 内容区
                        Column() {
                          Row() {
                            Text(item.comment.user_name)
                              .fontWeight(FontWeight.Bold)
                              .fontSize(15)
                              .fontColor('#007BFF')
                            Text(item.comment.create_time.split('T')[0])
                              .fontSize(11)
                              .fontColor('#999')
                              .margin({ left: 8 })
                          }
                          //图片展示
                          Grid() {
                            ForEach( item.comment.images, (img: string) => {
                              GridItem() {
                                Image( BACKEND_IMAGE_BASE + img )
                                  .width('100%')
                                  .aspectRatio(1)
                                  .objectFit(ImageFit.Cover)
                                  .borderRadius(12)
                                  .transform(this.matrix)
                              }
                            })
                          }
                          .columnsTemplate('1fr 1fr 1fr')
                          .rowsGap(8)
                          .columnsGap(8)
                          .margin({ bottom: 16 })
                          .align(Alignment.Start)
                          Text(item.comment.content)
                            .fontSize(14)
                            .fontColor('#222')
                            .margin({ top: 2, bottom: 2, left: 0 })
                            .textAlign(TextAlign.Start)
                            .align(Alignment.Start)
                        }
                        .align(Alignment.Top)
                        .flexGrow(1)
                        .width('60%')

                        // 按钮区（靠右，固定宽度）
                        Row({ space: 8 }) {
                          Button({ type: ButtonType.Circle }) {
                            Image(item.comment.is_liked ? $r('app.media.like_filled') : $r('app.media.like'))
                              .width(18)
                              .height(18)
                          }
                          .onClick(() => {
                            this.comment = item.comment;
                            this.likeComment();
                          })
                          .width(28)
                          .height(28)
                          .backgroundColor('transparent')

                          Text(item.comment.like_count.toString())
                            .fontSize(12)
                            .fontColor('#999')
                            .textAlign(TextAlign.Center)
                            .margin({ left: 2, right: 2 })

                          Button('回复')
                            .onClick(() => {
                              this.handleReplyClick(item.comment);
                            })
                            .fontSize(11)
                            .fontColor('#666')
                            .backgroundColor('transparent')
                            .padding({ left: 4, right: 4 })
                        }
                        .width(180)
                        .align(Alignment.End)
                      }
                      .width('100%') // Row占满整行

                      // 子评论
                      ForEach(item.replies, (reply: CommentTreeItem) => {
                        Row() {
                          // 头像
                          Image($r('app.media.avatar_default'))
                            .width(32)
                            .height(32)
                            .borderRadius(18)
                            .backgroundColor('#FFF')
                            .margin({
                              right: 0,
                              left: 0,
                              top: 0,
                              bottom: 0
                            })
                          // 内容区
                          Column() {
                            Row() {
                              Text(reply.comment.user_name)
                                .fontWeight(FontWeight.Bold)
                                .fontSize(13)
                                .fontColor('#007BFF')
                              Text(reply.comment.create_time.split('T')[0])
                                .fontSize(10)
                                .fontColor('#999')
                                .margin({ left: 8 })
                            }

                            Text(reply.comment.content)
                              .fontSize(13)
                              .fontColor('#222')
                              .margin({ top: 2, bottom: 2 })
                          }
                          .flexGrow(1)

                          // 按钮区（固定宽度，与父评论一致）
                          Row({ space: 8 }) {
                            Button({ type: ButtonType.Circle }) {
                              Image(reply.comment.is_liked ? $r('app.media.like_filled') : $r('app.media.like'))
                                .width(16)
                                .height(16)
                            }
                            .onClick(() => {
                              this.comment = reply.comment;
                              this.likeComment();
                            })
                            .width(24)
                            .height(24)
                            .backgroundColor('transparent')

                            Text(reply.comment.like_count.toString())
                              .fontSize(11)
                              .fontColor('#999')
                              .textAlign(TextAlign.Center)
                              .margin({ left: 2, right: 8 })
                            Button('回复')
                              .onClick(() => {
                                this.handleReplyClick(reply.comment);
                              })
                              .fontSize(12)
                              .fontColor('#666')
                              .backgroundColor('transparent')
                              .padding({ left: 6, right: 6 })
                          }
                          .width(120) // 按钮区宽度加大
                          .align(Alignment.End)
                        }
                        .margin({ left: 42, bottom: 8, right: 0 }) // 头像与父评论用户名左对齐
                      })
                    })
                  }

                  .padding({
                    left: 0,
                    right: 0,
                    top: 8,
                    bottom: 8
                  }) // 确保评论容器无内边距
                }
                .width('100%')
                .backgroundColor('#FFF')
                .padding({
                  left: 0,
                  right: 0,
                  top: 8,
                  bottom: 8
                })
              }.margin({ left: 0, right: 0 })
              .padding({ left: 0, right: 0 })
            }.margin({ left: 0, right: 0 })
            .padding({ left: 0, right: 0 })
          }.margin({ left: 0, right: 0 })
          .padding({ left: 0, right: 0 })
        }.margin({ left: 0, right: 0 })
        .padding({ left: 0, right: 0, bottom: 110 }) // 让出更多底部空间，确保评论完整显示
      }.margin({ left: 0, right: 0 })
      .padding({ left: 0, right: 0 })

      // 固定底部栏
      Row({ space: 6 }) {
        // 图片按钮
        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.ic_image'))
            .width(22)
            .height(22)
        }
        .onClick(() => {
          this.handleImageSearch();
        })
        .width(36)
        .height(36)
        .backgroundColor('transparent')

        // 评论输入框（直接渲染，无需条件和自动聚焦）
        TextInput({ placeholder: '发表评论...', text: this.commentContent })
          .onChange((value: string) => {
            this.commentContent = value;
          })
          .type(InputType.Normal)
          .height(36)
          .borderRadius(18)
          .padding({ left: 12 })
          .backgroundColor('#FFFFFF')
          .margin({ left: 2, right: 2 })
          .width('40%')

        // 发送按钮
        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.ic_send'))
            .width(22)
            .height(22)
        }
        .onClick(() => {
          this.submitComment();
        })
        .width(36)
        .height(36)
        .backgroundColor('transparent')

        Row({ space: 2 }) {
          // 点赞按钮+数字
          Button({ type: ButtonType.Circle }) {
            Image(this.isLiked ? $r('app.media.like_filled') : $r('app.media.like'))
              .width(22)
              .height(22)
          }
          .onClick(() => this.likeAntique())
          .width(36)
          .height(36)
          .backgroundColor('#F5F5F5')
          Text(this.likeCount.toString())
            .fontSize(15)
            .fontColor('#666666')
            .width(22)
            .textAlign(TextAlign.Center)
          // 收藏按钮+数量
          Button({ type: ButtonType.Circle }) {
            Image(this.isFavorited ? $r('app.media.favorite_filled') : $r('app.media.favorite'))
              .width(22)
              .height(22)
          }
          .onClick(() => this.favoriteAntique())
          .width(36)
          .height(36)
          .backgroundColor('#F5F5F5')
          Text(this.favoriteCount.toString())
            .fontSize(15)
            .fontColor('#666666')
            .width(22)
            .textAlign(TextAlign.Center)
        }
        .margin({ right: 8 })
      }
      .width('100%')
      .height(56)
      .backgroundColor('#F5F5F5')
      .position({ x: 0, y: '100%' })
      .translate({ y: -56 })
      .shadow({ radius: 8, color: '#EEE' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F8FA')
  }
}

function buildCommentTree(comments: CommentItem[], parentId: number | null = null): CommentTreeItem[] {
  return comments
    .filter((c: CommentItem) => (c.parent_id == null ? null : c.parent_id) === parentId)
    .map((parent: CommentItem) => {
      const replies: CommentTreeItem[] = buildCommentTree(comments, parent.comment_id);
      return new CommentTreeItem(parent, replies);
    });
}
