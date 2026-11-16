# frozen_string_literal: true

ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    div class: "grid grid-cols-2 gap-4 lg:grid-cols-4" do
      [ [ "Users", User.count ], [ "Books", Book.count ],
        [ "Categories", Category.count ], [ "Markets", Market.count ] ].each do |label, count|
        div class: "rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-900" do
          para label, class: "text-sm font-medium text-gray-500 dark:text-gray-400"
          para count, class: "mt-1 text-3xl font-bold text-gray-900 dark:text-gray-200"
        end
      end
    end

    panel "Recent books", class: "mt-6" do
      table_for Book.includes(:category).order(created_at: :desc).limit(5) do
        column(:title) { |book| link_to book.title, admin_book_path(book) }
        column :author
        column :category
      end
    end
  end
end
