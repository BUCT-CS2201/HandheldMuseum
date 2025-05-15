import os
import json
from pymilvus import connections, Collection
import logging
import numpy as np

# 配置日志
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Milvus连接配置
MILVUS_HOST = "10.12.112.166"
MILVUS_PORT = "19530"
COLLECTION_NAME = "antique_features"
DIMENSION = 512  # CLIP 特征维度

# 导出文件配置
EXPORT_FOLDER = 'exported_data'
EXPORT_FILE = 'milvus_data.json'

# 确保导出文件夹存在
if not os.path.exists(EXPORT_FOLDER):
    os.makedirs(EXPORT_FOLDER)

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

# 导出Milvus数据
def export_milvus_data():
    """从Milvus集合中导出数据并保存到本地文件"""
    if not connect_to_milvus():
        logger.error("Failed to connect to Milvus")
        return

    try:
        collection = Collection(name=COLLECTION_NAME)
        collection.load()

        # 查询所有数据
        results = collection.query(expr="id > 0", output_fields=["id", "image_vector"])
        logger.info(f"Queried {len(results)} records from Milvus collection {COLLECTION_NAME}")

        # 转换数据格式
        export_data = []
        for result in results:
            # 将float32转换为Python原生的float类型
            if isinstance(result['image_vector'], np.ndarray):
                result['image_vector'] = result['image_vector'].tolist()
            else:
                result['image_vector'] = [float(x) for x in result['image_vector']]
            export_data.append(result)

        # 保存到本地文件
        export_path = os.path.join(EXPORT_FOLDER, EXPORT_FILE)
        with open(export_path, 'w') as f:
            json.dump(export_data, f, indent=4)
        logger.info(f"Data exported to {export_path}")

    except Exception as e:
        logger.error(f"Error exporting data: {e}")

if __name__ == '__main__':
    export_milvus_data()