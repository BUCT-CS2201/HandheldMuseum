// pages/DynamicPublish.ets
import router from '@ohos.router';
import picker from '@ohos.file.picker';
import fileio from '@ohos.fileio';
import http from '@ohos.net.http';
import { DynamicItem, UploadImageItem } from '../common/types/DynamicTypes';
import fs from '@ohos.file.fs';
import preferences from '@ohos.data.preferences';
import prompt from '@ohos.prompt';

// 修改路径为 HarmonyOS 标准缓存路径
const UPLOAD_DIR = 'file:///data/user/0/com.example.app/cache/uploads/DynamicUploads/';

interface FetchResult {
  result: string | object;
  comment_id?: number;
}

interface GeneratedTypeLiteralInterface_2 {
  comment_id: number;
}

@Entry
@Component
struct DynamicPublish {
  @State content: string = '';
  @State selectedImages: string[] = [];
  @State publishLoading: boolean = false;
  @State showPlaceholder: boolean = true;
  @State hasFocus: boolean = false;
  @State errorMessage: string = '';
  @State showError: boolean = false;

  // 获取应用上下文
  private context = getContext(this);

  build() {
    Column() {
      // 顶部工具栏
      this.HeaderBar()

      // 内容编辑区
      Column() {
        Stack() {
          TextInput({ placeholder: '分享你的发现...' })
            .height(150)
            .width('94%')
            .margin(10)
            .fontSize(16)
            .fontColor('#333333')
            .backgroundColor('#FFFFFF')
            .borderRadius(8)
            .placeholderColor('#999999')
            .caretColor('#007AFF')
            .onChange((value: string) => {
              console.info('TextInput 内容变化:', value)
              this.showPlaceholder = value === ''
              this.content = value
              console.info('更新后的 content:', this.content)
            })
            .onEditChange((isEditing: boolean) => {
              this.hasFocus = isEditing
            })
        }

        // 图片预览区
        this.ImagePreview()

        // 错误提示
        if (this.showError) {
          Text(this.errorMessage)
            .fontSize(14)
            .fontColor('#FF3B30')
            .margin({ top: 8 })
            .onClick(() => {
              this.showError = false;
            })
        }
      }
      .layoutWeight(1)

      // 底部操作栏
      this.ActionBar()
    }
    .height('100%')
    .backgroundColor('#F8F8F8')
  }

  @Builder
  HeaderBar() {
    Row() {
      Button('取消')
        .fontSize(16)
        .fontColor('#333333')
        .backgroundColor(Color.Transparent)
        .margin({ left: 16 })
        .onClick(() => router.back())

      Text('发布动态')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Button('发布')
        .fontSize(16)
        .fontColor((this.content.trim().length > 0 || this.selectedImages.length > 0) ? '#007AFF' : '#999999')
        .margin({ right: 16 })
        .backgroundColor(Color.Transparent)
        .enabled((this.content.trim().length > 0 || this.selectedImages.length > 0) && !this.publishLoading)
        .onClick(() => this.publishDynamic())
    }
    .height(56)
    .width('100%')
    .border({ width: 0.5, color: '#EEEEEE' })
  }

  @Builder
  ImagePreview() {
    Grid() {
      ForEach(this.selectedImages, (uri: string, index: number) => {
        GridItem() {
          Stack() {
            Image(uri)
              .width('100%')
              .aspectRatio(1)
              .objectFit(ImageFit.Cover)
              .borderRadius(8)

            Button() {
              Image($r('app.media.ic_close'))
                .width(25)
                .height(25)
            }
            .width(24)
            .height(24)
            .borderRadius(12)
            .backgroundColor('#99000000')
            .position({ x: '95%', y: '5%' })
            .onClick(() => {
              this.selectedImages.splice(index, 1)
              this.selectedImages = [...this.selectedImages]
            })
          }
        }
      })

      if (this.selectedImages.length < 9) {
        GridItem() {
          Button() {
            Image($r('app.media.ic_add_image'))
              .width(60)
              .height(60)
          }
          .width(80)
          .height(80)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .onClick(() => this.pickImages())
        }
      }
    }
    .columnsTemplate('1fr 1fr 1fr')
    .columnsGap(8)
    .rowsGap(8)
    .margin(10)
  }

  @Builder
  ActionBar() {
    Row() {
      Text('已选图片')
        .fontSize(14)
        .fontColor('#666666')

      Text(`${this.selectedImages.length}/9`)
        .fontSize(14)
        .fontColor('#007AFF')
        .margin({ left: 8 })
    }
    .width('100%')
    .padding(16)
    .justifyContent(FlexAlign.Start)
  }

  private async pickImages() {
    try {
      const options = new picker.PhotoSelectOptions()
      options.maxSelectNumber = 9 - this.selectedImages.length
      options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE

      const photoPicker = new picker.PhotoViewPicker()
      const result = await photoPicker.select(options)

      if (result && result.photoUris && Array.isArray(result.photoUris)) {
        // 确保不超过9张图片
        const remainingSlots = 9 - this.selectedImages.length
        const newImages = result.photoUris.slice(0, remainingSlots)
        this.selectedImages = [...this.selectedImages, ...newImages]
      } else {
        console.warn('未选择图片或选择结果格式不正确')
      }
    } catch (error) {
      console.error('图片选择失败:', error)
      this.showError = true
      this.errorMessage = '图片选择失败，请重试'
    }
  }

  private async publishDynamic() {
    console.info('开始发布动态')
    if (!(this.content.trim().length > 0 || this.selectedImages.length > 0)) {
      console.info('发布条件不满足')
      this.showError = true;
      this.errorMessage = '请输入内容或选择图片';
      return;
    }

    this.publishLoading = true;
    try {
      const userId = await this.getUserId();
      if (!userId) {
        this.showToast('请先登录');
        return;
      }

      // 1. 提交动态内容（使用与评论相同的接口）
      const httpRequest = http.createHttp();
      const url = 'http://10.4.52.124:3000/api/antique/upload_comments/0'; // relicId 设为 0 表示动态
      const response: FetchResult = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        expectDataType: http.HttpDataType.OBJECT,
        extraData: JSON.stringify({
          user_id: userId,
          content: this.content,
          parent_id: 0
        })
      }) as FetchResult;

      // 2. 处理响应并上传图片
      if (response && response.result && typeof response.result === 'object') {
        const commentId = (response.result as GeneratedTypeLiteralInterface_2).comment_id;

        // 3. 上传图片（使用Python Flask接口）
        if (this.selectedImages.length > 0) {
          await this.uploadImagesWithCommentId(commentId);
        }

        this.showToast('动态已发布，审核通过后将显示');
        this.content = '';
        this.selectedImages = [];
        router.back();
      } else {
        throw new Error('提交服务器失败');
      }
    } catch (error) {
      console.error('发布失败:', error);
      this.showError = true;
      this.errorMessage = error.message || '发布失败，请重试';
    } finally {
      this.publishLoading = false;
    }
  }

  private async uploadImagesWithCommentId(commentId: number): Promise<void> {
    const userId = await this.getUserId();
    if (this.selectedImages.length === 0) {
      return;
    }

    // 使用Python Flask接口上传图片
    const uploadUrl: string = 'http://10.4.52.124:5000/upload_image';
    const httpRequest: http.HttpRequest = http.createHttp();

    console.info('准备上传图片，selectedImages:', JSON.stringify(this.selectedImages));

    for (const imageUri of this.selectedImages) {
      try {
        console.info('原始 imageUri:', imageUri);
        // 读取图片文件
        let resultPhoto = fs.openSync(imageUri, fs.OpenMode.READ_ONLY);
        console.info('resultPhoto:', JSON.stringify(resultPhoto));
        let fileTemp = fs.openSync(getContext().filesDir + resultPhoto.name, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
        console.info('fileTemp:', JSON.stringify(fileTemp));
        let imageUri_1: string = fileTemp.path;
        fs.copyFileSync(resultPhoto.fd, fileTemp.fd);
        fs.closeSync(resultPhoto);
        fs.closeSync(fileTemp);
        console.info('最终上传路径 imageUri_1:', imageUri_1);

        // 使用Python Flask接口上传图片
        const response: http.HttpResponse = await httpRequest.request(uploadUrl, {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'multipart/form-data',
            'Connection': 'keep-alive',
            'user_id': userId.toString(),
            'comment_id': commentId.toString()
          },
          expectDataType: http.HttpDataType.ARRAY_BUFFER,
          multiFormDataList: [
            {
              name: 'image',
              contentType: 'image/jpeg',
              filePath: imageUri_1,
              remoteFileName: 'file.jpg'
            },
          ],
        });

        console.info('上传返回:', JSON.stringify(response));

        if (response.responseCode !== 200) {
          throw new Error('图片上传失败');
        }
      } catch (error) {
        console.error('图片上传失败:', error);
        throw new Error(error.message || String(error));
      }
    }
  }

  private async getUserId(): Promise<number> {
    try {
      const userPreferences = await preferences.getPreferences(getContext(), 'userInfo');
      const userId: number = await userPreferences.get('userId', 0) as number;
      return userId;
    } catch (error) {
      console.error('获取用户ID失败:', error);
      return 0;
    }
  }

  private showToast(message: string) {
    prompt.showToast({ message: message });
  }
}