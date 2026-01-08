"""
使用优化的 BrowserSessionManager 爬取阿里云百炼模型价格信息

优化特性:
1. 会话复用 - 支持复用已创建的AgentGo session
2. 重试机制 - 自动重试失败的连接
3. 自动Fallback - AgentGo不可用时自动切换到本地浏览器
4. 资源清理 - 自动释放session资源

文档: https://docs.agentgo.live/fundamentals/using-browser-session
"""
import asyncio
import json
import os
import re
from typing import List, Dict, Any, Optional

from browser_session_manager import (
    BrowserSessionManager,
    SessionConfig,
    SessionMode
)

# 目标 URL - 阿里云百炼模型价格页面 (使用公开帮助文档)
TARGET_URL = "https://help.aliyun.com/zh/model-studio/getting-started/models"

# 输出目录
OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__))


def get_session_config() -> SessionConfig:
    """
    获取会话配置
    
    优先使用AgentGo，如果API Key未配置或连接失败，自动fallback到本地浏览器
    """
    api_key = os.getenv("AGENTGO_API_KEY", "")
    
    return SessionConfig(
        api_key=api_key,
        region="sg",  # 新加坡区域，对中国站点延迟较低
        disable_proxy=False,
        connection_timeout=30000,
        page_load_timeout=90000,  # 增加到90秒，阿里云文档站加载较慢
        max_retries=3,
        retry_delay=3.0,  # 增加重试间隔
        headless=True,
        mode=SessionMode.LOCAL  # 直接使用本地浏览器（AgentGo API Key已过期）
    )


async def crawl_bailian_models() -> Optional[List[Dict[str, Any]]]:
    """
    爬取百炼模型价格信息
    
    Returns:
        模型信息列表，失败返回None
    """
    print("=" * 70)
    print("🚀 开始爬取阿里云百炼模型价格信息")
    print("=" * 70)
    
    config = get_session_config()
    
    # 显示当前配置
    if config.api_key:
        print(f"\n📡 配置模式: AUTO (优先AgentGo, region={config.region})")
    else:
        print(f"\n📡 配置模式: LOCAL (未配置AgentGo API Key)")
    
    async with BrowserSessionManager(config) as manager:
        try:
            # 使用 get_page 上下文管理器爬取
            async with manager.get_page(TARGET_URL, wait_until="domcontentloaded") as page:
                # 等待表格加载
                try:
                    await page.wait_for_selector("table", timeout=30000)
                    print("✅ 检测到表格元素")
                except Exception:
                    print("⚠️ 未检测到表格，继续处理...")
                
                # 滚动加载动态内容
                await scroll_to_load_all(page, manager)
                
                # 提取模型信息
                models = await extract_model_info(page)
                
                # 打印会话统计
                stats = manager.get_session_stats()
                print(f"\n📊 会话统计: mode={stats['mode']}, sessions={stats['total_sessions']}")
                
                return models
            
        except Exception as e:
            print(f"❌ 爬取失败: {e}")
            import traceback
            traceback.print_exc()
            return None


async def scroll_to_load_all(page, manager: BrowserSessionManager):
    """
    滚动页面加载所有动态内容
    """
    print("⏳ 滚动加载动态内容...")
    await manager.scroll_and_load(page, scroll_pause=1.0, max_scrolls=5)
    
    # 保存HTML和截图用于调试
    html_path = os.path.join(OUTPUT_DIR, "bailian_page.html")
    screenshot_path = os.path.join(OUTPUT_DIR, "bailian_screenshot.png")
    
    await manager.save_html(page, html_path)
    await manager.take_screenshot(page, screenshot_path)


async def extract_model_info(page) -> list:
    """
    从页面中提取模型信息
    """
    models = []
    
    print("\n📊 开始提取模型信息...")
    
    # 尝试获取所有表格
    tables = await page.query_selector_all("table")
    print(f"   找到 {len(tables)} 个表格")
    
    for i, table in enumerate(tables):
        try:
            # 获取表头
            headers = await table.query_selector_all("th")
            header_texts = [await h.inner_text() for h in headers]
            
            # 获取表格行
            rows = await table.query_selector_all("tbody tr")
            
            print(f"\n   表格 {i+1}: {len(rows)} 行数据")
            if header_texts:
                print(f"   表头: {header_texts[:5]}...")  # 只显示前5个
            
            for row in rows:
                cells = await row.query_selector_all("td")
                cell_texts = [await c.inner_text() for c in cells]
                
                if cell_texts and len(cell_texts) > 0:
                    model_info = {
                        "raw_data": cell_texts,
                        "table_index": i
                    }
                    
                    # 尝试识别模型名称（通常包含 qwen, deepseek 等关键词）
                    for text in cell_texts:
                        text_lower = text.lower()
                        if any(kw in text_lower for kw in ["qwen", "deepseek", "glm", "llama", "baichuan"]):
                            model_info["model_name"] = text.strip()
                            break
                    
                    # 尝试识别价格（包含数字和元）
                    for text in cell_texts:
                        if re.search(r'\d+\.?\d*\s*(元|¥|\$)', text):
                            model_info["price_info"] = text.strip()
                    
                    models.append(model_info)
                    
        except Exception as e:
            print(f"   ⚠️ 解析表格 {i+1} 时出错: {e}")
    
    # 尝试其他方式提取（可能是非表格结构）
    if not models:
        print("\n   尝试其他方式提取...")
        
        # 查找包含价格信息的元素
        all_text = await page.inner_text("body")
        
        # 使用正则匹配模型名称
        model_patterns = [
            r'(qwen[\w\-\.]+)',
            r'(deepseek[\w\-\.]+)',
            r'(glm[\w\-\.]+)',
            r'(llama[\w\-\.]+)',
        ]
        
        found_models = set()
        for pattern in model_patterns:
            matches = re.findall(pattern, all_text, re.IGNORECASE)
            found_models.update(matches)
        
        for model in found_models:
            models.append({"model_name": model, "source": "text_extraction"})
    
    return models


def print_results(models: list):
    """
    打印结果
    """
    print("\n" + "=" * 70)
    print("📋 爬取结果汇总")
    print("=" * 70)
    
    if not models:
        print("❌ 未能提取到模型信息")
        return
    
    print(f"\n✅ 共识别到 {len(models)} 条模型相关数据")
    
    # 按是否有模型名称分类
    named_models = [m for m in models if m.get("model_name")]
    unnamed_data = [m for m in models if not m.get("model_name")]
    
    if named_models:
        print(f"\n📌 识别到的模型名称 ({len(named_models)} 个):")
        seen = set()
        for m in named_models:
            name = m.get("model_name", "").lower()
            if name not in seen:
                seen.add(name)
                price = m.get("price_info", "价格待解析")
                print(f"   • {m['model_name']}")
                if price != "价格待解析":
                    print(f"     价格: {price}")
    
    if unnamed_data:
        print(f"\n📝 其他数据行 ({len(unnamed_data)} 条):")
        for i, m in enumerate(unnamed_data[:10]):  # 只显示前10条
            raw = m.get("raw_data", [])
            if raw:
                print(f"   {i+1}. {' | '.join(str(x)[:30] for x in raw[:3])}")
        if len(unnamed_data) > 10:
            print(f"   ... 还有 {len(unnamed_data) - 10} 条数据")


async def main():
    """主函数"""
    models = await crawl_bailian_models()
    if models is not None:
        print_results(models)
    
    print("\n" + "=" * 70)
    print("✨ 爬取任务完成")
    print("=" * 70)


if __name__ == "__main__":
    asyncio.run(main())
