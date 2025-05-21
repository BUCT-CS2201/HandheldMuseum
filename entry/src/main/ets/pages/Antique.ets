import http from '@ohos.net.http'
import router from '@ohos.router'
import {BusinessError} from '@kit.BasicServicesKit'
import picker from '@ohos.file.picker'
import fs from '@ohos.file.fs'
import preferences from '@ohos.data.preferences';
import prompt from '@ohos.prompt';
import emitter from '@ohos.events.emitter';


interface AntiqueItem {
  id: number;
  name: string;
  image: string;
  category: string;
  like_count: number;
  views_count: number;  // 添加浏览量字段
}

interface ResponseId {
  similar_ids: Array<number>;
  count: number;
}

interface SearchResponse {
  code: number;
  message: string;
  data?: ResponseId;
}

// Interface for the overall response structure from /api/antique/status/:id
interface StatusApiResponse {
  result: string | StatusResultData; // result can be a string or the parsed data object
}

// Interface for the data inside the 'result' property (as returned by backend)
interface StatusResultData {
  relic_id: number;
}

// 添加DataSource类
class AntiqueDataSource implements IDataSource {
  private dataArray: Array<AntiqueItem> = []
  private listeners: DataChangeListener[] = []

  constructor(data: Array<AntiqueItem>) {
    this.dataArray = data
  }

  totalCount(): number {
    return this.dataArray.length
  }

  getData(index: number): AntiqueItem {
    return this.dataArray[index]
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    this.listeners.push(listener)
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index = this.listeners.indexOf(listener)
    if (index >= 0) {
      this.listeners.splice(index, 1)
    }
  }

  notifyDataChange(): void {
    this.listeners.forEach(listener => {
      listener.onDataChanged(this.totalCount())
    })
  }

  updateData(data: Array<AntiqueItem>): void {
    this.dataArray = data
    this.notifyDataChange()
  }
}

@Entry
@Component
export default struct Antique {
  @State searchText: string = ''
  @State selectedCategory: string = '全部'
  @State refreshKey: number = 0  // 新增强制刷新Key
  @State antiqueList: Array<AntiqueItem> = []
  @State filteredList: Array<AntiqueItem> = []
  @State isSearching: boolean = false
  @State private dataSource: AntiqueDataSource = new AntiqueDataSource([])

  private categories: Array<string> = ['全部', '唐', '宋', '元', '明', '清', '杂项']
  private categoryKeywordsMap: Record<string, Array<string>> = {
    '唐': [ '唐朝', '唐代'],
    '宋': [ '宋朝'],
    '元': [ '元朝'],
    '明': [ '明朝'],
    '清': [ '清朝']
  }
  private likeChangeSubscription = null;

  aboutToAppear(): void {
    this.fetchData()
    emitter.on('relicLikeChanged', () => {
      this.fetchData();
    });
  }

  fetchData(): void {
    let httpRequest = http.createHttp()
    httpRequest.request(
      `http://10.4.122.66:3000/api/antique/list?ts=${Date.now()}`,
      { method: http.RequestMethod.GET },
      (err, data) => {
        if (!err && data && typeof data.result === 'string') {
          try {
            const newList: AntiqueItem[] = JSON.parse(data.result);
            // 确保解析结果是一个数组
            if (Array.isArray(newList)) {
              console.info('[Antique] 获取到文物数据，数量:', newList.length);
              this.antiqueList = newList;
              this.updateFilteredData();
            } else {
              console.error('[Antique] 解析数据失败: 返回的不是数组');
            }
          } catch (e) {
            console.error('[Antique] 解析数据失败:', e)
          }
        } else {
          console.error('[Antique] 请求错误:', err)
        }
      }
    )
  }

  getFilteredList(): Array<AntiqueItem> {
    const search: string = this.searchText.trim().toLowerCase()
    const filteredList = this.antiqueList.filter(item => {
      const nameMatch: boolean = item.name.toLowerCase().includes(search)

      const isInCategory: boolean = (() => {
        if (this.selectedCategory === '全部') return true

        if (this.selectedCategory === '杂项') {
          // 所有不属于常规分类关键词的视为杂项
          return !Object.values(this.categoryKeywordsMap).some(keywordList =>
            keywordList.some(keyword => item.category.includes(keyword))
          )
        }
        const keywords: Array<string> = this.categoryKeywordsMap[this.selectedCategory] || []
        return keywords.some(keyword => item.category.includes(keyword))
      })()

      return nameMatch && isInCategory
    })

    console.info(`[Antique] 过滤结果: 搜索="${search}", 分类="${this.selectedCategory}", 结果数量=${filteredList.length}`)
    return filteredList
  }

  private updateFilteredData(): void {
    this.filteredList = this.getFilteredList()
    this.dataSource.updateData(this.filteredList)
    this.dataSource.notifyDataChange()
    this.refreshKey += 1  // 在数据更新后增加refreshKey
  }
  @State toastMessage: string = '';
  showToast(message: string) {
    this.toastMessage = message;
    setTimeout(() => {
      prompt.showToast({ message: this.toastMessage });
    }, 0);
  }

  private async updateViews(item: AntiqueItem): Promise<void> {
    try {
      const pref = await preferences.getPreferences(getContext(), 'userInfo');
      const userId = await pref.get('userId', 0) as number;

      if (!userId || typeof userId !== 'number') {
        console.error('未获取到用户ID，无法记录浏览历史');
        return;
      }

      // 本地预加 +1（乐观更新）
      item.views_count += 1;

      let httpRequest = http.createHttp();
      httpRequest.request(
        `http://10.4.122.66:3000/api/antique/views/${item.id}`,
        {
          method: http.RequestMethod.POST,
          header: { 'Content-Type': 'application/json' },
          extraData: JSON.stringify({ user_id: userId }),
        },
        (err, data) => {
          if (err) {
            item.views_count -= 1;
            console.error('更新浏览记录失败:', JSON.stringify(err));
          }
        }
      );
    } catch (err) {
      console.error('获取用户ID失败:', err);
    }
  }

  // 处理图片选择
  async handleImageSearch(): Promise<void> {
    try {
      // 创建图片选择器
      const photoPicker: picker.PhotoViewPicker = new picker.PhotoViewPicker();
      const options: picker.PhotoSelectOptions = {
        MIMEType: picker.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      };
      const result: picker.PhotoSelectResult = await photoPicker.select(options);

      if (result && result.photoUris && result.photoUris.length > 0) {
        this.isSearching = true;
        await this.uploadAndSearch(result.photoUris[0]);
      }
      else {
        console.info('没有上传图片');
      }
    } catch (error) {
      console.error('选择图片失败:', error);
    }
  }

  // 上传图片并搜索
  async uploadAndSearch(imageUri: string): Promise<void> {
    try {
      console.info('开始上传图片，图片URI:', imageUri);
      let httpRequest: http.HttpRequest = http.createHttp();

      // 读取图片文件
      console.info('开始读取图片文件');
      try {
        let resultPhoto = fs.openSync(imageUri, fs.OpenMode.READ_ONLY);
        let fileTemp = fs.openSync(getContext().filesDir + resultPhoto.name, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
        let imageUri_1: string = fileTemp.path;
        fs.copyFileSync(resultPhoto.fd, fileTemp.fd);
        fs.closeSync(resultPhoto);
        fs.closeSync(fileTemp);
        console.info('开始上传图片，图片URI:', imageUri_1);

        const uploadUrl: string = 'http://10.4.122.66:5000/search_similar';
        const response: http.HttpResponse = await httpRequest.request(uploadUrl, {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'multipart/form-data',
            'Connection': 'keep-alive'
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

        console.info('收到服务器响应，状态码:', response.responseCode);
        console.info('响应内容:', response.result);  // 打印响应内容

        if (response.responseCode === 200 && response.result instanceof ArrayBuffer) {
          // 使用 Uint8Array 将 ArrayBuffer 转换为字符串
          const uint8Array: Uint8Array = new Uint8Array(response.result);
          let resultString: string = '';

          // 使用 for 循环构建字符串
          for (let i = 0; i < uint8Array.length; i++) {
            resultString += String.fromCharCode(uint8Array[i]);
          }

          try {
            const result: SearchResponse = JSON.parse(resultString);
            console.info('解析响应数据:', JSON.stringify(result));
            if (result.code === 200 && result.data && result.data.similar_ids) {
              console.info('找到相似图片，ID列表:', result.data.similar_ids);
              // 跳转到搜索结果页面
              router.pushUrl({
                url: 'pages/SearchResult',
                params: { similarIds: result.data.similar_ids }
              });
            } else {
              console.error('搜索失败:', result.message);
            }
          } catch (jsonError) {
            console.error('JSON 解析失败:', jsonError);
          }
        } else {
          console.error('响应状态码不为200或结果不是字符串');
        }
      } catch (fileError) {
        console.error('文件操作失败:', fileError);
      }
    } catch (error) {
      console.error('上传图片失败，错误详情:', error);
    } finally {
      this.isSearching = false;
      console.info('搜索过程结束');
    }
  }

  build() {
    Column() {
      // 搜索框区域
      Row() {
        // 图像识别按钮
        Image($r('app.media.find_same'))
          .width(20)
          .height(20)
          .margin({ left: 12, right: 8 })
          .onClick(() => this.handleImageSearch())

        // 搜索图标
        Image($r('app.media.search_icon'))
          .width(20)
          .height(20)
          .margin({ right: 8 })

        // 输入框 + 搜索按钮组合
        Row() {
          TextInput({
            placeholder: '搜索文物名称',
            text: this.searchText
          })
            .onChange((value: string) => {
              this.searchText = value
            })
            .type(InputType.Normal)
            .backgroundColor('#FFFFFF')
            .borderRadius(8)
            .padding({ left: 10, right: 10, top: 8, bottom: 8 })
            .layoutWeight(1)

          Button('搜索')
            .onClick(() => this.updateFilteredData())
            .fontSize(14)
            .margin({ left: 6, right: 0 })
            .backgroundColor('#DAA520')
            .fontColor('#FFFFFF')
            .height(36)
            .borderRadius(6)
        }
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .padding({ left: 6, right: 6 })
        .width('70%')
        .height(40)
      }
      .height(40)
      .margin({ top: 16, left: 16, right: 16, bottom: 10 })
      .backgroundColor('#FFFFFF')
      .border({ width: 1, color: '#CCCCCC' })
      .borderRadius(8)
      .alignItems(VerticalAlign.Center)

      // 分类标签栏
      Row({ space: 8 }) {
        ForEach(this.categories, (cat: string) => {
          Column() {
            Image(
              cat === '全部' ? $r('app.media.tag_all') :
                cat === '唐'   ? $r('app.media.tag_tang') :
                  cat === '宋'   ? $r('app.media.tag_song') :
                    cat === '元'   ? $r('app.media.tag_yuan') :
                      cat === '明'   ? $r('app.media.tag_ming') :
                        cat === '清'   ? $r('app.media.tag_qing') :
                        $r('app.media.tag_misc')
            )
            .width(25)
            .height(24)
            .margin({ bottom: 4 })

            Text(cat)
              .fontSize(12)
              .fontColor('#333333')
          }
          .width(39)
          .padding(8)
          .backgroundColor('#FFFFFF')
          .border({
            width: 2,
            color: this.selectedCategory === cat ? '#DAA520' : 'transparent'  // 选中时加边框
          })
          .borderRadius(20)
          .onClick(() => {
            this.selectedCategory = cat
            this.updateFilteredData()
            this.refreshKey += 1  // 强制刷新
          })
        }, (cat: string, index: number) => `${index}-${cat}`)
      }
      .key(`category-tags-${this.refreshKey}`) // 让整个Row重新渲染
      .margin({ left: 1, right: 1, bottom: 10 })

      // 列表部分
      List() {
        LazyForEach(this.dataSource, (item: AntiqueItem) => {
          ListItem() {
            Column() {
              Image(item.image)
                .width('100%')
                .height(120)
                .borderRadius(8)
                .objectFit(ImageFit.Cover)
                .onClick(() => {
                  this.updateViews(item)  // 点击时更新浏览量
                  router.pushUrl({
                    url: 'pages/AntiqueDetail',
                    params: { id: item.id }
                  })
                })
              Text(item.name)
                .fontSize(14)
                .margin({ top: 8 })
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Row() {
                Image($r('app.media.like'))
                  .width(16)
                  .height(16)
                  .margin({ right: 4 })
                Text(item.like_count.toString())
                  .fontSize(12)
                  .fontColor('#666666')
                  .margin({ right: 12 })
                Image($r('app.media.views'))  // 添加浏览量图标
                  .width(16)
                  .height(16)
                  .margin({ right: 4 })
                Text(item.views_count.toString())  // 显示浏览量
                  .fontSize(12)
                  .fontColor('#666666')
              }
              .backgroundColor(Color.Transparent)
              .width('100%')
              .justifyContent(FlexAlign.Start)
              .margin({ top: 4 })
            }
            .width('100%')
            .padding(10)
            .backgroundColor('#FFFFFF')
            .borderRadius(10)
            .shadow({ radius: 3, color: '#cccccc', offsetX: 0, offsetY: 2 })
          }
        }, (item: AntiqueItem) => item.id.toString())
      }
      .key(`antique-list-${this.refreshKey}`)  // 添加key以强制刷新List
      .lanes(2)
      .padding(16)
      .cachedCount(6)
      .flexGrow(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F8FA')
  }

  onPageHide() {
    if (this.likeChangeSubscription) {
      emitter.off('relicLikeChanged', this.likeChangeSubscription);
      this.likeChangeSubscription = null;
    }
  }
}