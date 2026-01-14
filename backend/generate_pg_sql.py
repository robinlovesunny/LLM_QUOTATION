#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
阿里云百炼模型定价数据 - PostgreSQL 增强版SQL生成工具

功能增强:
- 结构化存储模式(mode)、Token阶梯(token_tier)等多维度定价信息
- 支持Batch调用、上下文缓存等特性标记
- 视频分辨率、音频时长等规格信息独立字段存储
"""

import json
import os
import re
import sys
import argparse
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, field

SOURCE_DIR = Path('/root/json3/output')

# 数据库名称
DB_NAME = 'quote_db'

CATEGORY_MAPPING = {
    '01_文本生成-通义千问': ('text_qwen', '文本生成-通义千问', 1),
    '02_文本生成-通义千问-开源版': ('text_qwen_opensource', '文本生成-通义千问-开源版', 2),
    '03_文本生成-第三方模型': ('text_thirdparty', '文本生成-第三方模型', 3),
    '04_图像生成': ('image_gen', '图像生成', 4),
    '05_图像生成-第三方模型': ('image_gen_thirdparty', '图像生成-第三方模型', 5),
    '06_语音合成（文本转语音）': ('tts', '语音合成', 6),
    '07_语音识别（语音转文本）与翻译（语音转成指定语种的文本）': ('asr', '语音识别与翻译', 7),
    '08_视频生成': ('video_gen', '视频生成', 8),
    '09_文本向量': ('text_embedding', '文本向量', 9),
    '10_多模态向量': ('multimodal_embedding', '多模态向量', 10),
    '11_文本分类、抽取、排序': ('text_nlu', '文本分类抽取排序', 11),
    '12_行业模型': ('industry', '行业模型', 12),
}


@dataclass
class ModelRecord:
    """模型记录数据类"""
    category_code: str
    model_code: str
    model_name: str
    display_name: str
    sub_category: str
    # 结构化字段
    mode: Optional[str] = None              # 模式：仅非思考模式/非思考和思考模式/仅思考模式
    token_tier: Optional[str] = None        # Token阶梯：0<Token≤32K 等
    resolution: Optional[str] = None        # 视频分辨率：720P/1080P 等
    supports_batch: bool = False            # 是否支持Batch调用半价
    supports_cache: bool = False            # 是否支持上下文缓存折扣
    remark: Optional[str] = None            # 其他备注
    # 价格信息
    prices: List[Dict] = field(default_factory=list)


def escape_sql(s: str) -> str:
    if s is None:
        return 'NULL'
    return "'" + s.replace("'", "''") + "'"


def escape_sql_bool(b: bool) -> str:
    return 'TRUE' if b else 'FALSE'


def parse_price(price_str: str) -> Tuple[Optional[float], Optional[str]]:
    if not price_str or not isinstance(price_str, str):
        return None, None
    price_str = price_str.strip()
    if '免费' in price_str or '不计费' in price_str:
        return 0.0, '免费'
    matches = re.findall(r'[\d.,]+', price_str)
    if not matches:
        return None, None
    try:
        price_value = float(matches[0].replace(',', ''))
    except ValueError:
        return None, None
    unit = '元'
    if '/' in price_str:
        unit_match = re.search(r'/([^\s]+)', price_str)
        if unit_match:
            unit = unit_match.group(1)
    return price_value, unit


def extract_model_info(raw_name: str) -> Tuple[str, bool, bool, str]:
    """
    从模型名称中提取结构化信息
    返回: (纯模型名, 是否支持Batch, 是否支持Cache, 其他备注)
    """
    if not raw_name:
        return '', False, False, ''
    
    parts = raw_name.split('|')
    model_name = parts[0].strip()
    
    supports_batch = False
    supports_cache = False
    remarks = []
    
    for part in parts[1:]:
        part = part.strip()
        if 'Batch' in part and '半价' in part:
            supports_batch = True
        elif '上下文缓存' in part and '折扣' in part:
            supports_cache = True
        elif part:
            remarks.append(part)
    
    remark = ' | '.join(remarks) if remarks else ''
    return model_name, supports_batch, supports_cache, remark


def identify_price_type(field_name: str, category_code: str) -> Tuple[str, str]:
    if '输入' in field_name and 'Token' in field_name:
        return 'input_token', '千Token'
    if '输出' in field_name and 'Token' in field_name:
        if '思维链' in field_name:
            return 'output_token_thinking', '千Token'
        return 'output_token', '千Token'
    if '输出' in field_name and '张' in field_name:
        return 'image_count', '张'
    if '输出' in field_name and '秒' in field_name:
        return 'video_second', '秒'
    if '输入' in field_name and '万字符' in field_name:
        return 'character', '万字符'
    if '输入' in field_name and '秒' in field_name:
        return 'audio_second', '秒'
    
    if category_code in ['image_gen', 'image_gen_thirdparty']:
        return 'image_count', '张'
    elif category_code == 'video_gen':
        return 'video_second', '秒'
    elif category_code == 'tts':
        return 'character', '万字符'
    elif category_code == 'asr':
        return 'audio_second', '秒'
    return 'output_price', '元'


class EnhancedPGSQLGenerator:
    """增强版PostgreSQL SQL生成器 - 支持结构化定价数据"""
    
    def __init__(self):
        self.stats = {'files': 0, 'records': 0, 'models': 0, 'prices': 0}
        self.all_models: List[ModelRecord] = []
    
    def process_all_files(self):
        """处理所有JSON文件，收集数据"""
        for category_dir in sorted(SOURCE_DIR.iterdir()):
            if not category_dir.is_dir() or category_dir.name.startswith('.'):
                continue
            if category_dir.name not in CATEGORY_MAPPING:
                continue
            
            category_code, _, _ = CATEGORY_MAPPING[category_dir.name]
            
            for json_file in sorted(category_dir.glob('*.json')):
                self.process_file(json_file, category_code)
    
    def process_file(self, filepath: Path, category_code: str):
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                data = json.load(f)
        except:
            return
        
        sub_category = data.get('sub_category', filepath.stem)
        records = data.get('data', [])
        if not records:
            return
        
        self.stats['files'] += 1
        
        for record in records:
            self.stats['records'] += 1
            raw_model_name = record.get('模型名称', '')
            if not raw_model_name:
                continue
            
            # 提取结构化信息
            model_code, supports_batch, supports_cache, remark = extract_model_info(raw_model_name)
            display_name = f"{sub_category} - {model_code}" if sub_category.lower() not in model_code.lower() else model_code
            
            # 提取模式和Token阶梯
            mode = record.get('模式')  # 如: "仅非思考模式", "非思考和思考模式"
            token_tier = record.get('单次请求的输入Token数')  # 如: "0<Token≤32K"
            resolution = record.get('输出视频分辨率')  # 如: "720P", "1080P"
            
            # 创建模型记录
            model_record = ModelRecord(
                category_code=category_code,
                model_code=model_code,
                model_name=model_code,
                display_name=display_name,
                sub_category=sub_category,
                mode=mode,
                token_tier=token_tier,
                resolution=resolution,
                supports_batch=supports_batch,
                supports_cache=supports_cache,
                remark=remark if remark else None
            )
            
            # 处理价格
            for field_name, field_value in record.items():
                if field_name == '模型名称' or '免费额度' in field_name:
                    continue
                if field_name in ['模式', '单次请求的输入Token数', '输出视频分辨率']:
                    continue
                
                price_value, unit = parse_price(field_value)
                if price_value is None:
                    continue
                
                dim_code, default_unit = identify_price_type(field_name, category_code)
                final_unit = unit if unit and unit != '免费' else default_unit
                
                model_record.prices.append({
                    'dim_code': dim_code,
                    'price': price_value,
                    'unit': final_unit
                })
                self.stats['prices'] += 1
            
            self.all_models.append(model_record)
            self.stats['models'] += 1
    
    def generate_sql(self) -> str:
        now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        sqls = [f"""-- =====================================================
-- 阿里云百炼模型定价数据同步SQL (PostgreSQL 增强版)
-- 生成时间: {now}
-- 模型数量: {self.stats['models']}
-- 价格记录: {self.stats['prices']}
-- 版本: v3.0 - 支持结构化多维度定价
-- =====================================================

SET client_encoding = 'UTF8';

-- =====================================================
-- 1. 创建/更新表结构（增强版）
-- =====================================================

CREATE TABLE IF NOT EXISTS pricing_snapshot (
    id SERIAL PRIMARY KEY,
    source_url TEXT NOT NULL,
    captured_at TIMESTAMP NOT NULL DEFAULT NOW(),
    status VARCHAR(20) NOT NULL DEFAULT 'success',
    parser_version VARCHAR(20) NOT NULL DEFAULT 'v3.0',
    raw_content_path TEXT,
    is_latest BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pricing_category (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    parent_code VARCHAR(50),
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pricing_dimension (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    default_unit VARCHAR(50) NOT NULL,
    value_type VARCHAR(20) NOT NULL DEFAULT 'float',
    description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- 增强版模型表：添加结构化字段
CREATE TABLE IF NOT EXISTS pricing_model (
    id SERIAL PRIMARY KEY,
    snapshot_id INTEGER REFERENCES pricing_snapshot(id),
    category_id INTEGER REFERENCES pricing_category(id),
    model_code VARCHAR(100),
    model_name VARCHAR(200) NOT NULL,
    display_name VARCHAR(200) NOT NULL,
    sub_category VARCHAR(100),
    -- 增强字段
    mode VARCHAR(50),                          -- 模式：仅非思考模式/非思考和思考模式/仅思考模式
    token_tier VARCHAR(50),                    -- Token阶梯：0<Token≤32K 等
    resolution VARCHAR(20),                    -- 视频分辨率：720P/1080P 等
    supports_batch BOOLEAN DEFAULT FALSE,      -- 是否支持Batch调用半价
    supports_cache BOOLEAN DEFAULT FALSE,      -- 是否支持上下文缓存折扣
    remark TEXT,                               -- 其他备注
    -- 原有字段
    rule_text TEXT,                            -- 兼容旧版：完整规则文本
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- 增强版价格表：添加mode和token_tier用于精确查询
CREATE TABLE IF NOT EXISTS pricing_model_price (
    id SERIAL PRIMARY KEY,
    snapshot_id INTEGER REFERENCES pricing_snapshot(id),
    model_id INTEGER REFERENCES pricing_model(id),
    dimension_code VARCHAR(50) REFERENCES pricing_dimension(code),
    unit_price DECIMAL(15,6) NOT NULL,
    currency VARCHAR(10) DEFAULT 'CNY',
    unit VARCHAR(50) NOT NULL,
    -- 增强字段（冗余存储，便于直接查询）
    mode VARCHAR(50),                          -- 模式
    token_tier VARCHAR(50),                    -- Token阶梯
    resolution VARCHAR(20),                    -- 分辨率
    rule_text TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- 添加新字段（如果表已存在）
DO $$
BEGIN
    -- pricing_model 新字段
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='pricing_model' AND column_name='mode') THEN
        ALTER TABLE pricing_model ADD COLUMN mode VARCHAR(50);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='pricing_model' AND column_name='token_tier') THEN
        ALTER TABLE pricing_model ADD COLUMN token_tier VARCHAR(50);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='pricing_model' AND column_name='resolution') THEN
        ALTER TABLE pricing_model ADD COLUMN resolution VARCHAR(20);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='pricing_model' AND column_name='supports_batch') THEN
        ALTER TABLE pricing_model ADD COLUMN supports_batch BOOLEAN DEFAULT FALSE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='pricing_model' AND column_name='supports_cache') THEN
        ALTER TABLE pricing_model ADD COLUMN supports_cache BOOLEAN DEFAULT FALSE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='pricing_model' AND column_name='sub_category') THEN
        ALTER TABLE pricing_model ADD COLUMN sub_category VARCHAR(100);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='pricing_model' AND column_name='remark') THEN
        ALTER TABLE pricing_model ADD COLUMN remark TEXT;
    END IF;
    
    -- pricing_model_price 新字段
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='pricing_model_price' AND column_name='mode') THEN
        ALTER TABLE pricing_model_price ADD COLUMN mode VARCHAR(50);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='pricing_model_price' AND column_name='token_tier') THEN
        ALTER TABLE pricing_model_price ADD COLUMN token_tier VARCHAR(50);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='pricing_model_price' AND column_name='resolution') THEN
        ALTER TABLE pricing_model_price ADD COLUMN resolution VARCHAR(20);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_model_snapshot ON pricing_model(snapshot_id);
CREATE INDEX IF NOT EXISTS idx_model_category ON pricing_model(category_id);
CREATE INDEX IF NOT EXISTS idx_model_code ON pricing_model(model_code);
CREATE INDEX IF NOT EXISTS idx_model_mode ON pricing_model(mode);
CREATE INDEX IF NOT EXISTS idx_model_token_tier ON pricing_model(token_tier);
CREATE INDEX IF NOT EXISTS idx_price_model ON pricing_model_price(model_id);
CREATE INDEX IF NOT EXISTS idx_price_snapshot ON pricing_model_price(snapshot_id);
CREATE INDEX IF NOT EXISTS idx_price_mode ON pricing_model_price(mode);
CREATE INDEX IF NOT EXISTS idx_price_token_tier ON pricing_model_price(token_tier);

-- =====================================================
-- 2. 插入基础数据
-- =====================================================

-- 类目数据
"""]
        
        # 类目数据
        for dir_name, (code, name, sort_order) in CATEGORY_MAPPING.items():
            sqls.append(f"INSERT INTO pricing_category (code, name, sort_order) VALUES ({escape_sql(code)}, {escape_sql(name)}, {sort_order}) ON CONFLICT (code) DO NOTHING;")
        
        # 维度数据
        sqls.append("\n-- 维度数据")
        dimensions = [
            ('input_token', '输入Token', '千Token'),
            ('output_token', '输出Token', '千Token'),
            ('output_token_thinking', '输出Token(思维链)', '千Token'),
            ('input_token_audio', '输入Token(音频)', '千Token'),
            ('input_token_image', '输入Token(图片)', '千Token'),
            ('image_count', '图片数量', '张'),
            ('video_second', '视频时长', '秒'),
            ('audio_second', '音频时长', '秒'),
            ('character', '字符数', '万字符'),
            ('output_price', '输出价格', '元'),
            ('input_price', '输入价格', '元'),
        ]
        for code, name, unit in dimensions:
            sqls.append(f"INSERT INTO pricing_dimension (code, name, default_unit) VALUES ({escape_sql(code)}, {escape_sql(name)}, {escape_sql(unit)}) ON CONFLICT (code) DO NOTHING;")
        
        # 创建快照
        sqls.append("""
-- =====================================================
-- 3. 创建快照并导入数据
-- =====================================================

-- 旧快照标记为非最新
UPDATE pricing_snapshot SET is_latest = FALSE WHERE is_latest = TRUE;

-- 创建新快照
INSERT INTO pricing_snapshot (source_url, status, parser_version, raw_content_path, is_latest)
VALUES ('file:///root/json3/output', 'success', 'v3.0.0', '/root/json3/output', TRUE);

-- 开始导入模型数据
DO $$
DECLARE
    v_snapshot_id INTEGER;
    v_category_id INTEGER;
    v_model_id INTEGER;
BEGIN
    -- 获取快照ID
    SELECT id INTO v_snapshot_id FROM pricing_snapshot WHERE is_latest = TRUE ORDER BY id DESC LIMIT 1;
    RAISE NOTICE '快照ID: %', v_snapshot_id;
""")
        
        # 生成模型和价格插入
        current_category = None
        
        for model in self.all_models:
            if model.category_code != current_category:
                current_category = model.category_code
                sqls.append(f"\n    -- 分类: {current_category}")
                sqls.append(f"    SELECT id INTO v_category_id FROM pricing_category WHERE code = {escape_sql(current_category)};")
            
            # 生成rule_text用于兼容
            rule_parts = []
            if model.mode:
                rule_parts.append(f"模式:{model.mode}")
            if model.token_tier:
                rule_parts.append(f"Token范围:{model.token_tier}")
            if model.resolution:
                rule_parts.append(f"分辨率:{model.resolution}")
            if model.supports_batch:
                rule_parts.append("Batch调用半价")
            if model.supports_cache:
                rule_parts.append("上下文缓存折扣")
            if model.remark:
                rule_parts.append(f"备注:{model.remark}")
            rule_text = ' | '.join(rule_parts) if rule_parts else None
            
            # 插入模型（增强版字段）
            sqls.append(f"""
    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, {escape_sql(model.model_code)}, {escape_sql(model.model_name)}, 
        {escape_sql(model.display_name)}, {escape_sql(model.sub_category)},
        {escape_sql(model.mode)}, {escape_sql(model.token_tier)}, {escape_sql(model.resolution)},
        {escape_sql_bool(model.supports_batch)}, {escape_sql_bool(model.supports_cache)},
        {escape_sql(model.remark)}, {escape_sql(rule_text)}
    ) RETURNING id INTO v_model_id;""")
            
            # 插入价格（包含冗余的mode/token_tier/resolution便于查询）
            for price_info in model.prices:
                sqls.append(f"""    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, {escape_sql(price_info['dim_code'])}, {price_info['price']}, 
        {escape_sql(price_info['unit'])}, {escape_sql(model.mode)}, {escape_sql(model.token_tier)}, 
        {escape_sql(model.resolution)}, {escape_sql(rule_text)}
    );""")
        
        sqls.append("""
    RAISE NOTICE '数据导入完成';
END $$;

-- =====================================================
-- 4. 验证结果
-- =====================================================

SELECT 
    '导入统计' AS "类型",
    (SELECT COUNT(*) FROM pricing_model WHERE snapshot_id = (SELECT id FROM pricing_snapshot WHERE is_latest = TRUE)) AS "模型数",
    (SELECT COUNT(*) FROM pricing_model_price WHERE snapshot_id = (SELECT id FROM pricing_snapshot WHERE is_latest = TRUE)) AS "价格数";

-- 按分类统计
SELECT 
    pc.name AS "分类",
    COUNT(pm.id) AS "模型数",
    COUNT(DISTINCT pm.mode) AS "模式数",
    COUNT(DISTINCT pm.token_tier) AS "阶梯数"
FROM pricing_category pc
LEFT JOIN pricing_model pm ON pm.category_id = pc.id 
    AND pm.snapshot_id = (SELECT id FROM pricing_snapshot WHERE is_latest = TRUE)
GROUP BY pc.id, pc.name, pc.sort_order
ORDER BY pc.sort_order;

-- 显示qwen3-max模型的详细定价（验证阶梯计费）
SELECT 
    pm.model_code,
    pm.mode,
    pm.token_tier,
    pm.supports_batch,
    pm.supports_cache,
    pmp.dimension_code,
    pmp.unit_price,
    pmp.unit
FROM pricing_model pm
JOIN pricing_model_price pmp ON pm.id = pmp.model_id
WHERE pm.model_code LIKE 'qwen3-max%'
    AND pm.snapshot_id = (SELECT id FROM pricing_snapshot WHERE is_latest = TRUE)
ORDER BY pm.model_code, pm.token_tier, pmp.dimension_code;
""")
        
        return '\n'.join(sqls)
    
    def print_stats(self):
        # 统计各维度数据
        modes = set(m.mode for m in self.all_models if m.mode)
        tiers = set(m.token_tier for m in self.all_models if m.token_tier)
        resolutions = set(m.resolution for m in self.all_models if m.resolution)
        batch_count = sum(1 for m in self.all_models if m.supports_batch)
        cache_count = sum(1 for m in self.all_models if m.supports_cache)
        
        print(f"""
统计:
- 处理文件: {self.stats['files']}
- 数据记录: {self.stats['records']}  
- 生成模型: {self.stats['models']}
- 生成价格: {self.stats['prices']}

多维度定价信息:
- 模式类型: {len(modes)} 种 ({', '.join(sorted(modes)) if modes else '无'})
- Token阶梯: {len(tiers)} 种
- 视频分辨率: {len(resolutions)} 种 ({', '.join(sorted(resolutions)) if resolutions else '无'})
- 支持Batch调用: {batch_count} 个模型
- 支持上下文缓存: {cache_count} 个模型
""")


def main():
    parser = argparse.ArgumentParser(description='生成PostgreSQL同步SQL（增强版）')
    parser.add_argument('--output', '-o', default='sync_pricing_pg.sql', help='输出文件')
    args = parser.parse_args()
    
    print("=" * 60)
    print("阿里云百炼模型定价 - PostgreSQL SQL生成（增强版 v3.0）")
    print("支持: 模式区分 | Token阶梯 | Batch调用 | 上下文缓存")
    print("=" * 60)
    
    if not SOURCE_DIR.exists():
        print(f"错误: 目录不存在 {SOURCE_DIR}")
        return 1
    
    gen = EnhancedPGSQLGenerator()
    gen.process_all_files()
    
    sql = gen.generate_sql()
    
    output_path = Path(args.output)
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(sql)
    
    gen.print_stats()
    print(f"✓ 文件已生成: {output_path}")
    print(f"  大小: {output_path.stat().st_size / 1024:.1f} KB")
    print(f"\n执行命令:")
    print(f"  psql -U postgres -d quote_db -f {output_path}")
    
    return 0


if __name__ == '__main__':
    sys.exit(main())
