"""add_debate_list_table

Revision ID: e8afbb20c4d6
Revises: 6a20075815bd
Create Date: 2026-01-16 19:33:06.879884

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'e8afbb20c4d6'
down_revision: Union[str, None] = '6a20075815bd'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 创建 debate_list 表
    op.create_table(
        'debate_list',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('qwen_model_name', sa.String(length=200), nullable=False, comment='阿里云模型准确名称'),
        sa.Column('qwen_display_name', sa.String(length=200), nullable=True, comment='阿里云模型显示名称'),
        sa.Column('doubao_input_model_name', sa.String(length=200), nullable=False, comment='豆包输入价格模型名称'),
        sa.Column('doubao_output_model_name', sa.String(length=200), nullable=False, comment='豆包输出价格模型名称'),
        sa.Column('is_active', sa.Boolean(), nullable=True, default=True, comment='是否激活'),
        sa.Column('created_at', sa.DateTime(), nullable=True, server_default=sa.text('now()'), comment='创建时间'),
        sa.Column('updated_at', sa.DateTime(), nullable=True, server_default=sa.text('now()'), comment='更新时间'),
        sa.PrimaryKeyConstraint('id')
    )
    # 创建索引
    op.create_index('ix_debate_list_qwen', 'debate_list', ['qwen_model_name'], unique=False)
    op.create_index('ix_debate_list_doubao_input', 'debate_list', ['doubao_input_model_name'], unique=False)


def downgrade() -> None:
    # 删除索引
    op.drop_index('ix_debate_list_doubao_input', table_name='debate_list')
    op.drop_index('ix_debate_list_qwen', table_name='debate_list')
    # 删除表
    op.drop_table('debate_list')
