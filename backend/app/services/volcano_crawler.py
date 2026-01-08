"""
火山引擎爬虫 - 爬取火山引擎产品和价格信息
"""
from typing import List, Dict, Any
from aiohttp import ClientSession
import logging
from .crawler_base import BaseCrawler, CrawlerResult

logger = logging.getLogger(__name__)


class VolcanoCrawler(BaseCrawler):
    """火山引擎爬虫"""
    
    def __init__(self):
        super().__init__(timeout=30, max_retries=3, retry_delay=2.0)
        
        # 火山引擎产品URL配置
        self.product_urls = {
            "doubao": {
                "name": "豆包大模型",
                "url": "https://www.volcengine.com/products/doubao",
                "pricing_url": "https://www.volcengine.com/docs/82379/1099320"
            },
            "ml-platform": {
                "name": "机器学习平台",
                "url": "https://www.volcengine.com/products/ml-platform",
                "pricing_url": "https://www.volcengine.com/docs/ml-platform/pricing"
            },
            "ecs-gpu": {
                "name": "GPU云服务器",
                "url": "https://www.volcengine.com/products/ecs",
                "pricing_url": "https://www.volcengine.com/docs/ecs/pricing"
            }
        }
    
    async def crawl_products(self) -> List[Dict[str, Any]]:
        """
        爬取火山引擎产品列表
        
        Returns:
            产品数据列表
        """
        result = CrawlerResult("volcano_products")
        
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
        
        logger.info(f"火山引擎产品爬取完成: {result.to_dict()}")
        return result.products
    
    async def _parse_product_page(
        self,
        html: str,
        product_code: str,
        config: Dict[str, str]
    ) -> Dict[str, Any]:
        """解析产品页面"""
        return {
            "product_code": f"volcano-{product_code}",
            "product_name": config["name"],
            "category": self._get_category_by_code(product_code),
            "vendor": "volcano",
            "description": f"{config['name']} - 火山引擎AI服务",
            "status": "active"
        }
    
    def _get_category_by_code(self, product_code: str) -> str:
        """根据产品代码获取类别"""
        category_map = {
            "doubao": "AI-大模型",
            "ml-platform": "AI-训练平台",
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
        result = CrawlerResult("volcano_prices")
        
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
        
        logger.info(f"火山引擎价格爬取完成: {result.to_dict()}")
        return result.prices
    
    async def _parse_pricing_page(
        self,
        html: str,
        product_code: str
    ) -> List[Dict[str, Any]]:
        """解析定价页面"""
        if product_code == "doubao":
            return self._get_doubao_pricing()
        elif product_code == "ml-platform":
            return self._get_ml_platform_pricing()
        elif product_code == "ecs-gpu":
            return self._get_ecs_gpu_pricing()
        else:
            return []
    
    def _get_doubao_pricing(self) -> List[Dict[str, Any]]:
        """获取豆包大模型定价(模拟数据)"""
        return [
            {
                "product_code": "volcano-doubao",
                "region": "cn-beijing",
                "spec_type": "doubao-pro",
                "billing_mode": "pay-as-you-go",
                "unit_price": "0.035",  # 输入Token单价
                "unit": "1k-input-tokens",
                "pricing_variables": {
                    "token_based": True,
                    "input_token_price": 0.035,
                    "output_token_price": 0.105,
                    "thinking_mode_multiplier": 2.0,
                    "batch_discount": 0.5
                }
            },
            {
                "product_code": "volcano-doubao",
                "region": "cn-beijing",
                "spec_type": "doubao-lite",
                "billing_mode": "pay-as-you-go",
                "unit_price": "0.005",
                "unit": "1k-input-tokens",
                "pricing_variables": {
                    "token_based": True,
                    "input_token_price": 0.005,
                    "output_token_price": 0.015,
                    "thinking_mode_multiplier": 1.0,
                    "batch_discount": 0.5
                }
            }
        ]
    
    def _get_ml_platform_pricing(self) -> List[Dict[str, Any]]:
        """获取机器学习平台定价(模拟数据)"""
        return [
            {
                "product_code": "volcano-ml-platform",
                "region": "cn-beijing",
                "spec_type": "ml.a10.1x",  # A10单卡
                "billing_mode": "pay-as-you-go",
                "unit_price": "11.00",
                "unit": "hour",
                "pricing_variables": {}
            }
        ]
    
    def _get_ecs_gpu_pricing(self) -> List[Dict[str, Any]]:
        """获取GPU云服务器定价(模拟数据)"""
        return [
            {
                "product_code": "volcano-ecs-gpu",
                "region": "cn-beijing",
                "spec_type": "ecs.gn7.8xlarge",  # A10 8卡
                "billing_mode": "subscription",
                "unit_price": "16500.00",
                "unit": "month",
                "pricing_variables": {}
            }
        ]
    
    async def crawl_all(self) -> CrawlerResult:
        """爬取所有数据"""
        result = CrawlerResult("volcano_all")
        
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
