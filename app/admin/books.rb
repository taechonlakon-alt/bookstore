ActiveAdmin.register Book do
  permit_params :title, :author, :description, :category_id, market_ids: []

  includes :category, :markets

  index do
    selectable_column
    id_column
    column :title
    column :author
    column :category
    column :created_at
    actions
  end

  filter :title
  filter :author
  filter :category

  show do
    attributes_table do
      row :title
      row :author
      row :description
      row :category
      row(:markets) { |book| book.markets.map(&:name).to_sentence }
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.semantic_errors
    f.inputs do
      f.input :title
      f.input :author
      f.input :description
      f.input :category, as: :select, include_blank: false
      f.input :markets, as: :check_boxes
    end
    f.actions
  end
end
