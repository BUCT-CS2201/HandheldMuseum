import os
import mysql.connector
import requests
from PIL import Image
from io import BytesIO

# MySQL数据库配置
MYSQL_HOST = '123.56.47.51'
MYSQL_USER = 'root'
MYSQL_PASSWORD = 'jike2201!'
MYSQL_DB = 'cultural_relics'
MYSQL_PORT = 3308  # 数据库端口

# 本地文件夹配置
DOWNLOAD_FOLDER = 'downloaded_images'

# 确保下载文件夹存在
if not os.path.exists(DOWNLOAD_FOLDER):
    os.makedirs(DOWNLOAD_FOLDER)

def download_images():
    """从MySQL数据库下载图片到本地文件夹"""
    try:
        # 连接MySQL数据库
        connection = mysql.connector.connect(
            host=MYSQL_HOST,
            user=MYSQL_USER,
            password=MYSQL_PASSWORD,
            database=MYSQL_DB,
            port=MYSQL_PORT
        )
        cursor = connection.cursor(dictionary=True)

        # 查询图片URL和文物ID
        cursor.execute("SELECT relic_id, img_url FROM relic_image")
        images = cursor.fetchall()

        for image in images:
            relic_id = image['relic_id']
            img_url = image['img_url']

            # 构造本地文件路径
            filename = f"{relic_id}.jpg"
            filepath = os.path.join(DOWNLOAD_FOLDER, filename)

            # 检查文件是否已经存在
            if os.path.exists(filepath):
                print(f"Image for relic ID {relic_id} already exists, skipping download.")
                continue

            # 下载图片
            response = requests.get(img_url, stream=True, verify=False)
            if response.status_code == 200:
                # 使用BytesIO直接从内存中读取图片
                image_data = Image.open(BytesIO(response.content)).convert("RGB")
                # 保存图片到本地文件夹
                image_data.save(filepath)
                print(f"Downloaded and saved image for relic ID {relic_id}")
            else:
                print(f"Failed to download image for relic ID {relic_id}, status code: {response.status_code}")

        cursor.close()
        connection.close()

    except Exception as e:
        print(f"Error: {e}")

if __name__ == '__main__':
    download_images()