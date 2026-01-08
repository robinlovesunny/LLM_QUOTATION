"""
爬虫管理API路由
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from typing import List, Optional
from datetime import datetime

from app.core.database import get_db
from app.models.crawler import CrawlerTask, TaskStatus
from app.services.crawler_scheduler import get_crawler_scheduler
from pydantic import BaseModel

router = APIRouter(prefix="/crawler", tags=["爬虫管理"])


# ========== Schemas ==========
class CrawlerTaskResponse(BaseModel):
    """爬虫任务响应"""
    task_id: str
    task_type: str
    status: str
    start_time: Optional[datetime]
    end_time: Optional[datetime]
    records_crawled: Optional[int]
    records_updated: Optional[int]
    error_message: Optional[str]
    
    class Config:
        from_attributes = True


class CrawlerTaskListResponse(BaseModel):
    """爬虫任务列表响应"""
    tasks: List[CrawlerTaskResponse]
    total: int


class TriggerTaskRequest(BaseModel):
    """触发任务请求"""
    task_type: str  # aliyun / volcano


class TriggerTaskResponse(BaseModel):
    """触发任务响应"""
    task_id: str
    message: str


class CrawlerStatsResponse(BaseModel):
    """爬虫统计信息"""
    total_tasks: int
    completed_tasks: int
    failed_tasks: int
    running_tasks: int
    last_aliyun_crawl: Optional[datetime]
    last_volcano_crawl: Optional[datetime]


# ========== API Endpoints ==========
@router.post("/tasks", response_model=TriggerTaskResponse)
async def trigger_crawler_task(
    request: TriggerTaskRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    手动触发爬虫任务
    
    Args:
        request: 触发请求
        db: 数据库会话
    
    Returns:
        任务ID和消息
    """
    if request.task_type not in ["aliyun", "volcano"]:
        raise HTTPException(
            status_code=400,
            detail="无效的任务类型,支持: aliyun, volcano"
        )
    
    # 检查是否有正在运行的任务
    result = await db.execute(
        select(CrawlerTask).where(
            CrawlerTask.task_type == request.task_type,
            CrawlerTask.status == TaskStatus.RUNNING
        )
    )
    running_task = result.scalar_one_or_none()
    
    if running_task:
        raise HTTPException(
            status_code=409,
            detail=f"任务类型 {request.task_type} 已有正在运行的任务"
        )
    
    # 异步触发任务
    scheduler = get_crawler_scheduler()
    import asyncio
    asyncio.create_task(scheduler.run_crawler(request.task_type))
    
    return TriggerTaskResponse(
        task_id="pending",
        message=f"爬虫任务 {request.task_type} 已触发,正在执行"
    )


@router.get("/tasks", response_model=CrawlerTaskListResponse)
async def get_crawler_tasks(
    task_type: Optional[str] = Query(None, description="任务类型过滤"),
    status: Optional[str] = Query(None, description="状态过滤"),
    page: int = Query(1, ge=1, description="页码"),
    size: int = Query(20, ge=1, le=100, description="每页数量"),
    db: AsyncSession = Depends(get_db)
):
    """
    获取爬虫任务列表
    
    Args:
        task_type: 任务类型过滤
        status: 状态过滤
        page: 页码
        size: 每页数量
        db: 数据库会话
    
    Returns:
        任务列表
    """
    # 构建查询
    query = select(CrawlerTask)
    
    if task_type:
        query = query.where(CrawlerTask.task_type == task_type)
    
    if status:
        try:
            status_enum = TaskStatus(status)
            query = query.where(CrawlerTask.status == status_enum)
        except ValueError:
            raise HTTPException(
                status_code=400,
                detail=f"无效的状态值: {status}"
            )
    
    # 总数查询
    from sqlalchemy import func
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar()
    
    # 分页查询
    query = query.order_by(desc(CrawlerTask.start_time))
    query = query.offset((page - 1) * size).limit(size)
    
    result = await db.execute(query)
    tasks = result.scalars().all()
    
    return CrawlerTaskListResponse(
        tasks=[
            CrawlerTaskResponse(
                task_id=task.task_id,
                task_type=task.task_type,
                status=task.status.value,
                start_time=task.start_time,
                end_time=task.end_time,
                records_crawled=task.records_crawled,
                records_updated=task.records_updated,
                error_message=task.error_message
            )
            for task in tasks
        ],
        total=total
    )


@router.get("/tasks/{task_id}", response_model=CrawlerTaskResponse)
async def get_crawler_task(
    task_id: str,
    db: AsyncSession = Depends(get_db)
):
    """
    获取爬虫任务详情
    
    Args:
        task_id: 任务ID
        db: 数据库会话
    
    Returns:
        任务详情
    """
    task = await db.get(CrawlerTask, task_id)
    
    if not task:
        raise HTTPException(status_code=404, detail="任务不存在")
    
    return CrawlerTaskResponse(
        task_id=task.task_id,
        task_type=task.task_type,
        status=task.status.value,
        start_time=task.start_time,
        end_time=task.end_time,
        records_crawled=task.records_crawled,
        records_updated=task.records_updated,
        error_message=task.error_message
    )


@router.get("/stats", response_model=CrawlerStatsResponse)
async def get_crawler_stats(db: AsyncSession = Depends(get_db)):
    """
    获取爬虫统计信息
    
    Args:
        db: 数据库会话
    
    Returns:
        统计信息
    """
    from sqlalchemy import func
    
    # 总任务数
    total_result = await db.execute(
        select(func.count()).select_from(CrawlerTask)
    )
    total_tasks = total_result.scalar()
    
    # 已完成任务数
    completed_result = await db.execute(
        select(func.count()).select_from(CrawlerTask).where(
            CrawlerTask.status == TaskStatus.COMPLETED
        )
    )
    completed_tasks = completed_result.scalar()
    
    # 失败任务数
    failed_result = await db.execute(
        select(func.count()).select_from(CrawlerTask).where(
            CrawlerTask.status == TaskStatus.FAILED
        )
    )
    failed_tasks = failed_result.scalar()
    
    # 运行中任务数
    running_result = await db.execute(
        select(func.count()).select_from(CrawlerTask).where(
            CrawlerTask.status == TaskStatus.RUNNING
        )
    )
    running_tasks = running_result.scalar()
    
    # 最近的阿里云爬虫时间
    aliyun_result = await db.execute(
        select(CrawlerTask.start_time).where(
            CrawlerTask.task_type == "aliyun",
            CrawlerTask.status == TaskStatus.COMPLETED
        ).order_by(desc(CrawlerTask.start_time)).limit(1)
    )
    last_aliyun_crawl = aliyun_result.scalar_one_or_none()
    
    # 最近的火山引擎爬虫时间
    volcano_result = await db.execute(
        select(CrawlerTask.start_time).where(
            CrawlerTask.task_type == "volcano",
            CrawlerTask.status == TaskStatus.COMPLETED
        ).order_by(desc(CrawlerTask.start_time)).limit(1)
    )
    last_volcano_crawl = volcano_result.scalar_one_or_none()
    
    return CrawlerStatsResponse(
        total_tasks=total_tasks,
        completed_tasks=completed_tasks,
        failed_tasks=failed_tasks,
        running_tasks=running_tasks,
        last_aliyun_crawl=last_aliyun_crawl,
        last_volcano_crawl=last_volcano_crawl
    )
