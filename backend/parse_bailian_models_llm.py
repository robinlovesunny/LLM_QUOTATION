#!/usr/bin/env python3
"""
基于 qwen-plus 的百炼模型数据解析器
使用LLM从HTML中提取结构化模型数据
"""

import os
import json
import re
from typing import List, Dict, Optional
from bs4 import BeautifulSoup
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

# JSON Schema 定义
MODEL_SCHEMA = {
    "type": "object",
    "properties": {
        "model_id": {"type": "string", "description": "API调用的模型标识符，如qwen-plus、deepseek-v3"},
        "model_name": {"type": "string", "description": "模型显示名称"},
        "vendor": {"type": "string", "enum": ["aliyun", "deepseek", "zhipu", "baichuan", "meta", "other"]},
        "category": {"type": "string", "enum": ["text_generation", "vision", "audio", "embedding", "rerank"]},
        "specs": {
            "type": "object",
            "properties": {
                "max_context_length": {"type": "integer"},
                "max_input_tokens": {"type": "integer"},
                "max_output_tokens": {"type": "integer"},
                "max_thinking_tokens": {"type": "integer"}
            }
        },
        "pricing": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "region": {"type": "string"},
                    "input_price": {"type": "object", "properties": {"price": {"type": "number"}, "unit": {"type": "string"}}},
                    "output_price": {"type": "object", "properties": {"price": {"type": "number"}, "unit": {"type": "string"}}},
                    "thinking_input_price": {"type": "object"},
                    "thinking_output_price": {"type": "object"}
                }
            }
        }
    },
    "required": ["model_id", "model_name", "vendor", "category"]
}


class LLMModelParser:
    """使用 qwen-plus 解析模型数据"""
    
    def __init__(self):
        self.client = OpenAI(
            api_key=os.getenv("DASHSCOPE_API_KEY"),
            base_url="https://dashscope.aliyuncs.com/compatible-mode/v1"
        )
        self.model = "qwen-plus"
    
    def parse_html_file(self, html_path: str) -> Dict:
        """解析HTML文件"""
        print("=" * 60)
        print("🤖 开始使用 qwen-plus 解析百炼模型数据")
        print("=" * 60)
        
        with open(html_path, 'r', encoding='utf-8') as f:
            html_content = f.read()
        
        # 使用BeautifulSoup预处理，提取表格
        soup = BeautifulSoup(html_content, 'html.parser')
        tables = soup.find_all('table')
        
        print(f"\n📊 找到 {len(tables)} 个表格")
        
        # 预筛选有效的定价表格
        valid_tables = []
        for table in tables:
            text = self._extract_table_text(table)
            # 必须包含价格关键词和模型相关词
            has_price = any(kw in text for kw in ['元/', '元/千', 'Token'])
            has_model = any(kw in text.lower() for kw in ['qwen', 'deepseek', 'llama', 'glm', 'model', '模型'])
            if has_price and has_model and len(text) > 100:
                valid_tables.append((table, text))
        
        print(f"📋 有效定价表格: {len(valid_tables)} 个")
        
        all_models = []
        total_input_tokens = 0
        total_output_tokens = 0
        
        for i, (table, table_text) in enumerate(valid_tables):
            print(f"\n🔄 处理表格 {i+1}/{len(valid_tables)}...")
            
            # 使用LLM解析
            models, usage = self._parse_table_with_llm(table_text, i+1)
            if models:
                all_models.extend(models)
                total_input_tokens += usage.get('input', 0)
                total_output_tokens += usage.get('output', 0)
                print(f"   ✅ 提取到 {len(models)} 个模型")
        
        # 去重
        unique_models = self._deduplicate_models(all_models)
        
        result = {
            "source": "bailian_llm_parsed",
            "parser": "qwen-plus",
            "model_count": len(unique_models),
            "models": unique_models,
            "token_usage": {
                "input_tokens": total_input_tokens,
                "output_tokens": total_output_tokens,
                "total_tokens": total_input_tokens + total_output_tokens
            }
        }
        
        # 保存结果
        output_path = html_path.replace('.html', '_llm.json')
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(result, f, ensure_ascii=False, indent=2)
        
        print(f"\n✅ LLM解析完成!")
        print(f"   - 模型数量: {len(unique_models)}")
        print(f"   - Token消耗: 输入={total_input_tokens}, 输出={total_output_tokens}")
        print(f"   - 输出文件: {output_path}")
        
        return result
    
    def _extract_table_text(self, table) -> str:
        """将表格转换为结构化文本"""
        rows = table.find_all('tr')
        if not rows:
            return ""
        
        lines = []
        for row in rows:
            cells = row.find_all(['th', 'td'])
            cell_texts = [cell.get_text(strip=True) for cell in cells]
            if any(cell_texts):
                lines.append(' | '.join(cell_texts))
        
        return '\n'.join(lines)
    
    def _parse_table_with_llm(self, table_text: str, table_index: int) -> tuple:
        """使用LLM解析表格"""
        
        # 限制文本长度，避免超出上下文
        if len(table_text) > 8000:
            table_text = table_text[:8000] + "\n...(截断)"
        
        prompt = f"""请从以下表格数据中提取LLM模型信息。

表格内容:
{table_text}

请提取每个模型的以下信息:
1. model_id: API调用的模型标识符(如qwen-plus, deepseek-v3，纯字母数字和-_.)
2. model_name: 模型名称
3. vendor: 厂商(aliyun/deepseek/zhipu/baichuan/meta/other)
4. category: 类别(text_generation/vision/audio/embedding/rerank)
5. specs: 规格(max_context_length, max_input_tokens, max_output_tokens, max_thinking_tokens)
6. pricing: 定价信息(input_price, output_price，单位是元/千Token)

重要规则:
- model_id必须是标准API名称格式，不包含中文
- 排除免费额度相关的价格信息
- 价格单位统一转换为 元/千Token
- 如果有思考模式价格，单独记录

请以JSON数组格式返回，只返回JSON，不要其他文字:
```json
[{{"model_id": "xxx", "model_name": "xxx", ...}}]
```"""
        
        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": "你是一个数据提取专家，擅长从表格中提取结构化信息。只返回JSON格式数据。"},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.1,
                max_tokens=4000
            )
            
            content = response.choices[0].message.content
            usage = {
                'input': response.usage.prompt_tokens,
                'output': response.usage.completion_tokens
            }
            
            # 提取JSON
            models = self._extract_json_from_response(content)
            return models, usage
            
        except Exception as e:
            print(f"   ❌ LLM调用失败: {e}")
            return [], {'input': 0, 'output': 0}
    
    def _extract_json_from_response(self, content: str) -> List[Dict]:
        """从LLM响应中提取JSON"""
        # 尝试提取代码块中的JSON
        json_match = re.search(r'```(?:json)?\s*([\s\S]*?)\s*```', content)
        if json_match:
            json_str = json_match.group(1)
        else:
            # 尝试直接解析
            json_str = content
        
        try:
            data = json.loads(json_str)
            if isinstance(data, list):
                return self._normalize_models(data)
            elif isinstance(data, dict) and 'models' in data:
                return self._normalize_models(data['models'])
            return []
        except json.JSONDecodeError:
            return []
    
    def _normalize_models(self, models: List[Dict]) -> List[Dict]:
        """标准化模型数据格式"""
        normalized = []
        for m in models:
            if not isinstance(m, dict):
                continue
            if not m.get('model_id'):
                continue
            
            # 标准化model_id
            model_id = str(m['model_id']).lower().strip()
            
            # 标准化pricing
            pricing = []
            raw_pricing = m.get('pricing')
            if raw_pricing and isinstance(raw_pricing, list):
                for p in raw_pricing:
                    if isinstance(p, dict):
                        pricing.append(self._normalize_pricing(p))
            elif isinstance(m.get('input_price'), (int, float, dict)):
                pricing.append(self._normalize_pricing(m))
            
            normalized.append({
                "model_id": model_id,
                "model_name": str(m.get('model_name', model_id)),
                "vendor": m.get('vendor', 'aliyun'),
                "category": m.get('category', 'text_generation'),
                "specs": m.get('specs') if isinstance(m.get('specs'), dict) else None,
                "pricing": pricing,
                "status": "active"
            })
        
        return normalized
    
    def _normalize_pricing(self, p: Dict) -> Dict:
        """标准化价格格式"""
        def parse_price(val):
            if isinstance(val, dict):
                return val
            if isinstance(val, (int, float)):
                return {"price": float(val), "unit": "千Token", "unit_quantity": 1000}
            return None
        
        return {
            "region": p.get('region', 'cn-shanghai'),
            "input_price": parse_price(p.get('input_price')),
            "output_price": parse_price(p.get('output_price')),
            "thinking_input_price": parse_price(p.get('thinking_input_price')),
            "thinking_output_price": parse_price(p.get('thinking_output_price'))
        }
    
    def _deduplicate_models(self, models: List[Dict]) -> List[Dict]:
        """去重，保留信息最完整的记录"""
        seen = {}
        for m in models:
            mid = m['model_id']
            if mid not in seen:
                seen[mid] = m
            else:
                # 保留信息更完整的
                existing = seen[mid]
                if m.get('pricing') and not existing.get('pricing'):
                    seen[mid] = m
                elif m.get('specs') and not existing.get('specs'):
                    seen[mid]['specs'] = m['specs']
        
        return list(seen.values())


def main():
    parser = LLMModelParser()
    result = parser.parse_html_file("bailian_page.html")
    
    # 显示厂商分布
    vendors = {}
    for m in result['models']:
        v = m.get('vendor', 'unknown')
        vendors[v] = vendors.get(v, 0) + 1
    
    print(f"\n📊 厂商分布:")
    for v, c in sorted(vendors.items(), key=lambda x: -x[1]):
        print(f"   - {v}: {c}")
    
    # 显示有价格的模型数
    with_price = sum(1 for m in result['models'] if m.get('pricing'))
    print(f"\n📊 有价格数据: {with_price}/{len(result['models'])}")


if __name__ == "__main__":
    main()
