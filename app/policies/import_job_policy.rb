# frozen_string_literal: true

class ImportJobPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def post_initialize
    end

    def authorized_to_edit_records
      scope.owned_by(user)
    end

    def authorized_to_view_records
      scope.owned_by(user)
    end
  end

  attr_reader :import_job, :parent_resource

  def post_initialize(import_job)
    @import_job = import_job
    @parent_resource = import_job.parent if import_job.is_a?(::ImportJob)
  end

  def index?
    user.present?
  end

  def show?
    user.admin? || user.owner_of?(import_job)
  end

  def new?
    user.admin? || user.owner_of?(parent_resource)
  end

  def create?
    user.admin? || user.owner_of?(parent_resource)
  end

  def destroy?
    user.admin? || user.owner_of?(import_job)
  end
end
