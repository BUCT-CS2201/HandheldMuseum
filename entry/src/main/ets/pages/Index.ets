import Antique from './Antique'
import Museum from './Museum'
import Personal from './Personal'
import DynamicItem from './UserDynamic'

import preferences from '@ohos.data.preferences';
import type { BusinessError } from '@ohos.base';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
import http from '@ohos.net.http';

interface UserInfo {
  user_id: number;
  phone_number: string;
  name: string;
  description?: string;
  gender?: number;
  age?: number;
  address?: string;
  wechat?: string;
  qq?: string;
  account_status: number;
  comment_status: number;
  role_type: number;
  create_time: string;
  update_time: string;
}

interface ApiResponse<T> {
  code: number;
  message: string;
  data?: T;
}

@Entry
@Component
struct Index {
  //记录当前界面下标
  @State currentIndex: number = 0;
  private tabsController: TabsController = new TabsController() ;
  @State needRefresh: boolean = false;
  @State userId:number = 0 ;
  private userPreferences: preferences.Preferences | null = null;
  @State userInfo: UserInfo | undefined = undefined;
  @State message: string = '' ;

  onPageShow() {
    console.log("show") ;
    this.initPreferences() ;
  }

  // 添加公共方法供外部调用
  public refresh() {
    console.log("Refreshing Personal component");
    this.initPreferences();
  }

  async initPreferences() {
    try {
      this.userPreferences = await preferences.getPreferences(getContext(), 'userInfo');
      await this.checkLoginStatus();
    } catch (error) {
      console.error('初始化偏好设置失败:', error);
      this.message = '初始化失败';
    }
  }

  async checkLoginStatus() {
    if (!this.userPreferences) {
      this.message = '请先登录';
      return;
    }

    try {
      const userId: number = await this.userPreferences.get('userId', 0) as number;
      console.info('获取到的用户ID:', userId);

      if (!userId || userId === 0) {
        this.message = '请先登录';
        return;
      }

      this.loadUserInfo(userId);
    } catch (error) {
      console.error('检查登录状态失败:', error);
      this.message = '检查登录状态失败';
    }
  }

  async loadUserInfo(userId: number) {
    try {
      let httpRequest = http.createHttp();
      console.info('开始请求用户信息, userId:', userId);

      httpRequest.request(
        `http://192.168.1.103:3000/api/user/info/${userId}`,
        {
          method: http.RequestMethod.GET,
          header: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          }
        },
        (err: BusinessError | undefined, data: http.HttpResponse) => {
          if (!err) {
            try {
              console.info('用户信息响应:', data.result);

              let result: UserInfo | undefined = undefined;
              if (typeof data.result === 'string') {
                const parsedData: ApiResponse<UserInfo> = JSON.parse(data.result);
                if (parsedData.code === 0 && parsedData.data) {
                  result = parsedData.data;
                } else {
                  throw new Error(parsedData.message || '获取用户信息失败');
                }
              } else if (typeof data.result === 'object' && data.result !== null) {
                const response = data.result as ApiResponse<UserInfo>;
                if (response.code === 0 && response.data) {
                  result = response.data;
                } else {
                  throw new Error(response.message || '获取用户信息失败');
                }
              }

              if (result) {
                this.userInfo = result;
                this.message = '用户信息加载成功';
              } else {
                this.message = '用户信息为空';
              }
            } catch (e) {
              console.error('解析异常:', e);
              this.message = e instanceof Error ? e.message : '数据解析失败';
            }
          } else {
            console.error('请求失败:', JSON.stringify(err));
            this.message = '获取用户信息失败';
          }
          httpRequest.destroy();
        }
      );
    } catch (error) {
      console.error('加载用户信息失败:', error);
      this.message = '加载用户信息失败';
    }
  }

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
          DynamicItem()
        }
        .tabBar(this.TabBuilder( '动态' , 2 , $r('app.media.information_on') , $r('app.media.information_off')))
        .padding(0)
        .margin(0)

        TabContent(){
          Personal({ userInfo: this.userInfo })
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
      .onChange((index: number) => {
        this.currentIndex = index
      })
    }
  }
}