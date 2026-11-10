class Admin::BooksController < Admin::BaseController
  before_action :set_book, only: %i[edit update destroy]

  def index
    @books = Book.includes(:category).order(:title)
  end

  def new
    @book = Book.new
  end

  def create
    @book = Book.new(book_params)
    if @book.save
      redirect_to admin_books_path, notice: "Book was created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @book.update(book_params)
      redirect_to admin_books_path, notice: "Book was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @book.destroy
    redirect_to admin_books_path, notice: "Book was deleted."
  end

  private

  def set_book
    @book = Book.find(params[:id])
  end

  def book_params
    params.expect(book: [ :title, :author, :description, :category_id ])
  end
end
