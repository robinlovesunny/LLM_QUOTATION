/**
 * 步骤2 - 参数配置页面
 * @description 报价流程第二步：为每个选中的模型选择具体的参数配置
 * 包括：模式（思考/非思考）、Token阶梯、分辨率、Batch支持等
 */
import React, { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { getModelPricingDetail } from '../api';

function QuoteStep2() {
  const navigate = useNavigate();
  
  // 从上一步获取的模型列表
  const [selectedModels, setSelectedModels] = useState([]);
  
  // 每个模型的变体选项：model_code -> variants[]
  const [variantsMap, setVariantsMap] = useState({});
  
  // 每个模型选中的配置：model_code -> { variantIds: [], variants: [] }
  const [modelConfigs, setModelConfigs] = useState({});
  
  // 加载状态
  const [loading, setLoading] = useState(true);
  
  // 当前展开的模型
  const [expandedModel, setExpandedModel] = useState(null);
  
  // 下拉引用
  const dropdownRefs = useRef({});

  useEffect(() => {
    loadStep1Data();
  }, []);

  // 点击外部关闭下拉
  useEffect(() => {
    const handleClickOutside = (event) => {
      if (expandedModel !== null) {
        const ref = dropdownRefs.current[expandedModel];
        if (ref && !ref.contains(event.target)) {
          setExpandedModel(null);
        }
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [expandedModel]);

  /**
   * 加载Step1数据并获取每个模型的变体
   */
  const loadStep1Data = async () => {
    const step1Data = sessionStorage.getItem('quoteStep1');
    if (!step1Data) {
      navigate('/quote/step1');
      return;
    }

    const { selectedModels: models } = JSON.parse(step1Data);
    if (!models || models.length === 0) {
      navigate('/quote/step1');
      return;
    }

    setSelectedModels(models);
    await loadModelVariants(models);
  };

  /**
   * 加载模型变体
   */
  const loadModelVariants = async (models) => {
    setLoading(true);
    const variants = {};
    const configs = {};

    const promises = models.map(async (model) => {
      try {
        const response = await getModelPricingDetail(model.model_code);
        if (response.data && response.data.found) {
          variants[model.model_code] = response.data.variants || [];
        } else {
          variants[model.model_code] = [];
        }
      } catch (error) {
        console.error(`获取模型 ${model.model_code} 变体失败:`, error);
        variants[model.model_code] = [];
      }
      configs[model.model_code] = { variantIds: [], variants: [] };
    });

    await Promise.all(promises);
    setVariantsMap(variants);
    setModelConfigs(configs);
    setLoading(false);
    
    // 恢复之前保存的配置
    const step2Data = sessionStorage.getItem('quoteStep2');
    if (step2Data) {
      const { modelConfigs: savedConfigs } = JSON.parse(step2Data);
      if (savedConfigs) {
        setModelConfigs(prev => ({ ...prev, ...savedConfigs }));
      }
    }
  };

  /**
   * 切换变体选择
   */
  const handleToggleVariant = (modelCode, variant) => {
    setModelConfigs(prev => {
      const current = prev[modelCode] || { variantIds: [], variants: [] };
      const isSelected = current.variantIds.includes(variant.id);
      
      if (isSelected) {
        return {
          ...prev,
          [modelCode]: {
            variantIds: current.variantIds.filter(id => id !== variant.id),
            variants: current.variants.filter(v => v.id !== variant.id)
          }
        };
      } else {
        return {
          ...prev,
          [modelCode]: {
            variantIds: [...current.variantIds, variant.id],
            variants: [...current.variants, variant]
          }
        };
      }
    });
  };

  /**
   * 检查模型的所有变体是否已全选
   */
  const isModelAllVariantsSelected = (modelCode) => {
    const variants = variantsMap[modelCode] || [];
    const config = modelConfigs[modelCode] || { variantIds: [], variants: [] };
    if (variants.length === 0) return false;
    return variants.every(v => config.variantIds.includes(v.id));
  };

  /**
   * 全选模型的所有变体
   */
  const handleSelectAllVariants = (modelCode) => {
    const variants = variantsMap[modelCode] || [];
    setModelConfigs(prev => ({
      ...prev,
      [modelCode]: {
        variantIds: variants.map(v => v.id),
        variants: variants
      }
    }));
  };

  /**
   * 取消模型的所有变体选择
   */
  const handleDeselectAllVariants = (modelCode) => {
    setModelConfigs(prev => ({
      ...prev,
      [modelCode]: {
        variantIds: [],
        variants: []
      }
    }));
  };

  /**
   * 获取价格显示
   */
  const getPriceDisplay = (prices) => {
    if (!prices || prices.length === 0) return '暂无价格';
    const input = prices.find(p => p.dimension_code === 'input' || p.dimension_code === 'input_token');
    const output = prices.find(p => p.dimension_code === 'output' || p.dimension_code === 'output_token' || p.dimension_code === 'output_token_thinking');
    
    if (input && output) {
      return `输入¥${input.unit_price} / 输出¥${output.unit_price}`;
    } else if (output) {
      return `¥${output.unit_price}/${output.unit}`;
    } else if (input) {
      return `¥${input.unit_price}/${input.unit}`;
    }
    return `¥${prices[0].unit_price}/${prices[0].unit}`;
  };

  /**
   * 获取选中配置的摘要文本
   */
  const getSelectedSummary = (modelCode) => {
    const config = modelConfigs[modelCode];
    if (!config || config.variants.length === 0) {
      return '请选择配置';
    }
    if (config.variants.length === 1) {
      const v = config.variants[0];
      let text = v.model_name;
      if (v.mode) text += ` (${v.mode})`;
      if (v.token_tier) text += ` [${v.token_tier}]`;
      return text;
    }
    return `已选择 ${config.variants.length} 个配置`;
  };

  /**
   * 下一步
   */
  const handleNext = () => {
    sessionStorage.setItem('quoteStep2', JSON.stringify({ modelConfigs }));
    navigate('/quote/step3');
  };

  /**
   * 上一步
   */
  const handlePrev = () => {
    sessionStorage.setItem('quoteStep2', JSON.stringify({ modelConfigs }));
    navigate('/quote/step1');
  };

  /**
   * 解析 rule_text 提取关键信息
   */
  const parseRuleText = (ruleText) => {
    if (!ruleText) return { mode: null, tokenTier: null, extras: [] };
    
    const result = { mode: null, tokenTier: null, extras: [] };
    const parts = ruleText.split(' | ');
    
    for (const part of parts) {
      if (part.startsWith('模式:')) {
        result.mode = part.replace('模式:', '');
      } else if (part.startsWith('Token范围:')) {
        result.tokenTier = part.replace('Token范围:', '');
      } else if (part.startsWith('备注:')) {
        // 备注可能包含多个特性，用 | 分隔
        const remarks = part.replace('备注:', '').split(' | ');
        result.extras.push(...remarks);
      } else if (part.includes('Batch') || part.includes('缓存')) {
        result.extras.push(part);
      }
    }
    
    return result;
  };

  /**
   * 渲染变体卡片
   */
  const renderVariantCard = (variant, isSelected, onClick) => {
    return (
      <div
        key={variant.id}
        onClick={onClick}
        className={`p-3 border-2 rounded-lg cursor-pointer transition-all ${
          isSelected
            ? 'border-primary bg-blue-50'
            : 'border-border hover:border-primary/50'
        }`}
      >
        <div className="flex items-start justify-between mb-2">
          <span className="text-sm font-medium text-text-primary">
            {variant.model_name}
          </span>
          {isSelected && (
            <svg className="w-5 h-5 text-primary flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
              <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
            </svg>
          )}
        </div>
        
        {/* 配置标签 */}
        <div className="flex flex-wrap gap-1.5 mb-2">
          {/* 优先显示结构化字段，如果没有则从 rule_text 解析 */}
          {(() => {
            const parsed = parseRuleText(variant.rule_text);
            const mode = variant.mode || parsed.mode;
            const tokenTier = variant.token_tier || parsed.tokenTier;
            
            return (
              <>
                {mode && (
                  <span className="px-2 py-0.5 bg-amber-100 text-amber-700 text-xs rounded">
                    {mode}
                  </span>
                )}
                {tokenTier && (
                  <span className="px-2 py-0.5 bg-blue-100 text-blue-700 text-xs rounded">
                    {tokenTier}
                  </span>
                )}
                {variant.resolution && (
                  <span className="px-2 py-0.5 bg-purple-100 text-purple-700 text-xs rounded">
                    {variant.resolution}
                  </span>
                )}
                {variant.supports_batch && (
                  <span className="px-2 py-0.5 bg-green-100 text-green-700 text-xs rounded">
                    Batch半价
                  </span>
                )}
                {variant.supports_cache && (
                  <span className="px-2 py-0.5 bg-orange-100 text-orange-700 text-xs rounded">
                    支持缓存
                  </span>
                )}
              </>
            );
          })()}
        </div>
        
        {/* 价格 */}
        <div className="text-sm text-primary font-medium">
          {getPriceDisplay(variant.prices)}
        </div>
        
        {/* 备注 */}
        {variant.remark && (
          <div className="text-xs text-text-secondary mt-1 truncate" title={variant.remark}>
            {variant.remark}
          </div>
        )}
      </div>
    );
  };

  return (
    <div className="max-w-4xl mx-auto">
      {/* 步骤进度条 */}
      <div className="flex items-center justify-center mb-8">
        <div className="flex items-center">
          <span className="text-text-secondary">模型选择</span>
          <div className="w-24 h-px bg-border mx-4"></div>
          <span className="text-primary font-medium">参数配置</span>
          <div className="w-24 h-px bg-border mx-4"></div>
          <span className="text-text-secondary">价格清单</span>
        </div>
      </div>

      {loading ? (
        <div className="text-center py-12 text-text-secondary">加载配置选项中...</div>
      ) : (
        <>
          {/* 提示信息 */}
          <div className="p-4 bg-blue-50 rounded-lg mb-6">
            <div className="flex items-start gap-3">
              <svg className="w-5 h-5 text-blue-600 flex-shrink-0 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clipRule="evenodd" />
              </svg>
              <div>
                <p className="text-sm text-blue-900 font-medium">为 {selectedModels.length} 个模型配置参数</p>
                <p className="text-sm text-blue-800 mt-1">
                  请选择每个模型的具体配置（模式、Token阶梯等），支持多选
                </p>
              </div>
            </div>
          </div>

          {/* 模型配置列表 */}
          <div className="space-y-4">
            {selectedModels.map(model => {
              const variants = variantsMap[model.model_code] || [];
              const config = modelConfigs[model.model_code] || { variantIds: [], variants: [] };
              const isExpanded = expandedModel === model.model_code;
              
              return (
                <div 
                  key={model.model_code}
                  className="bg-white border border-border rounded-xl p-4"
                  ref={el => dropdownRefs.current[model.model_code] = el}
                >
                  {/* 模型标题 */}
                  <div className="flex items-center justify-between mb-3">
                    <div>
                      <h3 className="text-base font-medium text-text-primary">
                        {model.model_code || model.model_name}
                      </h3>
                      <p className="text-xs text-text-secondary">{model.model_code}</p>
                    </div>
                    <div className="flex items-center gap-3">
                      <span className="text-xs text-text-secondary">
                        {variants.length} 个配置可选
                      </span>
                      {variants.length > 1 && (
                        isModelAllVariantsSelected(model.model_code) ? (
                          <button
                            onClick={() => handleDeselectAllVariants(model.model_code)}
                            className="text-xs text-red-500 hover:text-red-600 flex items-center gap-1 transition-colors"
                          >
                            <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                            </svg>
                            取消全选
                          </button>
                        ) : (
                          <button
                            onClick={() => handleSelectAllVariants(model.model_code)}
                            className="text-xs text-primary hover:text-primary/80 flex items-center gap-1 transition-colors"
                          >
                            <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                            </svg>
                            全选
                          </button>
                        )
                      )}
                    </div>
                  </div>
                  
                  {/* 配置选择器 */}
                  <div className="relative">
                    <button
                      type="button"
                      onClick={() => setExpandedModel(isExpanded ? null : model.model_code)}
                      className={`w-full px-4 py-3 bg-secondary border rounded-lg text-left flex items-center justify-between transition-all ${
                        isExpanded ? 'border-primary ring-2 ring-primary/20' : 'border-border hover:border-primary/50'
                      } ${config.variants.length > 0 ? 'text-text-primary' : 'text-text-secondary'}`}
                    >
                      <span className="text-sm truncate">
                        {getSelectedSummary(model.model_code)}
                      </span>
                      <svg 
                        className={`w-5 h-5 text-text-secondary transition-transform ${isExpanded ? 'rotate-180' : ''}`} 
                        fill="none" 
                        stroke="currentColor" 
                        viewBox="0 0 24 24"
                      >
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                      </svg>
                    </button>
                    
                    {/* 下拉配置列表 */}
                    {isExpanded && variants.length > 0 && (
                      <div className="absolute z-20 w-full mt-2 bg-white border border-border rounded-xl shadow-lg max-h-80 overflow-y-auto">
                        <div className="p-3">
                          <div className="flex items-center justify-between mb-2 pb-2 border-b border-border">
                            <span className="text-xs text-text-secondary">点击选择配置（支持多选）</span>
                            <button
                              onClick={() => setExpandedModel(null)}
                              className="text-xs text-primary hover:text-primary/80"
                            >
                              完成
                            </button>
                          </div>
                          <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
                            {variants.map(variant => 
                              renderVariantCard(
                                variant,
                                config.variantIds.includes(variant.id),
                                () => handleToggleVariant(model.model_code, variant)
                              )
                            )}
                          </div>
                        </div>
                      </div>
                    )}
                    
                    {variants.length === 0 && (
                      <p className="text-xs text-text-secondary mt-2">该模型暂无可用配置</p>
                    )}
                  </div>
                  
                  {/* 已选配置预览 */}
                  {config.variants.length > 0 && !isExpanded && (
                    <div className="mt-3 flex flex-wrap gap-2">
                      {config.variants.slice(0, 3).map(v => (
                        <span key={v.id} className="px-2 py-1 bg-blue-50 text-primary text-xs rounded">
                          {v.mode || ''} {v.token_tier || ''} {v.resolution || ''} - {getPriceDisplay(v.prices)}
                        </span>
                      ))}
                      {config.variants.length > 3 && (
                        <span className="px-2 py-1 bg-secondary text-text-secondary text-xs rounded">
                          +{config.variants.length - 3} 更多
                        </span>
                      )}
                    </div>
                  )}
                </div>
              );
            })}
          </div>

          {/* 底部按钮 */}
          <div className="bg-white border border-border rounded-xl p-6 mt-6">
            <div className="flex justify-center gap-4">
              <button
                onClick={handlePrev}
                className="px-8 py-3 bg-white text-primary border border-primary rounded-lg font-medium hover:bg-secondary transition-all"
              >
                上一步
              </button>
              <button
                onClick={handleNext}
                className="px-8 py-3 bg-primary text-white rounded-lg font-medium hover:bg-opacity-90 transition-all"
              >
                下一步：查看报价
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  );
}

export default QuoteStep2;
