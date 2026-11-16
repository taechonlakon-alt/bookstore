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
  end
end
