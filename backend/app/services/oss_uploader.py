"""
OSS上传服务 - 将文件上传到阿里云OSS
"""
from typing import Optional
from datetime import datetime, timedelta
import logging
import oss2
from pathlib import Path

from app.core.config import settings

logger = logging.getLogger(__name__)


class OSSUploader:
    """OSS上传器"""
    
    def __init__(self):
        """初始化OSS客户端"""
        # OSS配置(从环境变量读取)
        self.access_key_id = settings.OSS_ACCESS_KEY_ID
        self.access_key_secret = settings.OSS_ACCESS_KEY_SECRET
        self.endpoint = settings.OSS_ENDPOINT
        self.bucket_name = settings.OSS_BUCKET_NAME
        
        # 初始化Auth和Bucket
        if self.access_key_id and self.access_key_secret:
            self.auth = oss2.Auth(self.access_key_id, self.access_key_secret)
            self.bucket = oss2.Bucket(self.auth, self.endpoint, self.bucket_name)
        else:
            logger.warning("OSS配置未设置,上传功能将不可用")
            self.bucket = None
    
    async def upload_quote_file(
        self,
        file_content: bytes,
        quote_id: str,
        file_type: str = "xlsx"
    ) -> Optional[str]:
        """
        上传报价单文件
        
        Args:
            file_content: 文件内容字节流
            quote_id: 报价单ID
            file_type: 文件类型(xlsx/pdf)
        
        Returns:
            文件访问URL或None
        """
        if not self.bucket:
            logger.error("OSS未配置,无法上传文件")
            return None
        
        try:
            # 生成对象键
            now = datetime.now()
            year = now.strftime('%Y')
            month = now.strftime('%m')
            timestamp = now.strftime('%Y%m%d_%H%M%S')
            
            object_key = f"exports/{year}/{month}/{quote_id}/quote-{timestamp}.{file_type}"
            
            # 上传文件
            result = self.bucket.put_object(object_key, file_content)
            
            if result.status == 200:
                logger.info(f"文件上传成功: {object_key}")
                
                # 生成签名URL(有效期24小时)
                url = self.bucket.sign_url('GET', object_key, 24 * 3600)
                return url
            else:
                logger.error(f"文件上传失败,状态码: {result.status}")
                return None
        
        except Exception as e:
            logger.error(f"文件上传异常: {str(e)}", exc_info=True)
            return None
    
    async def upload_template(
        self,
        file_content: bytes,
        template_name: str
    ) -> Optional[str]:
        """
        上传模板文件
        
        Args:
            file_content: 文件内容
            template_name: 模板名称
        
        Returns:
            文件访问URL或None
        """
        if not self.bucket:
            logger.error("OSS未配置,无法上传模板")
            return None
        
        try:
            object_key = f"templates/{template_name}"
            
            # 上传文件
            result = self.bucket.put_object(object_key, file_content)
            
            if result.status == 200:
                logger.info(f"模板上传成功: {object_key}")
                
                # 模板文件设置为公共读
                self.bucket.put_object_acl(object_key, oss2.OBJECT_ACL_PUBLIC_READ)
                
                # 生成公共访问URL
                url = f"https://{self.bucket_name}.{self.endpoint}/{object_key}"
                return url
            else:
                logger.error(f"模板上传失败,状态码: {result.status}")
                return None
        
        except Exception as e:
            logger.error(f"模板上传异常: {str(e)}", exc_info=True)
            return None
    
    def get_file_url(self, object_key: str, expires: int = 3600) -> Optional[str]:
        """
        获取文件签名URL
        
        Args:
            object_key: 对象键
            expires: 过期时间(秒)
        
        Returns:
            签名URL或None
        """
        if not self.bucket:
            return None
        
        try:
            url = self.bucket.sign_url('GET', object_key, expires)
            return url
        except Exception as e:
            logger.error(f"生成签名URL失败: {str(e)}")
            return None
    
    def list_templates(self) -> list:
        """
        列出所有模板文件
        
        Returns:
            模板文件列表
        """
        if not self.bucket:
            return []
        
        try:
            templates = []
            for obj in oss2.ObjectIterator(self.bucket, prefix='templates/'):
                templates.append({
                    "name": obj.key.split('/')[-1],
                    "key": obj.key,
                    "size": obj.size,
                    "last_modified": obj.last_modified
                })
            return templates
        except Exception as e:
            logger.error(f"列出模板失败: {str(e)}")
            return []


# 全局上传器实例
_uploader: Optional[OSSUploader] = None


def get_oss_uploader() -> OSSUploader:
    """获取OSS上传器实例"""
    global _uploader
    if _uploader is None:
        _uploader = OSSUploader()
    return _uploader
