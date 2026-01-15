-- =====================================================
-- 阿里云百炼模型定价数据同步SQL (PostgreSQL 增强版)
-- 生成时间: 2026-01-14 20:01:09
-- 模型数量: 446
-- 价格记录: 750
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

INSERT INTO pricing_category (code, name, sort_order) VALUES ('text_qwen', '文本生成-通义千问', 1) ON CONFLICT (code) DO NOTHING;
INSERT INTO pricing_category (code, name, sort_order) VALUES ('text_qwen_opensource', '文本生成-通义千问-开源版', 2) ON CONFLICT (code) DO NOTHING;
INSERT INTO pricing_category (code, name, sort_order) VALUES ('text_thirdparty', '文本生成-第三方模型', 3) ON CONFLICT (code) DO NOTHING;
INSERT INTO pricing_category (code, name, sort_order) VALUES ('image_gen', '图像生成', 4) ON CONFLICT (code) DO NOTHING;
INSERT INTO pricing_category (code, name, sort_order) VALUES ('image_gen_thirdparty', '图像生成-第三方模型', 5) ON CONFLICT (code) DO NOTHING;
INSERT INTO pricing_category (code, name, sort_order) VALUES ('tts', '语音合成', 6) ON CONFLICT (code) DO NOTHING;
INSERT INTO pricing_category (code, name, sort_order) VALUES ('asr', '语音识别与翻译', 7) ON CONFLICT (code) DO NOTHING;
INSERT INTO pricing_category (code, name, sort_order) VALUES ('video_gen', '视频生成', 8) ON CONFLICT (code) DO NOTHING;
INSERT INTO pricing_category (code, name, sort_order) VALUES ('text_embedding', '文本向量', 9) ON CONFLICT (code) DO NOTHING;
INSERT INTO pricing_category (code, name, sort_order) VALUES ('multimodal_embedding', '多模态向量', 10) ON CONFLICT (code) DO NOTHING;
INSERT INTO pricing_category (code, name, sort_order) VALUES ('text_nlu', '文本分类抽取排序', 11) ON CONFLICT (code) DO NOTHING;
INSERT INTO pricing_category (code, name, sort_order) VALUES ('industry', '行业模型', 12) ON CONFLICT (code) DO NOTHING;

-- 维度数据
INSERT INTO pricing_dimension (code, name, default_unit) VALUES ('input_token', '输入Token', '千Token') ON CONFLICT (code) DO NOTHING;
INSERT INTO pricing_dimension (code, name, default_unit) VALUES ('output_token', '输出Token', '千Token') ON CONFLICT (code) DO NOTHING;
INSERT INTO pricing_dimension (code, name, default_unit) VALUES ('output_token_thinking', '输出Token(思维链)', '千Token') ON CONFLICT (code) DO NOTHING;
INSERT INTO pricing_dimension (code, name, default_unit) VALUES ('input_token_audio', '输入Token(音频)', '千Token') ON CONFLICT (code) DO NOTHING;
INSERT INTO pricing_dimension (code, name, default_unit) VALUES ('input_token_image', '输入Token(图片)', '千Token') ON CONFLICT (code) DO NOTHING;
INSERT INTO pricing_dimension (code, name, default_unit) VALUES ('image_count', '图片数量', '张') ON CONFLICT (code) DO NOTHING;
INSERT INTO pricing_dimension (code, name, default_unit) VALUES ('video_second', '视频时长', '秒') ON CONFLICT (code) DO NOTHING;
INSERT INTO pricing_dimension (code, name, default_unit) VALUES ('audio_second', '音频时长', '秒') ON CONFLICT (code) DO NOTHING;
INSERT INTO pricing_dimension (code, name, default_unit) VALUES ('character', '字符数', '万字符') ON CONFLICT (code) DO NOTHING;
INSERT INTO pricing_dimension (code, name, default_unit) VALUES ('output_price', '输出价格', '元') ON CONFLICT (code) DO NOTHING;
INSERT INTO pricing_dimension (code, name, default_unit) VALUES ('input_price', '输入价格', '元') ON CONFLICT (code) DO NOTHING;

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


    -- 分类: text_qwen
    SELECT id INTO v_category_id FROM pricing_category WHERE code = 'text_qwen';

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qvq-max', 'qvq-max', 
        'qvq-max', 'QVQ',
        '思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.008, 
        '元', '思考模式', NULL, 
        NULL, '模式:思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.032, 
        '元', '思考模式', NULL, 
        NULL, '模式:思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qvq-max-latest', 'qvq-max-latest', 
        'qvq-max-latest', 'QVQ',
        '思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.008, 
        '元', '思考模式', NULL, 
        NULL, '模式:思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.032, 
        '元', '思考模式', NULL, 
        NULL, '模式:思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qvq-max-2025-05-15', 'qvq-max-2025-05-15', 
        'qvq-max-2025-05-15', 'QVQ',
        '思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.008, 
        '元', '思考模式', NULL, 
        NULL, '模式:思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.032, 
        '元', '思考模式', NULL, 
        NULL, '模式:思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qvq-max-2025-03-25', 'qvq-max-2025-03-25', 
        'qvq-max-2025-03-25', 'QVQ',
        '思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.008, 
        '元', '思考模式', NULL, 
        NULL, '模式:思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.032, 
        '元', '思考模式', NULL, 
        NULL, '模式:思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qvq-plus', 'qvq-plus', 
        'qvq-plus', 'QVQ',
        '思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.002, 
        '元', '思考模式', NULL, 
        NULL, '模式:思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.005, 
        '元', '思考模式', NULL, 
        NULL, '模式:思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qvq-plus-latest', 'qvq-plus-latest', 
        'qvq-plus-latest', 'QVQ',
        '思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.002, 
        '元', '思考模式', NULL, 
        NULL, '模式:思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.005, 
        '元', '思考模式', NULL, 
        NULL, '模式:思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qvq-plus-2025-05-15', 'qvq-plus-2025-05-15', 
        'qvq-plus-2025-05-15', 'QVQ',
        '思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.002, 
        '元', '思考模式', NULL, 
        NULL, '模式:思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.005, 
        '元', '思考模式', NULL, 
        NULL, '模式:思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwq-plus', 'qwq-plus', 
        'qwq-plus', 'QwQ',
        '仅思考模式', NULL, NULL,
        TRUE, FALSE,
        NULL, '模式:仅思考模式 | Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0016, 
        '元', '仅思考模式', NULL, 
        NULL, '模式:仅思考模式 | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.004, 
        '元', '仅思考模式', NULL, 
        NULL, '模式:仅思考模式 | Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwq-plus-latest', 'qwq-plus-latest', 
        'qwq-plus-latest', 'QwQ',
        '仅思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0016, 
        '元', '仅思考模式', NULL, 
        NULL, '模式:仅思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.004, 
        '元', '仅思考模式', NULL, 
        NULL, '模式:仅思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwq-plus-2025-03-05', 'qwq-plus-2025-03-05', 
        'qwq-plus-2025-03-05', 'QwQ',
        '仅思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0016, 
        '元', '仅思考模式', NULL, 
        NULL, '模式:仅思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.004, 
        '元', '仅思考模式', NULL, 
        NULL, '模式:仅思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-audio-turbo', 'qwen-audio-turbo', 
        '通义千问Audio - qwen-audio-turbo', '通义千问Audio',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-audio-turbo-latest', 'qwen-audio-turbo-latest', 
        '通义千问Audio - qwen-audio-turbo-latest', '通义千问Audio',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-audio-turbo-2024-12-04', 'qwen-audio-turbo-2024-12-04', 
        '通义千问Audio - qwen-audio-turbo-2024-12-04', '通义千问Audio',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-audio-turbo-2024-08-07', 'qwen-audio-turbo-2024-08-07', 
        '通义千问Audio - qwen-audio-turbo-2024-08-07', '通义千问Audio',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-coder-plus', 'qwen3-coder-plus', 
        '通义千问Coder - qwen3-coder-plus', '通义千问Coder',
        '仅非思考模式', '0<Token≤32K', NULL,
        FALSE, TRUE,
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤32K | 上下文缓存折扣'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.004, 
        '元', '仅非思考模式', '0<Token≤32K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤32K | 上下文缓存折扣'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.016, 
        '元', '仅非思考模式', '0<Token≤32K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤32K | 上下文缓存折扣'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-coder-plus', 'qwen3-coder-plus', 
        '通义千问Coder - qwen3-coder-plus', '通义千问Coder',
        '仅非思考模式', '32K<Token≤128K', NULL,
        FALSE, TRUE,
        NULL, '模式:仅非思考模式 | Token范围:32K<Token≤128K | 上下文缓存折扣'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.006, 
        '元', '仅非思考模式', '32K<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:32K<Token≤128K | 上下文缓存折扣'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.024, 
        '元', '仅非思考模式', '32K<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:32K<Token≤128K | 上下文缓存折扣'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-coder-plus', 'qwen3-coder-plus', 
        '通义千问Coder - qwen3-coder-plus', '通义千问Coder',
        '仅非思考模式', '128K<Token≤256K', NULL,
        FALSE, TRUE,
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K | 上下文缓存折扣'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.01, 
        '元', '仅非思考模式', '128K<Token≤256K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K | 上下文缓存折扣'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.04, 
        '元', '仅非思考模式', '128K<Token≤256K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K | 上下文缓存折扣'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-coder-plus', 'qwen3-coder-plus', 
        '通义千问Coder - qwen3-coder-plus', '通义千问Coder',
        '仅非思考模式', '256K<Token≤1M', NULL,
        FALSE, TRUE,
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M | 上下文缓存折扣'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.02, 
        '元', '仅非思考模式', '256K<Token≤1M', 
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M | 上下文缓存折扣'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.2, 
        '元', '仅非思考模式', '256K<Token≤1M', 
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M | 上下文缓存折扣'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-coder-plus-2025-09-23', 'qwen3-coder-plus-2025-09-23', 
        '通义千问Coder - qwen3-coder-plus-2025-09-23', '通义千问Coder',
        '仅非思考模式', '0<Token≤32K', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤32K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.004, 
        '元', '仅非思考模式', '0<Token≤32K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤32K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.016, 
        '元', '仅非思考模式', '0<Token≤32K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤32K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-coder-plus-2025-09-23', 'qwen3-coder-plus-2025-09-23', 
        '通义千问Coder - qwen3-coder-plus-2025-09-23', '通义千问Coder',
        '仅非思考模式', '32K<Token≤128K', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:32K<Token≤128K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.006, 
        '元', '仅非思考模式', '32K<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:32K<Token≤128K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.024, 
        '元', '仅非思考模式', '32K<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:32K<Token≤128K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-coder-plus-2025-09-23', 'qwen3-coder-plus-2025-09-23', 
        '通义千问Coder - qwen3-coder-plus-2025-09-23', '通义千问Coder',
        '仅非思考模式', '128K<Token≤256K', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.01, 
        '元', '仅非思考模式', '128K<Token≤256K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.04, 
        '元', '仅非思考模式', '128K<Token≤256K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-coder-plus-2025-09-23', 'qwen3-coder-plus-2025-09-23', 
        '通义千问Coder - qwen3-coder-plus-2025-09-23', '通义千问Coder',
        '仅非思考模式', '256K<Token≤1M', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.02, 
        '元', '仅非思考模式', '256K<Token≤1M', 
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.2, 
        '元', '仅非思考模式', '256K<Token≤1M', 
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-coder-plus-2025-07-22', 'qwen3-coder-plus-2025-07-22', 
        '通义千问Coder - qwen3-coder-plus-2025-07-22', '通义千问Coder',
        '仅非思考模式', '0<Token≤32K', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤32K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.004, 
        '元', '仅非思考模式', '0<Token≤32K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤32K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.016, 
        '元', '仅非思考模式', '0<Token≤32K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤32K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-coder-plus-2025-07-22', 'qwen3-coder-plus-2025-07-22', 
        '通义千问Coder - qwen3-coder-plus-2025-07-22', '通义千问Coder',
        '仅非思考模式', '32K<Token≤128K', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:32K<Token≤128K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.006, 
        '元', '仅非思考模式', '32K<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:32K<Token≤128K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.024, 
        '元', '仅非思考模式', '32K<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:32K<Token≤128K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-coder-plus-2025-07-22', 'qwen3-coder-plus-2025-07-22', 
        '通义千问Coder - qwen3-coder-plus-2025-07-22', '通义千问Coder',
        '仅非思考模式', '128K<Token≤256K', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.01, 
        '元', '仅非思考模式', '128K<Token≤256K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.04, 
        '元', '仅非思考模式', '128K<Token≤256K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-coder-plus-2025-07-22', 'qwen3-coder-plus-2025-07-22', 
        '通义千问Coder - qwen3-coder-plus-2025-07-22', '通义千问Coder',
        '仅非思考模式', '256K<Token≤1M', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.02, 
        '元', '仅非思考模式', '256K<Token≤1M', 
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.2, 
        '元', '仅非思考模式', '256K<Token≤1M', 
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-coder-flash', 'qwen3-coder-flash', 
        '通义千问Coder - qwen3-coder-flash', '通义千问Coder',
        '仅非思考模式', '0<Token≤32K', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤32K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.001, 
        '元', '仅非思考模式', '0<Token≤32K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤32K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.004, 
        '元', '仅非思考模式', '0<Token≤32K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤32K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-coder-flash', 'qwen3-coder-flash', 
        '通义千问Coder - qwen3-coder-flash', '通义千问Coder',
        '仅非思考模式', '32K<Token≤128K', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:32K<Token≤128K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0015, 
        '元', '仅非思考模式', '32K<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:32K<Token≤128K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.006, 
        '元', '仅非思考模式', '32K<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:32K<Token≤128K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-coder-flash', 'qwen3-coder-flash', 
        '通义千问Coder - qwen3-coder-flash', '通义千问Coder',
        '仅非思考模式', '128K<Token≤256K', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0025, 
        '元', '仅非思考模式', '128K<Token≤256K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.01, 
        '元', '仅非思考模式', '128K<Token≤256K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-coder-flash', 'qwen3-coder-flash', 
        '通义千问Coder - qwen3-coder-flash', '通义千问Coder',
        '仅非思考模式', '256K<Token≤1M', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.005, 
        '元', '仅非思考模式', '256K<Token≤1M', 
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.025, 
        '元', '仅非思考模式', '256K<Token≤1M', 
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-coder-flash-2025-07-28', 'qwen3-coder-flash-2025-07-28', 
        '通义千问Coder - qwen3-coder-flash-2025-07-28', '通义千问Coder',
        '仅非思考模式', '0<Token≤32K', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤32K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.001, 
        '元', '仅非思考模式', '0<Token≤32K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤32K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.004, 
        '元', '仅非思考模式', '0<Token≤32K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤32K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-coder-flash-2025-07-28', 'qwen3-coder-flash-2025-07-28', 
        '通义千问Coder - qwen3-coder-flash-2025-07-28', '通义千问Coder',
        '仅非思考模式', '32K<Token≤128K', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:32K<Token≤128K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0015, 
        '元', '仅非思考模式', '32K<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:32K<Token≤128K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.006, 
        '元', '仅非思考模式', '32K<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:32K<Token≤128K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-coder-flash-2025-07-28', 'qwen3-coder-flash-2025-07-28', 
        '通义千问Coder - qwen3-coder-flash-2025-07-28', '通义千问Coder',
        '仅非思考模式', '128K<Token≤256K', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0025, 
        '元', '仅非思考模式', '128K<Token≤256K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.01, 
        '元', '仅非思考模式', '128K<Token≤256K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-coder-flash-2025-07-28', 'qwen3-coder-flash-2025-07-28', 
        '通义千问Coder - qwen3-coder-flash-2025-07-28', '通义千问Coder',
        '仅非思考模式', '256K<Token≤1M', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.005, 
        '元', '仅非思考模式', '256K<Token≤1M', 
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.025, 
        '元', '仅非思考模式', '256K<Token≤1M', 
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-coder-plus', 'qwen-coder-plus', 
        '通义千问Coder - qwen-coder-plus', '通义千问Coder',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0035, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.007, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-coder-plus-latest', 'qwen-coder-plus-latest', 
        '通义千问Coder - qwen-coder-plus-latest', '通义千问Coder',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0035, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.007, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-coder-plus-2024-11-06', 'qwen-coder-plus-2024-11-06', 
        '通义千问Coder - qwen-coder-plus-2024-11-06', '通义千问Coder',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0035, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.007, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-coder-turbo', 'qwen-coder-turbo', 
        '通义千问Coder - qwen-coder-turbo', '通义千问Coder',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.002, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.006, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-coder-turbo-latest', 'qwen-coder-turbo-latest', 
        '通义千问Coder - qwen-coder-turbo-latest', '通义千问Coder',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.002, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.006, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-coder-turbo-2024-09-19', 'qwen-coder-turbo-2024-09-19', 
        '通义千问Coder - qwen-coder-turbo-2024-09-19', '通义千问Coder',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.002, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.006, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-flash', 'qwen-flash', 
        '通义千问Flash - qwen-flash', '通义千问Flash',
        '非思考和思考模式', '0<Token≤128K', NULL,
        TRUE, TRUE,
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤128K | Batch调用半价 | 上下文缓存折扣'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.00015, 
        '元', '非思考和思考模式', '0<Token≤128K', 
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤128K | Batch调用半价 | 上下文缓存折扣'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.0015, 
        '元', '非思考和思考模式', '0<Token≤128K', 
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤128K | Batch调用半价 | 上下文缓存折扣'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-flash', 'qwen-flash', 
        '通义千问Flash - qwen-flash', '通义千问Flash',
        '非思考和思考模式', '128K<Token≤256K', NULL,
        TRUE, TRUE,
        NULL, '模式:非思考和思考模式 | Token范围:128K<Token≤256K | Batch调用半价 | 上下文缓存折扣'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0006, 
        '元', '非思考和思考模式', '128K<Token≤256K', 
        NULL, '模式:非思考和思考模式 | Token范围:128K<Token≤256K | Batch调用半价 | 上下文缓存折扣'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.006, 
        '元', '非思考和思考模式', '128K<Token≤256K', 
        NULL, '模式:非思考和思考模式 | Token范围:128K<Token≤256K | Batch调用半价 | 上下文缓存折扣'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-flash', 'qwen-flash', 
        '通义千问Flash - qwen-flash', '通义千问Flash',
        '非思考和思考模式', '256K<Token≤1M', NULL,
        TRUE, TRUE,
        NULL, '模式:非思考和思考模式 | Token范围:256K<Token≤1M | Batch调用半价 | 上下文缓存折扣'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0012, 
        '元', '非思考和思考模式', '256K<Token≤1M', 
        NULL, '模式:非思考和思考模式 | Token范围:256K<Token≤1M | Batch调用半价 | 上下文缓存折扣'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.012, 
        '元', '非思考和思考模式', '256K<Token≤1M', 
        NULL, '模式:非思考和思考模式 | Token范围:256K<Token≤1M | Batch调用半价 | 上下文缓存折扣'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-flash-2025-07-28', 'qwen-flash-2025-07-28', 
        '通义千问Flash - qwen-flash-2025-07-28', '通义千问Flash',
        '非思考和思考模式', '0<Token≤128K', NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤128K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.00015, 
        '元', '非思考和思考模式', '0<Token≤128K', 
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤128K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.0015, 
        '元', '非思考和思考模式', '0<Token≤128K', 
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤128K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-flash-2025-07-28', 'qwen-flash-2025-07-28', 
        '通义千问Flash - qwen-flash-2025-07-28', '通义千问Flash',
        '非思考和思考模式', '128K<Token≤256K', NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式 | Token范围:128K<Token≤256K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0006, 
        '元', '非思考和思考模式', '128K<Token≤256K', 
        NULL, '模式:非思考和思考模式 | Token范围:128K<Token≤256K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.006, 
        '元', '非思考和思考模式', '128K<Token≤256K', 
        NULL, '模式:非思考和思考模式 | Token范围:128K<Token≤256K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-flash-2025-07-28', 'qwen-flash-2025-07-28', 
        '通义千问Flash - qwen-flash-2025-07-28', '通义千问Flash',
        '非思考和思考模式', '256K<Token≤1M', NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式 | Token范围:256K<Token≤1M'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0012, 
        '元', '非思考和思考模式', '256K<Token≤1M', 
        NULL, '模式:非思考和思考模式 | Token范围:256K<Token≤1M'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.012, 
        '元', '非思考和思考模式', '256K<Token≤1M', 
        NULL, '模式:非思考和思考模式 | Token范围:256K<Token≤1M'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-long', 'qwen-long', 
        '通义千问Long - qwen-long', '通义千问Long',
        '仅非思考模式', NULL, NULL,
        TRUE, FALSE,
        NULL, '模式:仅非思考模式 | Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0005, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式 | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.002, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式 | Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-long-latest', 'qwen-long-latest', 
        '通义千问Long - qwen-long-latest', '通义千问Long',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0005, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.002, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-long-2025-01-25', 'qwen-long-2025-01-25', 
        '通义千问Long - qwen-long-2025-01-25', '通义千问Long',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0005, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.002, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-max', 'qwen3-max', 
        '通义千问Max - qwen3-max', '通义千问Max',
        '仅非思考模式', '0<Token≤32K', NULL,
        TRUE, TRUE,
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤32K | Batch调用半价 | 上下文缓存折扣'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0032, 
        '元', '仅非思考模式', '0<Token≤32K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤32K | Batch调用半价 | 上下文缓存折扣'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.0128, 
        '元', '仅非思考模式', '0<Token≤32K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤32K | Batch调用半价 | 上下文缓存折扣'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-max', 'qwen3-max', 
        '通义千问Max - qwen3-max', '通义千问Max',
        '仅非思考模式', '32K<Token≤128K', NULL,
        TRUE, TRUE,
        NULL, '模式:仅非思考模式 | Token范围:32K<Token≤128K | Batch调用半价 | 上下文缓存折扣'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0064, 
        '元', '仅非思考模式', '32K<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:32K<Token≤128K | Batch调用半价 | 上下文缓存折扣'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.0256, 
        '元', '仅非思考模式', '32K<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:32K<Token≤128K | Batch调用半价 | 上下文缓存折扣'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-max', 'qwen3-max', 
        '通义千问Max - qwen3-max', '通义千问Max',
        '仅非思考模式', '128K<Token≤252K', NULL,
        TRUE, TRUE,
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤252K | Batch调用半价 | 上下文缓存折扣'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0096, 
        '元', '仅非思考模式', '128K<Token≤252K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤252K | Batch调用半价 | 上下文缓存折扣'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.0384, 
        '元', '仅非思考模式', '128K<Token≤252K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤252K | Batch调用半价 | 上下文缓存折扣'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-max-2025-09-23', 'qwen3-max-2025-09-23', 
        '通义千问Max - qwen3-max-2025-09-23', '通义千问Max',
        '仅非思考模式', '0<Token≤32K', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤32K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.006, 
        '元', '仅非思考模式', '0<Token≤32K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤32K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.024, 
        '元', '仅非思考模式', '0<Token≤32K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤32K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-max-2025-09-23', 'qwen3-max-2025-09-23', 
        '通义千问Max - qwen3-max-2025-09-23', '通义千问Max',
        '仅非思考模式', '32K<Token≤128K', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:32K<Token≤128K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.01, 
        '元', '仅非思考模式', '32K<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:32K<Token≤128K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.04, 
        '元', '仅非思考模式', '32K<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:32K<Token≤128K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-max-2025-09-23', 'qwen3-max-2025-09-23', 
        '通义千问Max - qwen3-max-2025-09-23', '通义千问Max',
        '仅非思考模式', '128K<Token≤252K', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤252K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.015, 
        '元', '仅非思考模式', '128K<Token≤252K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤252K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.06, 
        '元', '仅非思考模式', '128K<Token≤252K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤252K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-max-preview', 'qwen3-max-preview', 
        '通义千问Max - qwen3-max-preview', '通义千问Max',
        '非思考和思考模式', '0<Token≤32K', NULL,
        FALSE, TRUE,
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K | 上下文缓存折扣'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.006, 
        '元', '非思考和思考模式', '0<Token≤32K', 
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K | 上下文缓存折扣'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.024, 
        '元', '非思考和思考模式', '0<Token≤32K', 
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K | 上下文缓存折扣'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-max-preview', 'qwen3-max-preview', 
        '通义千问Max - qwen3-max-preview', '通义千问Max',
        '非思考和思考模式', '32K<Token≤128K', NULL,
        FALSE, TRUE,
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤128K | 上下文缓存折扣'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.01, 
        '元', '非思考和思考模式', '32K<Token≤128K', 
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤128K | 上下文缓存折扣'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.04, 
        '元', '非思考和思考模式', '32K<Token≤128K', 
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤128K | 上下文缓存折扣'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-max-preview', 'qwen3-max-preview', 
        '通义千问Max - qwen3-max-preview', '通义千问Max',
        '非思考和思考模式', '128K<Token≤252K', NULL,
        FALSE, TRUE,
        NULL, '模式:非思考和思考模式 | Token范围:128K<Token≤252K | 上下文缓存折扣'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.015, 
        '元', '非思考和思考模式', '128K<Token≤252K', 
        NULL, '模式:非思考和思考模式 | Token范围:128K<Token≤252K | 上下文缓存折扣'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.06, 
        '元', '非思考和思考模式', '128K<Token≤252K', 
        NULL, '模式:非思考和思考模式 | Token范围:128K<Token≤252K | 上下文缓存折扣'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-max', 'qwen-max', 
        '通义千问Max - qwen-max', '通义千问Max',
        '仅非思考模式', '无阶梯计价', NULL,
        TRUE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价 | Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0024, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价 | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0096, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价 | Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-max-latest', 'qwen-max-latest', 
        '通义千问Max - qwen-max-latest', '通义千问Max',
        '仅非思考模式', '无阶梯计价', NULL,
        TRUE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价 | Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0024, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价 | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0096, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价 | Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-max-2025-01-25', 'qwen-max-2025-01-25', 
        '通义千问Max - qwen-max-2025-01-25', '通义千问Max',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0024, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0096, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-max-2024-09-19', 'qwen-max-2024-09-19', 
        '通义千问Max - qwen-max-2024-09-19', '通义千问Max',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.02, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.06, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-max-2024-04-28', 'qwen-max-2024-04-28', 
        '通义千问Max - qwen-max-2024-04-28', '通义千问Max',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.04, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.12, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-max-2024-04-03', 'qwen-max-2024-04-03', 
        '通义千问Max - qwen-max-2024-04-03', '通义千问Max',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.04, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.12, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-vl-ocr', 'qwen-vl-ocr', 
        '通义千问OCR - qwen-vl-ocr', '通义千问OCR',
        '仅非思考模式', NULL, NULL,
        TRUE, FALSE,
        NULL, '模式:仅非思考模式 | Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.005, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式 | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.005, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式 | Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-vl-ocr-latest', 'qwen-vl-ocr-latest', 
        '通义千问OCR - qwen-vl-ocr-latest', '通义千问OCR',
        '仅非思考模式', NULL, NULL,
        TRUE, FALSE,
        NULL, '模式:仅非思考模式 | Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0003, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式 | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0005, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式 | Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-vl-ocr-2025-11-20', 'qwen-vl-ocr-2025-11-20', 
        '通义千问OCR - qwen-vl-ocr-2025-11-20', '通义千问OCR',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0003, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0005, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-vl-ocr-2025-08-28', 'qwen-vl-ocr-2025-08-28', 
        '通义千问OCR - qwen-vl-ocr-2025-08-28', '通义千问OCR',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.005, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.005, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-vl-ocr-2025-04-13', 'qwen-vl-ocr-2025-04-13', 
        '通义千问OCR - qwen-vl-ocr-2025-04-13', '通义千问OCR',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.005, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.005, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-vl-ocr-2024-10-28', 'qwen-vl-ocr-2024-10-28', 
        '通义千问OCR - qwen-vl-ocr-2024-10-28', '通义千问OCR',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.005, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.005, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, '模型名称', '模型名称', 
        '通义千问Omni-Realtime - 模型名称', '通义千问Omni-Realtime',
        '模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:模式'
    ) RETURNING id INTO v_model_id;

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-omni-flash-realtime', 'qwen3-omni-flash-realtime', 
        '通义千问Omni-Realtime - qwen3-omni-flash-realtime', '通义千问Omni-Realtime',
        '非思考和思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0039, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0751, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-omni-flash-realtime-2025-12-01', 'qwen3-omni-flash-realtime-2025-12-01', 
        '通义千问Omni-Realtime - qwen3-omni-flash-realtime-2025-12-01', '通义千问Omni-Realtime',
        '非思考和思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0039, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0751, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-omni-flash-realtime-2025-09-15', 'qwen3-omni-flash-realtime-2025-09-15', 
        '通义千问Omni-Realtime - qwen3-omni-flash-realtime-2025-09-15', '通义千问Omni-Realtime',
        '非思考和思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0039, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0751, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, '模型名称', '模型名称', 
        '通义千问Omni-Realtime - 模型名称', '通义千问Omni-Realtime',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-omni-turbo-realtime', 'qwen-omni-turbo-realtime', 
        '通义千问Omni-Realtime - qwen-omni-turbo-realtime', '通义千问Omni-Realtime',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.006, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.05, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-omni-turbo-realtime-latest', 'qwen-omni-turbo-realtime-latest', 
        '通义千问Omni-Realtime - qwen-omni-turbo-realtime-latest', '通义千问Omni-Realtime',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.006, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.05, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-omni-turbo-realtime-2025-05-08', 'qwen-omni-turbo-realtime-2025-05-08', 
        '通义千问Omni-Realtime - qwen-omni-turbo-realtime-2025-05-08', '通义千问Omni-Realtime',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.006, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.05, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, '模型名称', '模型名称', 
        '通义千问Omni - 模型名称', '通义千问Omni',
        '模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:模式'
    ) RETURNING id INTO v_model_id;

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-omni-flash', 'qwen3-omni-flash', 
        '通义千问Omni - qwen3-omni-flash', '通义千问Omni',
        '非思考和思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0033, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0626, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-omni-flash-2025-12-01', 'qwen3-omni-flash-2025-12-01', 
        '通义千问Omni - qwen3-omni-flash-2025-12-01', '通义千问Omni',
        '非思考和思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0033, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0626, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-omni-flash-2025-09-15', 'qwen3-omni-flash-2025-09-15', 
        '通义千问Omni - qwen3-omni-flash-2025-09-15', '通义千问Omni',
        '非思考和思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0033, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0626, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, '模型名称', '模型名称', 
        '通义千问Omni - 模型名称', '通义千问Omni',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-omni-turbo', 'qwen-omni-turbo', 
        '通义千问Omni - qwen-omni-turbo', '通义千问Omni',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0015, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.05, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-omni-turbo-latest', 'qwen-omni-turbo-latest', 
        '通义千问Omni - qwen-omni-turbo-latest', '通义千问Omni',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0015, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.05, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-omni-turbo-2025-03-26', 'qwen-omni-turbo-2025-03-26', 
        '通义千问Omni - qwen-omni-turbo-2025-03-26', '通义千问Omni',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0015, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.05, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-omni-turbo-2025-01-19', 'qwen-omni-turbo-2025-01-19', 
        '通义千问Omni - qwen-omni-turbo-2025-01-19', '通义千问Omni',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0015, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.05, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, '模型名称', '模型名称', 
        '通义千问Plus - 模型名称', '通义千问Plus',
        '仅非思考模式', '单次请求的输入Token范围', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:单次请求的输入Token范围'
    ) RETURNING id INTO v_model_id;

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-plus', 'qwen-plus', 
        '通义千问Plus - qwen-plus', '通义千问Plus',
        '仅非思考模式', '0<Token≤128K', NULL,
        TRUE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤128K | Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '元', '仅非思考模式', '0<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤128K | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0008, 
        '元', '仅非思考模式', '0<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤128K | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.008, 
        '元', '仅非思考模式', '0<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤128K | Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-plus', 'qwen-plus', 
        '通义千问Plus - qwen-plus', '通义千问Plus',
        '仅非思考模式', '128K<Token≤256K', NULL,
        TRUE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K | Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 128.0, 
        '元', '仅非思考模式', '128K<Token≤256K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0024, 
        '元', '仅非思考模式', '128K<Token≤256K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.024, 
        '元', '仅非思考模式', '128K<Token≤256K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K | Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-plus', 'qwen-plus', 
        '通义千问Plus - qwen-plus', '通义千问Plus',
        '仅非思考模式', '256K<Token≤1M', NULL,
        TRUE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M | Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 256.0, 
        '元', '仅非思考模式', '256K<Token≤1M', 
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0048, 
        '元', '仅非思考模式', '256K<Token≤1M', 
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.064, 
        '元', '仅非思考模式', '256K<Token≤1M', 
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M | Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-plus-latest', 'qwen-plus-latest', 
        '通义千问Plus - qwen-plus-latest', '通义千问Plus',
        '仅非思考模式', '0<Token≤128K', NULL,
        TRUE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤128K | Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '元', '仅非思考模式', '0<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤128K | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0008, 
        '元', '仅非思考模式', '0<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤128K | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.008, 
        '元', '仅非思考模式', '0<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤128K | Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-plus-latest', 'qwen-plus-latest', 
        '通义千问Plus - qwen-plus-latest', '通义千问Plus',
        '仅非思考模式', '128K<Token≤256K', NULL,
        TRUE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K | Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 128.0, 
        '元', '仅非思考模式', '128K<Token≤256K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0024, 
        '元', '仅非思考模式', '128K<Token≤256K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.024, 
        '元', '仅非思考模式', '128K<Token≤256K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K | Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-plus-latest', 'qwen-plus-latest', 
        '通义千问Plus - qwen-plus-latest', '通义千问Plus',
        '仅非思考模式', '256K<Token≤1M', NULL,
        TRUE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M | Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 256.0, 
        '元', '仅非思考模式', '256K<Token≤1M', 
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0048, 
        '元', '仅非思考模式', '256K<Token≤1M', 
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.064, 
        '元', '仅非思考模式', '256K<Token≤1M', 
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M | Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-plus-2025-12-01', 'qwen-plus-2025-12-01', 
        '通义千问Plus - qwen-plus-2025-12-01', '通义千问Plus',
        '仅非思考模式', '0<Token≤128K', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤128K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '元', '仅非思考模式', '0<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤128K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0008, 
        '元', '仅非思考模式', '0<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤128K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.008, 
        '元', '仅非思考模式', '0<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤128K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-plus-2025-12-01', 'qwen-plus-2025-12-01', 
        '通义千问Plus - qwen-plus-2025-12-01', '通义千问Plus',
        '仅非思考模式', '128K<Token≤256K', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 128.0, 
        '元', '仅非思考模式', '128K<Token≤256K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0024, 
        '元', '仅非思考模式', '128K<Token≤256K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.024, 
        '元', '仅非思考模式', '128K<Token≤256K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-plus-2025-12-01', 'qwen-plus-2025-12-01', 
        '通义千问Plus - qwen-plus-2025-12-01', '通义千问Plus',
        '仅非思考模式', '256K<Token≤1M', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 256.0, 
        '元', '仅非思考模式', '256K<Token≤1M', 
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0048, 
        '元', '仅非思考模式', '256K<Token≤1M', 
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.064, 
        '元', '仅非思考模式', '256K<Token≤1M', 
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-plus-2025-09-11', 'qwen-plus-2025-09-11', 
        '通义千问Plus - qwen-plus-2025-09-11', '通义千问Plus',
        '仅非思考模式', '0<Token≤128K', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤128K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '元', '仅非思考模式', '0<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤128K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0008, 
        '元', '仅非思考模式', '0<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤128K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.008, 
        '元', '仅非思考模式', '0<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤128K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-plus-2025-09-11', 'qwen-plus-2025-09-11', 
        '通义千问Plus - qwen-plus-2025-09-11', '通义千问Plus',
        '仅非思考模式', '128K<Token≤256K', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 128.0, 
        '元', '仅非思考模式', '128K<Token≤256K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0024, 
        '元', '仅非思考模式', '128K<Token≤256K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.024, 
        '元', '仅非思考模式', '128K<Token≤256K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-plus-2025-09-11', 'qwen-plus-2025-09-11', 
        '通义千问Plus - qwen-plus-2025-09-11', '通义千问Plus',
        '仅非思考模式', '256K<Token≤1M', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 256.0, 
        '元', '仅非思考模式', '256K<Token≤1M', 
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0048, 
        '元', '仅非思考模式', '256K<Token≤1M', 
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.064, 
        '元', '仅非思考模式', '256K<Token≤1M', 
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-plus-2025-07-28', 'qwen-plus-2025-07-28', 
        '通义千问Plus - qwen-plus-2025-07-28', '通义千问Plus',
        '仅非思考模式', '0<Token≤128K', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤128K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '元', '仅非思考模式', '0<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤128K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0008, 
        '元', '仅非思考模式', '0<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤128K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.008, 
        '元', '仅非思考模式', '0<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤128K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-plus-2025-07-28', 'qwen-plus-2025-07-28', 
        '通义千问Plus - qwen-plus-2025-07-28', '通义千问Plus',
        '仅非思考模式', '128K<Token≤256K', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 128.0, 
        '元', '仅非思考模式', '128K<Token≤256K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0024, 
        '元', '仅非思考模式', '128K<Token≤256K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.024, 
        '元', '仅非思考模式', '128K<Token≤256K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤256K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-plus-2025-07-28', 'qwen-plus-2025-07-28', 
        '通义千问Plus - qwen-plus-2025-07-28', '通义千问Plus',
        '仅非思考模式', '256K<Token≤1M', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 256.0, 
        '元', '仅非思考模式', '256K<Token≤1M', 
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0048, 
        '元', '仅非思考模式', '256K<Token≤1M', 
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.064, 
        '元', '仅非思考模式', '256K<Token≤1M', 
        NULL, '模式:仅非思考模式 | Token范围:256K<Token≤1M'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-plus-2025-07-14', 'qwen-plus-2025-07-14', 
        '通义千问Plus - qwen-plus-2025-07-14', '通义千问Plus',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0008, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.008, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-plus-2025-04-28', 'qwen-plus-2025-04-28', 
        '通义千问Plus - qwen-plus-2025-04-28', '通义千问Plus',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0008, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.008, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-plus-2025-01-25', 'qwen-plus-2025-01-25', 
        '通义千问Plus - qwen-plus-2025-01-25', '通义千问Plus',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0008, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.002, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-plus-2025-01-12', 'qwen-plus-2025-01-12', 
        '通义千问Plus - qwen-plus-2025-01-12', '通义千问Plus',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0008, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.002, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-plus-2024-12-20', 'qwen-plus-2024-12-20', 
        '通义千问Plus - qwen-plus-2024-12-20', '通义千问Plus',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0008, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.002, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-plus-2024-11-27', 'qwen-plus-2024-11-27', 
        '通义千问Plus - qwen-plus-2024-11-27', '通义千问Plus',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0008, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.002, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-plus-2024-11-25', 'qwen-plus-2024-11-25', 
        '通义千问Plus - qwen-plus-2024-11-25', '通义千问Plus',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0008, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.002, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-plus-2024-09-19', 'qwen-plus-2024-09-19', 
        '通义千问Plus - qwen-plus-2024-09-19', '通义千问Plus',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0008, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.002, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-plus-2024-08-06', 'qwen-plus-2024-08-06', 
        '通义千问Plus - qwen-plus-2024-08-06', '通义千问Plus',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.004, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.012, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-plus-2024-07-23', 'qwen-plus-2024-07-23', 
        '通义千问Plus - qwen-plus-2024-07-23', '通义千问Plus',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.004, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.012, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, '模型名称', '模型名称', 
        '通义千问Turbo - 模型名称', '通义千问Turbo',
        '模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:模式'
    ) RETURNING id INTO v_model_id;

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-turbo', 'qwen-turbo', 
        '通义千问Turbo - qwen-turbo', '通义千问Turbo',
        '非思考和思考模式', NULL, NULL,
        TRUE, FALSE,
        NULL, '模式:非思考和思考模式 | Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0003, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式 | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.003, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式 | Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-turbo-latest', 'qwen-turbo-latest', 
        '通义千问Turbo - qwen-turbo-latest', '通义千问Turbo',
        '非思考和思考模式', NULL, NULL,
        TRUE, FALSE,
        NULL, '模式:非思考和思考模式 | Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0003, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式 | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.003, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式 | Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-turbo-2025-07-15', 'qwen-turbo-2025-07-15', 
        '通义千问Turbo - qwen-turbo-2025-07-15', '通义千问Turbo',
        '非思考和思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0003, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.003, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-turbo-2025-04-28', 'qwen-turbo-2025-04-28', 
        '通义千问Turbo - qwen-turbo-2025-04-28', '通义千问Turbo',
        '非思考和思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0003, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.003, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-turbo-2025-02-11', 'qwen-turbo-2025-02-11', 
        '通义千问Turbo - qwen-turbo-2025-02-11', '通义千问Turbo',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0003, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0006, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-turbo-2024-11-01', 'qwen-turbo-2024-11-01', 
        '通义千问Turbo - qwen-turbo-2024-11-01', '通义千问Turbo',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0003, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0006, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-turbo-2024-09-19', 'qwen-turbo-2024-09-19', 
        '通义千问Turbo - qwen-turbo-2024-09-19', '通义千问Turbo',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0003, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0006, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-turbo-2024-06-24', 'qwen-turbo-2024-06-24', 
        '通义千问Turbo - qwen-turbo-2024-06-24', '通义千问Turbo',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.002, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.006, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-vl-plus', 'qwen3-vl-plus', 
        '通义千问VL - qwen3-vl-plus', '通义千问VL',
        '非思考和思考模式', '0<Token≤32K', NULL,
        TRUE, FALSE,
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K | Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.001, 
        '元', '非思考和思考模式', '0<Token≤32K', 
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.01, 
        '元', '非思考和思考模式', '0<Token≤32K', 
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K | Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-vl-plus', 'qwen3-vl-plus', 
        '通义千问VL - qwen3-vl-plus', '通义千问VL',
        '非思考和思考模式', '32K<Token≤128K', NULL,
        TRUE, FALSE,
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤128K | Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0015, 
        '元', '非思考和思考模式', '32K<Token≤128K', 
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤128K | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.015, 
        '元', '非思考和思考模式', '32K<Token≤128K', 
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤128K | Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-vl-plus', 'qwen3-vl-plus', 
        '通义千问VL - qwen3-vl-plus', '通义千问VL',
        '非思考和思考模式', '128K<Token≤256K', NULL,
        TRUE, FALSE,
        NULL, '模式:非思考和思考模式 | Token范围:128K<Token≤256K | Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.003, 
        '元', '非思考和思考模式', '128K<Token≤256K', 
        NULL, '模式:非思考和思考模式 | Token范围:128K<Token≤256K | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.03, 
        '元', '非思考和思考模式', '128K<Token≤256K', 
        NULL, '模式:非思考和思考模式 | Token范围:128K<Token≤256K | Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-vl-plus-2025-12-19', 'qwen3-vl-plus-2025-12-19', 
        '通义千问VL - qwen3-vl-plus-2025-12-19', '通义千问VL',
        '非思考和思考模式', '0<Token≤32K', NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.001, 
        '元', '非思考和思考模式', '0<Token≤32K', 
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.01, 
        '元', '非思考和思考模式', '0<Token≤32K', 
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-vl-plus-2025-12-19', 'qwen3-vl-plus-2025-12-19', 
        '通义千问VL - qwen3-vl-plus-2025-12-19', '通义千问VL',
        '非思考和思考模式', '32K<Token≤128K', NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤128K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0015, 
        '元', '非思考和思考模式', '32K<Token≤128K', 
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤128K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.015, 
        '元', '非思考和思考模式', '32K<Token≤128K', 
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤128K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-vl-plus-2025-12-19', 'qwen3-vl-plus-2025-12-19', 
        '通义千问VL - qwen3-vl-plus-2025-12-19', '通义千问VL',
        '非思考和思考模式', '128K<Token≤256K', NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式 | Token范围:128K<Token≤256K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.003, 
        '元', '非思考和思考模式', '128K<Token≤256K', 
        NULL, '模式:非思考和思考模式 | Token范围:128K<Token≤256K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.03, 
        '元', '非思考和思考模式', '128K<Token≤256K', 
        NULL, '模式:非思考和思考模式 | Token范围:128K<Token≤256K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-vl-plus-2025-09-23', 'qwen3-vl-plus-2025-09-23', 
        '通义千问VL - qwen3-vl-plus-2025-09-23', '通义千问VL',
        '非思考和思考模式', '0<Token≤32K', NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.001, 
        '元', '非思考和思考模式', '0<Token≤32K', 
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.01, 
        '元', '非思考和思考模式', '0<Token≤32K', 
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-vl-plus-2025-09-23', 'qwen3-vl-plus-2025-09-23', 
        '通义千问VL - qwen3-vl-plus-2025-09-23', '通义千问VL',
        '非思考和思考模式', '32K<Token≤128K', NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤128K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0015, 
        '元', '非思考和思考模式', '32K<Token≤128K', 
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤128K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.015, 
        '元', '非思考和思考模式', '32K<Token≤128K', 
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤128K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-vl-plus-2025-09-23', 'qwen3-vl-plus-2025-09-23', 
        '通义千问VL - qwen3-vl-plus-2025-09-23', '通义千问VL',
        '非思考和思考模式', '128K<Token≤256K', NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式 | Token范围:128K<Token≤256K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.003, 
        '元', '非思考和思考模式', '128K<Token≤256K', 
        NULL, '模式:非思考和思考模式 | Token范围:128K<Token≤256K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.03, 
        '元', '非思考和思考模式', '128K<Token≤256K', 
        NULL, '模式:非思考和思考模式 | Token范围:128K<Token≤256K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-vl-flash', 'qwen3-vl-flash', 
        '通义千问VL - qwen3-vl-flash', '通义千问VL',
        '非思考和思考模式', '0<Token≤32K', NULL,
        TRUE, FALSE,
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K | Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.00015, 
        '元', '非思考和思考模式', '0<Token≤32K', 
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.0015, 
        '元', '非思考和思考模式', '0<Token≤32K', 
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K | Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-vl-flash', 'qwen3-vl-flash', 
        '通义千问VL - qwen3-vl-flash', '通义千问VL',
        '非思考和思考模式', '32K<Token≤128K', NULL,
        TRUE, FALSE,
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤128K | Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0003, 
        '元', '非思考和思考模式', '32K<Token≤128K', 
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤128K | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.003, 
        '元', '非思考和思考模式', '32K<Token≤128K', 
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤128K | Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-vl-flash', 'qwen3-vl-flash', 
        '通义千问VL - qwen3-vl-flash', '通义千问VL',
        '非思考和思考模式', '128K<Token≤256K', NULL,
        TRUE, FALSE,
        NULL, '模式:非思考和思考模式 | Token范围:128K<Token≤256K | Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0006, 
        '元', '非思考和思考模式', '128K<Token≤256K', 
        NULL, '模式:非思考和思考模式 | Token范围:128K<Token≤256K | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.006, 
        '元', '非思考和思考模式', '128K<Token≤256K', 
        NULL, '模式:非思考和思考模式 | Token范围:128K<Token≤256K | Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-vl-flash-2025-10-15', 'qwen3-vl-flash-2025-10-15', 
        '通义千问VL - qwen3-vl-flash-2025-10-15', '通义千问VL',
        '非思考和思考模式', '0<Token≤32K', NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.00015, 
        '元', '非思考和思考模式', '0<Token≤32K', 
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.0015, 
        '元', '非思考和思考模式', '0<Token≤32K', 
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-vl-flash-2025-10-15', 'qwen3-vl-flash-2025-10-15', 
        '通义千问VL - qwen3-vl-flash-2025-10-15', '通义千问VL',
        '非思考和思考模式', '32K<Token≤128K', NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤128K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0003, 
        '元', '非思考和思考模式', '32K<Token≤128K', 
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤128K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.003, 
        '元', '非思考和思考模式', '32K<Token≤128K', 
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤128K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-vl-flash-2025-10-15', 'qwen3-vl-flash-2025-10-15', 
        '通义千问VL - qwen3-vl-flash-2025-10-15', '通义千问VL',
        '非思考和思考模式', '128K<Token≤256K', NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式 | Token范围:128K<Token≤256K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0006, 
        '元', '非思考和思考模式', '128K<Token≤256K', 
        NULL, '模式:非思考和思考模式 | Token范围:128K<Token≤256K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.006, 
        '元', '非思考和思考模式', '128K<Token≤256K', 
        NULL, '模式:非思考和思考模式 | Token范围:128K<Token≤256K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-vl-max', 'qwen-vl-max', 
        '通义千问VL - qwen-vl-max', '通义千问VL',
        '仅非思考模式', '无阶梯计价', NULL,
        TRUE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价 | Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0016, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价 | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.004, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价 | Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-vl-max-latest', 'qwen-vl-max-latest', 
        '通义千问VL - qwen-vl-max-latest', '通义千问VL',
        '仅非思考模式', '无阶梯计价', NULL,
        TRUE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价 | Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0016, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价 | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.004, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价 | Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-vl-max-2025-08-13', 'qwen-vl-max-2025-08-13', 
        '通义千问VL - qwen-vl-max-2025-08-13', '通义千问VL',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0016, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.004, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-vl-max-2025-04-08', 'qwen-vl-max-2025-04-08', 
        '通义千问VL - qwen-vl-max-2025-04-08', '通义千问VL',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.003, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.009, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-vl-max-2025-04-02', 'qwen-vl-max-2025-04-02', 
        '通义千问VL - qwen-vl-max-2025-04-02', '通义千问VL',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.003, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.009, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-vl-max-2025-01-25', 'qwen-vl-max-2025-01-25', 
        '通义千问VL - qwen-vl-max-2025-01-25', '通义千问VL',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.003, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.009, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-vl-max-2024-12-30', 'qwen-vl-max-2024-12-30', 
        '通义千问VL - qwen-vl-max-2024-12-30', '通义千问VL',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.003, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.009, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-vl-max-2024-11-19', 'qwen-vl-max-2024-11-19', 
        '通义千问VL - qwen-vl-max-2024-11-19', '通义千问VL',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.003, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.009, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-vl-max-2024-10-30', 'qwen-vl-max-2024-10-30', 
        '通义千问VL - qwen-vl-max-2024-10-30', '通义千问VL',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.02, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.02, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-vl-max-2024-08-09', 'qwen-vl-max-2024-08-09', 
        '通义千问VL - qwen-vl-max-2024-08-09', '通义千问VL',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.02, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.02, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-vl-plus', 'qwen-vl-plus', 
        '通义千问VL - qwen-vl-plus', '通义千问VL',
        '仅非思考模式', '无阶梯计价', NULL,
        TRUE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价 | Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0008, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价 | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.002, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价 | Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-vl-plus-latest', 'qwen-vl-plus-latest', 
        '通义千问VL - qwen-vl-plus-latest', '通义千问VL',
        '仅非思考模式', '无阶梯计价', NULL,
        TRUE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价 | Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0008, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价 | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.002, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价 | Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-vl-plus-2025-08-15', 'qwen-vl-plus-2025-08-15', 
        '通义千问VL - qwen-vl-plus-2025-08-15', '通义千问VL',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0008, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.002, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-vl-plus-2025-07-10', 'qwen-vl-plus-2025-07-10', 
        '通义千问VL - qwen-vl-plus-2025-07-10', '通义千问VL',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.00015, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0015, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-vl-plus-2025-05-07', 'qwen-vl-plus-2025-05-07', 
        '通义千问VL - qwen-vl-plus-2025-05-07', '通义千问VL',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0015, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0045, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-vl-plus-2025-01-25', 'qwen-vl-plus-2025-01-25', 
        '通义千问VL - qwen-vl-plus-2025-01-25', '通义千问VL',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0015, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0045, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-vl-plus-2025-01-02', 'qwen-vl-plus-2025-01-02', 
        '通义千问VL - qwen-vl-plus-2025-01-02', '通义千问VL',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0015, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0045, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-vl-plus-2024-08-09', 'qwen-vl-plus-2024-08-09', 
        '通义千问VL - qwen-vl-plus-2024-08-09', '通义千问VL',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0015, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0045, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-math-plus', 'qwen-math-plus', 
        '通义千问数学模型 - qwen-math-plus', '通义千问数学模型',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.004, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.012, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-math-turbo', 'qwen-math-turbo', 
        '通义千问数学模型 - qwen-math-turbo', '通义千问数学模型',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.002, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.006, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-doc-turbo', 'qwen-doc-turbo', 
        '通义千问数据挖掘模型 - qwen-doc-turbo', '通义千问数据挖掘模型',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0006, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.001, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-deep-research', 'qwen-deep-research', 
        '通义千问深入研究模型 - qwen-deep-research', '通义千问深入研究模型',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.054, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.163, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-mt-plus', 'qwen-mt-plus', 
        '通义千问翻译模型 - qwen-mt-plus', '通义千问翻译模型',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0018, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0054, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-mt-flash', 'qwen-mt-flash', 
        '通义千问翻译模型 - qwen-mt-flash', '通义千问翻译模型',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0007, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.00195, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-mt-lite', 'qwen-mt-lite', 
        '通义千问翻译模型 - qwen-mt-lite', '通义千问翻译模型',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0006, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0016, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-mt-turbo', 'qwen-mt-turbo', 
        '通义千问翻译模型 - qwen-mt-turbo', '通义千问翻译模型',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0007, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.00195, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    -- 分类: text_qwen_opensource
    SELECT id INTO v_category_id FROM pricing_category WHERE code = 'text_qwen_opensource';

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qvq-72b-preview', 'qvq-72b-preview', 
        'qvq-72b-preview', 'QVQ',
        '思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.012, 
        '元', '思考模式', NULL, 
        NULL, '模式:思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.036, 
        '元', '思考模式', NULL, 
        NULL, '模式:思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwq-32b-preview', 'qwq-32b-preview', 
        'QwQ-Preview - qwq-32b-preview', 'QwQ-Preview',
        '思考模式', NULL, NULL,
        TRUE, FALSE,
        NULL, '模式:思考模式 | Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.002, 
        '元', '思考模式', NULL, 
        NULL, '模式:思考模式 | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.006, 
        '元', '思考模式', NULL, 
        NULL, '模式:思考模式 | Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwq-32b', 'qwq-32b', 
        'QwQ-开源版 - qwq-32b', 'QwQ-开源版',
        '思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.002, 
        '元', '思考模式', NULL, 
        NULL, '模式:思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.006, 
        '元', '思考模式', NULL, 
        NULL, '模式:思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2-audio-instruct', 'qwen2-audio-instruct', 
        'Qwen-Audio - qwen2-audio-instruct', 'Qwen-Audio',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-audio-chat', 'qwen-audio-chat', 
        'qwen-audio-chat', 'Qwen-Audio',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-coder-480b-a35b-instruct', 'qwen3-coder-480b-a35b-instruct', 
        'Qwen-Coder - qwen3-coder-480b-a35b-instruct', 'Qwen-Coder',
        '仅非思考模式', '0<Token≤32K', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤32K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.006, 
        '元', '仅非思考模式', '0<Token≤32K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤32K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.024, 
        '元', '仅非思考模式', '0<Token≤32K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤32K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-coder-480b-a35b-instruct', 'qwen3-coder-480b-a35b-instruct', 
        'Qwen-Coder - qwen3-coder-480b-a35b-instruct', 'Qwen-Coder',
        '仅非思考模式', '32K<Token≤128K', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:32K<Token≤128K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.009, 
        '元', '仅非思考模式', '32K<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:32K<Token≤128K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.036, 
        '元', '仅非思考模式', '32K<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:32K<Token≤128K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-coder-480b-a35b-instruct', 'qwen3-coder-480b-a35b-instruct', 
        'Qwen-Coder - qwen3-coder-480b-a35b-instruct', 'Qwen-Coder',
        '仅非思考模式', '128K<Token≤200K', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤200K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.015, 
        '元', '仅非思考模式', '128K<Token≤200K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤200K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.06, 
        '元', '仅非思考模式', '128K<Token≤200K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤200K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-coder-30b-a3b-instruct', 'qwen3-coder-30b-a3b-instruct', 
        'Qwen-Coder - qwen3-coder-30b-a3b-instruct', 'Qwen-Coder',
        '仅非思考模式', '0<Token≤32K', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤32K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0015, 
        '元', '仅非思考模式', '0<Token≤32K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤32K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.006, 
        '元', '仅非思考模式', '0<Token≤32K', 
        NULL, '模式:仅非思考模式 | Token范围:0<Token≤32K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-coder-30b-a3b-instruct', 'qwen3-coder-30b-a3b-instruct', 
        'Qwen-Coder - qwen3-coder-30b-a3b-instruct', 'Qwen-Coder',
        '仅非思考模式', '32K<Token≤128K', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:32K<Token≤128K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.00225, 
        '元', '仅非思考模式', '32K<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:32K<Token≤128K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.009, 
        '元', '仅非思考模式', '32K<Token≤128K', 
        NULL, '模式:仅非思考模式 | Token范围:32K<Token≤128K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-coder-30b-a3b-instruct', 'qwen3-coder-30b-a3b-instruct', 
        'Qwen-Coder - qwen3-coder-30b-a3b-instruct', 'Qwen-Coder',
        '仅非思考模式', '128K<Token≤200K', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤200K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.00375, 
        '元', '仅非思考模式', '128K<Token≤200K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤200K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.015, 
        '元', '仅非思考模式', '128K<Token≤200K', 
        NULL, '模式:仅非思考模式 | Token范围:128K<Token≤200K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2.5-coder-32b-instruct', 'qwen2.5-coder-32b-instruct', 
        'Qwen-Coder - qwen2.5-coder-32b-instruct', 'Qwen-Coder',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.002, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.006, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2.5-coder-14b-instruct', 'qwen2.5-coder-14b-instruct', 
        'Qwen-Coder - qwen2.5-coder-14b-instruct', 'Qwen-Coder',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.002, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.006, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2.5-coder-7b-instruct', 'qwen2.5-coder-7b-instruct', 
        'Qwen-Coder - qwen2.5-coder-7b-instruct', 'Qwen-Coder',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.001, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.002, 
        '元', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2.5-coder-3b-instruct', 'qwen2.5-coder-3b-instruct', 
        'Qwen-Coder - qwen2.5-coder-3b-instruct', 'Qwen-Coder',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0, 
        '千Token', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2.5-coder-1.5b-instruct', 'qwen2.5-coder-1.5b-instruct', 
        'Qwen-Coder - qwen2.5-coder-1.5b-instruct', 'Qwen-Coder',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0, 
        '千Token', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2.5-coder-0.5b-instruct', 'qwen2.5-coder-0.5b-instruct', 
        'Qwen-Coder - qwen2.5-coder-0.5b-instruct', 'Qwen-Coder',
        '仅非思考模式', '无阶梯计价', NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0, 
        '千Token', '仅非思考模式', '无阶梯计价', 
        NULL, '模式:仅非思考模式 | Token范围:无阶梯计价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2.5-math-72b-instruct', 'qwen2.5-math-72b-instruct', 
        'Qwen-Math - qwen2.5-math-72b-instruct', 'Qwen-Math',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.004, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.012, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2.5-math-7b-instruct', 'qwen2.5-math-7b-instruct', 
        'Qwen-Math - qwen2.5-math-7b-instruct', 'Qwen-Math',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.001, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.002, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2.5-math-1.5b-instruct', 'qwen2.5-math-1.5b-instruct', 
        'Qwen-Math - qwen2.5-math-1.5b-instruct', 'Qwen-Math',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, '模型名称', '模型名称', 
        'Qwen-Omni - 模型名称', 'Qwen-Omni',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2.5-omni-7b', 'qwen2.5-omni-7b', 
        'Qwen-Omni - qwen2.5-omni-7b', 'Qwen-Omni',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.002, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.076, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-vl-235b-a22b-thinking', 'qwen3-vl-235b-a22b-thinking', 
        'Qwen-VL - qwen3-vl-235b-a22b-thinking', 'Qwen-VL',
        '仅思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.002, 
        '元', '仅思考模式', NULL, 
        NULL, '模式:仅思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.02, 
        '元', '仅思考模式', NULL, 
        NULL, '模式:仅思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-vl-235b-a22b-instruct', 'qwen3-vl-235b-a22b-instruct', 
        'Qwen-VL - qwen3-vl-235b-a22b-instruct', 'Qwen-VL',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.002, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.008, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-vl-32b-thinking', 'qwen3-vl-32b-thinking', 
        'Qwen-VL - qwen3-vl-32b-thinking', 'Qwen-VL',
        '仅思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.002, 
        '元', '仅思考模式', NULL, 
        NULL, '模式:仅思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.02, 
        '元', '仅思考模式', NULL, 
        NULL, '模式:仅思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-vl-32b-instruct', 'qwen3-vl-32b-instruct', 
        'Qwen-VL - qwen3-vl-32b-instruct', 'Qwen-VL',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.002, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.008, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-vl-30b-a3b-thinking', 'qwen3-vl-30b-a3b-thinking', 
        'Qwen-VL - qwen3-vl-30b-a3b-thinking', 'Qwen-VL',
        '仅思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.00075, 
        '元', '仅思考模式', NULL, 
        NULL, '模式:仅思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.0075, 
        '元', '仅思考模式', NULL, 
        NULL, '模式:仅思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-vl-30b-a3b-instruct', 'qwen3-vl-30b-a3b-instruct', 
        'Qwen-VL - qwen3-vl-30b-a3b-instruct', 'Qwen-VL',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.00075, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.003, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-vl-8b-thinking', 'qwen3-vl-8b-thinking', 
        'Qwen-VL - qwen3-vl-8b-thinking', 'Qwen-VL',
        '仅思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0005, 
        '元', '仅思考模式', NULL, 
        NULL, '模式:仅思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.005, 
        '元', '仅思考模式', NULL, 
        NULL, '模式:仅思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-vl-8b-instruct', 'qwen3-vl-8b-instruct', 
        'Qwen-VL - qwen3-vl-8b-instruct', 'Qwen-VL',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0005, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.002, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2.5-vl-72b-instruct', 'qwen2.5-vl-72b-instruct', 
        'Qwen-VL - qwen2.5-vl-72b-instruct', 'Qwen-VL',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.016, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.048, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2.5-vl-32b-instruct', 'qwen2.5-vl-32b-instruct', 
        'Qwen-VL - qwen2.5-vl-32b-instruct', 'Qwen-VL',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.008, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.024, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2.5-vl-7b-instruct', 'qwen2.5-vl-7b-instruct', 
        'Qwen-VL - qwen2.5-vl-7b-instruct', 'Qwen-VL',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.002, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.005, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2.5-vl-3b-instruct', 'qwen2.5-vl-3b-instruct', 
        'Qwen-VL - qwen2.5-vl-3b-instruct', 'Qwen-VL',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0012, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0036, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2-vl-72b-instruct', 'qwen2-vl-72b-instruct', 
        'Qwen-VL - qwen2-vl-72b-instruct', 'Qwen-VL',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.016, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.048, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2-vl-7b-instruct', 'qwen2-vl-7b-instruct', 
        'Qwen-VL - qwen2-vl-7b-instruct', 'Qwen-VL',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2-vl-2b-instruct', 'qwen2-vl-2b-instruct', 
        'Qwen-VL - qwen2-vl-2b-instruct', 'Qwen-VL',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-vl-v1', 'qwen-vl-v1', 
        'qwen-vl-v1', 'Qwen-VL',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-vl-chat-v1', 'qwen-vl-chat-v1', 
        'qwen-vl-chat-v1', 'Qwen-VL',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen1.5-110b-chat', 'qwen1.5-110b-chat', 
        'qwen1.5-110b-chat', 'Qwen1.5',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.007, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.014, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen1.5-72b-chat', 'qwen1.5-72b-chat', 
        'qwen1.5-72b-chat', 'Qwen1.5',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.005, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.01, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen1.5-32b-chat', 'qwen1.5-32b-chat', 
        'qwen1.5-32b-chat', 'Qwen1.5',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0035, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.007, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen1.5-14b-chat', 'qwen1.5-14b-chat', 
        'qwen1.5-14b-chat', 'Qwen1.5',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.002, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.004, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen1.5-7b-chat', 'qwen1.5-7b-chat', 
        'qwen1.5-7b-chat', 'Qwen1.5',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.001, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.002, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen1.5-1.8b-chat', 'qwen1.5-1.8b-chat', 
        'qwen1.5-1.8b-chat', 'Qwen1.5',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen1.5-0.5b-chat', 'qwen1.5-0.5b-chat', 
        'qwen1.5-0.5b-chat', 'Qwen1.5',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2.5-14b-instruct-1m', 'qwen2.5-14b-instruct-1m', 
        'qwen2.5-14b-instruct-1m', 'Qwen2.5',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.001, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.003, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2.5-7b-instruct-1m', 'qwen2.5-7b-instruct-1m', 
        'qwen2.5-7b-instruct-1m', 'Qwen2.5',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0005, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.001, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2.5-72b-instruct', 'qwen2.5-72b-instruct', 
        'qwen2.5-72b-instruct', 'Qwen2.5',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.004, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.012, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2.5-32b-instruct', 'qwen2.5-32b-instruct', 
        'qwen2.5-32b-instruct', 'Qwen2.5',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.002, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.006, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2.5-14b-instruct', 'qwen2.5-14b-instruct', 
        'qwen2.5-14b-instruct', 'Qwen2.5',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.001, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.003, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2.5-7b-instruct', 'qwen2.5-7b-instruct', 
        'qwen2.5-7b-instruct', 'Qwen2.5',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0005, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.001, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2.5-3b-instruct', 'qwen2.5-3b-instruct', 
        'qwen2.5-3b-instruct', 'Qwen2.5',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0003, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0009, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2.5-1.5b-instruct', 'qwen2.5-1.5b-instruct', 
        'qwen2.5-1.5b-instruct', 'Qwen2.5',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2.5-0.5b-instruct', 'qwen2.5-0.5b-instruct', 
        'qwen2.5-0.5b-instruct', 'Qwen2.5',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2-72b-instruct', 'qwen2-72b-instruct', 
        'qwen2-72b-instruct', 'Qwen2',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.004, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.012, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2-57b-a14b-instruct', 'qwen2-57b-a14b-instruct', 
        'qwen2-57b-a14b-instruct', 'Qwen2',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0035, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.007, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2-7b-instruct', 'qwen2-7b-instruct', 
        'qwen2-7b-instruct', 'Qwen2',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.001, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.002, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2-1.5b-instruct', 'qwen2-1.5b-instruct', 
        'qwen2-1.5b-instruct', 'Qwen2',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2-0.5b-instruct', 'qwen2-0.5b-instruct', 
        'qwen2-0.5b-instruct', 'Qwen2',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-omni-30b-a3b-captioner', 'qwen3-omni-30b-a3b-captioner', 
        'Qwen3-Omni-Captioner - qwen3-omni-30b-a3b-captioner', 'Qwen3-Omni-Captioner',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0158, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0127, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, '模型名称', '模型名称', 
        'Qwen3 - 模型名称', 'Qwen3',
        '模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:模式'
    ) RETURNING id INTO v_model_id;

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-next-80b-a3b-thinking', 'qwen3-next-80b-a3b-thinking', 
        'qwen3-next-80b-a3b-thinking', 'Qwen3',
        '仅思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.001, 
        '元', '仅思考模式', NULL, 
        NULL, '模式:仅思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.01, 
        '元', '仅思考模式', NULL, 
        NULL, '模式:仅思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-next-80b-a3b-instruct', 'qwen3-next-80b-a3b-instruct', 
        'qwen3-next-80b-a3b-instruct', 'Qwen3',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.001, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-235b-a22b-thinking-2507', 'qwen3-235b-a22b-thinking-2507', 
        'qwen3-235b-a22b-thinking-2507', 'Qwen3',
        '仅思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.002, 
        '元', '仅思考模式', NULL, 
        NULL, '模式:仅思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.02, 
        '元', '仅思考模式', NULL, 
        NULL, '模式:仅思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-235b-a22b-instruct-2507', 'qwen3-235b-a22b-instruct-2507', 
        'qwen3-235b-a22b-instruct-2507', 'Qwen3',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.002, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-30b-a3b-thinking-2507', 'qwen3-30b-a3b-thinking-2507', 
        'qwen3-30b-a3b-thinking-2507', 'Qwen3',
        '仅思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.00075, 
        '元', '仅思考模式', NULL, 
        NULL, '模式:仅思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0075, 
        '元', '仅思考模式', NULL, 
        NULL, '模式:仅思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-30b-a3b-instruct-2507', 'qwen3-30b-a3b-instruct-2507', 
        'qwen3-30b-a3b-instruct-2507', 'Qwen3',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.00075, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-235b-a22b', 'qwen3-235b-a22b', 
        'qwen3-235b-a22b', 'Qwen3',
        '非思考和思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.002, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.02, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-32b', 'qwen3-32b', 
        'qwen3-32b', 'Qwen3',
        '非思考和思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.002, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.02, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-30b-a3b', 'qwen3-30b-a3b', 
        'qwen3-30b-a3b', 'Qwen3',
        '非思考和思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.00075, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0075, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-14b', 'qwen3-14b', 
        'qwen3-14b', 'Qwen3',
        '非思考和思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.001, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.01, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-8b', 'qwen3-8b', 
        'qwen3-8b', 'Qwen3',
        '非思考和思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0005, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.005, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-4b', 'qwen3-4b', 
        'qwen3-4b', 'Qwen3',
        '非思考和思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0003, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.003, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-1.7b', 'qwen3-1.7b', 
        'qwen3-1.7b', 'Qwen3',
        '非思考和思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0003, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.003, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-0.6b', 'qwen3-0.6b', 
        'qwen3-0.6b', 'Qwen3',
        '非思考和思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0003, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.003, 
        '元', '非思考和思考模式', NULL, 
        NULL, '模式:非思考和思考模式'
    );

    -- 分类: text_thirdparty
    SELECT id INTO v_category_id FROM pricing_category WHERE code = 'text_thirdparty';

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'deepseek-v3.2', 'deepseek-v3.2', 
        'deepseek-v3.2', 'DeepSeek',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.002, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.003, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'deepseek-v3.2-exp', 'deepseek-v3.2-exp', 
        'deepseek-v3.2-exp', 'DeepSeek',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.002, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.003, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'deepseek-v3.1', 'deepseek-v3.1', 
        'deepseek-v3.1', 'DeepSeek',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.004, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.012, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'deepseek-r1', 'deepseek-r1', 
        'deepseek-r1', 'DeepSeek',
        '仅非思考模式', NULL, NULL,
        TRUE, FALSE,
        NULL, '模式:仅非思考模式 | Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.004, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式 | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.016, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式 | Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'deepseek-r1-0528', 'deepseek-r1-0528', 
        'deepseek-r1-0528', 'DeepSeek',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.004, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.016, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'deepseek-v3', 'deepseek-v3', 
        'deepseek-v3', 'DeepSeek',
        '仅非思考模式', NULL, NULL,
        TRUE, FALSE,
        NULL, '模式:仅非思考模式 | Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.002, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式 | Batch调用半价'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.008, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式 | Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'deepseek-r1-distill-qwen-1.5b', 'deepseek-r1-distill-qwen-1.5b', 
        'deepseek-r1-distill-qwen-1.5b', 'DeepSeek',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'deepseek-r1-distill-qwen-7b', 'deepseek-r1-distill-qwen-7b', 
        'deepseek-r1-distill-qwen-7b', 'DeepSeek',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0005, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.001, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'deepseek-r1-distill-qwen-14b', 'deepseek-r1-distill-qwen-14b', 
        'deepseek-r1-distill-qwen-14b', 'DeepSeek',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.001, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.003, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'deepseek-r1-distill-qwen-32b', 'deepseek-r1-distill-qwen-32b', 
        'deepseek-r1-distill-qwen-32b', 'DeepSeek',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.002, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.006, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'deepseek-r1-distill-llama-8b', 'deepseek-r1-distill-llama-8b', 
        'deepseek-r1-distill-llama-8b', 'DeepSeek',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'deepseek-r1-distill-llama-70b', 'deepseek-r1-distill-llama-70b', 
        'deepseek-r1-distill-llama-70b', 'DeepSeek',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'glm-4.7', 'glm-4.7', 
        'glm-4.7', 'GLM',
        '非思考和思考模式', '0<Token≤32K', NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.003, 
        '元', '非思考和思考模式', '0<Token≤32K', 
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.014, 
        '元', '非思考和思考模式', '0<Token≤32K', 
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'glm-4.7', 'glm-4.7', 
        'glm-4.7', 'GLM',
        '非思考和思考模式', '32K<Token≤166K', NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤166K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.004, 
        '元', '非思考和思考模式', '32K<Token≤166K', 
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤166K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.016, 
        '元', '非思考和思考模式', '32K<Token≤166K', 
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤166K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'glm-4.6', 'glm-4.6', 
        'glm-4.6', 'GLM',
        '非思考和思考模式', '0<Token≤32K', NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.003, 
        '元', '非思考和思考模式', '0<Token≤32K', 
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.014, 
        '元', '非思考和思考模式', '0<Token≤32K', 
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'glm-4.6', 'glm-4.6', 
        'glm-4.6', 'GLM',
        '非思考和思考模式', '32K<Token≤166K', NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤166K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.004, 
        '元', '非思考和思考模式', '32K<Token≤166K', 
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤166K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.016, 
        '元', '非思考和思考模式', '32K<Token≤166K', 
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤166K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'glm-4.5', 'glm-4.5', 
        'glm-4.5', 'GLM',
        '非思考和思考模式', '0<Token≤32K', NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.003, 
        '元', '非思考和思考模式', '0<Token≤32K', 
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.014, 
        '元', '非思考和思考模式', '0<Token≤32K', 
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'glm-4.5', 'glm-4.5', 
        'glm-4.5', 'GLM',
        '非思考和思考模式', '32K<Token≤96K', NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤96K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.004, 
        '元', '非思考和思考模式', '32K<Token≤96K', 
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤96K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.016, 
        '元', '非思考和思考模式', '32K<Token≤96K', 
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤96K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'glm-4.5-air', 'glm-4.5-air', 
        'glm-4.5-air', 'GLM',
        '非思考和思考模式', '0<Token≤32K', NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0008, 
        '元', '非思考和思考模式', '0<Token≤32K', 
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.006, 
        '元', '非思考和思考模式', '0<Token≤32K', 
        NULL, '模式:非思考和思考模式 | Token范围:0<Token≤32K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'glm-4.5-air', 'glm-4.5-air', 
        'glm-4.5-air', 'GLM',
        '非思考和思考模式', '32K<Token≤96K', NULL,
        FALSE, FALSE,
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤96K'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0012, 
        '元', '非思考和思考模式', '32K<Token≤96K', 
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤96K'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token_thinking', 0.008, 
        '元', '非思考和思考模式', '32K<Token≤96K', 
        NULL, '模式:非思考和思考模式 | Token范围:32K<Token≤96K'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'kimi-k2-thinking', 'kimi-k2-thinking', 
        'kimi-k2-thinking', 'Kimi',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.004, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.016, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'Moonshot-Kimi-K2-Instruct', 'Moonshot-Kimi-K2-Instruct', 
        'Moonshot-Kimi-K2-Instruct', 'Kimi',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.004, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.016, 
        '元', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'abab6.5g-chat', 'abab6.5g-chat', 
        'MiniMax - abab6.5g-chat', 'MiniMax',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'abab6.5t-chat', 'abab6.5t-chat', 
        'MiniMax - abab6.5t-chat', 'MiniMax',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'abab6.5s-chat', 'abab6.5s-chat', 
        'MiniMax - abab6.5s-chat', 'MiniMax',
        '仅非思考模式', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:仅非思考模式'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0, 
        '千Token', '仅非思考模式', NULL, 
        NULL, '模式:仅非思考模式'
    );

    -- 分类: image_gen
    SELECT id INTO v_category_id FROM pricing_category WHERE code = 'image_gen';

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'aitryon', 'aitryon', 
        'AI试衣-OutfitAnyone - aitryon', 'AI试衣-OutfitAnyone',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'aitryon-plus', 'aitryon-plus', 
        'AI试衣-OutfitAnyone - aitryon-plus', 'AI试衣-OutfitAnyone',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'aitryon-parsing-v1', 'aitryon-parsing-v1', 
        'AI试衣-OutfitAnyone - aitryon-parsing-v1', 'AI试衣-OutfitAnyone',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'aitryon-refiner', 'aitryon-refiner', 
        'AI试衣-OutfitAnyone - aitryon-refiner', 'AI试衣-OutfitAnyone',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'aitryon', 'aitryon', 
        'AI试衣-OutfitAnyone - aitryon', 'AI试衣-OutfitAnyone',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.2, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'aitryon-plus', 'aitryon-plus', 
        'AI试衣-OutfitAnyone - aitryon-plus', 'AI试衣-OutfitAnyone',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.5, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'aitryon-parsing-v1', 'aitryon-parsing-v1', 
        'AI试衣-OutfitAnyone - aitryon-parsing-v1', 'AI试衣-OutfitAnyone',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.004, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'aitryon-refiner', 'aitryon-refiner', 
        'AI试衣-OutfitAnyone - aitryon-refiner', 'AI试衣-OutfitAnyone',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.3, 
        '张', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 25.0, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'aitryon-refiner', 'aitryon-refiner', 
        'AI试衣-OutfitAnyone - aitryon-refiner', 'AI试衣-OutfitAnyone',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.275, 
        '张', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 9.2, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 25.0, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'aitryon-refiner', 'aitryon-refiner', 
        'AI试衣-OutfitAnyone - aitryon-refiner', 'AI试衣-OutfitAnyone',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.25, 
        '张', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 8.4, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 125.0, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'aitryon-refiner', 'aitryon-refiner', 
        'AI试衣-OutfitAnyone - aitryon-refiner', 'AI试衣-OutfitAnyone',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.225, 
        '张', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 7.5, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 250.0, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'aitryon-refiner', 'aitryon-refiner', 
        'AI试衣-OutfitAnyone - aitryon-refiner', 'AI试衣-OutfitAnyone',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.2, 
        '张', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 6.7, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 1250.0, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'aitryon-refiner', 'aitryon-refiner', 
        'AI试衣-OutfitAnyone - aitryon-refiner', 'AI试衣-OutfitAnyone',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.175, 
        '张', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 5.8, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 2500.0, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'aitryon-refiner', 'aitryon-refiner', 
        'AI试衣-OutfitAnyone - aitryon-refiner', 'AI试衣-OutfitAnyone',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.15, 
        '张', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 5.0, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 2.5, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wanx-style-repaint-v1', 'wanx-style-repaint-v1', 
        '人像风格重绘 - wanx-style-repaint-v1', '人像风格重绘',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.12, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'facechain-facedetect', 'facechain-facedetect', 
        '人物写真生成-FaceChain - facechain-facedetect', '人物写真生成-FaceChain',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.0, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'facechain-finetune', 'facechain-finetune', 
        '人物写真生成-FaceChain - facechain-finetune', '人物写真生成-FaceChain',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 2.5, 
        '次', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'facechain-generation', 'facechain-generation', 
        '人物写真生成-FaceChain - facechain-generation', '人物写真生成-FaceChain',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.18, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'image-instance-segmentation', 'image-instance-segmentation', 
        '人物实例分割 - image-instance-segmentation', '人物实例分割',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.0, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wordart-texture', 'wordart-texture', 
        '创意文字生成-WordArt锦书 - wordart-texture', '创意文字生成-WordArt锦书',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.08, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wordart-semantic', 'wordart-semantic', 
        '创意文字生成-WordArt锦书 - wordart-semantic', '创意文字生成-WordArt锦书',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.24, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wanx-poster-generation-v1', 'wanx-poster-generation-v1', 
        '创意海报生成 - wanx-poster-generation-v1', '创意海报生成',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.0, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'image-erase-completion', 'image-erase-completion', 
        '图像擦除补全 - image-erase-completion', '图像擦除补全',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.0, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'image-out-painting', 'image-out-painting', 
        '图像画面扩展 - image-out-painting', '图像画面扩展',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.18, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wanx-background-generation-v2', 'wanx-background-generation-v2', 
        '图像背景生成 - wanx-background-generation-v2', '图像背景生成',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.08, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wanx-virtualmodel', 'wanx-virtualmodel', 
        '虚拟模特 - wanx-virtualmodel', '虚拟模特',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.0, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'virtualmodel-v2', 'virtualmodel-v2', 
        '虚拟模特 - virtualmodel-v2', '虚拟模特',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.0, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'z-image-turbo', 'z-image-turbo', 
        '通义-文生图-Z-Image - z-image-turbo', '通义-文生图-Z-Image',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.1, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wanx-x-painting', 'wanx-x-painting', 
        '通义万相图像局部重绘 - wanx-x-painting', '通义万相图像局部重绘',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.0, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.6-image', 'wan2.6-image', 
        '通义万相图像生成与编辑 - wan2.6-image', '通义万相图像生成与编辑',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.2, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.6-t2i', 'wan2.6-t2i', 
        '通义万相文生图 - wan2.6-t2i', '通义万相文生图',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.2, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.5-t2i-preview', 'wan2.5-t2i-preview', 
        '通义万相文生图 - wan2.5-t2i-preview', '通义万相文生图',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.2, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.2-t2i-plus', 'wan2.2-t2i-plus', 
        '通义万相文生图 - wan2.2-t2i-plus', '通义万相文生图',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.2, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.2-t2i-flash', 'wan2.2-t2i-flash', 
        '通义万相文生图 - wan2.2-t2i-flash', '通义万相文生图',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.14, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wanx2.1-t2i-plus', 'wanx2.1-t2i-plus', 
        '通义万相文生图 - wanx2.1-t2i-plus', '通义万相文生图',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.2, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wanx2.1-t2i-turbo', 'wanx2.1-t2i-turbo', 
        '通义万相文生图 - wanx2.1-t2i-turbo', '通义万相文生图',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.14, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wanx2.0-t2i-turbo', 'wanx2.0-t2i-turbo', 
        '通义万相文生图 - wanx2.0-t2i-turbo', '通义万相文生图',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.04, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wanx-v1', 'wanx-v1', 
        '通义万相文生图 - wanx-v1', '通义万相文生图',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.16, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wanx-sketch-to-image-lite', 'wanx-sketch-to-image-lite', 
        '通义万相涂鸦作画 - wanx-sketch-to-image-lite', '通义万相涂鸦作画',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.06, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.5-i2i-preview', 'wan2.5-i2i-preview', 
        '通义万相通用图像编辑 - wan2.5-i2i-preview', '通义万相通用图像编辑',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.2, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wanx2.1-imageedit', 'wanx2.1-imageedit', 
        '通义万相通用图像编辑 - wanx2.1-imageedit', '通义万相通用图像编辑',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.14, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-image-edit-plus', 'qwen-image-edit-plus', 
        '通义千问图像编辑 - qwen-image-edit-plus', '通义千问图像编辑',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.2, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-image-edit-plus-2025-12-15', 'qwen-image-edit-plus-2025-12-15', 
        '通义千问图像编辑 - qwen-image-edit-plus-2025-12-15', '通义千问图像编辑',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.2, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-image-edit-plus-2025-10-30', 'qwen-image-edit-plus-2025-10-30', 
        '通义千问图像编辑 - qwen-image-edit-plus-2025-10-30', '通义千问图像编辑',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.2, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-image-edit', 'qwen-image-edit', 
        '通义千问图像编辑 - qwen-image-edit', '通义千问图像编辑',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.3, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-mt-image', 'qwen-mt-image', 
        '通义千问图像翻译 - qwen-mt-image', '通义千问图像翻译',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.003, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-image-max', 'qwen-image-max', 
        '通义千问文生图 - qwen-image-max', '通义千问文生图',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.5, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-image-max-2025-12-30', 'qwen-image-max-2025-12-30', 
        '通义千问文生图 - qwen-image-max-2025-12-30', '通义千问文生图',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.5, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-image-plus', 'qwen-image-plus', 
        '通义千问文生图 - qwen-image-plus', '通义千问文生图',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.2, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-image-plus-2026-01-09', 'qwen-image-plus-2026-01-09', 
        '通义千问文生图 - qwen-image-plus-2026-01-09', '通义千问文生图',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.2, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-image', 'qwen-image', 
        '通义千问文生图 - qwen-image', '通义千问文生图',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.25, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'shoemodel-v1', 'shoemodel-v1', 
        '鞋靴模特 - shoemodel-v1', '鞋靴模特',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.0, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    -- 分类: image_gen_thirdparty
    SELECT id INTO v_category_id FROM pricing_category WHERE code = 'image_gen_thirdparty';

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'flux-merged', 'flux-merged', 
        'FLUX文生图模型 - flux-merged', 'FLUX文生图模型',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.0, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'flux-dev', 'flux-dev', 
        'FLUX文生图模型 - flux-dev', 'FLUX文生图模型',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.0, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'flux-schnell', 'flux-schnell', 
        'FLUX文生图模型 - flux-schnell', 'FLUX文生图模型',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.0, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'stable-diffusion-3.5-large', 'stable-diffusion-3.5-large', 
        'StableDiffusion文生图模型 - stable-diffusion-3.5-large', 'StableDiffusion文生图模型',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.0, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'stable-diffusion-3.5-large-turbo', 'stable-diffusion-3.5-large-turbo', 
        'StableDiffusion文生图模型 - stable-diffusion-3.5-large-turbo', 'StableDiffusion文生图模型',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.0, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'stable-diffusion-xl', 'stable-diffusion-xl', 
        'StableDiffusion文生图模型 - stable-diffusion-xl', 'StableDiffusion文生图模型',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.0, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'stable-diffusion-v1.5', 'stable-diffusion-v1.5', 
        'StableDiffusion文生图模型 - stable-diffusion-v1.5', 'StableDiffusion文生图模型',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.0, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    -- 分类: tts
    SELECT id INTO v_category_id FROM pricing_category WHERE code = 'tts';

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'cosyvoice-v3-plus', 'cosyvoice-v3-plus', 
        'cosyvoice-v3-plus', 'CosyVoice',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'character', 2.0, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'cosyvoice-v3-flash', 'cosyvoice-v3-flash', 
        'cosyvoice-v3-flash', 'CosyVoice',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'character', 1.0, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'cosyvoice-v2', 'cosyvoice-v2', 
        'cosyvoice-v2', 'CosyVoice',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'character', 2.0, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'cosyvoice-v1', 'cosyvoice-v1', 
        'cosyvoice-v1', 'CosyVoice',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'character', 2.0, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-tts-vd-realtime-2025-12-16', 'qwen3-tts-vd-realtime-2025-12-16', 
        'Qwen-TTS-Realtime - qwen3-tts-vd-realtime-2025-12-16', 'Qwen-TTS-Realtime',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'character', 1.0, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'character', 0.0, 
        '万字符', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-tts-vc-realtime-2025-11-27', 'qwen3-tts-vc-realtime-2025-11-27', 
        'Qwen-TTS-Realtime - qwen3-tts-vc-realtime-2025-11-27', 'Qwen-TTS-Realtime',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'character', 1.0, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'character', 0.0, 
        '万字符', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-tts-flash-realtime', 'qwen3-tts-flash-realtime', 
        'Qwen-TTS-Realtime - qwen3-tts-flash-realtime', 'Qwen-TTS-Realtime',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'character', 1.0, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'character', 0.0, 
        '万字符', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-tts-flash-realtime-2025-11-27', 'qwen3-tts-flash-realtime-2025-11-27', 
        'Qwen-TTS-Realtime - qwen3-tts-flash-realtime-2025-11-27', 'Qwen-TTS-Realtime',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'character', 1.0, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'character', 0.0, 
        '万字符', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-tts-flash-realtime-2025-09-18', 'qwen3-tts-flash-realtime-2025-09-18', 
        'Qwen-TTS-Realtime - qwen3-tts-flash-realtime-2025-09-18', 'Qwen-TTS-Realtime',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'character', 1.0, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'character', 0.0, 
        '万字符', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-tts-realtime', 'qwen-tts-realtime', 
        'qwen-tts-realtime', 'Qwen-TTS-Realtime',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0024, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.012, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-tts-realtime-latest', 'qwen-tts-realtime-latest', 
        'qwen-tts-realtime-latest', 'Qwen-TTS-Realtime',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0024, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.012, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-tts-realtime-2025-07-15', 'qwen-tts-realtime-2025-07-15', 
        'qwen-tts-realtime-2025-07-15', 'Qwen-TTS-Realtime',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0024, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.012, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-tts-flash', 'qwen3-tts-flash', 
        'Qwen-TTS - qwen3-tts-flash', 'Qwen-TTS',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'character', 0.8, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'character', 0.0, 
        '万字符', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-tts-flash-2025-11-27', 'qwen3-tts-flash-2025-11-27', 
        'Qwen-TTS - qwen3-tts-flash-2025-11-27', 'Qwen-TTS',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'character', 0.8, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'character', 0.0, 
        '万字符', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-tts-flash-2025-09-18', 'qwen3-tts-flash-2025-09-18', 
        'Qwen-TTS - qwen3-tts-flash-2025-09-18', 'Qwen-TTS',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'character', 0.8, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'character', 0.0, 
        '万字符', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-tts-flash', 'qwen-tts-flash', 
        'qwen-tts-flash', 'Qwen-TTS',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0016, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.01, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-tts-latest', 'qwen-tts-latest', 
        'qwen-tts-latest', 'Qwen-TTS',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0016, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.01, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-tts-2025-05-22', 'qwen-tts-2025-05-22', 
        'qwen-tts-2025-05-22', 'Qwen-TTS',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0016, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.01, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-tts-2025-04-10', 'qwen-tts-2025-04-10', 
        'qwen-tts-2025-04-10', 'Qwen-TTS',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0016, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.01, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-voice-enrollment', 'qwen-voice-enrollment', 
        'Qwen-TTS声音复刻 - qwen-voice-enrollment', 'Qwen-TTS声音复刻',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'character', 0.01, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-voice-design', 'qwen-voice-design', 
        'Qwen-TTS声音设计 - qwen-voice-design', 'Qwen-TTS声音设计',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'character', 0.2, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, '参见模型列表', '参见模型列表', 
        'Sambert - 参见模型列表', 'Sambert',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'character', 1.0, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    -- 分类: asr
    SELECT id INTO v_category_id FROM pricing_category WHERE code = 'asr';

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'fun-asr', 'fun-asr', 
        'fun-asr', 'Fun-ASR',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 0.00022, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'fun-asr-2025-11-07', 'fun-asr-2025-11-07', 
        'fun-asr-2025-11-07', 'Fun-ASR',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 0.00022, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'fun-asr-2025-08-25', 'fun-asr-2025-08-25', 
        'fun-asr-2025-08-25', 'Fun-ASR',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 0.00022, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'fun-asr-mtl', 'fun-asr-mtl', 
        'fun-asr-mtl', 'Fun-ASR',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 0.00022, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'fun-asr-mtl-2025-08-25', 'fun-asr-mtl-2025-08-25', 
        'fun-asr-mtl-2025-08-25', 'Fun-ASR',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 0.00022, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'gummy-realtime-v1', 'gummy-realtime-v1', 
        'Gummy语音识别/翻译 - gummy-realtime-v1', 'Gummy语音识别/翻译',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 0.00015, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'gummy-chat-v1', 'gummy-chat-v1', 
        'Gummy语音识别/翻译 - gummy-chat-v1', 'Gummy语音识别/翻译',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 0.00015, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'paraformer-v2', 'paraformer-v2', 
        'paraformer-v2', 'Paraformer',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 8e-05, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'paraformer-8k-v2', 'paraformer-8k-v2', 
        'paraformer-8k-v2', 'Paraformer',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 8e-05, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'paraformer-v1', 'paraformer-v1', 
        'paraformer-v1', 'Paraformer',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 8e-05, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'paraformer-8k-v1', 'paraformer-8k-v1', 
        'paraformer-8k-v1', 'Paraformer',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 8e-05, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'paraformer-mtl-v1', 'paraformer-mtl-v1', 
        'paraformer-mtl-v1', 'Paraformer',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 8e-05, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'paraformer-realtime-v2', 'paraformer-realtime-v2', 
        'paraformer-realtime-v2', 'Paraformer',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 0.00024, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'paraformer-realtime-v1', 'paraformer-realtime-v1', 
        'paraformer-realtime-v1', 'Paraformer',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 0.00024, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'paraformer-realtime-8k-v2', 'paraformer-realtime-8k-v2', 
        'paraformer-realtime-8k-v2', 'Paraformer',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 0.00024, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'paraformer-realtime-8k-v1', 'paraformer-realtime-8k-v1', 
        'paraformer-realtime-8k-v1', 'Paraformer',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 0.00024, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'sensevoice-v1', 'sensevoice-v1', 
        'sensevoice-v1', 'SenseVoice',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 0.0007, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'fun-asr-realtime', 'fun-asr-realtime', 
        '实时语音识别 - fun-asr-realtime', '实时语音识别',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 0.00033, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'fun-asr-realtime-2025-11-07', 'fun-asr-realtime-2025-11-07', 
        '实时语音识别 - fun-asr-realtime-2025-11-07', '实时语音识别',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 0.00033, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'fun-asr-realtime-2025-09-15', 'fun-asr-realtime-2025-09-15', 
        '实时语音识别 - fun-asr-realtime-2025-09-15', '实时语音识别',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 0.00033, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, '模型名称', '模型名称', 
        '通义千问3-LiveTranslate-Flash-Realtime - 模型名称', '通义千问3-LiveTranslate-Flash-Realtime',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-livetranslate-flash-realtime', 'qwen3-livetranslate-flash-realtime', 
        '通义千问3-LiveTranslate-Flash-Realtime - qwen3-livetranslate-flash-realtime', '通义千问3-LiveTranslate-Flash-Realtime',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.008, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.24, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-livetranslate-flash-realtime-2025-09-22', 'qwen3-livetranslate-flash-realtime-2025-09-22', 
        '通义千问3-LiveTranslate-Flash-Realtime - qwen3-livetranslate-flash-realtime-2025-09-22', '通义千问3-LiveTranslate-Flash-Realtime',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.008, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.24, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-asr-flash-realtime', 'qwen3-asr-flash-realtime', 
        '通义千问ASR-Realtime - qwen3-asr-flash-realtime', '通义千问ASR-Realtime',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 0.00033, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-asr-flash-realtime-2025-10-27', 'qwen3-asr-flash-realtime-2025-10-27', 
        '通义千问ASR-Realtime - qwen3-asr-flash-realtime-2025-10-27', '通义千问ASR-Realtime',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 0.00033, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-asr-flash-filetrans', 'qwen3-asr-flash-filetrans', 
        '通义千问ASR - qwen3-asr-flash-filetrans', '通义千问ASR',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 0.00022, 
        '秒', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 0.0, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-asr-flash-filetrans-2025-11-17', 'qwen3-asr-flash-filetrans-2025-11-17', 
        '通义千问ASR - qwen3-asr-flash-filetrans-2025-11-17', '通义千问ASR',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 0.00022, 
        '秒', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 0.0, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-asr-flash', 'qwen3-asr-flash', 
        '通义千问ASR - qwen3-asr-flash', '通义千问ASR',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 0.00022, 
        '秒', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 0.0, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-asr-flash-2025-09-08', 'qwen3-asr-flash-2025-09-08', 
        '通义千问ASR - qwen3-asr-flash-2025-09-08', '通义千问ASR',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 0.00022, 
        '秒', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'audio_second', 0.0, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-audio-asr', 'qwen-audio-asr', 
        '通义千问ASR - qwen-audio-asr', '通义千问ASR',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0, 
        '千Token', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-audio-asr-latest', 'qwen-audio-asr-latest', 
        '通义千问ASR - qwen-audio-asr-latest', '通义千问ASR',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0, 
        '千Token', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-audio-asr-2024-12-04', 'qwen-audio-asr-2024-12-04', 
        '通义千问ASR - qwen-audio-asr-2024-12-04', '通义千问ASR',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0, 
        '千Token', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0, 
        '千Token', NULL, NULL, 
        NULL, NULL
    );

    -- 分类: video_gen
    SELECT id INTO v_category_id FROM pricing_category WHERE code = 'video_gen';

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'videoretalk', 'videoretalk', 
        '声动人像VideoRetalk - videoretalk', '声动人像VideoRetalk',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.08, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'emo-detect-v1', 'emo-detect-v1', 
        '悦动人像EMO - emo-detect-v1', '悦动人像EMO',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.004, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'emo-v1', 'emo-v1', 
        '悦动人像EMO - emo-v1', '悦动人像EMO',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 1.0, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'liveportrait-detect', 'liveportrait-detect', 
        '灵动人像LivePortrait - liveportrait-detect', '灵动人像LivePortrait',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.004, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'liveportrait', 'liveportrait', 
        '灵动人像LivePortrait - liveportrait', '灵动人像LivePortrait',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.02, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'animate-anyone-detect-gen2', 'animate-anyone-detect-gen2', 
        '舞动人像AnimateAnyone - animate-anyone-detect-gen2', '舞动人像AnimateAnyone',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.004, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'animate-anyone-template-gen2', 'animate-anyone-template-gen2', 
        '舞动人像AnimateAnyone - animate-anyone-template-gen2', '舞动人像AnimateAnyone',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.08, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'animate-anyone-gen2', 'animate-anyone-gen2', 
        '舞动人像AnimateAnyone - animate-anyone-gen2', '舞动人像AnimateAnyone',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.08, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'emoji-detect-v1', 'emoji-detect-v1', 
        '表情包Emoji - emoji-detect-v1', '表情包Emoji',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.004, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'emoji-v1', 'emoji-v1', 
        '表情包Emoji - emoji-v1', '表情包Emoji',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.08, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'text-embedding-v4', 'text-embedding-v4', 
        '视频风格重绘 - text-embedding-v4', '视频风格重绘',
        NULL, NULL, NULL,
        TRUE, FALSE,
        NULL, 'Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0005, 
        '元', NULL, NULL, 
        NULL, 'Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'text-embedding-v3', 'text-embedding-v3', 
        '视频风格重绘 - text-embedding-v3', '视频风格重绘',
        NULL, NULL, NULL,
        TRUE, FALSE,
        NULL, 'Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0005, 
        '元', NULL, NULL, 
        NULL, 'Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'text-embedding-v2', 'text-embedding-v2', 
        '视频风格重绘 - text-embedding-v2', '视频风格重绘',
        NULL, NULL, NULL,
        TRUE, FALSE,
        NULL, 'Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0007, 
        '元', NULL, NULL, 
        NULL, 'Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'text-embedding-v1', 'text-embedding-v1', 
        '视频风格重绘 - text-embedding-v1', '视频风格重绘',
        NULL, NULL, NULL,
        TRUE, FALSE,
        NULL, 'Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0007, 
        '元', NULL, NULL, 
        NULL, 'Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'text-embedding-async-v2', 'text-embedding-async-v2', 
        '视频风格重绘 - text-embedding-async-v2', '视频风格重绘',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0007, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'text-embedding-async-v1', 'text-embedding-async-v1', 
        '视频风格重绘 - text-embedding-async-v1', '视频风格重绘',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0007, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.6-r2v', 'wan2.6-r2v', 
        '通义万相-参考生视频 - wan2.6-r2v', '通义万相-参考生视频',
        NULL, NULL, '720P',
        FALSE, FALSE,
        NULL, '分辨率:720P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 720.0, 
        '元', NULL, NULL, 
        '720P', '分辨率:720P'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.6, 
        '秒', NULL, NULL, 
        '720P', '分辨率:720P'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.6, 
        '秒', NULL, NULL, 
        '720P', '分辨率:720P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.6-r2v', 'wan2.6-r2v', 
        '通义万相-参考生视频 - wan2.6-r2v', '通义万相-参考生视频',
        NULL, NULL, '1080P',
        FALSE, FALSE,
        NULL, '分辨率:1080P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 1080.0, 
        '元', NULL, NULL, 
        '1080P', '分辨率:1080P'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 1.0, 
        '秒', NULL, NULL, 
        '1080P', '分辨率:1080P'
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 1.0, 
        '秒', NULL, NULL, 
        '1080P', '分辨率:1080P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.2-animate-move', 'wan2.2-animate-move', 
        '通义万相-图生动作 - wan2.2-animate-move', '通义万相-图生动作',
        '标准模式wan-std', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:标准模式wan-std'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.4, 
        '秒', '标准模式wan-std', NULL, 
        NULL, '模式:标准模式wan-std'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.2-animate-move', 'wan2.2-animate-move', 
        '通义万相-图生动作 - wan2.2-animate-move', '通义万相-图生动作',
        '专业模式wan-pro', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:专业模式wan-pro'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.6, 
        '秒', '专业模式wan-pro', NULL, 
        NULL, '模式:专业模式wan-pro'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.2-kf2v-flash', 'wan2.2-kf2v-flash', 
        '通义万相-图生视频-基于首尾帧 - wan2.2-kf2v-flash', '通义万相-图生视频-基于首尾帧',
        NULL, NULL, '480P',
        FALSE, FALSE,
        NULL, '分辨率:480P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.1, 
        '秒', NULL, NULL, 
        '480P', '分辨率:480P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.2-kf2v-flash', 'wan2.2-kf2v-flash', 
        '通义万相-图生视频-基于首尾帧 - wan2.2-kf2v-flash', '通义万相-图生视频-基于首尾帧',
        NULL, NULL, '720P',
        FALSE, FALSE,
        NULL, '分辨率:720P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.2, 
        '秒', NULL, NULL, 
        '720P', '分辨率:720P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.2-kf2v-flash', 'wan2.2-kf2v-flash', 
        '通义万相-图生视频-基于首尾帧 - wan2.2-kf2v-flash', '通义万相-图生视频-基于首尾帧',
        NULL, NULL, '1080P',
        FALSE, FALSE,
        NULL, '分辨率:1080P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.48, 
        '秒', NULL, NULL, 
        '1080P', '分辨率:1080P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wanx2.1-kf2v-plus', 'wanx2.1-kf2v-plus', 
        '通义万相-图生视频-基于首尾帧 - wanx2.1-kf2v-plus', '通义万相-图生视频-基于首尾帧',
        NULL, NULL, '720P',
        FALSE, FALSE,
        NULL, '分辨率:720P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.7, 
        '秒', NULL, NULL, 
        '720P', '分辨率:720P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.6-i2v', 'wan2.6-i2v', 
        '通义万相-图生视频-基于首帧 - wan2.6-i2v', '通义万相-图生视频-基于首帧',
        NULL, NULL, '720P',
        FALSE, FALSE,
        NULL, '分辨率:720P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.6, 
        '秒', NULL, NULL, 
        '720P', '分辨率:720P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.6-i2v', 'wan2.6-i2v', 
        '通义万相-图生视频-基于首帧 - wan2.6-i2v', '通义万相-图生视频-基于首帧',
        NULL, NULL, '1080P',
        FALSE, FALSE,
        NULL, '分辨率:1080P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 1.0, 
        '秒', NULL, NULL, 
        '1080P', '分辨率:1080P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.5-i2v-preview', 'wan2.5-i2v-preview', 
        '通义万相-图生视频-基于首帧 - wan2.5-i2v-preview', '通义万相-图生视频-基于首帧',
        NULL, NULL, '480P',
        FALSE, FALSE,
        NULL, '分辨率:480P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.3, 
        '秒', NULL, NULL, 
        '480P', '分辨率:480P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.5-i2v-preview', 'wan2.5-i2v-preview', 
        '通义万相-图生视频-基于首帧 - wan2.5-i2v-preview', '通义万相-图生视频-基于首帧',
        NULL, NULL, '720P',
        FALSE, FALSE,
        NULL, '分辨率:720P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.6, 
        '秒', NULL, NULL, 
        '720P', '分辨率:720P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.5-i2v-preview', 'wan2.5-i2v-preview', 
        '通义万相-图生视频-基于首帧 - wan2.5-i2v-preview', '通义万相-图生视频-基于首帧',
        NULL, NULL, '1080P',
        FALSE, FALSE,
        NULL, '分辨率:1080P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 1.0, 
        '秒', NULL, NULL, 
        '1080P', '分辨率:1080P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.2-i2v-flash', 'wan2.2-i2v-flash', 
        '通义万相-图生视频-基于首帧 - wan2.2-i2v-flash', '通义万相-图生视频-基于首帧',
        NULL, NULL, '480P',
        FALSE, FALSE,
        NULL, '分辨率:480P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.1, 
        '秒', NULL, NULL, 
        '480P', '分辨率:480P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.2-i2v-flash', 'wan2.2-i2v-flash', 
        '通义万相-图生视频-基于首帧 - wan2.2-i2v-flash', '通义万相-图生视频-基于首帧',
        NULL, NULL, '720P',
        FALSE, FALSE,
        NULL, '分辨率:720P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.2, 
        '秒', NULL, NULL, 
        '720P', '分辨率:720P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.2-i2v-flash', 'wan2.2-i2v-flash', 
        '通义万相-图生视频-基于首帧 - wan2.2-i2v-flash', '通义万相-图生视频-基于首帧',
        NULL, NULL, '1080P',
        FALSE, FALSE,
        NULL, '分辨率:1080P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.48, 
        '秒', NULL, NULL, 
        '1080P', '分辨率:1080P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.2-i2v-plus', 'wan2.2-i2v-plus', 
        '通义万相-图生视频-基于首帧 - wan2.2-i2v-plus', '通义万相-图生视频-基于首帧',
        NULL, NULL, '480P',
        FALSE, FALSE,
        NULL, '分辨率:480P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.14, 
        '秒', NULL, NULL, 
        '480P', '分辨率:480P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.2-i2v-plus', 'wan2.2-i2v-plus', 
        '通义万相-图生视频-基于首帧 - wan2.2-i2v-plus', '通义万相-图生视频-基于首帧',
        NULL, NULL, '1080P',
        FALSE, FALSE,
        NULL, '分辨率:1080P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.7, 
        '秒', NULL, NULL, 
        '1080P', '分辨率:1080P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wanx2.1-i2v-turbo', 'wanx2.1-i2v-turbo', 
        '通义万相-图生视频-基于首帧 - wanx2.1-i2v-turbo', '通义万相-图生视频-基于首帧',
        NULL, NULL, '480P',
        FALSE, FALSE,
        NULL, '分辨率:480P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.24, 
        '秒', NULL, NULL, 
        '480P', '分辨率:480P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wanx2.1-i2v-turbo', 'wanx2.1-i2v-turbo', 
        '通义万相-图生视频-基于首帧 - wanx2.1-i2v-turbo', '通义万相-图生视频-基于首帧',
        NULL, NULL, '720P',
        FALSE, FALSE,
        NULL, '分辨率:720P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.24, 
        '秒', NULL, NULL, 
        '720P', '分辨率:720P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wanx2.1-i2v-plus', 'wanx2.1-i2v-plus', 
        '通义万相-图生视频-基于首帧 - wanx2.1-i2v-plus', '通义万相-图生视频-基于首帧',
        NULL, NULL, '720P',
        FALSE, FALSE,
        NULL, '分辨率:720P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.7, 
        '秒', NULL, NULL, 
        '720P', '分辨率:720P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.2-s2v-detect', 'wan2.2-s2v-detect', 
        '通义万相-数字人 - wan2.2-s2v-detect', '通义万相-数字人',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'image_count', 0.004, 
        '张', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.2-s2v', 'wan2.2-s2v', 
        '通义万相-数字人 - wan2.2-s2v', '通义万相-数字人',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 480.0, 
        '秒', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.6-t2v', 'wan2.6-t2v', 
        '通义万相-文生视频 - wan2.6-t2v', '通义万相-文生视频',
        NULL, NULL, '720P',
        FALSE, FALSE,
        NULL, '分辨率:720P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.6, 
        '秒', NULL, NULL, 
        '720P', '分辨率:720P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.6-t2v', 'wan2.6-t2v', 
        '通义万相-文生视频 - wan2.6-t2v', '通义万相-文生视频',
        NULL, NULL, '1080P',
        FALSE, FALSE,
        NULL, '分辨率:1080P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 1.0, 
        '秒', NULL, NULL, 
        '1080P', '分辨率:1080P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.5-t2v-preview', 'wan2.5-t2v-preview', 
        '通义万相-文生视频 - wan2.5-t2v-preview', '通义万相-文生视频',
        NULL, NULL, '480P',
        FALSE, FALSE,
        NULL, '分辨率:480P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.3, 
        '秒', NULL, NULL, 
        '480P', '分辨率:480P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.5-t2v-preview', 'wan2.5-t2v-preview', 
        '通义万相-文生视频 - wan2.5-t2v-preview', '通义万相-文生视频',
        NULL, NULL, '720P',
        FALSE, FALSE,
        NULL, '分辨率:720P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.6, 
        '秒', NULL, NULL, 
        '720P', '分辨率:720P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.5-t2v-preview', 'wan2.5-t2v-preview', 
        '通义万相-文生视频 - wan2.5-t2v-preview', '通义万相-文生视频',
        NULL, NULL, '1080P',
        FALSE, FALSE,
        NULL, '分辨率:1080P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 1.0, 
        '秒', NULL, NULL, 
        '1080P', '分辨率:1080P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.2-t2v-plus', 'wan2.2-t2v-plus', 
        '通义万相-文生视频 - wan2.2-t2v-plus', '通义万相-文生视频',
        NULL, NULL, '480P',
        FALSE, FALSE,
        NULL, '分辨率:480P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.14, 
        '秒', NULL, NULL, 
        '480P', '分辨率:480P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.2-t2v-plus', 'wan2.2-t2v-plus', 
        '通义万相-文生视频 - wan2.2-t2v-plus', '通义万相-文生视频',
        NULL, NULL, '1080P',
        FALSE, FALSE,
        NULL, '分辨率:1080P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.7, 
        '秒', NULL, NULL, 
        '1080P', '分辨率:1080P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wanx2.1-t2v-turbo', 'wanx2.1-t2v-turbo', 
        '通义万相-文生视频 - wanx2.1-t2v-turbo', '通义万相-文生视频',
        NULL, NULL, '480P',
        FALSE, FALSE,
        NULL, '分辨率:480P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.24, 
        '秒', NULL, NULL, 
        '480P', '分辨率:480P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wanx2.1-t2v-turbo', 'wanx2.1-t2v-turbo', 
        '通义万相-文生视频 - wanx2.1-t2v-turbo', '通义万相-文生视频',
        NULL, NULL, '720P',
        FALSE, FALSE,
        NULL, '分辨率:720P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.24, 
        '秒', NULL, NULL, 
        '720P', '分辨率:720P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wanx2.1-t2v-plus', 'wanx2.1-t2v-plus', 
        '通义万相-文生视频 - wanx2.1-t2v-plus', '通义万相-文生视频',
        NULL, NULL, '720P',
        FALSE, FALSE,
        NULL, '分辨率:720P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.7, 
        '秒', NULL, NULL, 
        '720P', '分辨率:720P'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.2-animate-mix', 'wan2.2-animate-mix', 
        '通义万相-视频换人 - wan2.2-animate-mix', '通义万相-视频换人',
        '标准模式wan-std', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:标准模式wan-std'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.6, 
        '秒', '标准模式wan-std', NULL, 
        NULL, '模式:标准模式wan-std'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wan2.2-animate-mix', 'wan2.2-animate-mix', 
        '通义万相-视频换人 - wan2.2-animate-mix', '通义万相-视频换人',
        '专业模式wan-pro', NULL, NULL,
        FALSE, FALSE,
        NULL, '模式:专业模式wan-pro'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.9, 
        '秒', '专业模式wan-pro', NULL, 
        NULL, '模式:专业模式wan-pro'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'wanx2.1-vace-plus', 'wanx2.1-vace-plus', 
        '通义万相-通用视频编辑 - wanx2.1-vace-plus', '通义万相-通用视频编辑',
        NULL, NULL, '720P',
        FALSE, FALSE,
        NULL, '分辨率:720P'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'video_second', 0.7, 
        '秒', NULL, NULL, 
        '720P', '分辨率:720P'
    );

    -- 分类: text_embedding
    SELECT id INTO v_category_id FROM pricing_category WHERE code = 'text_embedding';

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'text-embedding-v4', 'text-embedding-v4', 
        '文本向量 - text-embedding-v4', '文本向量',
        NULL, NULL, NULL,
        TRUE, FALSE,
        NULL, 'Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0005, 
        '元', NULL, NULL, 
        NULL, 'Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'text-embedding-v3', 'text-embedding-v3', 
        '文本向量 - text-embedding-v3', '文本向量',
        NULL, NULL, NULL,
        TRUE, FALSE,
        NULL, 'Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0005, 
        '元', NULL, NULL, 
        NULL, 'Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'text-embedding-v2', 'text-embedding-v2', 
        '文本向量 - text-embedding-v2', '文本向量',
        NULL, NULL, NULL,
        TRUE, FALSE,
        NULL, 'Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0007, 
        '元', NULL, NULL, 
        NULL, 'Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'text-embedding-v1', 'text-embedding-v1', 
        '文本向量 - text-embedding-v1', '文本向量',
        NULL, NULL, NULL,
        TRUE, FALSE,
        NULL, 'Batch调用半价'
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0007, 
        '元', NULL, NULL, 
        NULL, 'Batch调用半价'
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'text-embedding-async-v2', 'text-embedding-async-v2', 
        '文本向量 - text-embedding-async-v2', '文本向量',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0007, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'text-embedding-async-v1', 'text-embedding-async-v1', 
        '文本向量 - text-embedding-async-v1', '文本向量',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0007, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    -- 分类: multimodal_embedding
    SELECT id INTO v_category_id FROM pricing_category WHERE code = 'multimodal_embedding';

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen2.5-vl-embedding', 'qwen2.5-vl-embedding', 
        '多模态向量 - qwen2.5-vl-embedding', '多模态向量',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_price', 0.0007, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token_image', 0.0018, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'tongyi-embedding-vision-plus', 'tongyi-embedding-vision-plus', 
        '多模态向量 - tongyi-embedding-vision-plus', '多模态向量',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_price', 0.0005, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token_image', 0.0005, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'tongyi-embedding-vision-flash', 'tongyi-embedding-vision-flash', 
        '多模态向量 - tongyi-embedding-vision-flash', '多模态向量',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_price', 0.00015, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token_image', 0.00015, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'multimodal-embedding-v1', 'multimodal-embedding-v1', 
        '多模态向量 - multimodal-embedding-v1', '多模态向量',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_price', 0.0007, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token_image', 0.0009, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    -- 分类: text_nlu
    SELECT id INTO v_category_id FROM pricing_category WHERE code = 'text_nlu';

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'opennlu-v1', 'opennlu-v1', 
        'opennlu-v1', 'OpenNLU',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.00465, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen3-rerank', 'qwen3-rerank', 
        '文本排序模型 - qwen3-rerank', '文本排序模型',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0005, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'gte-rerank-v2', 'gte-rerank-v2', 
        '文本排序模型 - gte-rerank-v2', '文本排序模型',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0008, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    -- 分类: industry
    SELECT id INTO v_category_id FROM pricing_category WHERE code = 'industry';

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'tongyi-intent-detect-v3', 'tongyi-intent-detect-v3', 
        '意图理解 - tongyi-intent-detect-v3', '意图理解',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0004, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.001, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'gui-plus', 'gui-plus', 
        '界面交互 - gui-plus', '界面交互',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0015, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.0045, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'qwen-plus-character', 'qwen-plus-character', 
        '角色扮演 - qwen-plus-character', '角色扮演',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.0008, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.002, 
        '元', NULL, NULL, 
        NULL, NULL
    );

    INSERT INTO pricing_model (
        snapshot_id, category_id, model_code, model_name, display_name, sub_category,
        mode, token_tier, resolution, supports_batch, supports_cache, remark, rule_text
    ) VALUES (
        v_snapshot_id, v_category_id, 'farui-plus', 'farui-plus', 
        '通义法睿 - farui-plus', '通义法睿',
        NULL, NULL, NULL,
        FALSE, FALSE,
        NULL, NULL
    ) RETURNING id INTO v_model_id;
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'input_token', 0.02, 
        '元', NULL, NULL, 
        NULL, NULL
    );
    INSERT INTO pricing_model_price (
        snapshot_id, model_id, dimension_code, unit_price, unit, mode, token_tier, resolution, rule_text
    ) VALUES (
        v_snapshot_id, v_model_id, 'output_token', 0.02, 
        '元', NULL, NULL, 
        NULL, NULL
    );

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
