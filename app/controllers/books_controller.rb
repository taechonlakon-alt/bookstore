class BooksController < ApplicationController
  def index
    @categories = Category.order(:name)
    @books = Book.in_category(params[:category_id]).search(params[:q]).order(:title)
  end

  def show
    @book = Book.find(params[:id])
  end
end
