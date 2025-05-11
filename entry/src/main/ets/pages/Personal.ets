import router from '@ohos.router';
import http from '@ohos.net.http';
import preferences from '@ohos.data.preferences';
import type { BusinessError } from '@ohos.base';
import promptAction from '@ohos.promptAction';

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
export default struct Personal {
  @Prop userInfo: UserInfo | undefined = undefined;
  @State message: string = '' ;
  private userPreferences: preferences.Preferences | null = null;
  @State internalNeedRefresh: boolean = false;

  aboutToAppear() {
    console.log("Appear");
    this.initPreferences() ;
  }

  async initPreferences() {
    try {
      this.userPreferences = await preferences.getPreferences(getContext(), 'userInfo');
    } catch (error) {
      console.error('初始化偏好设置失败:', error);
      this.message = '初始化失败';
    }
  }

  handleLogout() {
    if (!this.userPreferences) {
      promptAction.showToast({
        message: '系统错误',
        duration: 2000
      });
      return;
    }

    try {
      // 删除用户ID
      this.userPreferences.delete('userId');
      this.userPreferences.flush();
      // 更新状态
      this.userInfo = undefined;
      this.message = '请先登录';

      // 显示提示
      promptAction.showToast({
        message: '已退出登录',
        duration: 2000
      });

      // 直接返回
      router.back();
    } catch (error) {
      console.error('退出登录失败:', error);
      promptAction.showToast({
        message: '退出登录失败',
        duration: 2000
      });
    }
  }

  build() {
    Column() {
      if (!this.userInfo) {
        // 未登录状态显示
        Column() {
          Text(this.message)
            .fontSize(16)
            .fontColor('#666666')
          Button('去登录')
            .margin({ top: 20 })
            .onClick(() => {
              router.pushUrl({ url: 'pages/Login' });
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.userInfo) {
        // 顶部个人信息卡片
        Row() {
          Image('/common/images/default_avatar.png')
            .width(60)
            .height(60)
            .borderRadius(30)
            .margin({ left: 16 })
          Column() {
            Text(this.userInfo.name)
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
            Text(this.userInfo.phone_number)
              .fontSize(14)
              .fontColor('#666666')
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })
          .layoutWeight(1)
          Image($r('app.media.arrow_right'))
            .width(24)
            .height(24)
            .margin({ right: 16 })
        }
        .width('100%')
        .height(88)
        .backgroundColor('#FFFFFF')
        .onClick(() => {
          router.pushUrl({ url: 'pages/UserProfile' });
        })

        // 功能列表
        List() {
          ListItem() {
            this.MenuItem('我的收藏', $r('app.media.favorite'))
          }
          ListItem() {
            this.MenuItem('浏览历史', $r('app.media.history'))
          }
          ListItem() {
            this.MenuItem('消息通知', $r('app.media.notification'))
          }
          ListItem() {
            this.MenuItem('设置', $r('app.media.settings'), () => {
              router.pushUrl({ url: 'pages/Settings' });
            })
          }
        }
        .width('100%')
        .margin({ top: 12 })
        .backgroundColor('#FFFFFF')

        // 退出登录按钮
        Button('退出登录')
          .width('90%')
          .height(48)
          .margin({ top: 32 })
          .backgroundColor('#FF4D4F')
          .fontColor(Color.White)
          .onClick(() => {
            this.handleLogout();
          })
      } else {
        // 加载中或未登录状态
        Column() {
          if (this.message) {
            Text(this.message)
              .fontSize(16)
              .fontColor('#666666')
          } else {
            LoadingProgress()
              .width(50)
              .height(50)
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  MenuItem(title: string, icon: Resource, onClick?: () => void) {
    Row() {
      Image(icon)
        .width(24)
        .height(24)
        .margin({ left: 16 })
      Text(title)
        .fontSize(16)
        .margin({ left: 12 })
        .layoutWeight(1)
      Image($r('app.media.arrow_right'))
        .width(24)
        .height(24)
        .margin({ right: 16 })
    }
    .width('100%')
    .height(56)
    .backgroundColor('#FFFFFF')
    .onClick(() => {
      onClick?.();
    })
  }
} 