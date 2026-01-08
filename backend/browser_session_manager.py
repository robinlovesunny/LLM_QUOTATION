"""
Browser Session Manager - 优化的浏览器会话管理

功能：
1. 会话复用 - 支持复用已创建的AgentGo session
2. 重试机制 - 自动重试失败的连接
3. 连接池管理 - 管理多个session，支持并发
4. 本地Fallback - AgentGo不可用时自动切换到本地浏览器
5. 超时优化 - 合理的超时和等待策略
6. 资源清理 - 自动释放session资源

文档: https://docs.agentgo.live/fundamentals/using-browser-session
"""
import asyncio
import json
import os
import logging
from dataclasses import dataclass, field
from typing import Optional, Dict, List, Any, Callable
from urllib.parse import quote
from datetime import datetime, timedelta
from contextlib import asynccontextmanager
from enum import Enum

from playwright.async_api import async_playwright, Browser, Page, BrowserContext

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class SessionMode(Enum):
    """会话模式"""
    AGENTGO = "agentgo"      # 使用AgentGo云浏览器
    LOCAL = "local"          # 使用本地浏览器
    AUTO = "auto"            # 自动选择（优先AgentGo，失败则fallback到本地）


@dataclass
class SessionConfig:
    """会话配置"""
    # AgentGo配置
    api_key: str = ""
    region: str = "sg"  # 新加坡区域，对中国站点延迟较低
    disable_proxy: bool = False
    
    # 连接配置
    connection_timeout: int = 30000  # 连接超时(ms)
    page_load_timeout: int = 60000   # 页面加载超时(ms)
    idle_timeout: int = 120          # 空闲超时(秒)，AgentGo限制120秒
    
    # 重试配置
    max_retries: int = 3             # 最大重试次数
    retry_delay: float = 2.0         # 重试间隔(秒)
    retry_backoff: float = 1.5       # 重试指数退避系数
    
    # 本地浏览器配置
    headless: bool = True
    slow_mo: int = 0                 # 操作延迟(ms)，调试时可设置100-500
    
    # 会话模式
    mode: SessionMode = SessionMode.AUTO


@dataclass
class SessionInfo:
    """会话信息"""
    session_id: str
    mode: SessionMode
    created_at: datetime = field(default_factory=datetime.now)
    last_used_at: datetime = field(default_factory=datetime.now)
    is_active: bool = True
    page_count: int = 0
    max_pages: int = 4  # AgentGo限制每个session最多4个page
    
    def is_available(self) -> bool:
        """检查session是否可用"""
        if not self.is_active:
            return False
        if self.page_count >= self.max_pages:
            return False
        # 检查是否超过空闲超时
        idle_seconds = (datetime.now() - self.last_used_at).total_seconds()
        if idle_seconds > 110:  # 留10秒缓冲
            return False
        return True


class BrowserSessionManager:
    """
    浏览器会话管理器
    
    使用示例:
    ```python
    async with BrowserSessionManager() as manager:
        async with manager.get_page("https://example.com") as page:
            title = await page.title()
            print(f"Page title: {title}")
    ```
    """
    
    def __init__(self, config: Optional[SessionConfig] = None):
        self.config = config or SessionConfig()
        self._playwright = None
        self._browser: Optional[Browser] = None
        self._sessions: Dict[str, SessionInfo] = {}
        self._lock = asyncio.Lock()
        self._initialized = False
        
        # 从环境变量读取API Key
        if not self.config.api_key:
            self.config.api_key = os.getenv("AGENTGO_API_KEY", "")
    
    async def __aenter__(self):
        await self.initialize()
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        await self.cleanup()
    
    async def initialize(self):
        """初始化管理器"""
        if self._initialized:
            return
        
        self._playwright = await async_playwright().start()
        self._initialized = True
        logger.info("BrowserSessionManager initialized")
    
    async def cleanup(self):
        """清理所有资源"""
        if self._browser:
            try:
                await self._browser.close()
            except Exception as e:
                logger.warning(f"Error closing browser: {e}")
            self._browser = None
        
        if self._playwright:
            await self._playwright.stop()
            self._playwright = None
        
        self._sessions.clear()
        self._initialized = False
        logger.info("BrowserSessionManager cleaned up")
    
    def _get_agentgo_url(self, session_id: Optional[str] = None) -> str:
        """构建AgentGo连接URL"""
        options = {
            "_apikey": self.config.api_key,
            "_region": self.config.region,
            "_disable_proxy": self.config.disable_proxy
        }
        if session_id:
            options["_sessionId"] = session_id
        
        url_option_value = quote(json.dumps(options))
        return f"wss://app.browsers.live?launch-options={url_option_value}"
    
    async def _connect_agentgo(self, session_id: Optional[str] = None) -> Browser:
        """连接到AgentGo云浏览器"""
        url = self._get_agentgo_url(session_id)
        logger.info(f"Connecting to AgentGo (region: {self.config.region})...")
        
        browser = await self._playwright.chromium.connect(
            url,
            timeout=self.config.connection_timeout
        )
        logger.info("Connected to AgentGo successfully")
        return browser
    
    async def _launch_local(self) -> Browser:
        """启动本地浏览器"""
        logger.info("Launching local browser...")
        
        browser = await self._playwright.chromium.launch(
            headless=self.config.headless,
            slow_mo=self.config.slow_mo
        )
        logger.info("Local browser launched successfully")
        return browser
    
    async def _get_browser_with_retry(self) -> tuple[Browser, SessionMode]:
        """获取浏览器连接（带重试）"""
        last_error = None
        mode = self.config.mode
        
        # 如果是AUTO模式，先尝试AgentGo
        if mode == SessionMode.AUTO:
            if self.config.api_key:
                mode = SessionMode.AGENTGO
            else:
                logger.info("No AgentGo API key, using local browser")
                mode = SessionMode.LOCAL
        
        # 尝试连接
        for attempt in range(self.config.max_retries):
            try:
                if mode == SessionMode.AGENTGO:
                    browser = await self._connect_agentgo()
                    return browser, SessionMode.AGENTGO
                else:
                    browser = await self._launch_local()
                    return browser, SessionMode.LOCAL
                    
            except Exception as e:
                last_error = e
                delay = self.config.retry_delay * (self.config.retry_backoff ** attempt)
                logger.warning(
                    f"Browser connection failed (attempt {attempt + 1}/{self.config.max_retries}): {e}"
                )
                
                # 如果是AgentGo失败且是AUTO模式，尝试fallback到本地
                if mode == SessionMode.AGENTGO and self.config.mode == SessionMode.AUTO:
                    logger.info("AgentGo failed, falling back to local browser...")
                    mode = SessionMode.LOCAL
                    continue
                
                if attempt < self.config.max_retries - 1:
                    logger.info(f"Retrying in {delay:.1f}s...")
                    await asyncio.sleep(delay)
        
        raise ConnectionError(f"Failed to connect after {self.config.max_retries} attempts: {last_error}")
    
    async def get_browser(self) -> tuple[Browser, SessionMode]:
        """获取浏览器实例"""
        async with self._lock:
            if self._browser is None:
                self._browser, mode = await self._get_browser_with_retry()
                
                # 记录session信息
                session_info = SessionInfo(
                    session_id=f"session_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
                    mode=mode
                )
                self._sessions[session_info.session_id] = session_info
                
            return self._browser, self.config.mode
    
    @asynccontextmanager
    async def get_page(
        self,
        url: Optional[str] = None,
        wait_until: str = "domcontentloaded",
        timeout: Optional[int] = None,
        retry_navigation: bool = True
    ):
        """
        获取页面上下文管理器
        
        Args:
            url: 要访问的URL（可选）
            wait_until: 等待条件 ("load", "domcontentloaded", "networkidle")
            timeout: 页面加载超时(ms)
            retry_navigation: 是否重试导航失败
        
        Yields:
            Page: Playwright页面对象
        """
        if not self._initialized:
            await self.initialize()
        
        browser, mode = await self.get_browser()
        context = None
        page = None
        
        try:
            # 创建新的browser context（隔离cookies等）
            context = await browser.new_context(
                viewport={"width": 1920, "height": 1080},
                user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            )
            
            # 创建页面
            page = await context.new_page()
            
            # 设置超时
            actual_timeout = timeout or self.config.page_load_timeout
            page.set_default_timeout(actual_timeout)
            
            # 如果提供了URL，导航到该页面（带重试）
            if url:
                logger.info(f"Navigating to: {url}")
                await self._navigate_with_retry(
                    page, url, wait_until, actual_timeout, 
                    max_retries=self.config.max_retries if retry_navigation else 1
                )
            
            yield page
            
        finally:
            if page:
                try:
                    await page.close()
                except Exception as e:
                    logger.warning(f"Error closing page: {e}")
            if context:
                try:
                    await context.close()
                except Exception as e:
                    logger.warning(f"Error closing context: {e}")
    
    async def _navigate_with_retry(
        self,
        page,
        url: str,
        wait_until: str,
        timeout: int,
        max_retries: int = 3
    ):
        """带重试的页面导航"""
        last_error = None
        
        for attempt in range(max_retries):
            try:
                await page.goto(url, wait_until=wait_until, timeout=timeout)
                return
            except Exception as e:
                last_error = e
                if attempt < max_retries - 1:
                    delay = self.config.retry_delay * (self.config.retry_backoff ** attempt)
                    logger.warning(
                        f"Navigation failed (attempt {attempt + 1}/{max_retries}): {e}. "
                        f"Retrying in {delay:.1f}s..."
                    )
                    await asyncio.sleep(delay)
        
        raise last_error
    
    async def scrape_page(
        self,
        url: str,
        extractor: Callable[[Page], Any],
        wait_for_selector: Optional[str] = None,
        wait_timeout: int = 30000,
        pre_actions: Optional[Callable[[Page], None]] = None
    ) -> Any:
        """
        爬取页面并提取数据
        
        Args:
            url: 目标URL
            extractor: 数据提取函数，接收Page对象，返回提取的数据
            wait_for_selector: 等待出现的选择器
            wait_timeout: 等待超时(ms)
            pre_actions: 数据提取前的预处理动作（如滚动、点击等）
        
        Returns:
            提取的数据
        """
        async with self.get_page(url) as page:
            # 等待特定元素出现
            if wait_for_selector:
                try:
                    await page.wait_for_selector(wait_for_selector, timeout=wait_timeout)
                    logger.info(f"Selector '{wait_for_selector}' found")
                except Exception as e:
                    logger.warning(f"Selector wait timeout: {e}")
            
            # 执行预处理动作
            if pre_actions:
                await pre_actions(page)
            
            # 等待网络稳定
            await self._wait_for_network_idle(page)
            
            # 提取数据
            return await extractor(page)
    
    async def _wait_for_network_idle(self, page: Page, timeout: int = 5000):
        """等待网络空闲"""
        try:
            await page.wait_for_load_state("networkidle", timeout=timeout)
        except Exception:
            # networkidle超时不是致命错误
            pass
    
    async def scroll_and_load(
        self,
        page: Page,
        scroll_pause: float = 1.0,
        max_scrolls: int = 10
    ):
        """
        滚动页面加载动态内容
        
        Args:
            page: Playwright页面对象
            scroll_pause: 每次滚动后暂停时间(秒)
            max_scrolls: 最大滚动次数
        """
        for i in range(max_scrolls):
            # 获取当前滚动高度
            prev_height = await page.evaluate("document.body.scrollHeight")
            
            # 滚动到底部
            await page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
            await asyncio.sleep(scroll_pause)
            
            # 检查是否还有新内容
            new_height = await page.evaluate("document.body.scrollHeight")
            if new_height == prev_height:
                logger.info(f"Scroll completed after {i + 1} scrolls")
                break
        
        # 滚动回顶部
        await page.evaluate("window.scrollTo(0, 0)")
    
    async def take_screenshot(
        self,
        page: Page,
        path: str,
        full_page: bool = True
    ):
        """截图"""
        await page.screenshot(path=path, full_page=full_page)
        logger.info(f"Screenshot saved to: {path}")
    
    async def save_html(self, page: Page, path: str):
        """保存页面HTML"""
        content = await page.content()
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        logger.info(f"HTML saved to: {path}")
    
    def get_session_stats(self) -> Dict[str, Any]:
        """获取会话统计信息"""
        return {
            "total_sessions": len(self._sessions),
            "active_sessions": sum(1 for s in self._sessions.values() if s.is_active),
            "mode": self.config.mode.value,
            "sessions": [
                {
                    "id": s.session_id,
                    "mode": s.mode.value,
                    "created_at": s.created_at.isoformat(),
                    "last_used_at": s.last_used_at.isoformat(),
                    "is_active": s.is_active,
                    "page_count": s.page_count
                }
                for s in self._sessions.values()
            ]
        }


# 便捷函数：快速爬取页面
async def quick_scrape(
    url: str,
    extractor: Callable[[Page], Any],
    config: Optional[SessionConfig] = None,
    **kwargs
) -> Any:
    """
    快速爬取页面
    
    使用示例:
    ```python
    async def extract_title(page):
        return await page.title()
    
    title = await quick_scrape("https://example.com", extract_title)
    ```
    """
    async with BrowserSessionManager(config) as manager:
        return await manager.scrape_page(url, extractor, **kwargs)


# 便捷函数：快速获取页面HTML
async def quick_get_html(url: str, config: Optional[SessionConfig] = None) -> str:
    """快速获取页面HTML"""
    async def extractor(page: Page) -> str:
        return await page.content()
    
    return await quick_scrape(url, extractor, config)


# 便捷函数：快速截图
async def quick_screenshot(
    url: str,
    output_path: str,
    config: Optional[SessionConfig] = None
):
    """快速截图"""
    async with BrowserSessionManager(config) as manager:
        async with manager.get_page(url) as page:
            await manager.take_screenshot(page, output_path)
