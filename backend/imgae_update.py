import os
import torch
import numpy as np
from PIL import Image
from io import BytesIO
import mysql.connector
from flask import Flask, request, jsonify
from werkzeug.utils import secure_filename
from pymilvus import connections, FieldSchema, CollectionSchema, DataType, Collection, utility
from transformers import CLIPProcessor, CLIPModel
import json
import logging
import requests

#忽略无影响的报错和警告
import warnings
warnings.filterwarnings("ignore", category=FutureWarning)
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# 配置日志
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)




# 配置文件上传
UPLOAD_FOLDER = 'temp_uploads'
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}

# 确保上传文件夹存在
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

def allowed_file(filename):
    """检查文件扩展名是否允许"""
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


# CLIP模型加载
# model = CLIPModel.from_pretrained("openai/clip-vit-base-patch32",force_download=True)
# processor = CLIPProcessor.from_pretrained("openai/clip-vit-base-patch32",force_download=True)
# device = "cuda" if torch.cuda.is_available() else "cpu"
# model = model.to(device)
#上述方法直接从官网下载可能受网络限制  可以把模型手动下载 设置路径即可
model = CLIPModel.from_pretrained("./clip-vit-base-patch32",force_download=True)
processor = CLIPProcessor.from_pretrained("./clip-vit-base-patch32",force_download=True)
device = "cuda" if torch.cuda.is_available() else "cpu"
model = model.to(device)



# Milvus连接配置
MILVUS_HOST = "10.12.112.166"
MILVUS_PORT = "19530"
COLLECTION_NAME = "antique_features"
DIMENSION = 512  # CLIP 特征维度

# MySQL数据库配置
MYSQL_HOST = '123.56.47.51'
MYSQL_USER = 'root'
MYSQL_PASSWORD = 'jike2201!'
MYSQL_DB = 'cultural_relics'



# 连接向量数据库
def connect_to_milvus():
    """连接到Milvus数据库"""
    try:
        connections.connect(host=MILVUS_HOST, port=MILVUS_PORT)
        logger.info(f"Connected to Milvus server at {MILVUS_HOST}:{MILVUS_PORT}")
        return True
    except Exception as e:
        logger.error(f"Failed to connect to Milvus: {e}")
        return False

# 建立特征表
def create_milvus_collection():
    """创建Milvus集合（如果不存在）"""
    if utility.has_collection(COLLECTION_NAME):
        logger.info(f"Collection {COLLECTION_NAME} already exists")
        return Collection(name=COLLECTION_NAME)

    # 定义集合字段
    fields = [
        FieldSchema(name="id", dtype=DataType.INT64, is_primary=True),
        FieldSchema(name="image_vector", dtype=DataType.FLOAT_VECTOR, dim=DIMENSION)

    ]

    # 创建集合
    schema = CollectionSchema(fields=fields, description="Antique image  features")
    collection = Collection(name=COLLECTION_NAME, schema=schema)

    # 创建索引
    index_params = {
        "metric_type": "COSINE",
        "index_type": "IVF_FLAT",
        "params": {"nlist": 128}
    }
    collection.create_index(field_name="image_vector", index_params=index_params)


    logger.info(f"Created collection {COLLECTION_NAME} and indexes")
    return collection

# 连接mysql
def connect_to_mysql():
    """连接到MySQL数据库"""
    try:
        connection = mysql.connector.connect(
            host=MYSQL_HOST,
            port = 3308,
            user=MYSQL_USER,
            password=MYSQL_PASSWORD,
            database=MYSQL_DB
        )
        logger.info(f"Connected to MySQL database at {MYSQL_HOST}")
        return connection
    except Exception as e:
        logger.error(f"Failed to connect to MySQL: {e}")
        return None

# clip图片特征处理 512 dims
def get_image_features(image):
    """使用CLIP获取图像特征"""
    with torch.no_grad():
        inputs = processor(images=image, return_tensors="pt").to(device)
        features = model.get_image_features(**inputs)
        # 归一化特征向量
        features = features / features.norm(dim=1, keepdim=True)
        return features.cpu().numpy().flatten()


# 向量数据库构建
def load_all_antiques_to_milvus():
    """将所有文物图片和文本特征加载到Milvus数据库"""
    # 连接MySQL获取文物ID和图片URL信息
    mysql_conn = connect_to_mysql()
    if not mysql_conn:
        return

    cursor = mysql_conn.cursor(dictionary=True)
    cursor.execute("SELECT relic_id, img_url FROM relic_image")
    antiques = cursor.fetchall()
    cursor.close()
    mysql_conn.close()

    # 连接Milvus
    if not connect_to_milvus():
        return

    collection = create_milvus_collection()
    collection.load()

    # 存储每个文物的特征
    ids = []
    image_vectors = []


    for item in antiques:
        try:
            relic_id = item['relic_id']
            img_url = item['img_url']
            # 下载图片
            response = requests.get(img_url, stream=True,verify=False)
            if response.status_code == 200:
                # 使用BytesIO直接从内存中读取图片
                image = Image.open(BytesIO(response.content)).convert("RGB")
                # 获取图像特征
                img_vector = get_image_features(image)
                ids.append(relic_id)
                image_vectors.append(img_vector)
                logger.info(f"Processed antique ID {relic_id}")
            else:
                logger.warning(
                    f"Failed to download image for antique ID {relic_id}, status code: {response.status_code}")
        except Exception as e:
            logger.error(f"Error processing antique ID {relic_id}: {e}")

    # 批量插入到Milvus
    if ids:
        data = [ids, image_vectors]
        collection.insert(data)
        collection.flush()
        logger.info(f"Inserted {len(ids)} antiques into Milvus collection")





def search_by_image(image_vector, limit=20):
    """根据图像特征搜索相似文物"""
    collection = Collection(name=COLLECTION_NAME)
    collection.load()

    search_params = {"metric_type": "COSINE", "params": {"nprobe": 10}}
    results = collection.search(
        data=[image_vector],
        anns_field="image_vector",
        param=search_params,
        limit=limit,
        output_fields=["id"]
    )

    return [hit.id for hit in results[0]]


# 在原有代码之后添加以下内容：

# Flask初始化
app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 限制上传文件大小为16MB


@app.route('/search_similar', methods=['POST'])
def search_similar_antiques():
    """接收上传的图片，搜索相似文物并返回ID集合"""
    logger.info("Received image search request")
    logger.info("Request headers: %s", request.headers)
    # logger.info("Request body: %s", request.get_data())

    if 'image' not in request.files:
        logger.error("No image file in request")
        return jsonify({
            'code': 400,
            'message': '没有上传图片文件',
            'data': None
        })

    file = request.files['image']

    if file.filename == '':
        logger.error("Empty filename")
        return jsonify({
            'code': 400,
            'message': '文件名为空',
            'data': None
        })

    if file and allowed_file(file.filename):
        try:
            filename = secure_filename(file.filename)
            filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            file.save(filepath)
            logger.info(f"Saved uploaded file: {filepath}")

            image = Image.open(filepath).convert("RGB")
            image_vector = get_image_features(image)
            logger.info("Extracted image features")

            similar_ids = search_by_image(image_vector)
            logger.info(f"Found {len(similar_ids)} similar antiques")

            os.remove(filepath)
            logger.info("Cleaned up temporary file")
            logger.info(similar_ids)

            return jsonify({
                'code': 200,
                'message': '搜索成功',
                'data': {
                    'similar_ids': similar_ids,
                    'count': len(similar_ids)
                }
            })

        except Exception as e:
            logger.error(f"Error processing image: {e}")
            if os.path.exists(filepath):
                os.remove(filepath)
            return jsonify({
                'code': 500,
                'message': f'图片处理失败: {str(e)}',
                'data': None
            })
    else:
        logger.error(f"Invalid file type: {file.filename}")
        return jsonify({
            'code': 400,
            'message': '不支持的文件格式，仅支持png, jpg, jpeg, gif',
            'data': None
        })


# 插入用户图片信息到数据库
def insert_user_image(user_id, comment_id, image_suffix):
    try:
        mysql_conn = connect_to_mysql()
        if not mysql_conn:
            return None

        cursor = mysql_conn.cursor()
        insert_query = """
        INSERT INTO user_image (image_suffix, user_id, comment_id, status)
        VALUES (%s, %s, %s, %s)
        """
        cursor.execute(insert_query, (image_suffix, user_id, comment_id, 0))
        mysql_conn.commit()
        image_id = cursor.lastrowid
        cursor.close()
        mysql_conn.close()
        return image_id
    except Exception as e:
        print(f"Error inserting user image: {e}")
        return None


# 上传图片接口
@app.route('/upload_image', methods=['POST'])
def upload_image():
    if 'image' not in request.files:
        return jsonify({'code': 400, 'message': '没有上传图片文件', 'data': None})

    file = request.files['image']
    user_id = request.headers.get('user_id')
    comment_id = request.headers.get('comment_id')

    if user_id is None or comment_id is None:
        return jsonify({'code': 400, 'message': '缺少用户ID或评论ID', 'data': None})

    if file.filename == '':
        return jsonify({'code': 400, 'message': '文件名为空', 'data': None})

    if file and allowed_file(file.filename):
        try:
            filename = secure_filename(file.filename)
            file_suffix = filename.rsplit('.', 1)[1].lower()
            image_id = insert_user_image(user_id, comment_id, file_suffix)

            if image_id is None:
                return jsonify({'code': 500, 'message': '图片信息插入数据库失败', 'data': None})
            logger.info("image_id: %s", image_id)
            # 使用图片ID作为文件名
            image_filename = f"{image_id}.{file_suffix}"
            filepath = os.path.join('comment_image', image_filename)
            file.save(filepath)

            return jsonify({
                'code': 200,
                'message': '图片上传成功',
                'data': {
                    'image_id': image_id,
                    'image_name': image_filename
                }
            })
        except Exception as e:
            print(f"Error processing image upload: {e}")
            return jsonify({'code': 500, 'message': '图片上传失败', 'data': None})
    else:
        return jsonify({'code': 400, 'message': '不支持的文件格式', 'data': None})

@app.route('/health', methods=['GET'])
def health_check():
    """健康检查接口"""
    return jsonify({
        'code': 200,
        'message': 'Service is running',
        'data': {
            'status': 'healthy',
            'version': '1.0.0'
        }
    })


# 初始化数据库连接和加载数据的函数
def initialize_system():
    """初始化系统，包括连接数据库和加载数据"""
    logger.info("Initializing system...")

    # 连接Milvus
    if not connect_to_milvus():
        logger.error("Failed to connect to Milvus")
        return False

    # 确保集合存在
    collection = create_milvus_collection()

    # 如果集合为空，则加载所有文物数据
    if collection.num_entities == 0:
        logger.info("Collection is empty, loading all antiques...")
        load_all_antiques_to_milvus()
    else:
        logger.info(f"Collection already contains {collection.num_entities} items")

    return True


if __name__ == '__main__':
    # 初始化系统
    if initialize_system():
        # 启动Flask应用
        logger.info("Starting Flask server...")
        app.run(host='0.0.0.0', port=5000, debug=False)
    else:
        logger.error("System initialization failed")