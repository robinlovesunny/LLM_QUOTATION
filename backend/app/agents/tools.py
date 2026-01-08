"""
Function Calling工具集
"""
import json
from typing import Dict, Any
from decimal import Decimal

from app.services.pricing_engine import pricing_engine


class FunctionTools:
    """Function Calling工具集合"""
    
    @staticmethod
    def get_tool_definitions() -> list:
        """获取所有工具的定义"""
        return [
            {
                "name": "extract_entities",
                "description": "从用户输入文本中提取产品需求实体信息",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "text": {
                            "type": "string",
                            "description": "用户输入的需求文本"
                        }
                    },
                    "required": ["text"]
                }
            },
            {
                "name": "estimate_llm_usage",
                "description": "估算大模型产品的用量(Token数、调用频率、模式建议)",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "use_case": {
                            "type": "string",
                            "description": "使用场景描述"
                        },
                        "workload": {
                            "type": "string",
                            "description": "工作负载描述"
                        }
                    },
                    "required": ["use_case", "workload"]
                }
            },
            {
                "name": "calculate_price",
                "description": "计算产品价格,支持Token计费、思考模式、Batch折扣等",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "product_type": {
                            "type": "string",
                            "enum": ["llm", "standard"],
                            "description": "产品类型"
                        },
                        "base_price": {
                            "type": "number",
                            "description": "基础单价"
                        },
                        "context": {
                            "type": "object",
                            "description": "计费上下文(Token数、调用频率、数量等)"
                        }
                    },
                    "required": ["product_type", "base_price", "context"]
                }
            }
        ]
    
    @staticmethod
    async def extract_entities(text: str) -> Dict[str, Any]:
        """
        提取实体信息
        
        示例输入: "需要100张A10卡训练3个月"
        示例输出: {
            "product": "GPU实例",
            "spec": "A10",
            "quantity": 100,
            "duration": 3,
            "duration_unit": "月",
            "usage_pattern": "训练"
        }
        """
        # TODO: 这里可以调用更复杂的NER模型
        # 目前使用简单的规则提取
        entities = {
            "product": None,
            "quantity": None,
            "duration": None,
            "region": None,
            "usage_pattern": None
        }
        
        # 简单的关键词匹配
        import re
        
        # 提取数量
        quantity_match = re.search(r'(\d+)\s*[张个台块]', text)
        if quantity_match:
            entities["quantity"] = int(quantity_match.group(1))
        
        # 提取时长
        duration_match = re.search(r'(\d+)\s*[个]?[月年天]', text)
        if duration_match:
            entities["duration"] = int(duration_match.group(1))
        
        # 提取GPU型号
        if 'A10' in text or 'a10' in text:
            entities["product"] = "GPU实例"
            entities["spec"] = "A10"
        elif 'V100' in text or 'v100' in text:
            entities["product"] = "GPU实例"
            entities["spec"] = "V100"
        
        # 提取使用模式
        if '训练' in text:
            entities["usage_pattern"] = "训练"
        elif '推理' in text:
            entities["usage_pattern"] = "推理"
        
        return entities
    
    @staticmethod
    async def estimate_llm_usage(use_case: str, workload: str) -> Dict[str, Any]:
        """
        估算大模型用量
        
        Returns:
            {
                "estimated_tokens": int,
                "call_frequency": int,
                "thinking_mode_ratio": float,
                "batch_call_ratio": float,
                "recommendation": str
            }
        """
        # 基于场景的用量估算模板
        usage_templates = {
            "客服对话": {
                "estimated_tokens": 1000,
                "call_frequency": 10000,
                "thinking_mode_ratio": 0.0,
                "batch_call_ratio": 0.0
            },
            "内容生成": {
                "estimated_tokens": 2000,
                "call_frequency": 5000,
                "thinking_mode_ratio": 0.3,
                "batch_call_ratio": 0.5
            },
            "代码生成": {
                "estimated_tokens": 1500,
                "call_frequency": 3000,
                "thinking_mode_ratio": 0.5,
                "batch_call_ratio": 0.2
            }
        }
        
        # 匹配场景
        template = usage_templates.get("内容生成", {
            "estimated_tokens": 1000,
            "call_frequency": 5000,
            "thinking_mode_ratio": 0.2,
            "batch_call_ratio": 0.3
        })
        
        # 根据工作负载调整
        if "高频" in workload or "大量" in workload:
            template["call_frequency"] = int(template["call_frequency"] * 1.5)
        
        template["recommendation"] = (
            f"基于'{use_case}'场景和'{workload}'工作负载,建议配置:\n"
            f"- 预估每次调用Token数: {template['estimated_tokens']}\n"
            f"- 月调用次数: {template['call_frequency']}\n"
            f"- 思考模式占比: {template['thinking_mode_ratio']*100}%\n"
            f"- Batch调用占比: {template['batch_call_ratio']*100}%"
        )
        
        return template
    
    @staticmethod
    async def calculate_price(
        product_type: str,
        base_price: float,
        context: Dict[str, Any]
    ) -> Dict[str, Any]:
        """计算价格"""
        result = pricing_engine.calculate(
            Decimal(str(base_price)),
            {**context, "product_type": product_type}
        )
        return result
    
    @staticmethod
    async def execute_function(function_name: str, arguments: Dict[str, Any]) -> Any:
        """执行Function Call"""
        function_map = {
            "extract_entities": FunctionTools.extract_entities,
            "estimate_llm_usage": FunctionTools.estimate_llm_usage,
            "calculate_price": FunctionTools.calculate_price
        }
        
        func = function_map.get(function_name)
        if not func:
            raise ValueError(f"Unknown function: {function_name}")
        
        return await func(**arguments)


# 创建全局工具实例
function_tools = FunctionTools()
