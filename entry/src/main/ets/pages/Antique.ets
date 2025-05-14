import http from '@ohos.net.http'
import router from '@ohos.router'
import { BusinessError } from '@kit.BasicServicesKit'
interface AntiqueItem {
  id: number;
  name: string;
  image: string;
  category: string;
  like_count: number;
}

interface LikeResponse {
  like_count: number;
}

@Entry
@Component
export default struct Antique {
  @State searchText: string = ''
  @State selectedCategory: string = '全部'
  @State antiqueList: Array<AntiqueItem> = []

  private categories: Array<string> = ['全部', '唐', '宋', '元', '明', '清', '杂项']
  private categoryKeywordsMap: Record<string, Array<string>> = {
    '唐': ['唐', '唐朝', '唐代'],
    '宋': ['宋', '宋朝'],
    '元': ['元', '元朝'],
    '明': ['明', '明朝'],
    '清': ['清', '清朝']
  }
  aboutToAppear() {
    this.fetchData()
  }
fetchData(): void {
  let httpRequest = http.createHttp()
  httpRequest.request(
    `http://localhost:3000/api/antique/list?ts=${Date.now()}`,
    { method: http.RequestMethod.GET },
    (err, data) => {
      if (!err && data && typeof data.result === 'string') {
        const newList: AntiqueItem[] = JSON.parse(data.result)
        this.antiqueList.splice(0, this.antiqueList.length, ...newList)
        console.log('最新antiqueList:', this.antiqueList)
      } else {
        console.error('请求错误或数据格式不正确:', err)
      }
    }
  )
}
  getFilteredList(): Array<AntiqueItem> {
    const search = this.searchText.trim().toLowerCase()

    return this.antiqueList.filter(item => {
      const nameMatch = item.name.toLowerCase().includes(search)

      const isInCategory = (() => {
        if (this.selectedCategory === '全部') return true

        if (this.selectedCategory === '杂项') {
          // 所有不属于常规分类关键词的视为杂项
          return !Object.values(this.categoryKeywordsMap).some(keywordList =>
          keywordList.some(keyword => item.category.includes(keyword))
          )
        }
        const keywords = this.categoryKeywordsMap[this.selectedCategory] || []
        return keywords.some(keyword => item.category.includes(keyword))
      })()

      return nameMatch && isInCategory
    })
  }
  // 添加点赞处理函数
    private handleLike(item: AntiqueItem): void {
    // 1. 乐观更新：本地先+1，UI立即变化
    item.like_count += 1
    let httpRequest = http.createHttp()
    httpRequest.request(
      `http://localhost:3000/api/antique/like/${item.id}`,
      { method: http.RequestMethod.POST },
      (err, data) => {
        let response: LikeResponse | null = null
        if (!err && data) {
          if (typeof data.result === 'string') {
            // 新增：打印原始内容
            console.log('点赞接口返回字符串:', data.result)
            // 新增：判断是否为合法JSON
            try {
              const trimmed = data.result.trim()
              if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
                response = JSON.parse(data.result) as LikeResponse
              } else {
                console.error('点赞接口返回内容不是JSON:', data.result)
              }
            } catch (e) {
              console.error('点赞接口返回内容不是合法JSON:', data.result)
            }
          } else if (typeof data.result === 'object') {
            response = data.result as LikeResponse
          }
        }
        if (response && typeof response.like_count === 'number') {
          item.like_count = response.like_count
        } else {
          // 3. 请求失败，回滚本地+1
          item.like_count -= 1
          console.error('点赞请求失败，已回滚:', err)
        }
      }
    )
  }
  build() {
    Column() {
      // 固定顶部：搜索框 + 分类标签
      // 搜索框区域
      Row() {
        Image($r('app.media.search_icon'))
          .width(20)
          .height(20)
          .margin({ left: 12, right: 8 })

        TextInput({
          placeholder: '搜索文物名称',
          text: this.searchText
        })
          .onChange(value => this.searchText = value)
          .backgroundColor('#FFFFFF')
          .borderRadius(8)
          .padding(8)
          .width('100%')
      }
      .height(40)
      .margin({ top: 16, left: 16, right: 16, bottom: 10 })
      .backgroundColor('#FFFFFF')
      .border({ width: 1, color: '#CCCCCC' })
      .borderRadius(8)
      .alignItems(VerticalAlign.Center)
      // 分类标签栏（每项：图标在上，文字在下）
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
          .onClick(() => this.selectedCategory = cat)
        },(cat:string)=>cat)
      }
      .margin({ left: 1, right: 1, bottom: 10 })
      // ✅ 滚动区域：文物卡片列表
      Scroll() {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          ForEach(this.getFilteredList(), (item: AntiqueItem) => {
            Column() {
              // 文物图片
              Image(item.image)
                .width('100%')
                .aspectRatio(1)
                .objectFit(ImageFit.Cover)
                .borderRadius(10)

              // 文物名称和点赞信息
              Row() {
                Text(item.name)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .margin({ top: 6, bottom: 6 })
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Row() {
                  Image($r('app.media.like'))
                    .width(20)
                    .height(20)
                    .margin({ right: 4 })
                    .onClick(() => this.handleLike(item))
                  Text(item.like_count.toString())
                    .fontSize(14)
                    .fontColor('#666666')
                }
                .alignItems(VerticalAlign.Center)
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              .padding({ left: 8, right: 8 })
            }
            .width('48%')  // 宽度略小于 50%，留出间距
            .padding({
              left: 12,
              right: 12,
              top: 0,
              bottom: 12
            })
            .width('48%')
            .padding(10)
            .backgroundColor('#FFFFFF')
            .borderRadius(10)
            .shadow({ radius: 3, color: '#cccccc', offsetX: 0, offsetY: 2 })
            .onClick(() => {
              router.pushUrl({
                url: 'pages/AntiqueDetail',
                params: { id: item.id.toString() }
              }).catch((err: BusinessError) => {
                console.error(`跳转失败: ${err.message}`)
              })
            })
          }, (item: AntiqueItem) => item.id.toString())
        }
        .width('100%')
      }
      .flexGrow(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F8FA')
  }
}