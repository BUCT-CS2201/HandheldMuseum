# HandheldMuseum

## 项目简介
掌上博物馆系统是一款面向公众的移动端应用，旨在通过数字化技术，打破时间和空间的限制，为用户提供便捷、个性化的博物馆体验。系统基于华为 HarmonyOS 平台构建，前端采用 ArkTS 编写，后端主要使用 Node.js 框架进行业务逻辑开发，部分功能模块（如以图搜图）采用 Flask 搭建微服务，并结合 MySQL 数据库和 Milvus 向量引擎进行数据管理与特征搜索。

## 项目特点
- **多模态融合体验**：结合图像、文字、用户行为等多种数据，支持以图搜图、图文动态、图文评论等多模态交互方式，提升用户体验。
- **结构化内容驱动**：前后端接口以结构化数据为标准，便于扩展与维护；博物馆信息、文物元数据统一规范化建模。
- **用户行为跟踪与反馈**：系统自动记录用户收藏、浏览、点赞、评论行为，实现个性化推荐和用户偏好记忆。
- **高性能数据处理**：支持懒加载、分页加载、图片缓存等多种性能优化机制，提升页面响应速度和使用流畅度。
- **安全与审核机制**：图片与评论需审核后展示，系统支持评论过滤与状态管理，确保内容合规。

## 功能模块
- **文物展览与详情展示**：支持文物浏览、搜索、分类筛选，文物详情页展示高清图片、基本信息、简介等，并支持点赞、评论、收藏操作。

![image-20250528102442731](https://github.com/BUCT-CS2201/HandheldMuseum/blob/main/image/image-20250528102442731.png)

- **博物馆浏览模块**：提供博物馆信息展示、排行榜、公告等功能，支持博物馆详情页查看简介、预约链接、官网链接及馆藏精品。

![image-20250528102359404](https://github.com/BUCT-CS2201/HandheldMuseum/blob/main/image/image-20250528102359404.png)

- **用户与文物交互模块**：支持用户对文物点赞、评论、收藏，评论支持二级嵌套，点赞状态实时更新。

![image-20250528102432408](https://github.com/BUCT-CS2201/HandheldMuseum/blob/main/image/image-20250528102432408.png)

- **以图搜图模块**：用户可上传图片或拍摄照片，系统通过 CLIP 模型提取图像特征，查询 Milvus 向量库，返回相似文物列表。

![image-20250528102505926](https://github.com/BUCT-CS2201/HandheldMuseum/blob/main/image/image-20250528102505926.png)

- **用户动态模块**：用户可发布图文动态，查看全平台用户动态，支持点赞、评论操作，动态详情页支持图片预览。

![image-20250528102513768](https://github.com/BUCT-CS2201/HandheldMuseum/blob/main/image/image-20250528102513768.png)

- **用户信息管理模块**：支持用户注册、登录，展示用户基础信息，登录状态下可切换编辑模式修改信息。

![image-20250528102523677](https://github.com/BUCT-CS2201/HandheldMuseum/blob/main/image/image-20250528102523677.png)

- **登录 / 注册模块**：用户可通过手机号注册新账号或登录，登录信息本地持久化保存。

![image-20250528102531693](https://github.com/BUCT-CS2201/HandheldMuseum/blob/main/image/image-20250528102531693.png)

- **收藏与浏览记录**：用户可查看收藏记录和浏览历史，点击文物可跳转详情页。

![image-20250528102540296](https://github.com/BUCT-CS2201/HandheldMuseum/blob/main/image/image-20250528102540296.png)

## 技术栈
- **前端**：ArkTS + HarmonyOS + Stage 模型
- **后端**：Node.js + Express + Flask（图像处理模块）
- **数据库**：MySQL（关系型数据库） + Milvus（向量检索）
- **图像处理**：Python + CLIP 模型（transformers）
- **接口调用**：Axios + RESTful API
- **用户状态**：preferences + sessionStorage

## 项目架构
系统采用三层架构，包括前端应用层、应用服务层和数据存储层。前端应用层基于 HarmonyOS 的移动应用，提供用户界面和交互功能；应用服务层使用 Node.js 和 Flask 构建的后端服务，提供业务逻辑处理；数据存储层使用 MySQL 存储结构化数据，Milvus 存储图像特征向量，文件系统存储图片资源。

## 数据库设计
系统采用 MySQL 和 Milvus 作为数据库，MySQL 存储用户信息、文物信息、博物馆信息、评论信息等结构化数据，Milvus 存储图像特征向量，用于以图搜图功能的相似性检索。

## 使用方法
### 环境要求
- CPU：Intel i5 及以上
- 内存：8GB 及以上
- 操作系统：HarmonyOS
- Python 3.10，Node.js >= 16
- MySQL 8.x、Neo4j 5.x

### 后端部署
1. 进入后端目录：`cd backend`
2. 安装依赖：`pip install -r requirements.txt`
3. 启用后端服务：
   - `python upload_image.py`
   - `node server.js`
4. 在 DevEco Studio 运行真机模拟即可

## 文件结构
```
HandheldMuseum/
├── backend
│   ├── config
│   │   └── dbConfig.js
│   ├── routes
│   │   ├── antique.js
│   │   ├── Museum.js
│   │   └── user.js
│   ├── services
│   │   ├── mysqlService.js
│   │   ├── neo4jService.js
│   │   └── upload_image.py
│   ├── server.js
│   └── requirements.txt
├── entry
│   ├── src
│   │   ├── pages
│   │   │   ├── Antique.ets
│   │   │   ├── MuseumDetail.ets
│   │   │   ├── Login.ets
│   │   │   └── Personal.ets
│   │   └── resources
│   │       └── module.json5
│   └── ohosTest
├── comment_image
├── exported_data
├── node_modules
├── package.json
├── .gitignore
└── temp_uploads
```

## 项目状态
项目已完成开发和测试阶段，目前处于稳定运行状态。未来计划引入 AR/VR 技术，提供沉浸式文物展示体验；集成语音导览功能，支持多语言讲解；增加文物知识图谱，提供更深入的关联知识探索；开发个性化推荐功能，基于用户兴趣推荐文物和展览；拓展社交功能，支持用户组织线下活动和文化交流。
