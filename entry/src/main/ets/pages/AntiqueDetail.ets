import http from '@ohos.net.http';
import router from '@ohos.router';
import prompt from '@ohos.prompt';
import { UserStore } from '../common/UserStore';
import preferences from '@ohos.data.preferences';
import picker from '@ohos.file.picker'
import fs from '@ohos.file.fs'
import { BusinessError } from '@kit.BasicServicesKit';

// 路由参数类型
interface RouterParams {
  id?: number;
}
interface LikeResponse {
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

// 收藏相关
export interface RelicFavorite {
  is_favorited: boolean;
  favorite_count: number;
}

// 定义 RelicStatus 接口并导出
export interface RelicStatus {
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
  @State comments: CommentItem[] = [];
  @State commentTree: CommentTreeItem[] = [];
  @State commentContent: string = '';
  @State replyParentId: number | null = null;
  @State toastMessage: string = '';
  @State likeCount: number = 0;
  @State isLiked: boolean = false;
  @State favoriteCount: number = 0;
  @State isFavorited: boolean = false;
  @State selectedImages: string[] = []; // 用于存储选择的图片URI
  private userPreferences: preferences.Preferences | null = null;

  // 每次页面显示时，自动初始化和加载所有页面需要的数据和状态，确保用户看到的是最新的内容。
  aboutToAppear() {
    this.initPreferences(); // 初始化用户偏好设置（如获取本地存储的用户信息）

    const params = router.getParams() as RouterParams; // 获取路由参数（如页面跳转时传递的文物id）
    const relicId: number = params?.id ? parseInt(params.id.toString()) : 0; // 解析文物id，若无则为0

    console.log('aboutToAppear被调用，relicId:', relicId); // 打印日志，便于调试

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
    // 移除这里的同步调用，改到fetchAntiqueDetail的成功回调中调用
    // this.checkLikeAndFavoriteStatus();
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
    const url = `http://192.168.1.103:3000/api/antique/detail/${id}`;
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
          this.checkFavoriteStatus();

        } catch (e) {
          console.error('解析JSON失败:', e);
        }
      }
    );
  }

  fetchComments(id: number): void {
    console.log('fetchComments被调用，id:', id);
    const httpRequest = http.createHttp();
    const url = `http://192.168.1.103:3000/api/antique/comments/${id}`;
    httpRequest.request(
      url,
      { method: http.RequestMethod.GET, expectDataType: http.HttpDataType.OBJECT },
      (err: Error | undefined, data: FetchResult) => {
        if (err) {
          console.error('请求评论失败:', JSON.stringify(err));
          return;
        }

        // 添加调试日志
        console.log('评论接口返回:', JSON.stringify(data.result));

        let commentArr: CommentItem[] = [];
        if (typeof data.result === 'string') {
          commentArr = JSON.parse(data.result) as CommentItem[];
        } else if (typeof data.result === 'object') {
          commentArr = data.result as CommentItem[];
        }

        // 添加调试日志
        console.log('解析后的评论数组:', commentArr);

        // 只保留 status=1 且 is_deleted=0 的评论
        commentArr = commentArr.filter(c => c.status === 1 && c.is_deleted === 0);

        // 添加调试日志
        console.log('过滤后的评论数组:', commentArr);

        setTimeout(() => {
          this.comments = commentArr;
          this.commentTree = buildCommentTree(this.comments, null);
          console.log('最终评论树:', this.commentTree);
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
      const url = `http://192.168.1.103:3000/api/antique/upload_comments/${relicId}`; // 确保包含 relicId
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

    const uploadUrl: string = 'http://192.168.1.103:5000/upload_image'; // 假设这是上传图片的接口
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
    const url = `http://192.168.1.103:3000/api/antique/comments/like/${comment_id}`;
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
  // 添加点赞处理函数
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
      const serverUrl = 'http://192.168.1.103:3000/api/antique/like/' + this.antique.relic_id;
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
                  response = JSON.parse(trimmed) as LikeResponse // 使用trimmed进行解析
                  console.info('[like]成功解析响应数据:', JSON.stringify(response));
                } else {
                  console.error('[like]响应内容不是JSON格式:', data.result)
                }
              } catch (e) {
                console.error('[like]JSON解析失败:', e, '原始数据:', data.result)
              }
            } else if (typeof data.result === 'object') {
              response = data.result as LikeResponse
              console.info('[like]直接获取到对象响应:', JSON.stringify(response));
            }
          }

          if (response && typeof response.like_count === 'number') {
            // 请求成功，使用后端返回的最新点赞数更新底部显示
            this.likeCount = response.like_count;
            // 根据后端返回的点赞数判断是否已点赞
            // 如果当前点赞数大于之前记录的点赞数，说明是点赞操作
            // 如果当前点赞数小于之前记录的点赞数，说明是取消点赞操作
            this.isLiked = response.like_count > currentLikeCount;
            console.info('[like]点赞操作成功，点赞数更新为:', this.likeCount, '点赞状态:', this.isLiked);
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
      const serverUrl = 'http://192.168.1.103:3000/api/antique/favorite/' + this.antique.relic_id;
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
        `http://192.168.1.103:3000/api/antique/status/${this.antique.relic_id}?user_id=${userId}`,
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
          } catch(e) {
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
        `http://192.168.1.103:3000/api/antique/fstatus/${this.antique.relic_id}?user_id=${userId}`,
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
                          .width(36)
                          .height(36)
                          .borderRadius(18)
                          .backgroundColor('#FFF')
                          .margin({ right: 8, left: 0, top: 0, bottom: 0 })
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
                          Text(item.comment.content)
                            .fontSize(14)
                            .fontColor('#222')
                            .margin({ top: 2, bottom: 2, left: 0 })
                            .textAlign(TextAlign.Start)
                        }
                        .align(Alignment.Top)
                        // 按钮区（靠右，固定宽度）
                        Row({ space: 8 }) {
                          Button({ type: ButtonType.Circle }) {
                            Image($r('app.media.like'))
                              .width(18)
                              .height(18)
                          }
                          .onClick(() => this.likeComment(item.comment.comment_id))
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
                              this.replyParentId = item.comment.comment_id;
                              this.commentContent = `@${item.comment.user_name} `;
                            })
                            .fontSize(12)
                            .fontColor('#666')
                            .backgroundColor('transparent')
                            .padding({ left: 6, right: 0 })
                        }
                        .width(80) // 按钮区固定宽度
                      }
                      .width('100%') // Row占满整行

                      // 子评论
                      ForEach(item.replies, (reply: CommentTreeItem) => {
                        Row() {
                          // 头像
                          Image($r('app.media.avatar_default'))
                            .width(36)
                            .height(36)
                            .borderRadius(18)
                            .backgroundColor('#FFF')
                            .margin({ right: 6, left: 0, top: 0, bottom: 0 })
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
                              Image($r('app.media.like'))
                                .width(16)
                                .height(16)
                            }
                            .onClick(() => this.likeComment(reply.comment.comment_id))
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
                                this.replyParentId = reply.comment.comment_id;
                                this.commentContent = `@${reply.comment.user_name} `;
                              })
                              .fontSize(12)
                              .fontColor('#666')
                              .backgroundColor('transparent')
                              .padding({ left: 6, right: 6 })
                          }
                          .width(80) // 固定按钮区宽度
                          .align(Alignment.End)
                        }
                        .margin({ left: 42, bottom: 8, right: 0 }) // 头像与父评论用户名左对齐
                      })
                    })
                  }

                  .padding({ left: 0, right: 0, top: 8, bottom: 8 }) // 确保评论容器无内边距
                }
                .width('100%')
                .backgroundColor('#FFF')
                .padding({ left: 0, right: 0, top: 8, bottom: 8 })
              }.margin({ left: 0, right: 0 })
              .padding({ left: 0, right: 0 })
            }.margin({ left: 0, right: 0 })
            .padding({ left: 0, right: 0 })
          }.margin({ left: 0, right: 0 })
          .padding({ left: 0, right: 0 })
        }.margin({ left: 0, right: 0 })
        .padding({ left: 0, right: 0 ,bottom: 110})// 让出更多底部空间，确保评论完整显示
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
        .onClick(() => { this.handleImageSearch(); })
        .width(36)
        .height(36)
        .backgroundColor('transparent')

        // 评论输入框（固定宽度，防止撑满）
        TextInput({ placeholder: '发表评论...' })
          .onChange((value: string) => { this.commentContent = value; })
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
        .onClick(() => { this.submitComment(); })
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
