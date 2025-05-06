import http from '@ohos.net.http';

interface notice {
  notice_id : number
  museum_id : number
  notice_title : string
  notice_time : Date
  notice_author : string
  notice_content : string
  create_time : Date
  update_time : Date
}

@Entry
@Component
export default struct Museum {
  @State message: string = 'Hello World';
  @State notices: Array<notice> = [];

  aboutToAppear() {
    let httpRequest = http.createHttp();

    httpRequest.request(
      // 注意：如果在真机上调试，请将localhost替换为电脑的局域网IP
      'http://localhost:3000/api/museum/list',
      {
        method: http.RequestMethod.GET,
        // 你可以根据需要添加headers等参数
      },
      (err, data) => {
        console.log(data.result as string)
        if (!err) {
          try {
            let result: Array<notice> = [];
            if (typeof data.result === 'string') {
              result = JSON.parse(data.result) as Array<notice>;
            } else if (Array.isArray(data.result)) {
              result = data.result as Array<notice>;
            } else if (typeof data.result === 'object' && data.result !== null) {
              // 可能后端直接返回了对象
              result = [data.result as notice];
            }
            this.notices = result;
            this.message = '公告加载成功';
          } catch (e) {
            this.message = '数据解析失败';
          }
        } else {
          this.message = '公告获取失败';
          console.error(JSON.stringify(err));
        }
        httpRequest.destroy();
      }
    );
  }

  build() {
    Column() {
      Text(this.message)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 20 })

      // 公告列表
      ForEach(this.notices, (item:notice) => {
        Column() {
          Text(item.notice_title)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
          Text(item.notice_content)
            .fontSize(14)
            .margin({ bottom: 10 })
        }
        .margin({ bottom: 20 })
      }, (item: notice) => item.notice_id.toString() )
    }
    .height('100%')
    .width('100%')
    .padding(20)
  }
}