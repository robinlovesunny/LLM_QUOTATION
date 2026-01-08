"""
Redis客户端管理
"""
import redis.asyncio as redis
from loguru import logger

from app.core.config import settings

# Redis客户端
redis_client: redis.Redis = None


async def init_redis():
    """初始化Redis连接"""
    global redis_client
    try:
        redis_client = redis.from_url(
            settings.REDIS_URL,
            encoding="utf-8",
            decode_responses=True,
            max_connections=settings.REDIS_MAX_CONNECTIONS
        )
        # 测试连接
        await redis_client.ping()
        logger.info("Redis连接初始化成功")
    except Exception as e:
        logger.error(f"Redis连接初始化失败: {e}")
        raise


async def get_redis() -> redis.Redis:
    """获取Redis客户端"""
    return redis_client


async def close_redis():
    """关闭Redis连接"""
    if redis_client:
        await redis_client.close()
        logger.info("Redis连接已关闭")
