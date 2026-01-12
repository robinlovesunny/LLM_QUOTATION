"""
Function Calling Tools
Provides tools for AI agent to extract entities, estimate usage, and calculate prices
"""
import json
from typing import Dict, Any, List, Optional
from decimal import Decimal
from loguru import logger

from app.services.pricing_engine import pricing_engine


class FunctionTools:
    """Function Calling tool collection for AI agents"""
    
    @staticmethod
    def get_tool_definitions() -> list:
        """Get all tool definitions for Function Calling"""
        return [
            {
                "name": "extract_and_respond",
                "description": "Extract product requirement entities from user input and generate response. Call this when user describes their product needs.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "product_name": {
                            "type": "string",
                            "description": "Product or model name (e.g., qwen-max, qwen-plus, gpt-4, A10, V100)"
                        },
                        "product_type": {
                            "type": "string",
                            "enum": ["llm", "gpu", "storage", "network", "other"],
                            "description": "Product type category"
                        },
                        "use_case": {
                            "type": "string",
                            "description": "Usage scenario (e.g., customer service, content generation, training, inference)"
                        },
                        "quantity": {
                            "type": "integer",
                            "description": "Number of units/instances needed"
                        },
                        "duration_months": {
                            "type": "integer",
                            "description": "Duration in months"
                        },
                        "call_frequency": {
                            "type": "integer",
                            "description": "Expected monthly API call count (for LLM products)"
                        },
                        "estimated_tokens_per_call": {
                            "type": "integer",
                            "description": "Estimated tokens per API call (for LLM products)"
                        },
                        "region": {
                            "type": "string",
                            "description": "Deployment region (e.g., cn-beijing, cn-shanghai)"
                        },
                        "additional_requirements": {
                            "type": "string",
                            "description": "Any additional requirements mentioned"
                        }
                    },
                    "required": ["product_name", "product_type"]
                }
            },
            {
                "name": "estimate_llm_usage",
                "description": "Estimate LLM product usage based on use case and workload. Returns token estimates, call frequency, and mode recommendations.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "use_case": {
                            "type": "string",
                            "description": "Usage scenario description"
                        },
                        "workload": {
                            "type": "string",
                            "description": "Workload description (e.g., high frequency, batch processing)"
                        },
                        "product_name": {
                            "type": "string",
                            "description": "LLM product name"
                        }
                    },
                    "required": ["use_case", "workload"]
                }
            },
            {
                "name": "calculate_price",
                "description": "Calculate product price with support for Token pricing, thinking mode, Batch discount, etc.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "product_type": {
                            "type": "string",
                            "enum": ["llm", "standard"],
                            "description": "Product type"
                        },
                        "product_name": {
                            "type": "string",
                            "description": "Product name for price lookup"
                        },
                        "context": {
                            "type": "object",
                            "description": "Pricing context including tokens, call frequency, quantity, etc."
                        }
                    },
                    "required": ["product_type", "product_name", "context"]
                }
            }
        ]
    
    @staticmethod
    async def extract_and_respond(
        product_name: str,
        product_type: str,
        use_case: Optional[str] = None,
        quantity: Optional[int] = None,
        duration_months: Optional[int] = None,
        call_frequency: Optional[int] = None,
        estimated_tokens_per_call: Optional[int] = None,
        region: Optional[str] = None,
        additional_requirements: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Process extracted entities from user input and generate response with price estimation.
        This is called by the AI model with structured entities extracted from natural language.
        """
        logger.info(f"[Tools] extract_and_respond called: product={product_name}, type={product_type}")
        
        # Build entities dict
        entities = {
            "product_name": product_name,
            "product_type": product_type,
            "use_case": use_case,
            "quantity": quantity or 1,
            "duration_months": duration_months or 1,
            "call_frequency": call_frequency,
            "estimated_tokens_per_call": estimated_tokens_per_call,
            "region": region or "cn-beijing",
            "additional_requirements": additional_requirements
        }
        
        # Get product price from mock data
        price_info = FunctionTools._get_product_price(product_name, product_type)
        
        # Calculate price based on product type
        if product_type == "llm":
            # LLM products: token-based pricing
            tokens_per_call = estimated_tokens_per_call or 1000
            monthly_calls = call_frequency or 10000
            total_tokens = tokens_per_call * monthly_calls * (duration_months or 1)
            
            price_result = pricing_engine.calculate(
                Decimal(str(price_info["input_price"])),
                {
                    "product_type": "llm",
                    "input_token_price": price_info["input_price"],
                    "output_token_price": price_info["output_price"],
                    "input_tokens": int(total_tokens * 0.7),  # 70% input
                    "output_tokens": int(total_tokens * 0.3),  # 30% output
                    "thinking_mode_ratio": 0.0,
                    "batch_call_ratio": 0.0
                }
            )
        else:
            # Standard products: quantity * duration pricing
            price_result = pricing_engine.calculate(
                Decimal(str(price_info.get("unit_price", 100))),
                {
                    "product_type": "standard",
                    "quantity": quantity or 1,
                    "duration_months": duration_months or 1
                }
            )
        
        return {
            "entities": entities,
            "price_info": price_info,
            "price_calculation": price_result,
            "summary": FunctionTools._generate_summary(entities, price_result)
        }
    
    @staticmethod
    def _get_product_price(product_name: str, product_type: str) -> Dict[str, Any]:
        """
        Get product price from mock data (will be replaced with database lookup)
        """
        # Mock LLM product prices (per 1000 tokens, in CNY)
        llm_prices = {
            "qwen-max": {"input_price": 0.02, "output_price": 0.06, "name": "Qwen-Max"},
            "qwen-plus": {"input_price": 0.004, "output_price": 0.012, "name": "Qwen-Plus"},
            "qwen-turbo": {"input_price": 0.002, "output_price": 0.006, "name": "Qwen-Turbo"},
            "qwen-long": {"input_price": 0.0005, "output_price": 0.002, "name": "Qwen-Long"},
            "qwen-vl-max": {"input_price": 0.02, "output_price": 0.06, "name": "Qwen-VL-Max"},
            "qwen-vl-plus": {"input_price": 0.008, "output_price": 0.02, "name": "Qwen-VL-Plus"},
        }
        
        # Mock GPU prices (per hour, in CNY)
        gpu_prices = {
            "a10": {"unit_price": 15.0, "name": "NVIDIA A10", "memory": "24GB"},
            "v100": {"unit_price": 25.0, "name": "NVIDIA V100", "memory": "32GB"},
            "a100": {"unit_price": 45.0, "name": "NVIDIA A100", "memory": "80GB"},
        }
        
        product_key = product_name.lower().replace("-", "-").replace("_", "-")
        
        if product_type == "llm":
            return llm_prices.get(product_key, llm_prices["qwen-plus"])
        elif product_type == "gpu":
            return gpu_prices.get(product_key, gpu_prices["a10"])
        else:
            return {"unit_price": 100.0, "name": product_name}
    
    @staticmethod
    def _generate_summary(entities: Dict[str, Any], price_result: Dict[str, Any]) -> str:
        """Generate a summary message"""
        product = entities.get("product_name", "Unknown")
        final_price = price_result.get("final_price", 0)
        
        summary_parts = [f"Product: {product}"]
        
        if entities.get("use_case"):
            summary_parts.append(f"Use case: {entities['use_case']}")
        if entities.get("call_frequency"):
            summary_parts.append(f"Monthly calls: {entities['call_frequency']:,}")
        if entities.get("quantity") and entities.get("quantity") > 1:
            summary_parts.append(f"Quantity: {entities['quantity']}")
        if entities.get("duration_months"):
            summary_parts.append(f"Duration: {entities['duration_months']} months")
        
        summary_parts.append(f"Estimated cost: ¥{final_price:,.2f}")
        
        return " | ".join(summary_parts)
    
    @staticmethod
    async def extract_entities(text: str) -> Dict[str, Any]:
        """
        Legacy entity extraction using regex (kept for backward compatibility)
        """
        import re
        
        entities = {
            "product_name": None,
            "product_type": None,
            "quantity": None,
            "duration_months": None,
            "use_case": None,
            "region": None
        }
        
        # Extract quantity
        quantity_match = re.search(r'(\d+)\s*[张个台块万]', text)
        if quantity_match:
            entities["quantity"] = int(quantity_match.group(1))
        
        # Extract duration
        duration_match = re.search(r'(\d+)\s*[个]?月', text)
        if duration_match:
            entities["duration_months"] = int(duration_match.group(1))
        
        # Extract call frequency
        freq_match = re.search(r'(\d+)\s*万?\s*次', text)
        if freq_match:
            freq = int(freq_match.group(1))
            if '万' in text:
                freq *= 10000
            entities["call_frequency"] = freq
        
        # Detect product type and name
        text_lower = text.lower()
        if any(x in text_lower for x in ['qwen', 'gpt', '大模型', '对话', 'llm']):
            entities["product_type"] = "llm"
            if 'qwen-max' in text_lower or 'qwen max' in text_lower:
                entities["product_name"] = "qwen-max"
            elif 'qwen-plus' in text_lower or 'qwen plus' in text_lower:
                entities["product_name"] = "qwen-plus"
            else:
                entities["product_name"] = "qwen-plus"  # default
        elif any(x in text_lower for x in ['a10', 'v100', 'a100', 'gpu', '显卡']):
            entities["product_type"] = "gpu"
            if 'a10' in text_lower:
                entities["product_name"] = "a10"
            elif 'v100' in text_lower:
                entities["product_name"] = "v100"
            elif 'a100' in text_lower:
                entities["product_name"] = "a100"
        
        # Detect use case
        if '训练' in text:
            entities["use_case"] = "training"
        elif '推理' in text:
            entities["use_case"] = "inference"
        elif '客服' in text or '对话' in text:
            entities["use_case"] = "customer_service"
        elif '内容' in text or '生成' in text:
            entities["use_case"] = "content_generation"
        
        return entities
    
    @staticmethod
    async def estimate_llm_usage(
        use_case: str,
        workload: str,
        product_name: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Estimate LLM product usage based on use case and workload.
        """
        logger.info(f"[Tools] estimate_llm_usage: use_case={use_case}, workload={workload}")
        
        # Usage templates by scenario
        usage_templates = {
            "customer_service": {
                "estimated_tokens_per_call": 800,
                "call_frequency": 50000,
                "thinking_mode_ratio": 0.0,
                "batch_call_ratio": 0.0,
                "recommended_model": "qwen-turbo"
            },
            "content_generation": {
                "estimated_tokens_per_call": 2000,
                "call_frequency": 10000,
                "thinking_mode_ratio": 0.3,
                "batch_call_ratio": 0.5,
                "recommended_model": "qwen-plus"
            },
            "code_generation": {
                "estimated_tokens_per_call": 1500,
                "call_frequency": 5000,
                "thinking_mode_ratio": 0.5,
                "batch_call_ratio": 0.2,
                "recommended_model": "qwen-max"
            },
            "data_analysis": {
                "estimated_tokens_per_call": 3000,
                "call_frequency": 2000,
                "thinking_mode_ratio": 0.4,
                "batch_call_ratio": 0.6,
                "recommended_model": "qwen-long"
            },
            "default": {
                "estimated_tokens_per_call": 1000,
                "call_frequency": 10000,
                "thinking_mode_ratio": 0.2,
                "batch_call_ratio": 0.3,
                "recommended_model": "qwen-plus"
            }
        }
        
        # Match use case to template
        use_case_lower = use_case.lower()
        if any(x in use_case_lower for x in ['客服', 'customer', 'chat', '对话']):
            template = usage_templates["customer_service"]
        elif any(x in use_case_lower for x in ['内容', 'content', '生成', 'writing']):
            template = usage_templates["content_generation"]
        elif any(x in use_case_lower for x in ['代码', 'code', '编程', 'programming']):
            template = usage_templates["code_generation"]
        elif any(x in use_case_lower for x in ['数据', 'data', '分析', 'analysis']):
            template = usage_templates["data_analysis"]
        else:
            template = usage_templates["default"]
        
        # Adjust based on workload
        workload_lower = workload.lower()
        if any(x in workload_lower for x in ['高频', 'high', '大量', 'heavy']):
            template["call_frequency"] = int(template["call_frequency"] * 2)
        elif any(x in workload_lower for x in ['低频', 'low', '少量', 'light']):
            template["call_frequency"] = int(template["call_frequency"] * 0.5)
        
        template["use_case"] = use_case
        template["workload"] = workload
        template["recommendation"] = (
            f"Based on '{use_case}' scenario and '{workload}' workload:\n"
            f"- Estimated tokens per call: {template['estimated_tokens_per_call']:,}\n"
            f"- Monthly call frequency: {template['call_frequency']:,}\n"
            f"- Thinking mode ratio: {template['thinking_mode_ratio']*100:.0f}%\n"
            f"- Batch call ratio: {template['batch_call_ratio']*100:.0f}%\n"
            f"- Recommended model: {template['recommended_model']}"
        )
        
        return template
    
    @staticmethod
    async def calculate_price(
        product_type: str,
        product_name: str,
        context: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Calculate price for a product.
        """
        logger.info(f"[Tools] calculate_price: type={product_type}, name={product_name}")
        
        # Get product price
        price_info = FunctionTools._get_product_price(product_name, product_type)
        
        if product_type == "llm":
            # Use input price as base for LLM
            base_price = Decimal(str(price_info.get("input_price", 0.01)))
            context["input_token_price"] = price_info.get("input_price", 0.01)
            context["output_token_price"] = price_info.get("output_price", 0.03)
        else:
            base_price = Decimal(str(price_info.get("unit_price", 100)))
        
        result = pricing_engine.calculate(
            base_price,
            {**context, "product_type": product_type}
        )
        
        result["product_name"] = product_name
        result["price_info"] = price_info
        
        return result
    
    @staticmethod
    async def execute_function(function_name: str, arguments: Dict[str, Any]) -> Any:
        """
        Execute a function call from the AI model.
        """
        logger.info(f"[Tools] Executing function: {function_name}")
        
        function_map = {
            "extract_and_respond": FunctionTools.extract_and_respond,
            "extract_entities": FunctionTools.extract_entities,
            "estimate_llm_usage": FunctionTools.estimate_llm_usage,
            "calculate_price": FunctionTools.calculate_price
        }
        
        func = function_map.get(function_name)
        if not func:
            logger.error(f"[Tools] Unknown function: {function_name}")
            raise ValueError(f"Unknown function: {function_name}")
        
        return await func(**arguments)


# 创建全局工具实例
function_tools = FunctionTools()
