# Node Domain Model
# ドメインモデル - ノードのビジネスルールとバリデーションを持つ
class Node
  attr_reader :id, :name, :group_id, :domain

  def initialize(id:, name: nil, group_id: nil, domain: nil)
    @id = id
    @name = name || "Node #{id}"
    @group_id = group_id
    @domain = domain

    validate!
  end

  private

  def validate!
    raise ArgumentError, 'id is required' if @id.nil? || @id.to_s.empty?
  end
end
