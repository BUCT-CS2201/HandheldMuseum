import router from '@ohos.router';
import http from '@ohos.net.http';
import preferences from '@ohos.data.preferences';
import type { BusinessError } from '@ohos.base';

// 服务器配置
const SERVER_URL = 'http://localhost:3000'; // 使用 Android 模拟器的特殊 IP 地址

interface RegisterData {
  user_id: number;
}

interface RegisterResponse {
  code: number;
  message: string;
  data?: RegisterData;
}

@Entry
@Component
struct Register {
  @State phoneNumber: string = '';
  @State password: string = '';
  @State confirmPassword: string = '';
  @State name: string = '';
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
        Text('注册')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 16 })
      }
      .width('100%')
      .height(56)
      .backgroundColor('#FFFFFF')

      // 注册表单
      Column() {
        TextInput({ placeholder: '请输入手机号' })
          .type(InputType.PhoneNumber)
          .margin({ top: 32 })
          .onChange((value: string) => {
            this.phoneNumber = value;
          })

        TextInput({ placeholder: '请输入姓名' })
          .margin({ top: 16 })
          .onChange((value: string) => {
            this.name = value;
          })

        TextInput({ placeholder: '请输入密码' })
          .type(InputType.Password)
          .margin({ top: 16 })
          .onChange((value: string) => {
            this.password = value;
          })

        TextInput({ placeholder: '请确认密码' })
          .type(InputType.Password)
          .margin({ top: 16 })
          .onChange((value: string) => {
            this.confirmPassword = value;
          })

        if (this.message) {
          Text(this.message)
            .fontSize(14)
            .fontColor('#FF0000')
            .margin({ top: 8 })
        }

        Button('注册')
          .width('100%')
          .height(48)
          .margin({ top: 32 })
          .backgroundColor('#007DFF')
          .onClick(() => {
            this.handleRegister();
          })

        Row() {
          Text('已有账号？')
            .fontSize(14)
            .fontColor('#666666')
          Text('立即登录')
            .fontSize(14)
            .fontColor('#007DFF')
            .onClick(() => {
              router.back();
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

  async handleRegister() {
    // 表单验证
    if (!this.phoneNumber || !this.password || !this.confirmPassword || !this.name) {
      this.message = '请填写完整信息';
      return;
    }

    if (this.password !== this.confirmPassword) {
      this.message = '两次输入的密码不一致';
      return;
    }

    this.isLoading = true;
    this.message = '';

    try {
      let httpRequest = http.createHttp();
      httpRequest.request(
        `${SERVER_URL}/api/user/register`,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json'
          },
          extraData: JSON.stringify({
            phone_number: this.phoneNumber,
            password: this.password,
            name: this.name
          })
        },
        async (err: BusinessError | undefined, data: http.HttpResponse) => {
          if (!err) {
            try {
              console.info('Response data:', data.result);
              let result: RegisterResponse;
              
              if (typeof data.result === 'string') {
                try {
                  result = JSON.parse(data.result) as RegisterResponse;
                } catch (parseError) {
                  console.error('JSON parse error:', parseError);
                  console.error('Raw response:', data.result);
                  throw new Error('服务器连接失败，请检查网络连接');
                }
              } else if (typeof data.result === 'object' && data.result !== null) {
                result = data.result as RegisterResponse;
              } else {
                console.error('Unexpected response type:', typeof data.result);
                throw new Error('服务器响应格式错误');
              }

              if (result.code === 0 && result.data) {
                // 保存用户ID到本地存储
                const userPreferences = await preferences.getPreferences(getContext(), 'userInfo');
                await userPreferences.put('userId', result.data.user_id);
                await userPreferences.flush();
                
                // 注册成功，返回上一页
                router.back();
              } else {
                this.message = result.message || '注册失败';
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
            console.error('请求失败:', err);
            this.message = '网络请求失败，请检查网络连接';
          }
          httpRequest.destroy();
          this.isLoading = false;
        }
      );
    } catch (error) {
      console.error('注册失败:', error);
      this.message = '注册失败，请稍后重试';
      this.isLoading = false;
    }
  }
} 