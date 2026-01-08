"""
爬虫调度服务 - 定时触发爬虫任务并管理任务状态
"""
import asyncio
from typing import Optional, Dict, Any
from datetime import datetime
from uuid import uuid4
import logging
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.crawler import CrawlerTask, TaskStatus
from app.services.aliyun_crawler import AliyunCrawler
from app.services.volcano_crawler import VolcanoCrawler
from app.services.crawler_processor import CrawlerDataProcessor
from app.core.redis_client import get_redis

logger = logging.getLogger(__name__)


class CrawlerScheduler:
    """爬虫调度器"""
    
    def __init__(self):
        self.scheduler = AsyncIOScheduler()
        self.is_running = False
        self.aliyun_crawler = AliyunCrawler()
        self.volcano_crawler = VolcanoCrawler()
        self.processor = CrawlerDataProcessor()
    
    def start(self):
        """启动调度器"""
        if self.is_running:
            logger.warning("调度器已在运行")
            return
        
        # 配置定时任务 - 每周日凌晨2点执行
        self.scheduler.add_job(
            self.run_all_crawlers,
            CronTrigger(day_of_week='sun', hour=2, minute=0),
            id='weekly_crawler',
            name='每周爬虫任务',
            replace_existing=True
        )
        
        # 可选: 每日增量更新任务
        self.scheduler.add_job(
            self.run_incremental_update,
            CronTrigger(hour=3, minute=0),
            id='daily_increment',
            name='每日增量更新',
            replace_existing=True
        )
        
        self.scheduler.start()
        self.is_running = True
        logger.info("爬虫调度器已启动")
    
    def stop(self):
        """停止调度器"""
        if not self.is_running:
            return
        
        self.scheduler.shutdown()
        self.is_running = False
        logger.info("爬虫调度器已停止")
    
    async def run_all_crawlers(self):
        """运行所有爬虫"""
        logger.info("开始执行周期性爬虫任务")
        
        # 并行执行阿里云和火山引擎爬虫
        tasks = [
            self.run_crawler("aliyun"),
            self.run_crawler("volcano")
        ]
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # 记录结果
        for i, result in enumerate(results):
            if isinstance(result, Exception):
                logger.error(f"爬虫任务异常: {str(result)}")
            else:
                logger.info(f"爬虫任务完成: {result}")
    
    async def run_incremental_update(self):
        """运行增量更新"""
        logger.info("开始执行增量更新任务")
        # 增量更新逻辑可以后续实现
        # 例如:只更新价格变化的产品
    
    async def run_crawler(self, task_type: str) -> Dict[str, Any]:
        """
        运行单个爬虫任务
        
        Args:
            task_type: 任务类型(aliyun/volcano)
        
        Returns:
            任务执行结果
        """
        # 检查分布式锁,防止重复执行
        lock_acquired = await self._acquire_lock(task_type)
        if not lock_acquired:
            logger.warning(f"爬虫任务 {task_type} 已在执行中,跳过")
            return {"status": "skipped", "reason": "task_running"}
        
        task_id = str(uuid4())
        
        try:
            # 创建任务记录
            async for db in get_db():
                task = CrawlerTask(
                    task_id=task_id,
                    task_type=task_type,
                    status=TaskStatus.RUNNING,
                    start_time=datetime.now()
                )
                db.add(task)
                await db.commit()
                break
            
            # 执行爬虫
            if task_type == "aliyun":
                result = await self.aliyun_crawler.crawl_all()
            elif task_type == "volcano":
                result = await self.volcano_crawler.crawl_all()
            else:
                raise ValueError(f"未知的任务类型: {task_type}")
            
            # 处理爬取的数据
            async for db in get_db():
                update_count = await self.processor.process_crawler_result(
                    db,
                    result
                )
                
                # 更新任务状态
                task = await db.get(CrawlerTask, task_id)
                if task:
                    task.status = TaskStatus.COMPLETED if result.success else TaskStatus.FAILED
                    task.end_time = datetime.now()
                    task.records_crawled = result.records_crawled
                    task.records_updated = update_count
                    task.error_message = "\n".join(result.errors[:5]) if result.errors else None
                    await db.commit()
                
                break
            
            logger.info(f"爬虫任务 {task_type} 完成: {result.to_dict()}")
            return result.to_dict()
        
        except Exception as e:
            logger.error(f"爬虫任务 {task_type} 失败: {str(e)}", exc_info=True)
            
            # 更新任务状态为失败
            async for db in get_db():
                task = await db.get(CrawlerTask, task_id)
                if task:
                    task.status = TaskStatus.FAILED
                    task.end_time = datetime.now()
                    task.error_message = str(e)
                    await db.commit()
                break
            
            return {"status": "failed", "error": str(e)}
        
        finally:
            # 释放锁
            await self._release_lock(task_type)
    
    async def _acquire_lock(self, task_type: str, timeout: int = 3600) -> bool:
        """
        获取分布式锁
        
        Args:
            task_type: 任务类型
            timeout: 锁超时时间(秒)
        
        Returns:
            是否获取成功
        """
        redis = await get_redis()
        lock_key = f"crawler:lock:{task_type}"
        
        # 使用Redis的SET NX EX命令实现分布式锁
        result = await redis.set(lock_key, "1", ex=timeout, nx=True)
        return result is not None
    
    async def _release_lock(self, task_type: str):
        """释放分布式锁"""
        redis = await get_redis()
        lock_key = f"crawler:lock:{task_type}"
        await redis.delete(lock_key)


# 全局调度器实例
_scheduler: Optional[CrawlerScheduler] = None


def get_crawler_scheduler() -> CrawlerScheduler:
    """获取爬虫调度器实例"""
    global _scheduler
    if _scheduler is None:
        _scheduler = CrawlerScheduler()
    return _scheduler


async def start_crawler_scheduler():
    """启动爬虫调度器"""
    scheduler = get_crawler_scheduler()
    scheduler.start()
    logger.info("爬虫调度器服务已启动")


async def stop_crawler_scheduler():
    """停止爬虫调度器"""
    scheduler = get_crawler_scheduler()
    scheduler.stop()
    logger.info("爬虫调度器服务已停止")
