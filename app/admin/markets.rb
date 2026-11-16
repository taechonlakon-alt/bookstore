ActiveAdmin.register Market do
  permit_params :name, book_ids: []

  index do
    selectable_column
    id_column
    column :name
    column :created_at
    actions
  end

  filter :name
  filter :created_at

  show do
    attributes_table do
      row :name
      row(:books) { |market| market.books.map(&:title).to_sentence }
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.semantic_errors
    f.inputs do
      f.input :name
      f.input :books, as: :check_boxes
    end
    f.actions
  end
end
