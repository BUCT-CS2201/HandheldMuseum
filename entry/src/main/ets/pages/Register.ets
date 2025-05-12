import router from '@ohos.router';
import http from '@ohos.net.http';
import preferences from '@ohos.data.preferences';
import type { BusinessError } from '@ohos.base';
import promptAction from '@ohos.promptAction';

// 服务器配置
const SERVER_URL = 'http://localhost:3000';

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
  @State idNumber: string = '';
  @State message: string = '';
  @State isLoading: boolean = false;
  private userPreferences: preferences.Preferences | null = null;

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
    await this.userPreferences.put('userId', userId);
    await this.userPreferences.flush();
  }

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

        TextInput({ placeholder: '请输入昵称' })
          .margin({ top: 16 })
          .onChange((value: string) => {
            this.name = value;
          })

        TextInput({ placeholder: '请输入身份证号' })
          .margin({ top: 16 })
          .onChange((value: string) => {
            this.idNumber = value;
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
          .onClick(async () => {
            const success = await this.handleRegister();
            if (success) {
              console.log("success");
              this.getUIContext().getRouter().back();
            }
            else {
              console.log("false")
            }
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

  async handleRegister(): Promise<boolean> {
    // 表单验证
    if (!this.phoneNumber || !this.password || !this.confirmPassword || !this.name || !this.idNumber) {
      this.message = '请填写完整信息';
      return false;
    }

    if (this.password !== this.confirmPassword) {
      this.message = '两次输入的密码不一致';
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
      console.info('开始注册请求:', `${SERVER_URL}/api/user/register`);

      return new Promise<boolean>((resolve) => {
        httpRequest.request(
          `${SERVER_URL}/api/user/register`,
          {
            method: http.RequestMethod.POST,
            header: {
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            },
            extraData: JSON.stringify({
              phone_number: this.phoneNumber,
              password: this.password,
              name: this.name,
              id_number: this.idNumber
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

                let result: RegisterResponse;

                if (typeof data.result === 'string') {
                  try {
                    result = JSON.parse(data.result) as RegisterResponse;
                  } catch (parseError) {
                    console.error('JSON parse error:', parseError);
                    console.error('Raw response:', data.result);
                    this.message = '服务器连接失败，请检查网络连接';
                    resolve(false);
                    return;
                  }
                } else if (typeof data.result === 'object' && data.result !== null) {
                  result = data.result as RegisterResponse;
                } else {
                  console.error('Unexpected response type:', typeof data.result);
                  this.message = '服务器响应格式错误';
                  resolve(false);
                  return;
                }

                if (result.code === 0 && result.data) {
                  try {
                    await this.saveUserId(result.data.user_id);
                    console.log('注册成功');
                    resolve(true);
                  } catch (error) {
                    console.error('保存注册状态失败:', error);
                    this.message = '注册状态保存失败，请重试';
                    resolve(false);
                  }
                } else {
                  this.message = result.message || '注册失败';
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
      console.error('注册失败:', error);
      this.message = '注册失败，请稍后重试';
      this.isLoading = false;
      return false;
    }
  }
} 