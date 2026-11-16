class ActiveAdmin::UserPolicy < ActiveAdmin::ApplicationPolicy
  def destroy?
    admin? && record != user
  end
end
