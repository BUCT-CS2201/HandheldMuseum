// pages/DynamicPublish.ets
import router from '@ohos.router';
import picker from '@ohos.file.picker';
import fileio from '@ohos.fileio';
import http from '@ohos.net.http';
import { DynamicItem, UploadImageItem } from '../common/types/DynamicTypes';
import fs from '@ohos.file.fs';

// 修改路径为 HarmonyOS 标准缓存路径
const UPLOAD_DIR = 'file:///data/user/0/com.example.app/cache/uploads/';

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
              this.showPlaceholder = value === ''
              this.content = value
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
        .fontColor(this.canPublish ? '#007AFF' : '#999999')
        .margin({ right: 16 })
        .backgroundColor(Color.Transparent)
        .enabled(this.canPublish && !this.publishLoading)
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

  private get canPublish(): boolean {
    return this.content.trim().length > 0 || this.selectedImages.length > 0
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
    if (!this.canPublish) {
      this.showError = true;
      this.errorMessage = '请输入内容或选择图片';
      return;
    }

    this.publishLoading = true;
    try {
      // 1. 上传图片到本地缓存目录
      const savedImages = await this.saveImagesToLocal();
      if (savedImages.length === 0 && this.selectedImages.length > 0) {
        throw new Error('图片保存失败');
      }

      // 2. 创建动态对象
      const newDynamic = new DynamicItem(
        Date.now(),
        await this.getCurrentUsername(),
        this.content,
        new Date().toISOString(),
        0,
        savedImages,
        [],
        false,
        await this.getCurrentUserAvatar(),
        false
      );

      // 3. 调用API提交到服务器
      const success = await this.submitToServer(newDynamic);
      if (!success) {
        throw new Error('提交服务器失败');
      }

      // 4. 更新本地存储
      const currentDynamics = AppStorage.get<DynamicItem[]>('dynamics') || [];
      AppStorage.setOrCreate('dynamics', [newDynamic, ...currentDynamics]);

      router.back();
    } catch (error) {
      console.error('发布失败:', error);
      this.showError = true;
      this.errorMessage = error.message || '发布失败，请重试';
    } finally {
      this.publishLoading = false;
    }
  }

  private async saveImagesToLocal(): Promise<string[]> {
    const savedPaths: string[] = []
    for (const uri of this.selectedImages) {
      try {
        const fileName = `${Date.now()}-${Math.random().toString(36).substr(2, 9)}.jpg`
        const destPath = `${UPLOAD_DIR}${fileName}`

        await fs.copyFile(uri, destPath)
        savedPaths.push(destPath)
      } catch (error) {
        console.error('图片保存失败:', error)
      }
    }
    return savedPaths
  }

  private async getCurrentUsername(): Promise<string> {
    // 从AppStorage获取当前用户信息
    return AppStorage.get<string>('currentUsername') || '当前用户'
  }

  private async getCurrentUserAvatar(): Promise<Resource> {
    // 从AppStorage获取用户头像
    return AppStorage.get<Resource>('currentUserAvatar') || $r("app.media.default_avatar")
  }

  private async submitToServer(dynamic: DynamicItem): Promise<boolean> {
    try {
      let httpRequest = http.createHttp();
      let response = await httpRequest.request(
        "http://localhost:3000/api/dynamic/publish",
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json'
          },
          extraData: JSON.stringify({
            content: dynamic.content,
            images: dynamic.images.map(uri => {
              const fileName = uri.split('/').pop();
              const uploadImage: UploadImageItem = {
                image_id: fileName?.split('.')[0] || '',
                suffix: fileName?.split('.')[1] || 'jpg'
              };
              return uploadImage;
            })
          })
        }
      );
      return response.responseCode === 200;
    } catch (error) {
      console.error('API请求失败:', error)
      return false
    }
  }
}