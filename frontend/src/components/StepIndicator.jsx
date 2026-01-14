/**
 * 步骤指示器组件
 * @description 显示报价流程的步骤进度，支持点击返回上一步
 */
import React from 'react';
import { useNavigate } from 'react-router-dom';

/**
 * 步骤配置
 */
const STEPS = [
  { key: 'model', label: '模型选择', path: '/select-model' },
  { key: 'config', label: '模型配置', path: '/configure' },
  { key: 'price', label: '价格清单', path: '/quote/step1' }
];

/**
 * 步骤指示器组件
 * @param {Object} props - 组件属性
 * @param {string} props.currentStep - 当前步骤 ('model' | 'config' | 'price')
 * @param {string} props.categoryCode - 类目代码（用于返回模型选择页）
 * @param {string} props.modelId - 模型ID（用于返回配置页）
 * @returns {JSX.Element}
 */
function StepIndicator({ currentStep, categoryCode, modelId }) {
  const navigate = useNavigate();
  
  // 获取当前步骤索引
  const currentIndex = STEPS.findIndex(s => s.key === currentStep);
  
  /**
   * 处理步骤点击
   * @param {number} stepIndex - 点击的步骤索引
   */
  const handleStepClick = (stepIndex) => {
    // 只能点击已完成的步骤（返回上一步）
    if (stepIndex >= currentIndex) return;
    
    const step = STEPS[stepIndex];
    
    // 根据步骤类型导航到对应页面
    if (step.key === 'model' && categoryCode) {
      navigate(`/select-model/${categoryCode}`);
    } else if (step.key === 'config' && modelId) {
      navigate(`/configure/${modelId}`);
    }
  };

  return (
    <div className="flex items-center justify-center mb-8">
      <div className="flex items-center gap-0">
        {STEPS.map((step, index) => {
          const isCompleted = index < currentIndex;
          const isCurrent = index === currentIndex;
          const isClickable = index < currentIndex;
          
          return (
            <React.Fragment key={step.key}>
              {/* 步骤项 */}
              <button
                onClick={() => handleStepClick(index)}
                disabled={!isClickable}
                className={`
                  flex items-center gap-2 px-4 py-2 rounded-lg transition-all
                  ${isClickable 
                    ? 'cursor-pointer hover:bg-secondary' 
                    : 'cursor-default'
                  }
                `}
              >
                {/* 步骤图标/数字 */}
                <span 
                  className={`
                    w-6 h-6 rounded-full flex items-center justify-center text-sm font-medium transition-all
                    ${isCompleted 
                      ? 'bg-primary text-white' 
                      : isCurrent 
                        ? 'bg-primary text-white' 
                        : 'bg-secondary text-text-secondary'
                    }
                  `}
                >
                  {isCompleted ? (
                    <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                    </svg>
                  ) : (
                    index + 1
                  )}
                </span>
                
                {/* 步骤标签 */}
                <span 
                  className={`
                    text-sm font-medium transition-all
                    ${isCompleted 
                      ? 'text-primary' 
                      : isCurrent 
                        ? 'text-primary' 
                        : 'text-text-secondary'
                    }
                  `}
                >
                  {step.label}
                </span>
              </button>
              
              {/* 连接线 */}
              {index < STEPS.length - 1 && (
                <div 
                  className={`
                    w-12 h-0.5 transition-all
                    ${index < currentIndex 
                      ? 'bg-primary' 
                      : 'bg-border'
                    }
                  `}
                />
              )}
            </React.Fragment>
          );
        })}
      </div>
    </div>
  );
}

export default StepIndicator;
