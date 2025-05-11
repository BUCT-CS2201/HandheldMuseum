import Antique from './Antique'
import Museum from './Museum'
@Entry
@Component
struct Index {
  //记录当前界面下标
  @State currentIndex: number = 0;
  private tabsController: TabsController = new TabsController() ;

  // 获取当前页面标题
  getCurrentTitle(): string {
    switch (this.currentIndex) {
      case 0:
        return '首页';
      case 1:
        return '文物';
      case 2:
        return '动态';
      case 3:
        return '个人';
      default:
        return '';
    }
  }

  //单个tab内容组件
  @Builder TabBuilder(title: string, targetIndex: number, selectedImg: Resource, normalImg: Resource) {
    Column() {
      Image(this.currentIndex === targetIndex ? selectedImg : normalImg)
        .size({ width: 25, height: 25 })
        .objectFit(ImageFit.Contain)
      Text(title)
        .fontColor(this.currentIndex === targetIndex ? '#1698CE' : '#6B6B6B')
    }
    .width('100%')
    .height(50)
    .justifyContent(FlexAlign.Center)
    .onClick( () => {
      this.currentIndex = targetIndex ;
      this.tabsController.changeIndex(this.currentIndex) ;
    })
  }

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        Text(this.getCurrentTitle())
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor('#8B4513')
          .fontFamily('STKaiti')
      }
      .width('100%')
      .height(30)
      .backgroundColor('#F5E6D3')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .shadow({
        radius: 6,
        color: '#1A000000',
        offsetX: 0,
        offsetY: 2
      })

      Tabs({ barPosition: BarPosition.End , controller: this.tabsController}){

        TabContent(){
          Museum()
        }
        .tabBar(this.TabBuilder( '首页' , 0 , $r('app.media.Museum_on') , $r('app.media.Museum_off')))
        .padding(0)
        .margin(0)

        TabContent(){
          Antique()
        }
        .tabBar(this.TabBuilder( '文物' , 1 , $r('app.media.antique_on') , $r('app.media.antique_off')))
        .padding(0)
        .margin(0)

        TabContent(){
          Text('动态')
        }
        .tabBar(this.TabBuilder( '动态' , 2 , $r('app.media.information_on') , $r('app.media.information_off')))
        .padding(0)
        .margin(0)

        TabContent(){
          Text('个人')
        }
        .tabBar(this.TabBuilder( '个人' , 3 , $r('app.media.person_on') , $r('app.media.person_off')))
        .padding(0)
        .margin(0)

      }
      .barWidth('100%')
      .barHeight(56)
      .barMode(BarMode.Fixed)
      .backgroundColor('#F5E6D3')
      .padding(0)
      .margin(0)
      .width('100%')
      .height('100%')
    }
  }
}