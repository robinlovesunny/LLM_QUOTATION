"""
百炼模型数据解析器 V2 - 更精确的解析逻辑
"""
import json
import re
from datetime import datetime
from bs4 import BeautifulSoup
from typing import Dict, List, Any, Optional, Tuple
from decimal import Decimal


class BailianModelParserV2:
    """百炼模型数据解析器 V2"""
    
    def __init__(self, html_file: str):
        with open(html_file, 'r', encoding='utf-8') as f:
            self.soup = BeautifulSoup(f.read(), 'html.parser')
        
        self.models: Dict[str, Dict[str, Any]] = {}  # 用 dict 去重
        self.current_region = "cn-beijing"
    
    def parse(self) -> Dict[str, Any]:
        """解析 HTML 并返回结构化数据"""
        
        # 解析详细定价表
        self._parse_pricing_tables()
        
        # 构建最终输出
        result = {
            "metadata": {
                "source": "https://help.aliyun.com/zh/model-studio/getting-started/models",
                "crawl_time": datetime.now().isoformat(),
                "version": "2.0.0"
            },
            "models": list(self.models.values())
        }
        
        return result
    
    def _parse_pricing_tables(self):
        """解析所有定价表格"""
        tables = self.soup.find_all('table')
        
        current_region = "cn-beijing"
        current_category = "text_generation"
        
        for table in tables:
            # 检查表格前的标题确定地域
            prev_heading = table.find_previous(['h2', 'h3', 'h4'])
            if prev_heading:
                heading_text = prev_heading.get_text(strip=True)
                if '新加坡' in heading_text or '国际' in heading_text:
                    current_region = "ap-southeast-1"
                elif '北京' in heading_text or '中国内地' in heading_text:
                    current_region = "cn-beijing"
                
                # 确定类别
                current_category = self._detect_category(heading_text)
            
            # 检查是否是定价表
            first_row = table.find('tr')
            if not first_row:
                continue
            
            header_text = first_row.get_text()
            if '模型名称' not in header_text:
                continue
            
            # 解析表格头
            headers = self._parse_headers(table)
            if not headers:
                continue
            
            # 解析数据行
            self._parse_table_rows(table, headers, current_region, current_category)
    
    def _parse_headers(self, table) -> List[str]:
        """解析表格头"""
        rows = table.find_all('tr')
        if len(rows) < 2:
            return []
        
        # 第一行是主表头，第二行可能是子表头
        header_cells = rows[0].find_all(['th', 'td'])
        headers = [c.get_text(strip=True) for c in header_cells]
        
        # 检查第二行是否是子表头（如 "(Token数)" "(每千Token)"）
        if len(rows) > 1:
            sub_header_cells = rows[1].find_all(['th', 'td'])
            sub_headers = [c.get_text(strip=True) for c in sub_header_cells]
            if sub_headers and '(' in sub_headers[0]:
                # 合并表头
                for i, sub in enumerate(sub_headers):
                    if i < len(headers) and sub:
                        headers[i] = f"{headers[i]}{sub}"
        
        return headers
    
    def _parse_table_rows(self, table, headers: List[str], region: str, category: str):
        """解析表格数据行"""
        rows = table.find_all('tr')
        
        # 跳过表头行
        start_idx = 2 if len(rows) > 1 and '(' in rows[1].get_text() else 1
        
        current_model_id = None
        current_model_data = None
        
        for row in rows[start_idx:]:
            cells = row.find_all(['td', 'th'])
            if not cells:
                continue
            
            cell_texts = [c.get_text(strip=True) for c in cells]
            
            # 尝试提取模型 ID
            model_id = self._extract_model_id(cell_texts[0] if cell_texts else "")
            
            if model_id:
                # 新模型
                current_model_id = model_id
                current_model_data = self._create_model_entry(
                    model_id, cell_texts, headers, region, category
                )
                
                if current_model_id not in self.models:
                    self.models[current_model_id] = current_model_data
                else:
                    # 合并不同地域的价格
                    self._merge_pricing(self.models[current_model_id], current_model_data)
            
            elif current_model_id and len(cell_texts) > 1:
                # 可能是同一模型的不同模式（思考/非思考）
                mode_text = cell_texts[0] if cell_texts else ""
                if '思考' in mode_text or '非思考' in mode_text:
                    self._add_mode_pricing(
                        self.models.get(current_model_id), 
                        cell_texts, headers, region, mode_text
                    )
    
    def _extract_model_id(self, text: str) -> Optional[str]:
        """从文本中提取模型 ID"""
        if not text:
            return None
            
        # 清理文本中的多余空格
        text = text.strip()
            
        # 标准模型 ID 正则模式 - 优先匹配更完整的模式
        patterns = [
            # deepseek 系列 - 精确匹配版本号
            r'\b(deepseek-v3\.2-exp)\b',  # deepseek-v3.2-exp
            r'\b(deepseek-v3\.2)\b',  # deepseek-v3.2
            r'\b(deepseek-v3\.1)\b',  # deepseek-v3.1
            r'\b(deepseek-v3)\b',  # deepseek-v3 (基础版，放在版本号后面)
            r'\b(deepseek-r1-0528)\b',  # deepseek-r1-0528
            r'\b(deepseek-r1-distill-qwen-32b)\b',
            r'\b(deepseek-r1-distill-qwen-14b)\b',
            r'\b(deepseek-r1-distill-qwen-7b)\b',
            r'\b(deepseek-r1-distill-qwen-1\.5b)\b',
            r'\b(deepseek-r1-distill-llama-70b)\b',
            r'\b(deepseek-r1-distill-llama-8b)\b',
            r'\b(deepseek-r1)\b',
            # qwen 系列 - 带日期版本
            r'\b(qwen3-max-\d{4}-\d{2}-\d{2})\b',
            r'\b(qwen3-max-preview)\b',
            r'\b(qwen3-max)\b',
            r'\b(qwen-max-latest)\b',
            r'\b(qwen-max)\b',
            r'\b(qwen-plus-latest)\b',
            r'\b(qwen-plus)\b',
            r'\b(qwen-turbo-latest)\b',
            r'\b(qwen-turbo)\b',
            r'\b(qwen-flash)\b',
            r'\b(qwen-long)\b',
            r'\b(qwen3-omni-flash)\b',
            r'\b(qwen-omni-turbo-latest)\b',
            r'\b(qwen-omni-turbo)\b',
            # qvq 系列
            r'\b(qvq-max-latest)\b',
            r'\b(qvq-max)\b',
            r'\b(qvq-plus)\b',
            r'\b(qvq-72b-preview)\b',
            # qwen vl 系列
            r'\b(qwen3-vl-plus)\b',
            r'\b(qwen-vl-max-latest)\b',
            r'\b(qwen-vl-max)\b',
            r'\b(qwen-vl-plus)\b',
            # qwen coder 系列
            r'\b(qwen3-coder-plus)\b',
            r'\b(qwen-coder-plus-latest)\b',
            r'\b(qwen-coder-plus)\b',
            r'\b(qwen-coder-turbo-latest)\b',
            r'\b(qwen-coder-turbo)\b',
            # qwen 开源版 - 1M长文本
            r'\b(qwen2\.5-14b-instruct-1m)\b',
            r'\b(qwen2\.5-7b-instruct-1m)\b',
            # qwen 开源版 - 通用
            r'\b(qwen2\.5-72b-instruct)\b',
            r'\b(qwen2\.5-32b-instruct)\b',
            r'\b(qwen2\.5-14b-instruct)\b',
            r'\b(qwen2\.5-7b-instruct)\b',
            r'\b(qwen2\.5-3b-instruct)\b',
            r'\b(qwen2\.5-1\.5b-instruct)\b',
            r'\b(qwen2\.5-0\.5b-instruct)\b',
            r'\b(qwen2-72b-instruct)\b',
            r'\b(qwen2-7b-instruct)\b',
            # qwen audio 系列
            r'\b(qwen-audio-turbo)\b',
            r'\b(qwen3-tts-flash)\b',
            r'\b(qwen3-asr)\b',
            # embedding/rerank
            r'\b(text-embedding-v[0-9]+)\b',
            r'\b(qwen3-embedding-\d+b)\b',
            r'\b(qwen3-rerank)\b',
            # cosyvoice
            r'\b(cosyvoice-v[0-9a-z\-]+)\b',
            # llama 系列
            r'\b(llama-3\.3-70b-instruct)\b',
            r'\b(llama-3\.2-90b-vision-instruct)\b',
            r'\b(llama-3\.2-11b-vision-instruct)\b',
            r'\b(llama-3\.2-3b-instruct)\b',
            r'\b(llama-3\.2-1b-instruct)\b',
            r'\b(llama-3\.1-405b-instruct)\b',
            r'\b(llama-3\.1-70b-instruct)\b',
            r'\b(llama-3\.1-8b-instruct)\b',
            r'\b(llama-3-70b-instruct)\b',
            r'\b(llama-3-8b-instruct)\b',
            # glm 系列
            r'\b(glm-4\.7)\b',
            r'\b(glm-4-plus)\b',
            r'\b(glm-4-air)\b',
            r'\b(glm-4-flash)\b',
            # baichuan
            r'\b(baichuan[0-9]+-[a-z0-9\-]+)\b',
        ]
            
        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                return match.group(1).lower()
            
        return None
    
    def _create_model_entry(self, model_id: str, cells: List[str], 
                           headers: List[str], region: str, category: str) -> Dict:
        """创建模型数据条目"""
        
        # 清理 model_name - 提取模型标识符部分
        raw_name = cells[0] if cells else model_id
        model_name = self._clean_model_name(raw_name, model_id)
        
        # 确定厂商
        vendor = self._determine_vendor(model_id)
        
        # 解析规格
        specs = self._parse_specs(cells, headers)
        
        # 解析价格
        pricing = self._parse_pricing(cells, headers, region)
        
        # 检查是否支持思考模式
        supports_thinking = self._check_thinking_support(cells, headers)
        
        return {
            "model_id": model_id,
            "model_name": model_name,
            "vendor": vendor,
            "category": category,
            "version_type": self._detect_version_type(cells, headers),
            "specs": specs,
            "pricing": [pricing] if pricing else [],
            "status": "active"
        }
    
    def _parse_specs(self, cells: List[str], headers: List[str]) -> Dict:
        """解析模型规格"""
        specs = {}
        
        for i, header in enumerate(headers):
            if i >= len(cells):
                continue
            
            cell = cells[i].replace(',', '').replace('，', '')
            
            # 提取合理范围内的数值
            if '上下文' in header and '长度' in header:
                val = self._extract_reasonable_number(cell, max_val=100_000_000)
                if val:
                    specs["max_context_length"] = val
            elif '最大输入' in header:
                val = self._extract_reasonable_number(cell, max_val=100_000_000)
                if val:
                    specs["max_input_tokens"] = val
            elif '最大输出' in header:
                val = self._extract_reasonable_number(cell, max_val=1_000_000)
                if val:
                    specs["max_output_tokens"] = val
            elif '思维链' in header or '思考' in header:
                val = self._extract_reasonable_number(cell, max_val=1_000_000)
                if val:
                    specs["max_thinking_tokens"] = val
        
        return specs if specs else None
    
    def _extract_reasonable_number(self, text: str, max_val: int = 100_000_000) -> Optional[int]:
        """从文本中提取合理范围内的数值"""
        if not text:
            return None
        
        # 尝试提取数值
        # 方法1: 提取第一个独立的数字 (常见格式如 "131072", "32768")
        match = re.search(r'\b(\d{1,10})\b', text)
        if match:
            val = int(match.group(1))
            # 检查是否在合理范围内 (100 到 max_val)
            if 100 <= val <= max_val:
                return val
        
        # 方法2: 支持带单位的数值 (如 "10M", "1000K")
        match = re.search(r'(\d+(?:\.\d+)?)\s*([MKmk])?', text)
        if match:
            num = float(match.group(1))
            unit = match.group(2)
            if unit and unit.upper() == 'M':
                num *= 1_000_000
            elif unit and unit.upper() == 'K':
                num *= 1_000
            val = int(num)
            if 100 <= val <= max_val:
                return val
        
        return None
    
    def _clean_model_name(self, raw_name: str, model_id: str) -> str:
        """清理模型名称，去除描述性文字"""
        if not raw_name:
            return model_id
        
        # 分割点 - 这些文字通常标记描述开始
        split_markers = [
            '当前', '又称', 'Batch', '始终', '相比', '基于', '上下文缓存',
            '满血版', '蒸馏版', '具有更强', '提供最佳', '享有折扣'
        ]
        
        result = raw_name
        for marker in split_markers:
            if marker in result:
                result = result.split(marker)[0]
        
        # 去除末尾的数字+B（参数量），它通常是描述的一部分而非模型ID
        # 例如 "deepseek-v3.2685B" -> 应该处理为 "deepseek-v3.2"
        result = re.sub(r'(\d+)[Bb]\s*$', '', result)
        
        result = result.strip()
        
        # 如果清理后为空或太短，使用 model_id
        return result if len(result) >= 3 else model_id
    
    def _parse_pricing(self, cells: List[str], headers: List[str], region: str) -> Optional[Dict]:
        """解析价格信息"""
        pricing = {
            "region": region,
            "region_name": "中国内地（北京）" if region == "cn-beijing" else "国际（新加坡）",
            "currency": "CNY",
            "billing_type": "token",
            "supports_thinking_mode": False,
            "thinking_mode_same_price": True,
            "has_context_tiered_pricing": False
        }
        
        input_price = None
        output_price = None
        
        for i, header in enumerate(headers):
            if i >= len(cells):
                continue
            
            cell = cells[i]
            
            # 检查是否有阶梯计价
            if '阶梯' in cell:
                pricing["has_context_tiered_pricing"] = True
                continue
            
            # 提取价格
            price_match = re.search(r'([\d\.]+)\s*元', cell)
            if price_match:
                price_val = float(price_match.group(1))
                
                if '输入' in header:
                    input_price = price_val
                elif '输出' in header:
                    output_price = price_val
                elif '成本' in header or '价格' in header:
                    # 需要判断是输入还是输出
                    if input_price is None:
                        input_price = price_val
                    else:
                        output_price = price_val
        
        if input_price is not None:
            pricing["input_price"] = {
                "price": input_price,
                "unit": "千Token",
                "unit_quantity": 1000
            }
        
        if output_price is not None:
            pricing["output_price"] = {
                "price": output_price,
                "unit": "千Token",
                "unit_quantity": 1000
            }
        
        # 检查模式
        for i, header in enumerate(headers):
            if '模式' in header and i < len(cells):
                mode = cells[i]
                if '思考' in mode and '非' not in mode:
                    pricing["supports_thinking_mode"] = True
                elif '仅非思考' in mode:
                    pricing["supports_thinking_mode"] = False
        
        return pricing if (input_price or output_price) else None
    
    def _merge_pricing(self, existing: Dict, new_data: Dict):
        """合并价格数据"""
        if not new_data.get("pricing"):
            return
        
        for new_price in new_data["pricing"]:
            # 检查是否已有相同地域
            found = False
            for ep in existing.get("pricing", []):
                if ep["region"] == new_price["region"]:
                    found = True
                    break
            
            if not found:
                existing.setdefault("pricing", []).append(new_price)
    
    def _add_mode_pricing(self, model: Dict, cells: List[str], 
                         headers: List[str], region: str, mode_text: str):
        """添加不同模式的价格"""
        if not model:
            return
        
        # 查找对应地域的价格
        for pricing in model.get("pricing", []):
            if pricing["region"] == region:
                if '思考' in mode_text and '非' not in mode_text:
                    pricing["supports_thinking_mode"] = True
                    # 可以进一步提取思考模式的价格
                break
    
    def _determine_vendor(self, model_id: str) -> str:
        """确定厂商"""
        model_lower = model_id.lower()
        
        if model_lower.startswith('qwen') or model_lower.startswith('qvq') or 'embedding' in model_lower:
            return "aliyun"
        elif 'deepseek' in model_lower:
            return "deepseek"
        elif 'llama' in model_lower:
            return "meta"
        elif 'glm' in model_lower or 'chatglm' in model_lower:
            return "zhipu"
        elif 'baichuan' in model_lower:
            return "baichuan"
        elif 'cosyvoice' in model_lower:
            return "aliyun"
        else:
            return "other"
    
    def _detect_category(self, heading: str) -> str:
        """根据标题确定类别"""
        if '视觉' in heading or 'VL' in heading or '多模态' in heading:
            return "vision"
        elif '语音' in heading or 'TTS' in heading or 'ASR' in heading or '合成' in heading:
            return "audio"
        elif '向量' in heading or 'Embedding' in heading:
            return "embedding"
        elif '图像' in heading or '文生图' in heading:
            return "image_generation"
        elif '视频' in heading:
            return "video_generation"
        else:
            return "text_generation"
    
    def _detect_version_type(self, cells: List[str], headers: List[str]) -> str:
        """检测版本类型"""
        for i, header in enumerate(headers):
            if '版本' in header and i < len(cells):
                version = cells[i].lower()
                if '稳定' in version:
                    return "stable"
                elif '快照' in version:
                    return "snapshot"
                elif '预览' in version:
                    return "preview"
                elif 'latest' in version:
                    return "latest"
        return "stable"
    
    def _check_thinking_support(self, cells: List[str], headers: List[str]) -> bool:
        """检查是否支持思考模式"""
        for i, header in enumerate(headers):
            if '模式' in header and i < len(cells):
                mode = cells[i]
                if '思考' in mode:
                    return True
        return False


def main():
    """主函数"""
    print("=" * 70)
    print("🔄 开始解析百炼模型数据 (V2)")
    print("=" * 70)
    
    try:
        parser = BailianModelParserV2("bailian_page.html")
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
        with_pricing = 0
        
        for model in result['models']:
            v = model.get('vendor', 'unknown')
            c = model.get('category', 'unknown')
            vendors[v] = vendors.get(v, 0) + 1
            categories[c] = categories.get(c, 0) + 1
            if model.get('pricing'):
                with_pricing += 1
        
        print(f"\n📊 厂商分布:")
        for v, count in sorted(vendors.items(), key=lambda x: -x[1]):
            print(f"   - {v}: {count}")
        
        print(f"\n📊 类别分布:")
        for c, count in sorted(categories.items(), key=lambda x: -x[1]):
            print(f"   - {c}: {count}")
        
        print(f"\n📊 有价格数据: {with_pricing}/{len(result['models'])}")
        
        return result
        
    except FileNotFoundError:
        print("❌ 错误: 未找到 bailian_page.html 文件")
        return None
    except Exception as e:
        print(f"❌ 解析错误: {e}")
        import traceback
        traceback.print_exc()
        return None


if __name__ == "__main__":
    main()
