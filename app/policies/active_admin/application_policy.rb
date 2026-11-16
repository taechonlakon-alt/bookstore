# frozen_string_literal: true

module ActiveAdmin
  class ApplicationPolicy
    attr_reader :user, :record

    def initialize(user, record)
      @user = user
      @record = record
    end

    def index?
      admin?
    end

    def show?
      admin?
    end

    def new?
      admin?
    end

    def create?
      admin?
    end

    def edit?
      admin?
    end

    def update?
      admin?
    end

    def destroy?
      admin?
    end

    def destroy_all?
      admin?
    end

    private

    def admin?
      user&.admin? || false
    end

    class Scope
      def initialize(user, scope)
        @user = user
        @scope = scope
      end

      def resolve
        user&.admin? ? scope.all : scope.none
      end

      private

      attr_reader :user, :scope
    end
  end
end
