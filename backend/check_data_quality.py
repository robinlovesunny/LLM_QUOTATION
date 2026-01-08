#!/usr/bin/env python3
"""检查解析数据质量"""
import json

with open('bailian_models.json', 'r') as f:
    data = json.load(f)

print('=' * 70)
print('数据质量检查报告')
print('=' * 70)

# 检查 specs 数值
print('\n📊 specs 数值检查:')
issues = []
for m in data['models']:
    specs = m.get('specs')
    if specs:
        for key, val in specs.items():
            if isinstance(val, int) and val > 100_000_000:
                issues.append(f"  - {m['model_id']}: {key} = {val}")
if issues:
    print('\n'.join(issues))
else:
    print('  ✅ 所有 specs 数值在合理范围内')

# 检查 model_name 是否包含描述
print('\n📊 model_name 检查:')
desc_markers = ['当前', '又称', 'Batch', '始终', '相比', '基于', '享有', '满血', '蒸馏']
issues = []
for m in data['models']:
    name = m.get('model_name', '')
    for marker in desc_markers:
        if marker in name:
            issues.append(f"  - {m['model_id']}: name='{name}'")
            break
if issues:
    print('\n'.join(issues[:10]))
else:
    print('  ✅ 所有 model_name 已清理干净')

# 检查 model_id 是否完整
print('\n📊 model_id 检查:')
issues = []
for m in data['models']:
    mid = m.get('model_id', '')
    if mid.endswith('.') or mid.endswith('-') or len(mid) < 5:
        issues.append(f"  - '{mid}' (不完整)")
if issues:
    print('\n'.join(issues))
else:
    print('  ✅ 所有 model_id 格式正确')

# 统计
print('\n📊 统计信息:')
print(f"  - 总模型数: {len(data['models'])}")
with_price = sum(1 for m in data['models'] if m.get('pricing'))
print(f"  - 有价格数据: {with_price}")
with_specs = sum(1 for m in data['models'] if m.get('specs'))
print(f"  - 有规格数据: {with_specs}")

# 显示示例模型
print('\n📝 示例模型:')
for m in data['models'][:5]:
    print(f"\n  [{m['model_id']}]")
    print(f"    name: {m['model_name']}")
    print(f"    vendor: {m.get('vendor')}")
    print(f"    specs: {m.get('specs')}")
    pricing = m.get('pricing', [])
    if pricing:
        p = pricing[0]
        inp = p.get('input_price', {}).get('price', 'N/A')
        out = p.get('output_price', {}).get('price', 'N/A')
        print(f"    price: input={inp}, output={out}")
    else:
        print(f"    price: 无定价")
