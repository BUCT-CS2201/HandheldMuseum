// pages/DynamicPublish.ets
import router from '@ohos.router';
import picker from '@ohos.file.picker';
import { DynamicItem } from './UserDynamic';
import fileio from '@ohos.fileio';
@Entry
@Component
struct DynamicPublish {
  @State content: string = '';
  @State selectedImages: string[] = [];
  @State publishLoading: boolean = false;
  @State showPlaceholder: boolean = true;
  @State hasFocus: boolean = false;
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
        .fontColor('#ff1f1414')
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
        .fontColor(this.canPublish ? '#007AFF' : '#ff211919')
        .margin({ right: 16 })
        .backgroundColor(Color.Transparent)
        .enabled(!this.publishLoading) // 禁用按钮防止重复提交
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
              .overlay(

              )

            Button() {
              Image($r('app.media.ic_close'))
                .width(25)
                .height(25)
            }
            .width(24)
            .height(24)
            .borderRadius(12)
            .backgroundColor('#99000000')
            .position({ x: '99%', y: '5%' })
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

  private pickImages() {
    const options = new picker.PhotoSelectOptions()
    options.maxSelectNumber = 9 - this.selectedImages.length
    options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE

    new picker.PhotoViewPicker().select(options)
      .then(selected => {
        this.selectedImages = [...this.selectedImages, ...selected.photoUris]
      })
  }


  private publishDynamic() {
    console.log('开始发布，已选图片数量:', this.selectedImages.length)

    // 打印选中的图片URI
    this.selectedImages.forEach((uri, index) => {
      console.log(`图片${index + 1}:`, uri)
    })

    // 创建动态对象（暂时保持空数组）
    const newDynamic = new DynamicItem(
      Date.now(),
      $r('app.media.default_avatar'),
      '当前用户',
      this.content,
      new Date().toLocaleString(),
      0,
      this.selectedImages, // ✅ 直接使用 string[]
      false,
      []
    )

    // 获取现有数据
    const currentDynamics = AppStorage.get<DynamicItem[]>('dynamics') || []
    console.log('存储前数据：', currentDynamics)

    // 更新存储
    AppStorage.setOrCreate('dynamics', [newDynamic, ...currentDynamics])

    // 验证存储结果
    const updated = AppStorage.get<DynamicItem[]>('dynamics')
    console.log('存储后数据：', updated)

    router.back()

  }
}