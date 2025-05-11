import router from '@ohos.router';
import http from '@ohos.net.http';
import preferences from '@ohos.data.preferences';
import type { BusinessError } from '@ohos.base';

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

@Entry
@Component
export struct Personal {
  @State userInfo: UserInfo | undefined = undefined;
  @State message: string = '';

  aboutToAppear() {
    this.loadUserInfo();
  }

  async loadUserInfo() {
    try {
      const userPreferences = await preferences.getPreferences(getContext(), 'userInfo');
      const userId: number = await userPreferences.get('userId', 0) as number;
      // if (!userId) {
      //   router.pushUrl({ url: 'pages/Login' });
      //   return;
      // }

      let httpRequest = http.createHttp();
      httpRequest.request(
        `http://localhost:3000/api/user/${userId}`,
        {
          method: http.RequestMethod.GET,
        },
        (err: BusinessError | undefined, data: http.HttpResponse) => {
          if (!err) {
            try {
              let result: UserInfo | undefined = undefined;
              if (typeof data.result === 'string') {
                result = JSON.parse(data.result) as UserInfo;
              } else if (typeof data.result === 'object' && data.result !== null) {
                result = data.result as UserInfo;
              }
              if (result) {
                this.userInfo = result;
                this.message = '用户信息加载成功';
              } else {
                this.message = '用户信息为空';
              }
            } catch (e) {
              this.message = '数据解析失败';
              console.error('解析异常:', JSON.stringify(e));
            }
          } else {
            this.message = '获取用户信息失败';
            console.error(JSON.stringify(err));
          }
          httpRequest.destroy();
        }
      );
    } catch (error) {
      console.error('加载用户信息失败:', error);
      this.message = '加载用户信息失败';
    }
  }

  build() {
    Column() {
      if (this.userInfo) {
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