"""
Function Calling工具集 - 智能报价助手
"""
import json
from typing import Dict, Any, List
from decimal import Decimal
from loguru import logger

from app.services.pricing_engine import pricing_engine
from app.core.database import async_session_maker
from sqlalchemy import select, text


class FunctionTools:
    """Function Calling工具集合"""
    
    @staticmethod
    def get_tool_definitions() -> list:
        """获取所有工具的定义"""
        return [
            {
                "name": "search_models",
                "description": "搜索大模型产品，支持按名称、类别、功能搜索。用于回答用户关于有哪些模型、模型推荐等问题",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "keyword": {
                            "type": "string",
                            "description": "搜索关键词，如模型名称(qwen、通义)、类别(文本、语音、视觉)、场景(客服、写作)"
                        },
                        "category": {
                            "type": "string",
                            "description": "产品类别，如：文本生成、视觉理解、语音、向量"
                        },
                        "limit": {
                            "type": "integer",
                            "description": "返回数量限制，默认5"
                        }
                    },
                    "required": []
                }
            },
            {
                "name": "get_model_price",
                "description": "查询指定模型的价格信息。用于回答用户关于某个模型多少钱的问题",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "model_name": {
                            "type": "string",
                            "description": "模型名称，如qwen-max、qwen-plus"
                        }
                    },
                    "required": ["model_name"]
                }
            },
            {
                "name": "calculate_monthly_cost",
                "description": "根据用量估算月费用。用于回答用户关于每月花费多少钱的问题",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "model_name": {
                            "type": "string",
                            "description": "模型名称"
                        },
                        "daily_calls": {
                            "type": "integer",
                            "description": "每日调用次数"
                        },
                        "avg_input_tokens": {
                            "type": "integer",
                            "description": "平均每次输入token数，默认1000"
                        },
                        "avg_output_tokens": {
                            "type": "integer",
                            "description": "平均每次输出token数，默认500"
                        }
                    },
                    "required": ["model_name", "daily_calls"]
                }
            },
            {
                "name": "recommend_model",
                "description": "根据用户场景和预算推荐合适的模型",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "use_case": {
                            "type": "string",
                            "description": "使用场景，如：智能客服、内容生成、代码助手、数据分析"
                        },
                        "budget": {
                            "type": "number",
                            "description": "月预算(元)，可选"
                        },
                        "priority": {
                            "type": "string",
                            "enum": ["cost", "performance", "balanced"],
                            "description": "优先考虑因素：cost=成本优先, performance=效果优先, balanced=均衡"
                        }
                    },
                    "required": ["use_case"]
                }
            },
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
            },
            {
                "name": "generate_quote_item",
                "description": "生成报价项，将模型配置转换为可添加到报价单的结构化数据。当用户确认要添加某个模型到报价单时调用",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "model_name": {
                            "type": "string",
                            "description": "模型名称"
                        },
                        "daily_calls": {
                            "type": "integer",
                            "description": "每日调用次数"
                        },
                        "avg_input_tokens": {
                            "type": "integer",
                            "description": "平均输入token数，默认1000"
                        },
                        "avg_output_tokens": {
                            "type": "integer",
                            "description": "平均输出token数，默认500"
                        },
                        "duration_months": {
                            "type": "integer",
                            "description": "使用时长(月)，默认1"
                        }
                    },
                    "required": ["model_name"]
                }
            },
            {
                "name": "create_quote_summary",
                "description": "生成报价单摘要，汇总所有已添加的报价项。当用户要求查看报价单或确认报价时调用",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "items": {
                            "type": "array",
                            "description": "报价项列表",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "model_name": {"type": "string"},
                                    "monthly_cost": {"type": "number"}
                                }
                            }
                        },
                        "customer_name": {
                            "type": "string",
                            "description": "客户名称"
                        }
                    },
                    "required": ["items"]
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
    async def search_models(
        keyword: str = None,
        category: str = None,
        limit: int = 5
    ) -> Dict[str, Any]:
        """搜索模型"""
        try:
            async with async_session_maker() as session:
                sql = """
                    SELECT p.product_code, p.product_name, p.category, p.vendor,
                           pp.unit_price, pp.unit, pp.pricing_variables
                    FROM products p
                    LEFT JOIN product_prices pp ON p.product_code = pp.product_code
                    WHERE p.status = 'active'
                """
                params = {}
                
                if keyword:
                    sql += " AND (p.product_name ILIKE :keyword OR p.category ILIKE :keyword)"
                    params["keyword"] = f"%{keyword}%"
                
                if category:
                    sql += " AND p.category ILIKE :category"
                    params["category"] = f"%{category}%"
                
                sql += " LIMIT :limit"
                params["limit"] = limit
                
                result = await session.execute(text(sql), params)
                rows = result.fetchall()
                
                models = []
                for row in rows:
                    pricing_vars = row.pricing_variables or {}
                    models.append({
                        "model_id": row.product_code,
                        "model_name": row.product_name,
                        "category": row.category,
                        "vendor": row.vendor,
                        "input_price": pricing_vars.get("input_price"),
                        "output_price": pricing_vars.get("output_price"),
                        "unit": row.unit or "千Token"
                    })
                
                return {
                    "found": len(models),
                    "models": models,
                    "message": f"找到 {len(models)} 个模型" if models else "未找到匹配的模型"
                }
        except Exception as e:
            logger.error(f"搜索模型失败: {e}")
            return {"found": 0, "models": [], "error": str(e)}
    
    @staticmethod
    async def get_model_price(model_name: str) -> Dict[str, Any]:
        """查询模型价格"""
        try:
            async with async_session_maker() as session:
                sql = """
                    SELECT p.product_code, p.product_name, p.category,
                           pp.unit_price, pp.unit, pp.billing_mode, pp.pricing_variables
                    FROM products p
                    LEFT JOIN product_prices pp ON p.product_code = pp.product_code
                    WHERE p.product_code ILIKE :name OR p.product_name ILIKE :name
                """
                result = await session.execute(text(sql), {"name": f"%{model_name}%"})
                rows = result.fetchall()
                
                if not rows:
                    return {"found": False, "message": f"未找到模型: {model_name}"}
                
                row = rows[0]
                pricing_vars = row.pricing_variables or {}
                
                return {
                    "found": True,
                    "model_id": row.product_code,
                    "model_name": row.product_name,
                    "category": row.category,
                    "pricing": {
                        "input_price": pricing_vars.get("input_price"),
                        "output_price": pricing_vars.get("output_price"),
                        "unit": row.unit or "千Token",
                        "billing_mode": row.billing_mode
                    },
                    "message": f"{row.product_name} 价格: 输入 {pricing_vars.get('input_price', 'N/A')}元/{row.unit or '千Token'}, 输出 {pricing_vars.get('output_price', 'N/A')}元/{row.unit or '千Token'}"
                }
        except Exception as e:
            logger.error(f"查询价格失败: {e}")
            return {"found": False, "error": str(e)}
    
    @staticmethod
    async def calculate_monthly_cost(
        model_name: str,
        daily_calls: int,
        avg_input_tokens: int = 1000,
        avg_output_tokens: int = 500
    ) -> Dict[str, Any]:
        """计算月费用"""
        price_info = await FunctionTools.get_model_price(model_name)
        
        if not price_info.get("found"):
            return price_info
        
        pricing = price_info.get("pricing", {})
        input_price = pricing.get("input_price", 0) or 0
        output_price = pricing.get("output_price", 0) or 0
        
        # 计算月费用
        monthly_calls = daily_calls * 30
        input_cost = (avg_input_tokens / 1000) * input_price * monthly_calls
        output_cost = (avg_output_tokens / 1000) * output_price * monthly_calls
        total_cost = input_cost + output_cost
        
        return {
            "model_name": price_info["model_name"],
            "daily_calls": daily_calls,
            "monthly_calls": monthly_calls,
            "avg_input_tokens": avg_input_tokens,
            "avg_output_tokens": avg_output_tokens,
            "input_cost": round(input_cost, 2),
            "output_cost": round(output_cost, 2),
            "total_monthly_cost": round(total_cost, 2),
            "message": f"预估月费用: ¥{total_cost:,.2f} (输入: ¥{input_cost:,.2f}, 输出: ¥{output_cost:,.2f})"
        }
    
    @staticmethod
    async def recommend_model(
        use_case: str,
        budget: float = None,
        priority: str = "balanced"
    ) -> Dict[str, Any]:
        """推荐模型"""
        # 场景到模型的推荐映射
        recommendations = {
            "客服": ["qwen-plus", "qwen-turbo"],
            "智能客服": ["qwen-plus", "qwen-turbo"],
            "对话": ["qwen-plus", "qwen-max"],
            "内容生成": ["qwen-max", "qwen-plus"],
            "写作": ["qwen-max", "qwen-plus"],
            "代码": ["qwen-coder-plus", "qwen-max"],
            "代码助手": ["qwen-coder-plus", "qwen-max"],
            "数据分析": ["qwen-max", "qwen-plus"],
            "图像理解": ["qwen-vl-max", "qwen-vl-plus"],
            "视觉": ["qwen-vl-max", "qwen-vl-plus"],
            "语音": ["cosyvoice-v2", "paraformer-v2"],
        }
        
        # 匹配场景
        matched_models = []
        for key, models in recommendations.items():
            if key in use_case:
                matched_models = models
                break
        
        if not matched_models:
            matched_models = ["qwen-plus", "qwen-max"]  # 默认推荐
        
        # 查询推荐模型的详细信息
        result_models = []
        for model_id in matched_models:
            price_info = await FunctionTools.get_model_price(model_id)
            if price_info.get("found"):
                result_models.append({
                    "model_id": price_info["model_id"],
                    "model_name": price_info["model_name"],
                    "pricing": price_info["pricing"],
                    "recommendation_reason": f"适合{use_case}场景" if priority == "performance" else "性价比高"
                })
        
        return {
            "use_case": use_case,
            "priority": priority,
            "recommendations": result_models,
            "message": f"为'{use_case}'场景推荐以下模型" if result_models else "暂无推荐模型"
        }
    
    @staticmethod
    async def generate_quote_item(
        model_name: str,
        daily_calls: int = 1000,
        avg_input_tokens: int = 1000,
        avg_output_tokens: int = 500,
        duration_months: int = 1
    ) -> Dict[str, Any]:
        """生成报价项"""
        # 获取模型价格
        price_info = await FunctionTools.get_model_price(model_name)
        
        if not price_info.get("found"):
            return {"success": False, "error": f"未找到模型: {model_name}"}
        
        # 计算月费用
        cost_info = await FunctionTools.calculate_monthly_cost(
            model_name, daily_calls, avg_input_tokens, avg_output_tokens
        )
        
        monthly_cost = cost_info.get("total_monthly_cost", 0)
        total_cost = monthly_cost * duration_months
        
        # 生成报价项
        quote_item = {
            "id": f"qi_{model_name}_{daily_calls}",
            "model_id": price_info["model_id"],
            "model_name": price_info["model_name"],
            "category": price_info.get("category", "AI-大模型"),
            "config": {
                "daily_calls": daily_calls,
                "avg_input_tokens": avg_input_tokens,
                "avg_output_tokens": avg_output_tokens,
                "duration_months": duration_months
            },
            "pricing": price_info.get("pricing", {}),
            "monthly_cost": monthly_cost,
            "total_cost": round(total_cost, 2),
            "duration_months": duration_months
        }
        
        return {
            "success": True,
            "quote_item": quote_item,
            "action": "add_to_quote",
            "message": f"✅ 已生成报价项:\n- 模型: {price_info['model_name']}\n- 日调用量: {daily_calls:,}次\n- 月费用: ¥{monthly_cost:,.2f}\n- 总费用({duration_months}个月): ¥{total_cost:,.2f}"
        }
    
    @staticmethod
    async def create_quote_summary(
        items: List[Dict[str, Any]],
        customer_name: str = ""
    ) -> Dict[str, Any]:
        """生成报价单摘要"""
        if not items:
            return {
                "success": False,
                "message": "报价单为空，请先添加产品"
            }
        
        total_monthly = sum(item.get("monthly_cost", 0) for item in items)
        total_amount = sum(item.get("total_cost", item.get("monthly_cost", 0)) for item in items)
        
        summary = {
            "success": True,
            "action": "show_quote_summary",
            "quote": {
                "customer_name": customer_name or "未填写",
                "items": items,
                "item_count": len(items),
                "total_monthly": round(total_monthly, 2),
                "total_amount": round(total_amount, 2)
            },
            "message": f"📝 **报价单摘要**\n\n客户: {customer_name or '未填写'}\n产品数: {len(items)}项\n月费用: ¥{total_monthly:,.2f}\n**总金额: ¥{total_amount:,.2f}**"
        }
        
        return summary
    
    @staticmethod
    async def execute_function(function_name: str, arguments: Dict[str, Any]) -> Any:
        """执行Function Call"""
        function_map = {
            "search_models": FunctionTools.search_models,
            "get_model_price": FunctionTools.get_model_price,
            "calculate_monthly_cost": FunctionTools.calculate_monthly_cost,
            "recommend_model": FunctionTools.recommend_model,
            "extract_entities": FunctionTools.extract_entities,
            "estimate_llm_usage": FunctionTools.estimate_llm_usage,
            "calculate_price": FunctionTools.calculate_price,
            "generate_quote_item": FunctionTools.generate_quote_item,
            "create_quote_summary": FunctionTools.create_quote_summary
        }
        
        func = function_map.get(function_name)
        if not func:
            raise ValueError(f"Unknown function: {function_name}")
        
        return await func(**arguments)


# 创建全局工具实例
function_tools = FunctionTools()
