"""
配置管理模块
"""
from typing import List
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """应用配置"""
    
    # 应用配置
    APP_NAME: str = "报价侠系统"
    APP_VERSION: str = "1.0.0"
    APP_DEBUG: bool = True
    APP_HOST: str = "0.0.0.0"
    APP_PORT: int = 8000
    
    # 数据库配置
    DATABASE_URL: str
    DATABASE_POOL_SIZE: int = 20
    DATABASE_MAX_OVERFLOW: int = 10
    
    # Redis配置
    REDIS_URL: str
    REDIS_MAX_CONNECTIONS: int = 50
    
    # 百炼API配置
    DASHSCOPE_API_KEY: str
    BAILIAN_MODEL: str = "qwen-max"
    
    # 阿里云OSS配置
    OSS_ACCESS_KEY_ID: str
    OSS_ACCESS_KEY_SECRET: str
    OSS_ENDPOINT: str
    OSS_BUCKET_NAME: str
    
    # 日志配置
    LOG_LEVEL: str = "INFO"
    LOG_FILE: str = "logs/app.log"
    
    # CORS配置
    CORS_ORIGINS: List[str] = ["http://localhost:3000", "http://localhost:5173"]
    
    # 爬虫配置
    CRAWLER_USER_AGENT: str = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
    CRAWLER_DELAY: int = 2
    CRAWLER_CONCURRENT_REQUESTS: int = 5
    
    # 编排服务配置
    AGENTGO_API_KEY: str = ""
    
    # 限流配置
    RATE_LIMIT_PER_IP: int = 100
    RATE_LIMIT_WINDOW: int = 60
    
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True
    )


# 全局配置实例
settings = Settings()
