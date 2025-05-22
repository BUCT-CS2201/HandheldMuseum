import router from '@ohos.router';
import http from '@ohos.net.http';
import preferences from '@ohos.data.preferences';
import type { BusinessError } from '@ohos.base';
import promptAction from '@ohos.promptAction';
import emitter from '@ohos.events.emitter';

// 服务器配置
const SERVER_URL = 'http://10.4.69.110:3000'; // 使用 Android 模拟器的特殊 IP 地址

interface LoginData {
  user_id: number;
}

interface LoginResponse {
  code: number;
  message: string;
  data?: LoginData;
}

@Entry
@Component
struct Login {
  @State phoneNumber: string = '';
  @State password: string = '';
  @State message: string = '';
  @State isLoading: boolean = false;
  @State shouldNavigateBack: boolean = false;
  @State loginSuccess: boolean = false;
  private userPreferences: preferences.Preferences | null = null;
  private userId: number = 0;

  aboutToAppear() {
    this.initPreferences();
  }

  async initPreferences() {
    try {
      this.userPreferences = await preferences.getPreferences(getContext(), 'userInfo');
    } catch (error) {
      console.error('初始化偏好设置失败:', error);
      this.message = '初始化失败';
    }
  }

  async saveUserId(userId: number) {
    if (!this.userPreferences) {
      throw new Error('系统错误，请重试');
    }
    this.userId = userId;
    await this.userPreferences.put('userId', userId);
    await this.userPreferences.flush();

    // 发送登录状态改变事件
    emitter.emit('loginStateChanged');
  }

  build() {
    if (this.loginSuccess) {

    } else {
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
          Text('登录')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .margin({ left: 16 })
        }
        .width('100%')
        .height(56)
        .backgroundColor('#FFFFFF')

        // 登录表单
        Column() {
          TextInput({ placeholder: '请输入手机号' })
            .type(InputType.PhoneNumber)
            .margin({ top: 32 })
            .onChange((value: string) => {
              this.phoneNumber = value;
            })

          TextInput({ placeholder: '请输入密码' })
            .type(InputType.Password)
            .margin({ top: 16 })
            .onChange((value: string) => {
              this.password = value;
            })

          if (this.message) {
            Text(this.message)
              .fontSize(14)
              .fontColor('#FF0000')
              .margin({ top: 8 })
          }

          Button('登录')
            .width('100%')
            .height(48)
            .margin({ top: 32 })
            .backgroundColor('#007DFF')
            .onClick(async () => {
              const success = await this.handleLogin();

              if (success) {
                console.log("success");
                this.getUIContext().getRouter().back();
              }
              else {
                console.log("false");
              }
            })

          Row() {
            Text('还没有账号？')
              .fontSize(14)
              .fontColor('#666666')
            Text('立即注册')
              .fontSize(14)
              .fontColor('#007DFF')
              .onClick(() => {
                router.pushUrl({ url: 'pages/Register' });
              })
          }
          .margin({ top: 16 })
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#FFFFFF')
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F5')
    }
  }

  async handleLogin(): Promise<boolean> {
    if (!this.phoneNumber || !this.password) {
      this.message = '请输入手机号和密码';
      return false;
    }

    if (!this.userPreferences) {
      this.message = '系统错误，请重试';
      return false;
    }

    this.isLoading = true;
    this.message = '';

    try {
      let httpRequest = http.createHttp();
      console.info('开始登录请求:', `${SERVER_URL}/api/user/login`);

      return new Promise<boolean>((resolve) => {
        httpRequest.request(
          `${SERVER_URL}/api/user/login`,
          {
            method: http.RequestMethod.POST,
            header: {
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            },
            extraData: JSON.stringify({
              phone_number: this.phoneNumber,
              password: this.password
            }),
            connectTimeout: 60000,
            readTimeout: 60000
          },
          async (err: BusinessError | undefined, data: http.HttpResponse) => {
            if (!err) {
              try {
                console.info('Response status:', data.responseCode);
                console.info('Response headers:', data.header);
                console.info('Response data:', data.result);

                let result: LoginResponse;

                if (typeof data.result === 'string') {
                  try {
                    result = JSON.parse(data.result) as LoginResponse;
                  } catch (parseError) {
                    console.error('JSON parse error:', parseError);
                    console.error('Raw response:', data.result);
                    this.message = '服务器连接失败，请检查网络连接';
                    resolve(false);
                    return;
                  }
                } else if (typeof data.result === 'object' && data.result !== null) {
                  result = data.result as LoginResponse;
                } else {
                  console.error('Unexpected response type:', typeof data.result);
                  this.message = '服务器响应格式错误';
                  resolve(false);
                  return;
                }

                if (result.code === 0 && result.data) {
                  try {
                    await this.saveUserId(result.data.user_id);
                    console.log('登录成功');
                    resolve(true);
                  } catch (error) {
                    console.error('保存登录状态失败:', error);
                    this.message = '登录状态保存失败，请重试';
                    resolve(false);
                  }
                } else {
                  this.message = result.message || '登录失败';
                  resolve(false);
                }
              } catch (e) {
                console.error('解析异常:', e);
                if (e instanceof Error) {
                  this.message = e.message;
                } else {
                  this.message = '服务器响应格式错误';
                }
                resolve(false);
              }
            } else {
              console.error('请求失败:', JSON.stringify(err));
              this.message = '网络请求失败，请检查网络连接';
              resolve(false);
            }
            httpRequest.destroy();
            this.isLoading = false;
          }
        );
      });
    } catch (error) {
      console.error('登录失败:', error);
      this.message = '登录失败，请稍后重试';
      this.isLoading = false;
      return false;
    }
  }
} 