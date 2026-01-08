"""
爬虫基类 - 提供通用爬虫能力
"""
import asyncio
from abc import ABC, abstractmethod
from typing import Dict, List, Any, Optional
from datetime import datetime
import logging
from aiohttp import ClientSession, ClientTimeout
from bs4 import BeautifulSoup
import json

logger = logging.getLogger(__name__)


class BaseCrawler(ABC):
    """爬虫基类"""
    
    def __init__(
        self,
        timeout: int = 30,
        max_retries: int = 3,
        retry_delay: float = 2.0
    ):
        """
        初始化爬虫
        
        Args:
            timeout: 请求超时时间(秒)
            max_retries: 最大重试次数
            retry_delay: 重试延迟(秒)
        """
        self.timeout = ClientTimeout(total=timeout)
        self.max_retries = max_retries
        self.retry_delay = retry_delay
        
        # 反爬策略配置
        self.user_agents = [
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
        ]
        self.current_ua_index = 0
    
    def get_headers(self) -> Dict[str, str]:
        """获取请求头"""
        self.current_ua_index = (self.current_ua_index + 1) % len(self.user_agents)
        return {
            "User-Agent": self.user_agents[self.current_ua_index],
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
            "Accept-Encoding": "gzip, deflate, br",
            "Connection": "keep-alive"
        }
    
    async def fetch(
        self,
        session: ClientSession,
        url: str,
        method: str = "GET",
        **kwargs
    ) -> Optional[str]:
        """
        发起HTTP请求
        
        Args:
            session: aiohttp会话
            url: 目标URL
            method: HTTP方法
            **kwargs: 其他请求参数
        
        Returns:
            响应文本或None
        """
        for attempt in range(self.max_retries):
            try:
                headers = self.get_headers()
                headers.update(kwargs.pop("headers", {}))
                
                async with session.request(
                    method,
                    url,
                    headers=headers,
                    timeout=self.timeout,
                    **kwargs
                ) as response:
                    if response.status == 200:
                        return await response.text()
                    elif response.status == 429:  # 限流
                        logger.warning(f"受到限流,URL: {url},等待 {self.retry_delay * (attempt + 1)} 秒")
                        await asyncio.sleep(self.retry_delay * (attempt + 1))
                    else:
                        logger.error(f"请求失败,状态码: {response.status}, URL: {url}")
                        return None
                        
            except asyncio.TimeoutError:
                logger.warning(f"请求超时,第 {attempt + 1} 次尝试,URL: {url}")
                if attempt < self.max_retries - 1:
                    await asyncio.sleep(self.retry_delay)
            except Exception as e:
                logger.error(f"请求异常: {str(e)}, URL: {url}")
                if attempt < self.max_retries - 1:
                    await asyncio.sleep(self.retry_delay)
        
        return None
    
    def parse_html(self, html: str) -> BeautifulSoup:
        """解析HTML"""
        return BeautifulSoup(html, "html.parser")
    
    @abstractmethod
    async def crawl_products(self) -> List[Dict[str, Any]]:
        """
        爬取产品数据 - 子类必须实现
        
        Returns:
            产品数据列表
        """
        pass
    
    @abstractmethod
    async def crawl_prices(self, product_code: str) -> List[Dict[str, Any]]:
        """
        爬取产品价格 - 子类必须实现
        
        Args:
            product_code: 产品代码
        
        Returns:
            价格数据列表
        """
        pass
    
    def validate_product_data(self, product: Dict[str, Any]) -> bool:
        """
        验证产品数据完整性
        
        Args:
            product: 产品数据
        
        Returns:
            是否有效
        """
        required_fields = ["product_code", "product_name", "category"]
        return all(field in product and product[field] for field in required_fields)
    
    def validate_price_data(self, price: Dict[str, Any]) -> bool:
        """
        验证价格数据完整性
        
        Args:
            price: 价格数据
        
        Returns:
            是否有效
        """
        required_fields = ["product_code", "unit_price", "unit"]
        return all(field in price and price[field] for field in required_fields)


class CrawlerResult:
    """爬虫结果"""
    
    def __init__(self, task_type: str):
        self.task_type = task_type
        self.start_time = datetime.now()
        self.end_time: Optional[datetime] = None
        self.products: List[Dict[str, Any]] = []
        self.prices: List[Dict[str, Any]] = []
        self.errors: List[str] = []
        self.records_crawled = 0
        self.records_valid = 0
    
    def add_product(self, product: Dict[str, Any]):
        """添加产品数据"""
        self.products.append(product)
        self.records_crawled += 1
    
    def add_price(self, price: Dict[str, Any]):
        """添加价格数据"""
        self.prices.append(price)
        self.records_crawled += 1
    
    def add_error(self, error: str):
        """添加错误信息"""
        self.errors.append(error)
        logger.error(f"爬虫错误 [{self.task_type}]: {error}")
    
    def finish(self):
        """标记完成"""
        self.end_time = datetime.now()
        self.records_valid = len(self.products) + len(self.prices)
    
    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        duration = (self.end_time - self.start_time).total_seconds() if self.end_time else 0
        return {
            "task_type": self.task_type,
            "start_time": self.start_time.isoformat(),
            "end_time": self.end_time.isoformat() if self.end_time else None,
            "duration_seconds": duration,
            "records_crawled": self.records_crawled,
            "records_valid": self.records_valid,
            "products_count": len(self.products),
            "prices_count": len(self.prices),
            "errors_count": len(self.errors),
            "errors": self.errors[:10]  # 只保留前10条错误
        }
    
    @property
    def success(self) -> bool:
        """是否成功"""
        return self.records_valid > 0 and len(self.errors) < self.records_crawled * 0.5
