import http from '@ohos.net.http'

interface AntiqueItem {
  id: number;
  name: string;
  image: string;
  category: string;
}

@Component
export default struct Antique {
  @State searchText: string = ''
  @State selectedCategory: string = '全部'
  @State antiqueList: Array<AntiqueItem> = []

  private categories: Array<string> = ['全部', '唐', '宋', '元', '明', '清','杂项']

  aboutToAppear() {
    this.fetchData()
  }

  fetchData(): void {
    let httpRequest = http.createHttp()
    httpRequest.request(
      'http://192.168.1.100:3000/api/antique/list',
      { method: http.RequestMethod.GET },
      (err, data) => {
        if (!err && typeof data.result === 'string') {
          this.antiqueList = JSON.parse(data.result)
        } else {
          console.error('请求错误或数据格式不正确:', err)
        }
      }
    )
  }

  getFilteredList(): Array<AntiqueItem> {
    return this.antiqueList.filter(item =>
    (this.selectedCategory === '全部' || item.category === this.selectedCategory) &&
    item.name.includes(this.searchText)
    )
  }

  build() {
    Column() {
      // ✅ 固定顶部：搜索框 + 分类标签
      Column() {
        TextInput({
          placeholder: '搜索文物名称',
          text: this.searchText
        })
          .onChange(value => this.searchText = value)
          .margin({ top: 0, left: 16, right: 16 })
          .padding(10)
          .border({ width: 1, color: '#cccccc' })
          .borderRadius(8)

        Row({ space: 8 }) {
          ForEach(this.categories, (cat: string) => {
            Button(cat)
              .type(ButtonType.Normal)
              .backgroundColor(this.selectedCategory === cat ? '#1698CE' : '#EEEEEE')
              .fontColor(this.selectedCategory === cat ? '#FFFFFF' : '#000000')
              .padding({ left: 8, right: 8 })
              .onClick(() => this.selectedCategory = cat)
          })
        }
        .margin({ top: 0, left: 16, right: 16, bottom: 10 })
      }

      // ✅ 滚动区域：文物卡片列表
      // 文物卡片滑动展示
      Scroll() {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          ForEach(this.getFilteredList(), (item: AntiqueItem) => {
            Column() {
              Image(item.image)
                .width('100%')
                .aspectRatio(1)
                .objectFit(ImageFit.Cover)
                .borderRadius(10)

              Text(item.name)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .margin({ top: 6, bottom: 6 })
            }
            .width('48%')  // 宽度略小于 50%，留出间距
            .padding(10)
            .backgroundColor('#FFFFFF')
            .borderRadius(10)
            .shadow({ radius: 3, color: '#cccccc', offsetX: 0, offsetY: 2 })
          })
        }
        .width('100%')
      }

      .margin({ bottom: 30 })
    }
    .align(Alignment.TopStart)
    .backgroundColor('#F7F8FA')
  }
}
