import router from "@ohos.router";

export { CommentItem, DynamicItem };
// 评论数据结构
class CommentItem {
  id: number;
  user: string;
  content: string;
  time: string;

  constructor(id: number, user: string, content: string, time: string) {
    this.id = id;
    this.user = user;
    this.content = content;
    this.time = time;
  }
}

// 动态数据结构
class DynamicItem {
  id: number;
  avatar: Resource;
  username: string;
  content: string;
  time: string;
  likes: number;
  isLiked: boolean;
  images?: string[]; // 更新为 string[]
  comments: CommentItem[];

  constructor(
    id: number,
    avatar: Resource,
    username: string,
    content: string,
    time: string,
    likes: number,
    images?: string[],
    isLiked: boolean = false,
    comments: CommentItem[] = []
  ) {
    this.id = id;
    this.avatar = avatar;
    this.username = username;
    this.content = content;
    this.time = time;
    this.likes = likes;
    this.images = images;
    this.isLiked = isLiked;
    this.comments = comments;
  }
}

// 临时测试数据
const mockData: DynamicItem[] = [
  new DynamicItem(
    1,
    $r('app.media.user_avatar1'),
    '考古爱好者',
    '今天在故宫看到了这件青花瓷，釉色太美了！',
    '2小时前',
    15,
    [
      'app.media.dynamic_img1',
      'app.media.dynamic_img2'
    ],
    false,
    [
      new CommentItem(1, '博物馆迷', '这件文物在哪个展厅？', '1小时前'),
      new CommentItem(2, '历史学生', '釉色工艺确实精湛！', '30分钟前')
    ]
  ),
  new DynamicItem(
    2,
    $r('app.media.user_avatar2'),
    '历史研究员',
    '分享一本关于青铜器的好书：《中国古代青铜器鉴赏》',
    '5小时前',
    8,
    ['app.media.dynamic_img3'],
    true
  )
];

@Entry
@Component
struct UserDynamic {
  @StorageLink('dynamics') dynamics: DynamicItem[] = mockData
  aboutToAppear() {
    // 初始化加载数据
    if (!AppStorage.get('dynamics')) {
      AppStorage.setOrCreate('dynamics', mockData);
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('用户动态')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)

        Button('+ 发布')
          .width(100)        // 明确按钮尺寸
          .height(56)        // 符合Material Design规范
          .fontSize(18)
          .fontColor('#FFFFFF')
          .backgroundColor('#ff0f0f10')
          .fontWeight(FontWeight.Bold)
          .borderRadius(28)  // 椭圆形参数（高度56时半径28）
          .onClick(() => {
            router.pushUrl({
              url: 'pages/DynamicPublish'
            })
          })
      }
      .padding(10)
      .width('100%')

      // 动态列表
      List({ space: 12 }) {
        ForEach(this.dynamics, (item: DynamicItem, index?: number) => {
          ListItem() {
            DynamicItemComponent({
              item: item,
              onLike: (isLiked: boolean) => {
                if (typeof index === 'number') {
                  this.dynamics[index] = new DynamicItem(
                    item.id,
                    item.avatar,
                    item.username,
                    item.content,
                    item.time,
                    isLiked ? item.likes - 1 : item.likes + 1,
                    item.images,
                    !isLiked,
                    item.comments // 👍 保留原有评论，不改动
                  )

                }
              },
              onComment: (newComment: CommentItem) => {
                if (typeof index === 'number') {
                  const updatedItem = new DynamicItem(
                    item.id,
                    item.avatar,
                    item.username,
                    item.content,
                    item.time,
                    item.likes,
                    item.images,
                    item.isLiked,
                    [...item.comments, newComment] // 👈 更新评论数组
                  )
                  this.dynamics[index] = updatedItem; // ✅ 触发响应式更新
                  AppStorage.set('dynamics', this.dynamics); // ✅ 持久化存储更新
                }
              }
            })
          }
          .padding(8)
        })
      }
      .width('100%')
      .layoutWeight(1)
      .divider({ strokeWidth: 0.5, color: '#eeeeee' })
    }
    .backgroundColor('#F8F8F8')
  }
  onPageShow() {
    const storedDynamics = AppStorage.get<DynamicItem[]>('dynamics');
    this.dynamics = storedDynamics ? [...storedDynamics] : []; // 修正变量名拼写
  }
}

@Component
struct DynamicItemComponent {
  @Prop item: DynamicItem
  private onLike: (isLiked: boolean) => void = () => {}
  private onComment: (comment: CommentItem) => void = () => {}
  @State showComments: boolean = false
  @State showCommentDialog: boolean = false
  @State commentText: string = ''

  build() {
    Column() {
      // 卡片容器
      Column() {
        // 用户信息
        Row() {
          Image(this.item.avatar)
            .width(48)
            .height(48)
            .borderRadius(24)
            .margin({ right: 12 })

          Column() {
            Text(this.item.username)
              .fontSize(16)
              .fontColor('#333333')
              .fontWeight(FontWeight.Medium)

            Text(this.item.time)
              .fontSize(12)
              .fontColor('#999999')
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')

        // 动态内容
        Text(this.item.content)
          .fontSize(15)
          .fontColor('#444444')
          .lineHeight(20)
          .margin({ top: 12, bottom: 8 })
          .width('100%')

        // 图片展示
        if (this.item.images && this.item.images.length > 0) {
          Grid() {
            ForEach(this.item.images, (imgPath: string) => {
              GridItem() {
                // 判断是否为本地图片路径
                if(this.getImagePath(imgPath)==false) {
                  Image($r(imgPath))// 使用 $r 处理字符串路径
                    //Image(this.getImagePath(imgPath)) // 直接传递处理后的路径
                    .width('100%')
                    .aspectRatio(1)
                    .objectFit(ImageFit.Cover)
                    .borderRadius(8)
                    .transition({
                      type: TransitionType.All,
                      scale: { x: 0.95, y: 0.95 }
                    })
                }
                else{
                  Image(imgPath)// 使用 $r 处理字符串路径
                    //Image(this.getImagePath(imgPath)) // 直接传递处理后的路径
                    .width('100%')
                    .aspectRatio(1)
                    .objectFit(ImageFit.Cover)
                    .borderRadius(8)
                    .transition({
                      type: TransitionType.All,
                      scale: { x: 0.95, y: 0.95 }
                    })
                }
              }
            })
          }
          .columnsTemplate('1fr 1fr 1fr')
          .rowsGap(6)
          .columnsGap(6)
          .margin({ top: 8 })
        }

        // 互动按钮
        Row() {
          // 点赞按钮
          Button({ type: ButtonType.Normal }) {
            Row() {
              Image($r('app.media.ic_like'))
                .width(20)
                .height(20)
                .fillColor(this.item.isLiked ? '#FF3A30' : '#666666')

              Text(this.item.likes.toString())
                .fontColor(this.item.isLiked ? '#FF3A30' : '#666666')
                .margin({ left: 4 })
            }
          }
          .onClick(() => {
            animateTo({
              duration: 200,
              curve: Curve.EaseInOut
            }, () => {
              this.onLike(this.item.isLiked)
            })
          })
          .backgroundColor(Color.Transparent)
          .padding(6)
          .margin({ right: 20 })

          // 评论按钮
          Button({ type: ButtonType.Normal }) {
            Row() {
              Image($r('app.media.ic_comment'))
                .width(20)
                .height(20)
                .fillColor('#666666')

              Text('评论')
                .fontColor('#666666')
                .margin({ left: 4 })
            }
          }
          .onClick(() => this.showCommentDialog = true)
          .backgroundColor(Color.Transparent)
          .padding(6)
        }
        .margin({ top: 12 })

        // 评论列表
        if (this.showComments && this.item.comments.length > 0) {
          Column() {
            ForEach(this.item.comments, (comment: CommentItem) => {
              Column() {
                Row() {
                  Text(comment.user)
                    .fontColor('#007AFF')
                    .fontSize(14)

                  Text(comment.content)
                    .fontColor('#333333')
                    .fontSize(14)
                    .margin({ left: 8 })
                }
                .width('100%')

                Text(comment.time)
                  .fontSize(12)
                  .fontColor('#999999')
                  .margin({ top: 4 })
              }
              .padding(8)
            })
          }
          .margin({ top: 12 })
        }

        // 展开/收起按钮
        if (this.item.comments.length > 0) {
          Text(this.showComments ? '收起评论' : `查看全部${this.item.comments.length}条评论`)
            .fontColor('#007AFF')
            .fontSize(12)
            .margin({ top: 8 })
            .onClick(() => this.showComments = !this.showComments)
        }
      }
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .shadow({ radius: 8, color: '#10000000', offsetX: 0, offsetY: 2 })

      // 评论弹窗
      if (this.showCommentDialog) {

        Column() {
          // 自定义输入提示
          Text('发表评论')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#222222')
            .margin({ bottom: 12 })

          TextArea({
            text: this.commentText,
            placeholder: '请输入你的评论…',
          })
            .onChange((value: string) => {
              this.commentText = value
            })
            .width('100%')
            .height(120)
            .fontSize(16)
            .border({ width: 1, color: '#CCCCCC' })
            .borderRadius(10)
            .padding(10)
            .margin({ bottom: 20 })

          Row() {
            Button('取消')
              .width(130)
              .height(40)
              .backgroundColor('#DDDDDD')
              .fontColor('#333333')
              .borderRadius(20)
              .onClick(() => this.showCommentDialog = false)

            Button('发布')
              .width(130)
              .height(40)
              .backgroundColor('#007AFF')
              .fontColor('#ffffff')
              .borderRadius(20)
              .onClick(() => this.handleCommentSubmit())
          }
          .justifyContent(FlexAlign.SpaceBetween)
        }
        .padding(24)
        .width('80%')
        .backgroundColor('#ffffff')
        .borderRadius(16)
        .shadow({ radius: 12, color: '#00000022', offsetX: 0, offsetY: 4 })
      }
    }
    .padding(10)
  }

  private handleCommentSubmit(): void {
    console.log("发布评论按钮被点击");
    if (this.commentText.trim()) {
      const newComment = new CommentItem(
        Date.now(),
        '当前用户',
        this.commentText,
        '刚刚'
      )
      if (this.onComment) {
        this.onComment(newComment) // 确保调用传入的回调
      }
      this.commentText = ''
      this.showCommentDialog = false // 关闭弹窗
      this.showComments = true   // 自动展开评论列表
    }
  }
  // 图片路径处理函数
  private getImagePath(imgPath: string): boolean {
    // 判断是否为文件路径
    if (imgPath.startsWith('file://')) {
      return true; // 如果是文件路径，直接返回
    } else {
      return false; // 强制转换为字符串
    }
  }


}