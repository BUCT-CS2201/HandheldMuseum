import router from '@ohos.router';

@Entry
@Component
struct Settings {
  @State isDarkMode: boolean = false;
  @State isNotificationEnabled: boolean = true;
  @State isAutoPlayEnabled: boolean = true;

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Image($r('app.media.back'))
          .width(24)
          .height(24)
          .margin({ left: 16 })
          .onClick(() => {
            router.back();
          })
        Text('设置')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 16 })
      }
      .width('100%')
      .height(56)
      .backgroundColor('#FFFFFF')

      // 设置列表
      List() {
        ListItem() {
          this.SettingItem('深色模式', this.isDarkMode, (value) => {
            this.isDarkMode = value;
          })
        }
        ListItem() {
          this.SettingItem('消息通知', this.isNotificationEnabled, (value) => {
            this.isNotificationEnabled = value;
          })
        }
        ListItem() {
          this.SettingItem('自动播放', this.isAutoPlayEnabled, (value) => {
            this.isAutoPlayEnabled = value;
          })
        }
        ListItem() {
          this.SettingItem('清除缓存', false, undefined, '2.5MB')
        }
        ListItem() {
          this.SettingItem('关于我们', false, undefined, 'v1.0.0')
        }
      }
      .width('100%')
      .margin({ top: 12 })
      .backgroundColor('#FFFFFF')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  SettingItem(title: string, hasSwitch: boolean, onSwitchChange?: (value: boolean) => void, rightText?: string) {
    Row() {
      Text(title)
        .fontSize(16)
        .margin({ left: 16 })
        .layoutWeight(1)
      if (hasSwitch) {
        Toggle({ type: ToggleType.Switch, isOn: hasSwitch })
          .onChange((isOn: boolean) => {
            onSwitchChange?.(isOn);
          })
          .margin({ right: 16 })
      } else if (rightText) {
        Text(rightText)
          .fontSize(14)
          .fontColor('#666666')
          .margin({ right: 16 })
      }
    }
    .width('100%')
    .height(56)
    .backgroundColor('#FFFFFF')
  }
} 