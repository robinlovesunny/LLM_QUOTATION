"""
阿里云产品爬虫 - 爬取阿里云官网产品和价格信息
"""
from typing import List, Dict, Any
from aiohttp import ClientSession
import logging
import json
import re
from .crawler_base import BaseCrawler, CrawlerResult

logger = logging.getLogger(__name__)


class AliyunCrawler(BaseCrawler):
    """阿里云产品爬虫"""
    
    def __init__(self):
        super().__init__(timeout=30, max_retries=3, retry_delay=2.0)
        
        # 阿里云大模型产品URL配置
        self.product_urls = {
            "bailian": {
                "name": "百炼大模型服务",
                "url": "https://bailian.console.aliyun.com/",
                "pricing_url": "https://help.aliyun.com/zh/model-studio/product-overview/billing"
            },
            "pai-dlc": {
                "name": "PAI-DLC深度学习容器",
                "url": "https://www.aliyun.com/product/bigdata/learn",
                "pricing_url": "https://help.aliyun.com/zh/pai/product-overview/billing-of-dlc"
            },
            "ecs-gpu": {
                "name": "ECS GPU计算型实例",
                "url": "https://www.aliyun.com/product/ecs",
                "pricing_url": "https://www.aliyun.com/price/product"
            }
        }
    
    async def crawl_products(self) -> List[Dict[str, Any]]:
        """
        爬取阿里云产品列表
        
        Returns:
            产品数据列表
        """
        result = CrawlerResult("aliyun_products")
        
        try:
            async with ClientSession() as session:
                for product_code, config in self.product_urls.items():
                    try:
                        # 爬取产品页面
                        html = await self.fetch(session, config["url"])
                        if not html:
                            result.add_error(f"无法获取产品页面: {product_code}")
                            continue
                        
                        # 解析产品信息
                        product = await self._parse_product_page(
                            html,
                            product_code,
                            config
                        )
                        
                        if self.validate_product_data(product):
                            result.add_product(product)
                        else:
                            result.add_error(f"产品数据验证失败: {product_code}")
                        
                    except Exception as e:
                        result.add_error(f"爬取产品失败 {product_code}: {str(e)}")
        
        except Exception as e:
            result.add_error(f"爬虫任务失败: {str(e)}")
        
        finally:
            result.finish()
        
        logger.info(f"阿里云产品爬取完成: {result.to_dict()}")
        return result.products
    
    async def _parse_product_page(
        self,
        html: str,
        product_code: str,
        config: Dict[str, str]
    ) -> Dict[str, Any]:
        """
        解析产品页面
        
        Args:
            html: 页面HTML
            product_code: 产品代码
            config: 产品配置
        
        Returns:
            产品数据
        """
        # 由于实际页面结构复杂,这里提供一个基础模板
        # 实际使用时需要根据真实页面结构调整解析逻辑
        
        return {
            "product_code": product_code,
            "product_name": config["name"],
            "category": self._get_category_by_code(product_code),
            "vendor": "aliyun",
            "description": f"{config['name']} - 阿里云AI大模型服务",
            "status": "active"
        }
    
    def _get_category_by_code(self, product_code: str) -> str:
        """根据产品代码获取类别"""
        category_map = {
            "bailian": "AI-大模型",
            "pai-dlc": "AI-训练平台",
            "ecs-gpu": "计算-GPU实例"
        }
        return category_map.get(product_code, "其他")
    
    async def crawl_prices(self, product_code: str) -> List[Dict[str, Any]]:
        """
        爬取产品价格
        
        Args:
            product_code: 产品代码
        
        Returns:
            价格数据列表
        """
        result = CrawlerResult("aliyun_prices")
        
        try:
            config = self.product_urls.get(product_code)
            if not config:
                result.add_error(f"未知的产品代码: {product_code}")
                result.finish()
                return result.prices
            
            async with ClientSession() as session:
                # 爬取定价页面
                html = await self.fetch(session, config["pricing_url"])
                if not html:
                    result.add_error(f"无法获取定价页面: {product_code}")
                    result.finish()
                    return result.prices
                
                # 解析价格信息
                prices = await self._parse_pricing_page(html, product_code)
                
                for price in prices:
                    if self.validate_price_data(price):
                        result.add_price(price)
                    else:
                        result.add_error(f"价格数据验证失败: {product_code}")
        
        except Exception as e:
            result.add_error(f"爬取价格失败 {product_code}: {str(e)}")
        
        finally:
            result.finish()
        
        logger.info(f"阿里云价格爬取完成: {result.to_dict()}")
        return result.prices
    
    async def _parse_pricing_page(
        self,
        html: str,
        product_code: str
    ) -> List[Dict[str, Any]]:
        """
        解析定价页面
        
        Args:
            html: 页面HTML
            product_code: 产品代码
        
        Returns:
            价格数据列表
        """
        # 由于实际定价页面结构复杂,这里提供模拟数据
        # 实际使用时需要根据真实页面结构调整解析逻辑
        
        if product_code == "bailian":
            # 百炼大模型定价
            return self._get_bailian_pricing()
        elif product_code == "pai-dlc":
            # PAI-DLC定价
            return self._get_pai_dlc_pricing()
        elif product_code == "ecs-gpu":
            # GPU实例定价
            return self._get_ecs_gpu_pricing()
        else:
            return []
    
    def _get_bailian_pricing(self) -> List[Dict[str, Any]]:
        """获取百炼大模型定价(模拟数据)"""
        # 参考: https://bailian.console.aliyun.com/
        return [
            {
                "product_code": "bailian",
                "region": "cn-hangzhou",
                "spec_type": "qwen-max",
                "billing_mode": "pay-as-you-go",
                "unit_price": "0.040",  # 输入Token单价(元/千Token)
                "unit": "1k-input-tokens",
                "pricing_variables": {
                    "token_based": True,
                    "input_token_price": 0.040,  # 输入Token单价
                    "output_token_price": 0.120,  # 输出Token单价
                    "thinking_mode_multiplier": 2.0,  # 思考模式系数
                    "batch_discount": 0.5  # Batch调用折扣
                }
            },
            {
                "product_code": "bailian",
                "region": "cn-hangzhou",
                "spec_type": "qwen-plus",
                "billing_mode": "pay-as-you-go",
                "unit_price": "0.008",
                "unit": "1k-input-tokens",
                "pricing_variables": {
                    "token_based": True,
                    "input_token_price": 0.008,
                    "output_token_price": 0.024,
                    "thinking_mode_multiplier": 2.0,
                    "batch_discount": 0.5
                }
            },
            {
                "product_code": "bailian",
                "region": "cn-hangzhou",
                "spec_type": "qwen-turbo",
                "billing_mode": "pay-as-you-go",
                "unit_price": "0.003",
                "unit": "1k-input-tokens",
                "pricing_variables": {
                    "token_based": True,
                    "input_token_price": 0.003,
                    "output_token_price": 0.006,
                    "thinking_mode_multiplier": 1.0,  # Turbo无思考模式
                    "batch_discount": 0.5
                }
            }
        ]
    
    def _get_pai_dlc_pricing(self) -> List[Dict[str, Any]]:
        """获取PAI-DLC定价(模拟数据)"""
        return [
            {
                "product_code": "pai-dlc",
                "region": "cn-hangzhou",
                "spec_type": "ecs.gn7i-c16g1.4xlarge",  # A10单卡
                "billing_mode": "pay-as-you-go",
                "unit_price": "12.50",  # 元/小时
                "unit": "hour",
                "pricing_variables": {}
            },
            {
                "product_code": "pai-dlc",
                "region": "cn-hangzhou",
                "spec_type": "ecs.gn7i-c32g1.8xlarge",  # A10双卡
                "billing_mode": "pay-as-you-go",
                "unit_price": "25.00",
                "unit": "hour",
                "pricing_variables": {}
            }
        ]
    
    def _get_ecs_gpu_pricing(self) -> List[Dict[str, Any]]:
        """获取ECS GPU实例定价(模拟数据)"""
        return [
            {
                "product_code": "ecs-gpu",
                "region": "cn-hangzhou",
                "spec_type": "ecs.gn7i.24xlarge",  # A10 8卡
                "billing_mode": "subscription",
                "unit_price": "18000.00",  # 元/月
                "unit": "month",
                "pricing_variables": {}
            },
            {
                "product_code": "ecs-gpu",
                "region": "cn-beijing",
                "spec_type": "ecs.gn7i.24xlarge",
                "billing_mode": "subscription",
                "unit_price": "18500.00",
                "unit": "month",
                "pricing_variables": {}
            }
        ]
    
    async def crawl_all(self) -> CrawlerResult:
        """
        爬取所有数据(产品+价格)
        
        Returns:
            爬虫结果
        """
        result = CrawlerResult("aliyun_all")
        
        try:
            # 1. 爬取产品列表
            products = await self.crawl_products()
            result.products.extend(products)
            
            # 2. 爬取每个产品的价格
            for product_code in self.product_urls.keys():
                prices = await self.crawl_prices(product_code)
                result.prices.extend(prices)
        
        except Exception as e:
            result.add_error(f"爬取失败: {str(e)}")
        
        finally:
            result.finish()
        
        return result
