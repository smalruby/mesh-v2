require 'spec_helper'
require 'time'
require_relative '../../../lambda/use_cases/leave_group'
require_relative '../../../lambda/domain/group'
require_relative '../../../lambda/domain/node'

RSpec.describe LeaveGroupUseCase do
  let(:repository) { double('Repository') }
  let(:use_case) { described_class.new(repository) }

  describe '#execute' do
    let(:group_id) { 'group-123' }
    let(:domain) { 'example.com' }
    let(:host_id) { 'host-001' }
    let(:member_id) { 'member-002' }

    let(:existing_group) do
      Group.new(
        id: group_id,
        name: 'Test Group',
        host_id: host_id,
        domain: domain,
        created_at: Time.now.utc.iso8601
      )
    end

    context '一般メンバーが退出する場合' do
      it 'メンバーをグループから削除してNodeを返す' do
        # Setup: グループ情報取得
        allow(repository).to receive(:find_group)
          .with(group_id, domain)
          .and_return(existing_group)

        # Setup: メンバー削除操作
        expect(repository).to receive(:remove_node_from_group)
          .with(group_id, domain, member_id)
          .and_return(true)

        # Execute
        result = use_case.execute(
          group_id: group_id,
          domain: domain,
          node_id: member_id
        )

        # Verify: Nodeオブジェクトが返される
        expect(result).to be_a(Node)
        expect(result.id).to eq(member_id)
        expect(result.group_id).to be_nil # 退出後はグループIDがnil
        expect(result.domain).to be_nil
      end

      it 'メンバー削除に失敗した場合はエラーを発生させる' do
        allow(repository).to receive(:find_group)
          .with(group_id, domain)
          .and_return(existing_group)

        allow(repository).to receive(:remove_node_from_group)
          .with(group_id, domain, member_id)
          .and_return(false)

        expect {
          use_case.execute(
            group_id: group_id,
            domain: domain,
            node_id: member_id
          )
        }.to raise_error(StandardError, /Failed to remove node from group/)
      end
    end

    context 'ホストが退出する場合（グループ解散）' do
      it 'グループ全体を削除してnilを返す' do
        # Setup: グループ情報取得（hostIdが一致）
        allow(repository).to receive(:find_group)
          .with(group_id, domain)
          .and_return(existing_group)

        # Setup: グループ解散操作
        expect(repository).to receive(:dissolve_group)
          .with(group_id, domain)
          .and_return(true)

        # Execute
        result = use_case.execute(
          group_id: group_id,
          domain: domain,
          node_id: host_id
        )

        # Verify: nilが返される（GraphQLスキーマではNode?型なのでnull可能）
        expect(result).to be_nil
      end

      it 'グループ解散に失敗した場合はエラーを発生させる' do
        allow(repository).to receive(:find_group)
          .with(group_id, domain)
          .and_return(existing_group)

        allow(repository).to receive(:dissolve_group)
          .with(group_id, domain)
          .and_return(false)

        expect {
          use_case.execute(
            group_id: group_id,
            domain: domain,
            node_id: host_id
          )
        }.to raise_error(StandardError, /Failed to dissolve group/)
      end
    end

    context 'エラーケース' do
      it 'グループが存在しない場合はエラーを発生させる' do
        allow(repository).to receive(:find_group)
          .with(group_id, domain)
          .and_return(nil)

        expect {
          use_case.execute(
            group_id: group_id,
            domain: domain,
            node_id: member_id
          )
        }.to raise_error(StandardError, /Group not found/)
      end

      it 'group_idが空の場合はエラーを発生させる' do
        expect {
          use_case.execute(
            group_id: '',
            domain: domain,
            node_id: member_id
          )
        }.to raise_error(ArgumentError, /group_id is required/)
      end

      it 'domainが空の場合はエラーを発生させる' do
        expect {
          use_case.execute(
            group_id: group_id,
            domain: '',
            node_id: member_id
          )
        }.to raise_error(ArgumentError, /domain is required/)
      end

      it 'node_idが空の場合はエラーを発生させる' do
        expect {
          use_case.execute(
            group_id: group_id,
            domain: domain,
            node_id: ''
          )
        }.to raise_error(ArgumentError, /node_id is required/)
      end
    end
  end
end
