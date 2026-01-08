#!/usr/bin/env python3
"""
基于 qwen-plus 的百炼模型数据解析器 V2
改进：支持阶梯计价表格的关联解析
"""

import os
import json
import re
from typing import List, Dict, Optional, Tuple
from bs4 import BeautifulSoup, Tag
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()


class LLMModelParserV2:
    """使用 qwen-plus 解析模型数据，支持阶梯计价"""
    
    def __init__(self):
        self.client = OpenAI(
            api_key=os.getenv("DASHSCOPE_API_KEY"),
            base_url="https://dashscope.aliyuncs.com/compatible-mode/v1"
        )
        self.model = "qwen-plus"
    
    def parse_html_file(self, html_path: str) -> Dict:
        """解析HTML文件"""
        print("=" * 60)
        print("🤖 开始使用 qwen-plus 解析百炼模型数据 (V2 - 支持阶梯计价)")
        print("=" * 60)
        
        with open(html_path, 'r', encoding='utf-8') as f:
            html_content = f.read()
        
        soup = BeautifulSoup(html_content, 'html.parser')
        
        # 找出所有表格及其上下文关系
        table_groups = self._find_model_and_pricing_tables(soup)
        print(f"\n📊 找到 {len(table_groups)} 组模型+阶梯计价表格")
        
        all_models = []
        total_input_tokens = 0
        total_output_tokens = 0
        
        for i, group in enumerate(table_groups):
            print(f"\n🔄 处理表格组 {i+1}/{len(table_groups)}...")
            print(f"   模型: {group['models'][:3]}...")
            
            models, usage = self._parse_table_group_with_llm(group)
            if models:
                all_models.extend(models)
                total_input_tokens += usage.get('input', 0)
                total_output_tokens += usage.get('output', 0)
                print(f"   ✅ 提取到 {len(models)} 个模型")
        
        # 去重
        unique_models = self._deduplicate_models(all_models)
        
        result = {
            "source": "bailian_llm_v2_parsed",
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
        output_path = html_path.replace('.html', '_llm_v2.json')
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(result, f, ensure_ascii=False, indent=2)
        
        print(f"\n✅ LLM V2 解析完成!")
        print(f"   - 模型数量: {len(unique_models)}")
        print(f"   - Token消耗: 输入={total_input_tokens}, 输出={total_output_tokens}")
        print(f"   - 输出文件: {output_path}")
        
        return result
    
    def _find_model_and_pricing_tables(self, soup: BeautifulSoup) -> List[Dict]:
        """
        找出模型表格及其关联的阶梯计价表格
        结构：模型表格 -> 描述文字 -> 阶梯计价表格
        """
        groups = []
        tables = soup.find_all('table')
        
        for i, table in enumerate(tables):
            table_text = self._extract_table_text(table)
            
            # 检查是否是模型表格（包含"阶梯计价"引用）
            if '阶梯计价' in table_text and '请参见' in table_text:
                # 提取模型名称
                models = self._extract_model_names_from_table(table)
                if not models:
                    continue
                
                # 查找紧随其后的阶梯计价表格
                tiered_pricing_table = self._find_next_pricing_table(table)
                
                if tiered_pricing_table:
                    tiered_text = self._extract_table_text(tiered_pricing_table)
                    groups.append({
                        'models': models,
                        'model_table_text': table_text,
                        'tiered_pricing_text': tiered_text,
                        'has_tiered_pricing': True
                    })
        
        return groups
    
    def _extract_model_names_from_table(self, table: Tag) -> List[str]:
        """从表格中提取模型名称"""
        models = []
        rows = table.find_all('tr')
        
        # 常见模型名称模式
        model_patterns = [
            r'\b(qwen[0-9a-z\-\.]+)\b',
            r'\b(deepseek-[a-z0-9\-\.]+)\b',
            r'\b(glm-[0-9a-z\-\.]+)\b',
            r'\b(llama-[0-9a-z\-\.]+)\b',
        ]
        
        for row in rows:
            cells = row.find_all(['td', 'th'])
            for cell in cells:
                text = cell.get_text()
                for pattern in model_patterns:
                    matches = re.findall(pattern, text, re.IGNORECASE)
                    models.extend([m.lower() for m in matches])
        
        return list(set(models))
    
    def _find_next_pricing_table(self, model_table: Tag) -> Optional[Tag]:
        """查找模型表格之后的阶梯计价表格"""
        # 获取当前表格之后的兄弟元素
        current = model_table.next_sibling
        
        # 最多向后查找5个元素
        for _ in range(10):
            if current is None:
                break
            
            # 如果是表格，检查是否是阶梯计价表格
            if isinstance(current, Tag) and current.name == 'table':
                table_text = self._extract_table_text(current)
                # 阶梯计价表格特征：包含Token区间和价格
                if ('Token' in table_text and 
                    ('≤' in table_text or '<' in table_text) and
                    '元' in table_text):
                    return current
            
            # 如果遇到段落，检查是否包含"阶梯计费"描述
            if isinstance(current, Tag) and current.name == 'p':
                text = current.get_text()
                if '阶梯计' in text:
                    # 继续查找下一个表格
                    pass
            
            current = current.next_sibling
        
        return None
    
    def _extract_table_text(self, table: Tag) -> str:
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
    
    def _parse_table_group_with_llm(self, group: Dict) -> Tuple[List[Dict], Dict]:
        """使用LLM解析表格组（模型+阶梯计价）"""
        
        prompt = f"""请从以下数据中提取LLM模型定价信息。

## 模型表格
{group['model_table_text'][:4000]}

## 阶梯计价表格
{group['tiered_pricing_text'][:2000]}

## 要求
1. 为每个模型（{', '.join(group['models'][:5])}等）创建完整的数据条目
2. 阶梯计价表格中的价格适用于上面所有模型
3. 按照上下文窗口分段建模tiered_pricing：
   - 每个价格段包含：token_range（如"0-128K"）、input_price、output_price
4. model_id必须是标准API名称（如qwen-plus, qwen-max）

## 输出格式（JSON数组）
```json
[{{
  "model_id": "qwen-plus",
  "model_name": "通义千问Plus",
  "vendor": "aliyun",
  "category": "text_generation",
  "specs": {{"max_context_length": 1000000, "max_input_tokens": 995904}},
  "tiered_pricing": [
    {{"token_range": "0-128K", "input_price": 0.008, "output_price": 0.002}},
    {{"token_range": "128K-256K", "input_price": 0.016, "output_price": 0.004}}
  ]
}}]
```

只返回JSON数组，不要其他文字。"""
        
        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": "你是数据提取专家，擅长从复杂表格中提取结构化信息。只返回JSON。"},
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
            
            models = self._extract_json_from_response(content)
            return models, usage
            
        except Exception as e:
            print(f"   ❌ LLM调用失败: {e}")
            return [], {'input': 0, 'output': 0}
    
    def _extract_json_from_response(self, content: str) -> List[Dict]:
        """从LLM响应中提取JSON"""
        json_match = re.search(r'```(?:json)?\s*([\s\S]*?)\s*```', content)
        if json_match:
            json_str = json_match.group(1)
        else:
            json_str = content
        
        try:
            data = json.loads(json_str)
            if isinstance(data, list):
                return self._normalize_models(data)
            return []
        except json.JSONDecodeError:
            return []
    
    def _normalize_models(self, models: List[Dict]) -> List[Dict]:
        """标准化模型数据格式"""
        normalized = []
        for m in models:
            if not isinstance(m, dict) or not m.get('model_id'):
                continue
            
            model_id = str(m['model_id']).lower().strip()
            
            # 处理tiered_pricing -> 转换为标准pricing格式
            pricing = []
            if m.get('tiered_pricing'):
                for tier in m['tiered_pricing']:
                    if isinstance(tier, dict):
                        pricing.append({
                            "region": "cn-beijing",
                            "token_range": tier.get('token_range', ''),
                            "input_price": {
                                "price": tier.get('input_price', 0),
                                "unit": "千Token",
                                "unit_quantity": 1000
                            },
                            "output_price": {
                                "price": tier.get('output_price', 0),
                                "unit": "千Token",
                                "unit_quantity": 1000
                            }
                        })
            
            normalized.append({
                "model_id": model_id,
                "model_name": str(m.get('model_name', model_id)),
                "vendor": m.get('vendor', 'aliyun'),
                "category": m.get('category', 'text_generation'),
                "specs": m.get('specs') if isinstance(m.get('specs'), dict) else None,
                "pricing": pricing,
                "has_tiered_pricing": len(pricing) > 1,
                "status": "active"
            })
        
        return normalized
    
    def _deduplicate_models(self, models: List[Dict]) -> List[Dict]:
        """去重，保留信息最完整的记录"""
        seen = {}
        for m in models:
            mid = m['model_id']
            if mid not in seen:
                seen[mid] = m
            else:
                existing = seen[mid]
                # 保留pricing更完整的
                if len(m.get('pricing', [])) > len(existing.get('pricing', [])):
                    seen[mid] = m
        
        return list(seen.values())


def main():
    parser = LLMModelParserV2()
    result = parser.parse_html_file("bailian_page.html")
    
    # 显示有阶梯计价的模型
    tiered_models = [m for m in result['models'] if m.get('has_tiered_pricing')]
    print(f"\n📊 有阶梯计价的模型: {len(tiered_models)}")
    for m in tiered_models[:5]:
        print(f"   - {m['model_id']}: {len(m.get('pricing', []))} 个价格段")
        for p in m.get('pricing', [])[:2]:
            print(f"     {p.get('token_range')}: 输入={p.get('input_price', {}).get('price')}, 输出={p.get('output_price', {}).get('price')}")


if __name__ == "__main__":
    main()
