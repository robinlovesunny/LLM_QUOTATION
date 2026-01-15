"""
FastAPI应用主入口
"""
import os
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from loguru import logger

from app.core.config import settings
from app.core.database import init_db
from app.core.redis_client import init_redis
from app.core.middleware import setup_error_handling
from app.api.v1 import api_router
from app.services.crawler_scheduler import start_crawler_scheduler, stop_crawler_scheduler


@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期管理"""
    # 启动时初始化
    logger.info("初始化数据库连接...")
    await init_db()
    
    logger.info("初始化Redis连接...")
    await init_redis()
    
    logger.info("启动爬虫调度器...")
    await start_crawler_scheduler()
    
    logger.info(f"{settings.APP_NAME} 启动完成")
    
    yield
    
    # 关闭时清理
    logger.info("停止爬虫调度器...")
    await stop_crawler_scheduler()
    
    logger.info("关闭数据库连接...")
    logger.info(f"{settings.APP_NAME} 已关闭")


# 创建FastAPI应用
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="一站式智能化报价平台",
    lifespan=lifespan,
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json"
)

# 配置CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 设置错误处理和日志中间件
setup_error_handling(app)

# 确保日志目录存在
os.makedirs("logs", exist_ok=True)

# 注册路由
app.include_router(api_router, prefix="/api/v1")


@app.get("/")
async def root():
    """根路径"""
    return {
        "message": f"欢迎使用{settings.APP_NAME}",
        "version": settings.APP_VERSION,
        "docs": "/api/docs"
    }


@app.get("/health")
async def health_check():
    """基础健康检查"""
    return {"status": "healthy"}


@app.get("/health/detailed")
async def detailed_health_check():
    """
    详细健康检查 - 包含数据库和Redis状态
    用于监控和自动恢复判断
    """
    from app.core.database import engine
    from app.core.redis_client import redis_client
    from sqlalchemy import text
    import time
    
    health_status = {
        "status": "healthy",
        "timestamp": time.time(),
        "version": settings.APP_VERSION,
        "checks": {}
    }
    
    # 检查数据库连接
    try:
        async with engine.begin() as conn:
            await conn.execute(text("SELECT 1"))
        health_status["checks"]["database"] = {"status": "healthy", "message": "连接正常"}
    except Exception as e:
        health_status["checks"]["database"] = {"status": "unhealthy", "message": str(e)}
        health_status["status"] = "degraded"
    
    # 检查Redis连接
    try:
        if redis_client:
            await redis_client.ping()
            health_status["checks"]["redis"] = {"status": "healthy", "message": "连接正常"}
        else:
            health_status["checks"]["redis"] = {"status": "unhealthy", "message": "客户端未初始化"}
            health_status["status"] = "degraded"
    except Exception as e:
        health_status["checks"]["redis"] = {"status": "unhealthy", "message": str(e)}
        health_status["status"] = "degraded"
    
    return health_status


@app.get("/health/live")
async def liveness_check():
    """存活检查 - 仅检查应用是否响应"""
    return {"alive": True}


@app.get("/health/ready")
async def readiness_check():
    """
    就绪检查 - 检查应用是否准备好接收流量
    """
    from app.core.database import engine
    from app.core.redis_client import redis_client
    from sqlalchemy import text
    
    try:
        # 检查数据库
        async with engine.begin() as conn:
            await conn.execute(text("SELECT 1"))
        
        # 检查Redis
        if redis_client:
            await redis_client.ping()
        
        return {"ready": True}
    except Exception as e:
        logger.warning(f"就绪检查失败: {e}")
        from fastapi import Response
        return Response(content='{"ready": false}', status_code=503, media_type="application/json")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=settings.APP_HOST,
        port=settings.APP_PORT,
        reload=settings.APP_DEBUG
    )
