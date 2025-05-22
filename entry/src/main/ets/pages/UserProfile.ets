import router from '@ohos.router';
import http from '@ohos.net.http';
import preferences from '@ohos.data.preferences';
import type { BusinessError } from '@ohos.base';
import picker from '@ohos.file.picker';
import fileio from '@ohos.fileio';
import fs from '@ohos.file.fs';
import prompt from '@ohos.prompt';

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
  avatar_url?: string;
  id_number?: string;
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
  @State selectedAvatar: string = '';
  @State isUploading: boolean = false;

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
        `http://10.4.117.113:3000/api/user/info/${userId}`,
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
            // 使用新的头像组件
            this.AvatarSection()

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
                  this.InfoItem('身份证号', this.userInfo.id_number || '', true)
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
                  this.InfoItem('身份证号', this.userInfo.id_number || '', false)
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
  AvatarSection() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Image(this.selectedAvatar || this.userInfo?.avatar_url || $r("app.media.default_avatar"))
        .width(100)
        .height(100)
        .borderRadius(50)
        .margin({ top: 20, bottom: 20 })
        .objectFit(ImageFit.Cover)
      if (this.isEditing) {
        Image($r('app.media.camera'))
          .width(24)
          .height(24)
          .margin({ right: 4, bottom: 4 })
          .onClick(() => this.pickAvatar())
      }
    }
  }

  private async pickAvatar() {
    try {
      const options = new picker.PhotoSelectOptions();
      options.maxSelectNumber = 1;
      options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;

      const photoPicker = new picker.PhotoViewPicker();
      const result = await photoPicker.select(options);

      if (result && result.photoUris && result.photoUris.length > 0) {
        this.selectedAvatar = result.photoUris[0];
        await this.uploadAvatar();
      }
    } catch (error) {
      console.error('选择头像失败:', error);
      prompt.showToast({ message: '选择头像失败，请重试' });
    }
  }

  private async uploadAvatar() {
    if (!this.selectedAvatar || !this.userInfo) {
      return;
    }

    this.isUploading = true;
    try {
      // 读取图片文件
      let resultPhoto = fs.openSync(this.selectedAvatar, fs.OpenMode.READ_ONLY);
      let fileTemp = fs.openSync(getContext().filesDir + resultPhoto.name, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      let imageUri = fileTemp.path;
      fs.copyFileSync(resultPhoto.fd, fileTemp.fd);
      fs.closeSync(resultPhoto);
      fs.closeSync(fileTemp);

      // 上传图片
      const uploadUrl = 'http://10.4.117.113:5000/upload_avatar';
      const uploadRequest = http.createHttp();

      const response = await uploadRequest.request(uploadUrl, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'multipart/form-data',
          'Connection': 'keep-alive',
          'user_id': this.userInfo.user_id.toString()
        },
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        multiFormDataList: [
          {
            name: 'image',
            contentType: 'image/jpeg',
            filePath: imageUri,
            remoteFileName: `${this.userInfo.user_id}.jpg`
          },
        ],
      });

      if (response.responseCode === 200) {
        prompt.showToast({ message: '头像上传成功' });
        // 更新用户信息中的头像URL
        if (this.userInfo) {
          this.userInfo.avatar_url = `http://10.4.117.113:5000/uploads/avatars/${this.userInfo.user_id}.jpg`;
        }
        // 重新加载用户信息
        this.loadUserInfo();
      } else {
        throw new Error('头像上传失败');
      }
    } catch (error) {
      console.error('上传头像失败:', error);
      prompt.showToast({ message: '上传头像失败，请重试' });
    } finally {
      this.isUploading = false;
    }
  }

  @Builder
  InfoItem(label: string, value: string, editable: boolean) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor('#666666')
        .width(80)
      if (editable) {
        if (label === '性别') {
          Select([
            { value: '男' },
            { value: '女' }
          ])
            .selected(0)
            .value(value)
            .width('100%')
            .height(40)
            .backgroundColor('#F5F5F5')
            .borderRadius(4)
            .padding({ left: 8, right: 8 })
            .margin({ left: 8 })
            .onSelect((index: number, value: string) => {
              if (!this.userInfo) return;
              this.userInfo.gender = value === '男' ? 1 : 0;
            })
        } else {
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
                case '身份证号':
                  this.userInfo.id_number = newValue;
                  break;
              }
            })
        }
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

  // 验证身份证号格式
  private validateIdNumber(idNumber: string): boolean {
    const idNumberRegex = /^\d{18}$/;
    return idNumberRegex.test(idNumber);
  }

  async saveUserInfo() {
    if (!this.userInfo) return;

    // 验证身份证号格式
    if (this.userInfo.id_number && !this.validateIdNumber(this.userInfo.id_number)) {
      prompt.showToast({ message: '请输入18位身份证号码' });
      return;
    }

    this.isLoading = true;
    this.message = '';

    try {
      let httpRequest = http.createHttp();
      httpRequest.request(
        `http://10.4.117.113:3000/api/user/info/${this.userInfo.user_id}`,
        {
          method: http.RequestMethod.PUT,
          header: {
            'Content-Type': 'application/json'
          },
          extraData: JSON.stringify({
            name: this.userInfo.name,
            phone_number: this.userInfo.phone_number,
            id_number: this.userInfo.id_number,
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