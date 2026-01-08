"""
计费计算引擎测试
"""
import pytest
from decimal import Decimal

from app.services.pricing_engine import PricingEngine


class TestPricingEngine:
    """计费计算引擎测试"""
    
    def setup_method(self):
        """初始化测试"""
        self.engine = PricingEngine()
    
    def test_llm_token_pricing(self):
        """测试大模型Token计费"""
        base_price = Decimal("0.040")  # 输入Token单价
        
        context = {
            "product_type": "llm",
            "estimated_tokens": 10000,  # 1万Token
            "call_frequency": 100,  # 调用100次
            "thinking_mode_ratio": 0,  # 无思考模式
            "batch_call_ratio": 0,  # 无Batch调用
            "pricing_variables": {
                "token_based": True,
                "input_token_price": 0.040,
                "output_token_price": 0.120
            }
        }
        
        result = self.engine.calculate(base_price, context)
        
        # 验证计算结果
        assert "final_price" in result
        # Token计费: 0.040 × 10000 × 100 = 40000元
        assert float(result["final_price"]) == 40000.0
    
    def test_llm_thinking_mode_pricing(self):
        """测试思考模式计费"""
        base_price = Decimal("0.040")
        
        context = {
            "product_type": "llm",
            "estimated_tokens": 10000,
            "call_frequency": 100,
            "thinking_mode_ratio": 1.0,  # 100%思考模式
            "batch_call_ratio": 0,
            "thinking_mode_multiplier": 1.5,  # 思考模式1.5倍价格
            "pricing_variables": {
                "token_based": True,
                "input_token_price": 0.040
            }
        }
        
        result = self.engine.calculate(base_price, context)
        
        # 思考模式价格: 40000 + 40000 * 0.5 * 1.0 = 60000元
        assert float(result["final_price"]) == 60000.0
    
    def test_llm_batch_discount(self):
        """测试Batch调用折扣"""
        base_price = Decimal("0.040")
        
        context = {
            "product_type": "llm",
            "estimated_tokens": 10000,
            "call_frequency": 100,
            "thinking_mode_ratio": 0,
            "batch_call_ratio": 1.0,  # 100% Batch调用
            "pricing_variables": {
                "token_based": True,
                "input_token_price": 0.040,
                "batch_discount": 0.5  # Batch调用半价
            }
        }
        
        result = self.engine.calculate(base_price, context)
        
        # Batch调用半价: 40000 * 0.5 = 20000元
        assert float(result["final_price"]) == 20000.0
    
    def test_standard_pricing(self):
        """测试标准计费"""
        base_price = Decimal("10.00")  # 10元/月
        
        context = {
            "product_type": "standard",
            "quantity": 10,  # 10台
            "duration_months": 12,  # 12个月
        }
        
        result = self.engine.calculate(base_price, context)
        
        # 10 × 10 × 12 = 1200元
        assert float(result["final_price"]) == 1200.0
    
    def test_pricing_with_discount_rules(self):
        """测试折扣规则应用"""
        base_price = Decimal("100.00")
        
        context = {
            "product_type": "standard",
            "quantity": 1,
            "duration": 1,
            "discount_rules": [
                {
                    "type": "tiered",
                    "tiers": [
                        {"min_amount": 0, "max_amount": 1000, "discount_rate": 1.0},
                        {"min_amount": 1000, "max_amount": 10000, "discount_rate": 0.9}
                    ]
                }
            ]
        }
        
        result = self.engine.calculate(base_price, context)
        
        # 价格100元,不满足阶梯折扣,应该是原价
        assert float(result["final_price"]) == 100.0
