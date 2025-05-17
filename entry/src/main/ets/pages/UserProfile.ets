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

interface ApiResponse {
  code: number;
  message: string;
  data?: UserInfo;
}

@Entry
@Component
struct UserProfile {
  @State userInfo: UserInfo | undefined = undefined;
  @State isEditing: boolean = false;
  @State isLoading: boolean = false;
  @State message: string = '';

  aboutToAppear() {
    this.loadUserInfo();
  }

  async loadUserInfo() {
    try {
      const userPreferences = await preferences.getPreferences(getContext(), 'userInfo');
      const userId: number = await userPreferences.get('userId', 0) as number;
      if (!userId) {
        router.pushUrl({ url: 'pages/Login' });
        return;
      }

      let httpRequest = http.createHttp();
      httpRequest.request(
        `http://localhost:3000/api/user/info/${userId}`,
        {
          method: http.RequestMethod.GET,
        },
        (err: BusinessError | undefined, data: http.HttpResponse) => {
          if (!err) {
            try {
              let result: ApiResponse;
              if (typeof data.result === 'string') {
                result = JSON.parse(data.result) as ApiResponse;
              } else {
                result = data.result as ApiResponse;
              }
              if (result.code === 0 && result.data) {
                this.userInfo = result.data;
              } else {
                this.message = result.message || '用户信息为空';
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
      // 顶部导航栏
      Row() {
        Image($r('app.media.back'))
          .width(24)
          .height(24)
          .margin({ left: 16 })
          .onClick(() => {
            router.back();
          })
        Text('个人信息')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 16 })
        Blank()
        Text(this.isEditing ? '保存' : '编辑')
          .fontSize(16)
          .fontColor('#007DFF')
          .margin({ right: 16 })
          .onClick(() => {
            if (this.isEditing) {
              this.saveUserInfo();
            } else {
              this.isEditing = true;
              console.info('进入编辑模式, isEditing: ', this.isEditing);
            }
          })
      }
      .width('100%')
      .height(56)
      .backgroundColor('#FFFFFF')

      if (this.userInfo) {
        // 个人信息内容
        Scroll() {
          Column() {
            // 头像
            Stack({ alignContent: Alignment.BottomEnd }) {
              Image($r("app.media.default_avatar"))
                .width(100)
                .height(100)
                .borderRadius(50)
                .margin({ top: 20, bottom: 20 })
              if (this.isEditing) {
                Image($r('app.media.camera'))
                  .width(24)
                  .height(24)
                  .margin({ right: 4, bottom: 4 })
              }
            }

            // 信息列表
            List() {
              if(this.isEditing) {
                ListItem() {
                  this.InfoItem('用户名', this.userInfo.name, true)
                }
                ListItem() {
                  this.InfoItem('手机号', this.userInfo.phone_number, false)
                }
                ListItem() {
                  this.InfoItem('性别', this.userInfo.gender === 1 ? '男' : '女', true)
                }
                ListItem() {
                  this.InfoItem('年龄', this.userInfo.age?.toString() || '', true)
                }
                ListItem() {
                  this.InfoItem('地址', this.userInfo.address || '', true)
                }
                ListItem() {
                  this.InfoItem('微信号', this.userInfo.wechat || '', true)
                }
                ListItem() {
                  this.InfoItem('QQ号', this.userInfo.qq || '', true)
                }
                ListItem() {
                  this.InfoItem('个人简介', this.userInfo.description || '', true)
                }
              }
              else {
                ListItem() {
                  this.InfoItem('用户名', this.userInfo.name, false)
                }
                ListItem() {
                  this.InfoItem('手机号', this.userInfo.phone_number, false)
                }
                ListItem() {
                  this.InfoItem('性别', this.userInfo.gender === 1 ? '男' : '女', false)
                }
                ListItem() {
                  this.InfoItem('年龄', this.userInfo.age?.toString() || '', false)
                }
                ListItem() {
                  this.InfoItem('地址', this.userInfo.address || '', false)
                }
                ListItem() {
                  this.InfoItem('微信号', this.userInfo.wechat || '', false)
                }
                ListItem() {
                  this.InfoItem('QQ号', this.userInfo.qq || '', false)
                }
                ListItem() {
                  this.InfoItem('个人简介', this.userInfo.description || '', false)
                }
              }
            }
            .width('100%')
            .backgroundColor('#FFFFFF')
            .margin({ top: 16 })
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        // 加载中或错误状态
        Column() {
          if (this.isLoading) {
            LoadingProgress()
              .width(50)
              .height(50)
          } else {
            Text(this.message || '加载失败，请重试')
              .fontSize(16)
              .fontColor('#666666')
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
  InfoItem(label: string, value: string, editable: boolean) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor('#666666')
        .width(80)
      if (editable) {
        TextInput({ text: value, placeholder: `请输入${label}` })
          .fontSize(16)
          .backgroundColor('#F5F5F5')
          .layoutWeight(1)
          .height(40)
          .borderRadius(4)
          .padding({ left: 8, right: 8 })
          .margin({ left: 8 })
          .onChange((newValue: string) => {
            if (!this.userInfo) return;
            // 更新对应的用户信息字段
            switch (label) {
              case '性别':
                this.userInfo.gender = newValue === '男' ? 1 : 0;
                break;
              case '年龄':
                this.userInfo.age = parseInt(newValue) || 0;
                break;
              case '地址':
                this.userInfo.address = newValue;
                break;
              case '微信号':
                this.userInfo.wechat = newValue;
                break;
              case 'QQ号':
                this.userInfo.qq = newValue;
                break;
              case '个人简介':
                this.userInfo.description = newValue;
                break;
              case '用户名':
                this.userInfo.name = newValue;
                break;
              case '手机号':
                this.userInfo.phone_number = newValue;
                break;
            }
          })
      } else {
        Text(value)
          .fontSize(16)
          .layoutWeight(1)
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor('#FFFFFF')
  }

  async saveUserInfo() {
    if (!this.userInfo) return;

    this.isLoading = true;
    this.message = '';

    try {
      let httpRequest = http.createHttp();
      httpRequest.request(
        `http://localhost:3000/api/user/info/${this.userInfo.user_id}`,
        {
          method: http.RequestMethod.PUT,
          header: {
            'Content-Type': 'application/json'
          },
          extraData: JSON.stringify({
            name: this.userInfo.name,
            phone_number: this.userInfo.phone_number,
            gender: this.userInfo.gender,
            age: this.userInfo.age,
            address: this.userInfo.address,
            wechat: this.userInfo.wechat,
            qq: this.userInfo.qq,
            description: this.userInfo.description
          })
        },
        (err: BusinessError | undefined, data: http.HttpResponse) => {
          if (!err) {
            try {
              let result: ApiResponse;
              console.info('服务器响应:', data.result); // 添加日志输出
              
              if (typeof data.result === 'string') {
                try {
                  result = JSON.parse(data.result) as ApiResponse;
                } catch (parseError) {
                  console.error('JSON解析失败，原始数据:', data.result);
                  throw new Error('服务器返回的数据格式不正确');
                }
              } else if (data.result) {
                result = data.result as ApiResponse;
              } else {
                throw new Error('响应数据为空');
              }

              if (result.code === 0) {
                this.isEditing = false;
                this.message = '保存成功';
                console.info('退出编辑模式, isEditing: ', this.isEditing);
                // 重新加载用户信息以更新界面
                this.loadUserInfo();
                // 使用try-catch包装router.back()调用
                try {
                  router.back();
                } catch (routerError) {
                  // 在预览器中，这个错误是预期的，可以忽略
                  if (routerError.message?.includes('UI execution context not found')) {
                    console.info('在预览器环境中，忽略返回错误');
                  } else {
                    console.error('返回上一页失败:', routerError);
                  }
                  // 确保界面状态正确
                  this.isEditing = false;
                }
              } else {
                this.message = result.message || '保存失败';
              }
            } catch (e) {
              this.message = '数据解析失败';
              console.error('解析异常:', e instanceof Error ? e.message : '未知错误');
              if (e instanceof Error) {
                console.error('错误详情:', e.stack);
              }
            }
          } else {
            this.message = '保存失败';
            console.error('请求错误:', err.message || '未知错误');
            console.error('错误详情:', err);
          }
          httpRequest.destroy();
          this.isLoading = false;
        }
      );
    } catch (error) {
      console.error('保存失败:', error instanceof Error ? error.message : '未知错误');
      this.message = '保存失败';
      this.isLoading = false;
    }
  }
} 