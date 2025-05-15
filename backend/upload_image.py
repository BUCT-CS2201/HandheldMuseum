import os
import numpy as np
import torch
from PIL import Image
from pymilvus import connections, FieldSchema, CollectionSchema, DataType, Collection, utility
from transformers import CLIPProcessor, CLIPModel
import logging

# 配置日志
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Milvus连接配置
MILVUS_HOST = "10.12.112.166"
MILVUS_PORT = "19530"
COLLECTION_NAME = "antique_features"
DIMENSION = 512  # CLIP 特征维度

# 本地图片文件夹配置
IMAGE_FOLDER = 'downloaded_images'

# CLIP模型加载
model = CLIPModel.from_pretrained("L:/Project/Model/pretrain/pretrained/clip-vit-base-patch32")
processor = CLIPProcessor.from_pretrained("L:/Project/Model/pretrain/pretrained/clip-vit-base-patch32")
device = "cuda" if torch.cuda.is_available() else "cpu"
model = model.to(device)

# 连接Milvus
def connect_to_milvus():
    """连接到Milvus数据库"""
    try:
        connections.connect(host=MILVUS_HOST, port=MILVUS_PORT)
        logger.info(f"Connected to Milvus server at {MILVUS_HOST}:{MILVUS_PORT}")
        return True
    except Exception as e:
        logger.error(f"Failed to connect to Milvus: {e}")
        return False

# 创建Milvus集合
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
    schema = CollectionSchema(fields=fields, description="Antique image features")
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

# 提取图片特征
def get_image_features(image_path):
    """使用CLIP获取图像特征"""
    image = Image.open(image_path).convert("RGB")
    inputs = processor(images=image, return_tensors="pt").to(device)
    with torch.no_grad():
        features = model.get_image_features(**inputs)
        # 归一化特征向量
        features = features / features.norm(dim=1, keepdim=True)
    return features.cpu().numpy().flatten()

# 获取Milvus中已存在的ID
def get_existing_ids(collection):
    """获取Milvus集合中已存在的ID"""
    collection.load()
    existing_ids = collection.query(expr="id > 0", output_fields=["id"])
    return [item['id'] for item in existing_ids]

# 逐张图片上传到Milvus
def upload_images_to_milvus():
    """逐张图片上传到Milvus数据库"""
    if not connect_to_milvus():
        logger.error("Failed to connect to Milvus")
        return

    collection = create_milvus_collection()
    existing_ids = get_existing_ids(collection)

    for filename in os.listdir(IMAGE_FOLDER):
        if filename.endswith(('.png', '.jpg', '.jpeg', '.gif')):
            image_path = os.path.join(IMAGE_FOLDER, filename)
            try:
                # 使用文件名（去掉扩展名）作为ID
                image_id = int(os.path.splitext(filename)[0])
                if image_id in existing_ids:
                    logger.info(f"Image with ID {image_id} already exists in Milvus, skipping upload.")
                    continue
                # 提取图片特征
                image_vector = get_image_features(image_path)
                # 插入到Milvus
                collection.insert([[image_id], [image_vector]])
                collection.flush()
                logger.info(f"Uploaded image {filename} with ID {image_id} to Milvus")
            except Exception as e:
                logger.error(f"Error processing image {filename}: {e}")

if __name__ == '__main__':
    upload_images_to_milvus()