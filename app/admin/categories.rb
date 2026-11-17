ActiveAdmin.register Category do
  permit_params :name

  index do
    selectable_column
    id_column
    column :name
    column :created_at
    actions
  end

  filter :name
  filter :created_at

  config.add_batch_action(
    :destroy,
    proc { I18n.t("active_admin.delete") },
    priority: 100,
    confirm: proc { I18n.t("active_admin.batch_actions.delete_confirmation", plural_model: "categories") },
    if: proc { destroy_action_authorized?(Category) }
  ) do |selected_ids|
    deleted, failed = batch_action_collection.find(selected_ids).partition do |category|
      authorize! ActiveAdmin::Auth::DESTROY, category
      destroy_resource(category)
      category.destroyed?
    end

    if failed.empty?
      redirect_to admin_categories_path, notice: I18n.t("active_admin.batch_actions.successfully_destroyed", count: deleted.size, model: "category", plural_model: "categories")
    else
      redirect_to admin_categories_path, alert: batch_destroy_failure_message(deleted, failed)
    end
  end

  form do |f|
    f.semantic_errors
    f.inputs do
      f.input :name
    end
    f.actions
  end

  controller do
    def destroy
      super do |_success, failure|
        failure.html { redirect_to admin_categories_path, alert: resource.errors.full_messages.to_sentence }
      end
    end

    private

    def batch_destroy_failure_message(deleted, failed)
      errors = failed.flat_map { |category| category.errors.full_messages }.uniq.to_sentence
      return errors if deleted.empty?

      "Deleted #{helpers.pluralize(deleted.size, "category")}. #{errors}"
    end
  end
end
