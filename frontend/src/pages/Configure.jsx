import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { getModels, getModelPricing } from '../api';
import StepIndicator from '../components/StepIndicator';

function Configure() {
  const { modelId } = useParams();
  const navigate = useNavigate();
  const [categoryCode, setCategoryCode] = useState('');
  const [modelFamily, setModelFamily] = useState([]);
  const [selectedModelId, setSelectedModelId] = useState(modelId);
  const [selectedModel, setSelectedModel] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadInitialData();
  }, [modelId]);

  useEffect(() => {
    if (selectedModelId) {
      loadModelDetails();
    }
  }, [selectedModelId]);

  const loadInitialData = async () => {
    try {
      // 先获取初始模型信息，获取其category_code
      const response = await getModelPricing(modelId);
      const initialModel = response.data;
      setSelectedModel(initialModel);
      
      // 提取类目代码（从scategory字段解析）
      if (initialModel.category_code) {
        setCategoryCode(initialModel.category_code);
      }
      
      // 加载同族模型
      loadModelFamily(initialModel.model_name);
    } catch (error) {
      console.error('加载初始数据失败:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadModelFamily = async (baseName) => {
    try {
      // 这里需要一个新的API来获取同族模型
      // 暂时使用模拟数据
      const familyModels = [
        {
          id: 1,
          name: 'qwen3-max',
          displayName: 'qwen3-max',
          mode: '仅非思考模式',
          tokenLimit: '0-32K / 32K-128K / 128K-252K',
          inputPrices: [0.0032, 0.0064, 0.0096],
          outputPrices: [0.0128, 0.0256, 0.0384]
        },
        {
          id: 2,
          name: 'qwen3-max-2025-09-23',
          displayName: 'qwen3-max-2025-09-23',
          mode: '仅非思考模式',
          tokenLimit: '0-32K / 32K-128K / 128K-252K',
          inputPrices: [0.006, 0.01, 0.015],
          outputPrices: [0.024, 0.04, 0.06]
        },
        {
          id: 3,
          name: 'qwen3-max-preview',
          displayName: 'qwen3-max-preview',
          mode: '非思考和思考模式',
          tokenLimit: '0-32K / 32K-128K / 128K-252K',
          inputPrices: [0.006, 0.01, 0.015],
          outputPrices: [0.024, 0.04, 0.06]
        }
      ];
      setModelFamily(familyModels);
    } catch (error) {
      console.error('加载模型族失败:', error);
    }
  };

  const loadModelDetails = async () => {
    try {
      const response = await getModelPricing(selectedModelId);
      setSelectedModel(response.data);
    } catch (error) {
      console.error('加载模型详情失败:', error);
    }
  };

  const handleModelChange = (modelId) => {
    setSelectedModelId(modelId);
  };

  if (loading) {
    return <div className="text-center py-12">加载中...</div>;
  }

  return (
    <div className="max-w-4xl mx-auto">
      {/* 步骤指示器 */}
      <StepIndicator 
        currentStep="config" 
        categoryCode={categoryCode}
        modelId={modelId} 
      />
      
      <button
        onClick={() => categoryCode ? navigate(`/select-model/${categoryCode}`) : navigate(-1)}
        className="text-text-secondary hover:text-text-primary mb-6 flex items-center gap-1"
      >
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
        </svg>
        返回选择模型
      </button>

      <div className="bg-white rounded-xl shadow-sm p-6 space-y-6">
        {/* 页面标题 */}
        <div>
          <h2 className="text-2xl font-semibold text-text-primary mb-2">
            模型配置
          </h2>
          <p className="text-text-secondary text-sm">
            选择具体模型查看计费参数
          </p>
        </div>

        {/* 模型选择 */}
        <div>
          <label className="block text-sm font-medium text-text-primary mb-3">
            选择模型 *
          </label>
          <div className="grid grid-cols-1 gap-3">
            {modelFamily.map((model) => (
              <div
                key={model.id}
                onClick={() => handleModelChange(model.id)}
                className={`p-4 border-2 rounded-lg cursor-pointer transition-all ${
                  selectedModelId === model.id
                    ? 'border-primary bg-blue-50'
                    : 'border-border hover:border-primary/50'
                }`}
              >
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <div className="font-medium text-text-primary mb-1">
                      {model.displayName}
                    </div>
                    <div className="text-sm text-text-secondary">
                      模式: {model.mode}
                    </div>
                  </div>
                  {selectedModelId === model.id && (
                    <div className="text-primary">
                      <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 20 20">
                        <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                      </svg>
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* 计费参数展示 */}
        {selectedModel && (
          <div className="border-t border-border pt-6">
            <h3 className="font-medium text-text-primary mb-4">计费参数</h3>
            <div className="bg-secondary rounded-lg p-4">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border">
                    <th className="text-left py-2 px-3 text-text-secondary font-medium">参数</th>
                    <th className="text-left py-2 px-3 text-text-secondary font-medium">值</th>
                  </tr>
                </thead>
                <tbody>
                  {selectedModel.prices && selectedModel.prices.map((price, idx) => (
                    <tr key={idx} className="border-b border-border last:border-0">
                      <td className="py-3 px-3 text-text-primary">
                        {price.dimension_name}
                      </td>
                      <td className="py-3 px-3">
                        <div className="text-text-primary font-medium">
                          ¥{price.unit_price} / {price.unit}
                        </div>
                        {price.rule_text && (
                          <div className="text-xs text-text-secondary mt-1">
                            {price.rule_text}
                          </div>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {/* 说明信息 */}
            <div className="mt-4 p-3 bg-blue-50 rounded-lg">
              <div className="flex items-start gap-2">
                <svg className="w-5 h-5 text-blue-600 flex-shrink-0 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clipRule="evenodd" />
                </svg>
                <div className="text-sm text-blue-900">
                  <p className="font-medium mb-1">计费说明</p>
                  <ul className="list-disc list-inside space-y-1 text-blue-800">
                    <li>按实际使用的Token数量计费</li>
                    <li>不同Token区间可能有不同单价（阶梯定价）</li>
                    <li>具体费用根据实际调用情况计算</li>
                  </ul>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default Configure;
