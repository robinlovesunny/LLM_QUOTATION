"""
百炼模型数据解析器 - 将爬取的 HTML 转换为结构化 JSON
"""
import json
import re
from datetime import datetime
from bs4 import BeautifulSoup
from typing import Dict, List, Any, Optional


class BailianModelParser:
    """百炼模型数据解析器"""
    
    def __init__(self, html_file: str):
        with open(html_file, 'r', encoding='utf-8') as f:
            self.soup = BeautifulSoup(f.read(), 'html.parser')
        
        self.models: List[Dict[str, Any]] = []
        self.current_region = "cn-beijing"
        self.current_category = "text_generation"
    
    def parse(self) -> Dict[str, Any]:
        """解析 HTML 并返回结构化数据"""
        
        # 解析所有表格
        self._parse_all_tables()
        
        # 构建最终输出
        result = {
            "metadata": {
                "source": "https://help.aliyun.com/zh/model-studio/getting-started/models",
                "crawl_time": datetime.now().isoformat(),
                "version": "1.0.0"
            },
            "models": self.models
        }
        
        return result
    
    def _parse_all_tables(self):
        """解析所有表格"""
        tables = self.soup.find_all('table')
        print(f"找到 {len(tables)} 个表格")
        
        # 获取所有标题用于上下文判断
        headings = self.soup.find_all(['h1', 'h2', 'h3', 'h4'])
        
        current_section = ""
        current_region = "cn-beijing"
        
        for table in tables:
            # 尝试获取表格前的标题来确定上下文
            prev = table.find_previous(['h2', 'h3', 'h4'])
            if prev:
                section_text = prev.get_text(strip=True)
                if '新加坡' in section_text or '国际' in section_text:
                    current_region = "ap-southeast-1"
                elif '北京' in section_text or '中国内地' in section_text:
                    current_region = "cn-beijing"
                current_section = section_text
            
            # 解析表格
            self._parse_model_table(table, current_region, current_section)
    
    def _parse_model_table(self, table, region: str, section: str):
        """解析单个模型表格"""
        rows = table.find_all('tr')
        if not rows:
            return
        
        # 获取表头
        headers = []
        header_row = rows[0]
        for th in header_row.find_all(['th', 'td']):
            headers.append(th.get_text(strip=True))
        
        # 检查是否是价格表格
        is_pricing_table = any(kw in ' '.join(headers).lower() for kw in 
                              ['价格', '输入', '输出', 'token', '模型名称', '单价'])
        
        if not is_pricing_table:
            return
        
        # 解析数据行
        for row in rows[1:]:
            cells = row.find_all(['td', 'th'])
            if not cells:
                continue
            
            cell_texts = [c.get_text(strip=True) for c in cells]
            
            # 尝试提取模型信息
            model_info = self._extract_model_from_row(headers, cell_texts, region, section)
            if model_info:
                self._merge_or_add_model(model_info)
    
    def _extract_model_from_row(self, headers: List[str], cells: List[str], 
                                 region: str, section: str) -> Optional[Dict]:
        """从表格行提取模型信息"""
        if not cells or len(cells) < 2:
            return None
        
        # 尝试识别模型名称
        model_id = None
        model_name = None
        
        for i, cell in enumerate(cells):
            # 精确匹配模型 ID（API 名称）- 只匹配标准格式
            # 模型ID格式: 字母开头，可包含字母数字和-._，不包含中文
            model_patterns = [
                # qwen 系列 - 包含日期版本
                r'\b(qwen3?-(?:max|plus|flash|turbo|coder|vl|audio|long|omni|tts|asr)(?:-\d{4}-\d{2}-\d{2})?)\b',
                r'\b(qwen3?-(?:max|plus|flash|turbo|coder|vl|audio|long|omni|tts|asr)-[a-z]+(?:-\d{4}-\d{2}-\d{2})?)\b',
                r'\b(qwen[23]?\.?[0-9]*-[0-9]+b-[a-z\-]+)\b',
                r'\b(qwen-(?:max|plus|turbo|vl|audio|tts)(?:-latest|-\d{4}-\d{2}-\d{2})?)\b',
                r'\b(qvq-(?:max|plus|72b-preview)(?:-\d{4}-\d{2}-\d{2})?)\b',
                # deepseek 系列
                r'\b(deepseek-(?:v[0-9\.]+|r[0-9]+)(?:-[a-z0-9\-\.]+)?)\b',
                # llama 系列
                r'\b(llama[0-9\.]+(?:-[0-9]+b)?-[a-z\-]+)\b',
                # 其他
                r'\b(text-embedding-v[0-9]+)\b',
                r'\b(chatglm-[a-z0-9\-]+)\b',
                r'\b(baichuan[0-9]+-[a-z0-9\-]+)\b',
                r'\b(glm-[0-9a-z\-]+)\b',
                r'\b(cosyvoice-v[0-9a-z\-]+)\b',
            ]
            
            for pattern in model_patterns:
                match = re.search(pattern, cell, re.IGNORECASE)
                if match:
                    model_id = match.group(1).lower()
                    # 清理 model_name
                    model_name = cell.split('\n')[0]
                    model_name = re.split(r'当前|又称|Batch|batch|上下文', model_name)[0].strip()
                    break
            
            if model_id:
                break
        
        if not model_id:
            return None
        
        # 提取价格信息
        pricing = self._extract_pricing(headers, cells, region, section)
        
        # 确定模型类别
        category = self._determine_category(model_id, section)
        
        # 确定厂商
        vendor = self._determine_vendor(model_id)
        
        # 判断是否支持思考模式
        supports_thinking = self._check_thinking_support(model_id, cells)
        
        return {
            "model_id": model_id,
            "model_name": model_name or model_id,
            "vendor": vendor,
            "category": category,
            "pricing": [pricing] if pricing else [],
            "supports_thinking_mode": supports_thinking
        }
    
    def _extract_pricing(self, headers: List[str], cells: List[str], 
                         region: str, section: str) -> Optional[Dict]:
        """提取价格信息"""
        pricing = {
            "region": region,
            "region_name": "中国内地（北京）" if region == "cn-beijing" else "国际（新加坡）",
            "currency": "CNY",
            "billing_type": "token",
            "supports_thinking_mode": False,
            "thinking_mode_same_price": True,
            "has_context_tiered_pricing": False
        }
        
        # 解析价格
        input_price = None
        output_price = None
        context_prices = []
        
        for i, header in enumerate(headers):
            if i >= len(cells):
                continue
            
            cell = cells[i]
            header_lower = header.lower()
            
            # 检查是否有上下文阶梯
            context_match = re.search(r'(\d+)K?<.*?≤(\d+)K', header)
            if context_match:
                pricing["has_context_tiered_pricing"] = True
            
            # 提取价格数值
            price_match = re.search(r'([\d\.]+)\s*元', cell)
            if price_match:
                price_val = float(price_match.group(1))
                
                if '输入' in header or 'input' in header_lower:
                    input_price = price_val
                elif '输出' in header or 'output' in header_lower:
                    output_price = price_val
                elif '价格' in header or '单价' in header:
                    # 统一价格
                    input_price = price_val
        
        if input_price is not None:
            pricing["input_price"] = {"price": input_price, "unit": "千Token", "unit_quantity": 1000}
        if output_price is not None:
            pricing["output_price"] = {"price": output_price, "unit": "千Token", "unit_quantity": 1000}
        
        # 如果没有提取到价格，返回 None
        if input_price is None and output_price is None:
            return None
        
        return pricing
    
    def _determine_category(self, model_id: str, section: str) -> str:
        """确定模型类别"""
        model_lower = model_id.lower()
        section_lower = section.lower() if section else ""
        
        if 'embedding' in model_lower or '向量' in section_lower:
            return "embedding"
        elif 'rerank' in model_lower:
            return "rerank"
        elif 'vl' in model_lower or '视觉' in section_lower or 'vision' in section_lower:
            return "vision"
        elif 'audio' in model_lower or 'asr' in model_lower or '语音' in section_lower:
            return "audio"
        elif 'tts' in model_lower or '合成' in section_lower:
            return "speech_synthesis"
        elif 'image' in model_lower or '图像' in section_lower or '文生图' in section_lower:
            return "image_generation"
        elif 'video' in model_lower or '视频' in section_lower:
            return "video_generation"
        else:
            return "text_generation"
    
    def _determine_vendor(self, model_id: str) -> str:
        """确定厂商"""
        model_lower = model_id.lower()
        
        if model_lower.startswith('qwen') or model_lower.startswith('text-embedding'):
            return "aliyun"
        elif 'deepseek' in model_lower:
            return "deepseek"
        elif 'llama' in model_lower:
            return "meta"
        elif 'glm' in model_lower or 'chatglm' in model_lower:
            return "zhipu"
        elif 'baichuan' in model_lower:
            return "baichuan"
        elif 'kimi' in model_lower or 'moonshot' in model_lower:
            return "moonshot"
        else:
            return "other"
    
    def _check_thinking_support(self, model_id: str, cells: List[str]) -> bool:
        """检查是否支持思考模式"""
        model_lower = model_id.lower()
        cell_text = ' '.join(cells).lower()
        
        # 思考模式关键词
        if any(kw in cell_text for kw in ['思考', 'thinking', '推理']):
            return True
        
        # 部分模型默认支持思考模式
        thinking_models = ['qwen3-max', 'qwen3-plus', 'deepseek-r1', 'qvq']
        return any(m in model_lower for m in thinking_models)
    
    def _merge_or_add_model(self, new_model: Dict):
        """合并或添加模型"""
        # 查找是否已存在
        for existing in self.models:
            if existing["model_id"] == new_model["model_id"]:
                # 合并 pricing
                if new_model.get("pricing"):
                    for new_price in new_model["pricing"]:
                        # 检查是否已有相同地域的价格
                        exists = False
                        for ep in existing.get("pricing", []):
                            if ep["region"] == new_price["region"]:
                                exists = True
                                break
                        if not exists:
                            existing.setdefault("pricing", []).append(new_price)
                return
        
        # 不存在，添加新模型
        self.models.append(new_model)


def main():
    """主函数"""
    print("=" * 70)
    print("🔄 开始解析百炼模型数据")
    print("=" * 70)
    
    try:
        parser = BailianModelParser("bailian_page.html")
        result = parser.parse()
        
        # 保存结果
        output_file = "bailian_models.json"
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(result, f, ensure_ascii=False, indent=2)
        
        print(f"\n✅ 解析完成!")
        print(f"   - 模型数量: {len(result['models'])}")
        print(f"   - 输出文件: {output_file}")
        
        # 统计信息
        vendors = {}
        categories = {}
        for model in result['models']:
            v = model.get('vendor', 'unknown')
            c = model.get('category', 'unknown')
            vendors[v] = vendors.get(v, 0) + 1
            categories[c] = categories.get(c, 0) + 1
        
        print(f"\n📊 厂商分布:")
        for v, count in sorted(vendors.items(), key=lambda x: -x[1]):
            print(f"   - {v}: {count}")
        
        print(f"\n📊 类别分布:")
        for c, count in sorted(categories.items(), key=lambda x: -x[1]):
            print(f"   - {c}: {count}")
        
        return result
        
    except FileNotFoundError:
        print("❌ 错误: 未找到 bailian_page.html 文件")
        print("   请先运行 test_bailian_crawler.py 爬取页面")
        return None
    except Exception as e:
        print(f"❌ 解析错误: {e}")
        import traceback
        traceback.print_exc()
        return None


if __name__ == "__main__":
    main()
