import router from '@ohos.router';
import http from '@ohos.net.http';
import preferences from '@ohos.data.preferences';
import type { BusinessError } from '@ohos.base';

// 服务器配置
const SERVER_URL = 'http://localhost:3000'; // 使用 Android 模拟器的特殊 IP 地址

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
          .onClick(() => {
            this.handleLogin();
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

  async handleLogin() {
    if (!this.phoneNumber || !this.password) {
      this.message = '请输入手机号和密码';
      return;
    }

    this.isLoading = true;
    this.message = '';

    try {
      let httpRequest = http.createHttp();
      console.info('开始登录请求:', `${SERVER_URL}/api/user/login`);
      
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
                  throw new Error('服务器连接失败，请检查网络连接');
                }
              } else if (typeof data.result === 'object' && data.result !== null) {
                result = data.result as LoginResponse;
              } else {
                console.error('Unexpected response type:', typeof data.result);
                throw new Error('服务器响应格式错误');
              }

              if (result.code === 0 && result.data) {
                // 保存用户ID到本地存储
                const userPreferences = await preferences.getPreferences(getContext(), 'userInfo');
                await userPreferences.put('userId', result.data.user_id);
                await userPreferences.flush();
                
                // 登录成功，返回上一页
                router.back();
              } else {
                this.message = result.message || '登录失败';
              }
            } catch (e) {
              console.error('解析异常:', e);
              if (e instanceof Error) {
                this.message = e.message;
              } else {
                this.message = '服务器响应格式错误';
              }
            }
          } else {
            console.error('请求失败:', JSON.stringify(err));
            this.message = '网络请求失败，请检查网络连接';
          }
          httpRequest.destroy();
          this.isLoading = false;
        }
      );
    } catch (error) {
      console.error('登录失败:', error);
      this.message = '登录失败，请稍后重试';
      this.isLoading = false;
    }
  }
} 