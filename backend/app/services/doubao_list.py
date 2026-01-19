"""
火山引擎豆包大模型定价爬虫 - 独立爬虫模块
用于获取火山方舟平台模型定价信息

目标URL: https://www.volcengine.com/pricing?product=ark_bd&tab=1
获取分类: 深度思考模型、大语言模型、视觉理解模型、视觉大模型、语音大模型
排除分类: GUI Agent模型、向量模型、模型精调

注意: 本文件为独立爬虫，不影响原工程的爬虫规则

使用方法:
1. 安装依赖: pip install playwright && playwright install chromium
2. 运行爬虫: python -m app.services.doubao_list
3. 输出文件: doubao_pricing_YYYYMMDD_HHMMSS.json
"""

import asyncio
import json
import logging
import re
from datetime import datetime
from typing import Dict, List, Any, Optional
from pathlib import Path

try:
    from aiohttp import ClientSession, ClientTimeout
    AIOHTTP_AVAILABLE = True
except ImportError:
    AIOHTTP_AVAILABLE = False

logger = logging.getLogger(__name__)


class DoubaoListCrawler:
    """
    豆包大模型定价爬虫
    
    使用 Playwright 获取动态渲染的定价页面数据
    """
    
    # 目标URL
    TARGET_URL = "https://www.volcengine.com/pricing?product=ark_bd&tab=1"
    
    # 需要获取的模型分类
    TARGET_CATEGORIES = [
        "深度思考模型",
        "大语言模型", 
        "视觉理解模型",
        "视觉大模型",
        "语音大模型"
    ]
    
    # 排除的分类
    EXCLUDED_CATEGORIES = [
        "GUI Agent模型",
        "向量模型",
        "模型精调"
    ]
    
    def __init__(self, output_dir: str = None):
        """
        初始化爬虫
        
        Args:
            output_dir: 输出目录，默认为当前目录
        """
        self.output_dir = Path(output_dir) if output_dir else Path(__file__).parent.parent.parent
        self.crawl_time = None
        
    async def crawl(self) -> Dict[str, Any]:
        """
        执行爬取任务
        
        Returns:
            包含分类定价数据的字典
        """
        self.crawl_time = datetime.now().isoformat()
        result = {
            "crawl_time": self.crawl_time,
            "source_url": self.TARGET_URL,
            "categories": {}
        }
        
        # 尝试使用 Playwright 爬取（支持动态页面）
        try:
            from playwright.async_api import async_playwright
            playwright_available = True
        except ImportError:
            playwright_available = False
            logger.warning("playwright 未安装，将使用备用方法")
        
        if playwright_available:
            try:
                async with async_playwright() as p:
                    # 启动浏览器（headless模式）
                    browser = await p.chromium.launch(headless=True)
                    page = await browser.new_page()
                    
                    logger.info(f"正在访问: {self.TARGET_URL}")
                    await page.goto(self.TARGET_URL, wait_until="networkidle", timeout=60000)
                    
                    # 等待页面完全加载（价格数据需要等待渲染）
                    await page.wait_for_timeout(5000)
                    
                    # 提取各分类的定价数据
                    for category in self.TARGET_CATEGORIES:
                        try:
                            category_data = await self._extract_category_data(page, category)
                            if category_data:
                                result["categories"][category] = category_data
                                logger.info(f"成功获取 {category} 数据: {len(category_data)} 条")
                        except Exception as e:
                            logger.error(f"获取 {category} 数据失败: {str(e)}")
                            result["categories"][category] = []
                    
                    await browser.close()
                    return result
                    
            except Exception as e:
                error_msg = str(e)
                # 检查是否是浏览器未安装的错误
                if "Executable doesn't exist" in error_msg:
                    logger.error("Playwright 浏览器未安装，请运行: playwright install chromium")
                    result["error"] = "请先安装浏览器: playwright install chromium"
                else:
                    logger.error(f"Playwright 爬取失败: {error_msg}")
                    result["error"] = error_msg
        else:
            result["error"] = "请先安装 playwright: pip install playwright && playwright install chromium"
        
        return result
    
    async def _extract_category_data(self, page, category: str) -> List[Dict[str, Any]]:
        """
        提取指定分类的定价数据
        
        Args:
            page: Playwright 页面对象
            category: 分类名称
            
        Returns:
            该分类下的模型定价列表
        """
        # 根据分类类型选择不同的提取逻辑
        if category in ["深度思考模型", "大语言模型", "视觉理解模型"]:
            return await self._extract_token_based_pricing(page, category)
        elif category == "视觉大模型":
            return await self._extract_vision_model_pricing(page)
        elif category == "语音大模型":
            return await self._extract_speech_model_pricing(page)
        else:
            return []
    
    async def _extract_token_based_pricing(self, page, category: str) -> List[Dict[str, Any]]:
        """
        提取基于Token计费的模型定价（深度思考/大语言/视觉理解）
        
        Args:
            page: Playwright 页面对象
            category: 分类名称
            
        Returns:
            模型定价列表
        """
        # 使用更简单的JavaScript提取方法：直接解析页面文本
        js_code = f"""
        () => {{
            const result = [];
            const fullText = document.body.innerText;
            
            // 定义所有分类及其顺序
            const allCategories = [
                '深度思考模型', '大语言模型', '视觉理解模型', 
                'GUI Agent模型', '视觉大模型', '语音大模型', 
                '向量模型', '模型精调'
            ];
            
            // 找到当前分类的起始位置
            const startIdx = fullText.indexOf('{category}');
            if (startIdx === -1) return result;
            
            // 找到下一个分类的位置作为结束位置
            let endIdx = fullText.length;
            for (const cat of allCategories) {{
                if (cat === '{category}') continue;
                const idx = fullText.indexOf(cat, startIdx + '{category}'.length);
                if (idx !== -1 && idx < endIdx) {{
                    endIdx = idx;
                }}
            }}
            
            // 提取该分类的文本内容
            const sectionText = fullText.substring(startIdx, endIdx);
            const lines = sectionText.split('\\n').map(l => l.trim()).filter(l => l);
            
            // 识别模型提供方
            const providers = ['字节跳动', '深度求索', '月之暗面', '阿里云Wan-AI'];
            
            // 解析数据行
            let currentProvider = '';
            for (let i = 0; i < lines.length; i++) {{
                const line = lines[i];
                
                // 更新当前提供方
                if (providers.includes(line)) {{
                    currentProvider = line;
                    continue;
                }}
                
                // 识别模型名称（包含特定关键词）
                const modelKeywords = ['Doubao', 'DeepSeek', 'Kimi'];
                const isModelLine = modelKeywords.some(k => line.includes(k));
                
                if (isModelLine && line.includes('（') && (line.includes('输入') || line.includes('输出'))) {{
                    const modelName = line;
                    
                    // 向后查找上下文长度、服务类型和价格
                    let contextLength = '';
                    let serviceType = '';
                    let price = '';
                    
                    for (let j = i + 1; j < Math.min(i + 5, lines.length); j++) {{
                        const nextLine = lines[j];
                        
                        // 跳过空行和提供方
                        if (!nextLine || providers.includes(nextLine)) break;
                        
                        // 检测上下文长度（包含k的数字，如32k, 128k, 256k）
                        if (!contextLength && (nextLine.match(/\\d+k/i) || nextLine.includes('输入长度'))) {{
                            contextLength = nextLine;
                            continue;
                        }}
                        
                        // 检测服务类型
                        if (!serviceType && (nextLine.includes('推理') || nextLine.includes('批量'))) {{
                            serviceType = nextLine;
                            continue;
                        }}
                        
                        // 检测价格（纯数字或小数）
                        if (!price && /^\\d+\\.?\\d*$/.test(nextLine)) {{
                            price = nextLine;
                            break;
                        }}
                    }}
                    
                    // 只添加有价格的记录
                    if (price && price !== '-') {{
                        result.push({{
                            provider: currentProvider || '字节跳动',
                            model: modelName,
                            context_length: contextLength,
                            service_type: serviceType,
                            price: price,
                            unit: '元/千tokens'
                        }});
                    }}
                }}
            }}
            
            return result;
        }}
        """
        
        try:
            data = await page.evaluate(js_code)
            if data and len(data) > 0:
                return data
            # 如果没有数据，使用备用方法
            logger.warning(f"{category} 主方法未获取到数据，尝试备用方法")
            return await self._extract_by_text_parsing(page, category)
        except Exception as e:
            logger.error(f"提取 {category} 数据时出错: {str(e)}")
            return await self._extract_by_text_parsing(page, category)
    
    async def _extract_by_text_parsing(self, page, category: str) -> List[Dict[str, Any]]:
        """
        备用方法：通过文本解析提取数据
        
        Args:
            page: Playwright 页面对象
            category: 分类名称
            
        Returns:
            模型定价列表
        """
        # 获取页面全文
        full_text = await page.evaluate("() => document.body.innerText")
        
        # 定义分类边界
        all_categories = [
            "深度思考模型", "大语言模型", "视觉理解模型",
            "GUI Agent模型", "视觉大模型", "语音大模型", 
            "向量模型", "模型精调"
        ]
        
        # 找到当前分类的位置
        start_idx = full_text.find(category)
        if start_idx == -1:
            return []
        
        # 找到下一个分类的位置
        end_idx = len(full_text)
        for cat in all_categories:
            if cat == category:
                continue
            idx = full_text.find(cat, start_idx + len(category))
            if idx != -1 and idx < end_idx:
                end_idx = idx
        
        # 提取该分类的文本
        section_text = full_text[start_idx:end_idx]
        
        # 解析表格数据
        result = []
        lines = section_text.split('\n')
        
        current_provider = ""
        for i, line in enumerate(lines):
            line = line.strip()
            
            # 识别提供方
            if line in ["字节跳动", "深度求索", "月之暗面", "阿里云Wan-AI"]:
                current_provider = line
                continue
            
            # 识别模型名称行（包含特定关键词的行）
            if any(keyword in line for keyword in ["Doubao", "DeepSeek", "Kimi"]):
                model_name = line
                # 尝试获取后续的上下文长度、服务类型和价格
                context = lines[i + 1].strip() if i + 1 < len(lines) else ""
                service_type = lines[i + 2].strip() if i + 2 < len(lines) else ""
                price = lines[i + 3].strip() if i + 3 < len(lines) else ""
                
                # 验证价格格式
                try:
                    if price and price != "-":
                        float(price)
                        result.append({
                            "provider": current_provider,
                            "model": model_name,
                            "context_length": context,
                            "service_type": service_type,
                            "price": price,
                            "unit": "元/千tokens"
                        })
                except ValueError:
                    pass
        
        return result
    
    async def _extract_vision_model_pricing(self, page) -> List[Dict[str, Any]]:
        """
        提取视觉大模型定价
        
        Args:
            page: Playwright 页面对象
            
        Returns:
            视觉大模型定价列表
        """
        js_code = """
        () => {
            const result = [];
            const fullText = document.body.innerText;
            
            // 找到视觉大模型分类
            const startIdx = fullText.indexOf('视觉大模型');
            if (startIdx === -1) return result;
            
            // 找到下一个分类
            const endIdx = fullText.indexOf('语音大模型', startIdx);
            const sectionText = endIdx !== -1 ? fullText.substring(startIdx, endIdx) : fullText.substring(startIdx);
            
            // 提取模型信息
            const models = [
                'Doubao-Seedance-1.0-pro',
                'Doubao-Seedance-1.0-lite', 
                'Wan2.1-14B',
                'Doubao-Seedream4.0',
                'Doubao-Seedream3.0',
                'Doubao-SeedEdit3.0'
            ];
            
            const lines = sectionText.split('\\n');
            let currentProvider = '';
            
            for (let i = 0; i < lines.length; i++) {
                const line = lines[i].trim();
                
                if (line === '字节跳动' || line === '阿里云Wan-AI') {
                    currentProvider = line;
                    continue;
                }
                
                for (const modelName of models) {
                    if (line === modelName) {
                        // 获取价格和单位
                        let price = '';
                        let unit = '';
                        let freeQuota = '';
                        
                        // 查找后续的价格信息
                        for (let j = i + 1; j < Math.min(i + 5, lines.length); j++) {
                            const nextLine = lines[j].trim();
                            // 检查是否为价格
                            if (/^\\d+\\.?\\d*$/.test(nextLine)) {
                                price = nextLine;
                            }
                            // 检查是否为单位
                            if (nextLine === '千tokens' || nextLine === '张') {
                                unit = nextLine;
                            }
                            // 检查是否为免费额度
                            if (nextLine.includes('万tokens') || nextLine.includes('张')) {
                                if (!freeQuota) freeQuota = nextLine;
                            }
                        }
                        
                        if (price) {
                            result.push({
                                provider: currentProvider || '字节跳动',
                                model: modelName,
                                price: price,
                                unit: '元/' + (unit || '次'),
                                free_quota: freeQuota
                            });
                        }
                        break;
                    }
                }
            }
            
            return result;
        }
        """
        
        try:
            data = await page.evaluate(js_code)
            return data if data else []
        except Exception as e:
            logger.error(f"提取视觉大模型数据时出错: {str(e)}")
            return []
    
    async def _extract_speech_model_pricing(self, page) -> List[Dict[str, Any]]:
        """
        提取语音大模型定价
        
        Args:
            page: Playwright 页面对象
            
        Returns:
            语音大模型定价列表
        """
        js_code = """
        () => {
            const result = [];
            const fullText = document.body.innerText;
            
            // 找到语音大模型分类
            const startIdx = fullText.indexOf('语音大模型');
            if (startIdx === -1) return result;
            
            // 找到下一个分类（向量模型）
            const endIdx = fullText.indexOf('向量模型', startIdx);
            const sectionText = endIdx !== -1 ? fullText.substring(startIdx, endIdx) : fullText.substring(startIdx);
            
            // 语音模型列表
            const models = [
                {name: '语音合成大模型', type: '推理服务'},
                {name: '声音复刻大模型', type: '推理服务'}
            ];
            
            const lines = sectionText.split('\\n');
            
            for (const model of models) {
                const modelIdx = lines.findIndex(line => line.trim() === model.name);
                if (modelIdx !== -1) {
                    // 查找价格
                    for (let j = modelIdx + 1; j < Math.min(modelIdx + 5, lines.length); j++) {
                        const line = lines[j].trim();
                        if (/^\\d+$/.test(line)) {
                            result.push({
                                provider: '字节跳动',
                                model: model.name,
                                service_type: model.type,
                                price: line,
                                unit: '元/万字符',
                                free_quota: '5000 字符'
                            });
                            break;
                        }
                    }
                }
            }
            
            return result;
        }
        """
        
        try:
            data = await page.evaluate(js_code)
            return data if data else []
        except Exception as e:
            logger.error(f"提取语音大模型数据时出错: {str(e)}")
            return []
    
    def save_to_json(self, data: Dict[str, Any], filename: str = None) -> str:
        """
        将数据保存为JSON文件
        
        Args:
            data: 要保存的数据
            filename: 文件名，默认使用时间戳命名
            
        Returns:
            保存的文件路径
        """
        if not filename:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"doubao_pricing_{timestamp}.json"
        
        filepath = self.output_dir / filename
        
        # 确保目录存在
        filepath.parent.mkdir(parents=True, exist_ok=True)
        
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        
        logger.info(f"数据已保存到: {filepath}")
        return str(filepath)


async def crawl_doubao_pricing(output_dir: str = None, save_json: bool = True) -> Dict[str, Any]:
    """
    便捷函数：爬取豆包大模型定价信息
    
    Args:
        output_dir: 输出目录
        save_json: 是否保存为JSON文件
        
    Returns:
        定价数据字典
    """
    crawler = DoubaoListCrawler(output_dir=output_dir)
    data = await crawler.crawl()
    
    if save_json and data:
        crawler.save_to_json(data)
    
    return data


# 命令行入口
if __name__ == "__main__":
    import sys
    
    # 配置日志
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    # 解析命令行参数
    output_dir = sys.argv[1] if len(sys.argv) > 1 else None
    
    # 运行爬虫
    result = asyncio.run(crawl_doubao_pricing(output_dir=output_dir))
    
    # 打印结果摘要
    print("\n" + "=" * 50)
    print("爬取完成!")
    print("=" * 50)
    
    if "categories" in result:
        for category, models in result["categories"].items():
            if isinstance(models, list):
                print(f"{category}: {len(models)} 条记录")
            elif isinstance(models, dict) and "error" in models:
                print(f"{category}: 获取失败 - {models['error']}")
    
    if "error" in result:
        print(f"错误: {result['error']}")
