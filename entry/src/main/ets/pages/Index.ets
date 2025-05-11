import Antique from './Antique'
import Museum from './Museum'
import { Personal } from './Personal';

@Entry
@Component
struct Index {
  //记录当前界面下标
  @State currentIndex: number = 0;
  private tabsController: TabsController = new TabsController() ;
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

    Tabs({ barPosition: BarPosition.End , controller: this.tabsController}){

      TabContent(){
        Museum()
      }
      .tabBar(this.TabBuilder( '首页' , 0 , $r('app.media.Museum_on') , $r('app.media.Museum_off')))

      TabContent(){
        Antique()
      }
      .tabBar(this.TabBuilder( '文物' , 1 , $r('app.media.antique_on') , $r('app.media.antique_off')))

      TabContent(){
        Text('动态')
      }
      .tabBar(this.TabBuilder( '动态' , 2 , $r('app.media.information_on') , $r('app.media.information_off')))

      TabContent(){
        Personal()
      }
      .tabBar(this.TabBuilder( '个人' , 3 , $r('app.media.person_on') , $r('app.media.person_off')))

    }
    .barWidth('100%')
    .barHeight(56)
    .barMode(BarMode.Fixed)

  }
}