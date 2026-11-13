
# Style

* **High Standards**: Write code that is clean, readable, and a pleasure to read.
* **Collaboration**: Discuss code, ask questions, and use Pull Requests to address code smells.
* **Consistency**: When unsure, look for similar code in the project for inspiration.

## Methods ordering

We order methods in classes in the following order:

1. `class` methods
2. `public` methods with `initialize` at the top.
3. `private` methods

## Invocation order

Order methods vertically by invocation order.

Place each private method by its first call, reading the public methods from top to bottom. If `index` calls `json_options` and `create` later calls `user_params` before `json_options`, `json_options` still comes first because `index` uses it first.

```ruby
class SomeClass
  def some_method
    method_1
    method_2
  end

  private

  def method_1
    method_1_1
    method_1_2
  end

  def method_1_1
    # ...
  end

  def method_1_2
    # ...
  end

  def method_2
    method_2_1
    method_2_2
  end

  def method_2_1
    # ...
  end

  def method_2_2
    # ...
  end
end
```

## To bang or not to bang

We use `do_something!` when the method can raise an error.

Apply this naming rule to application-owned methods that deliberately raise or propagate errors, such as wrappers around `create!` or `destroy!`. Keep framework-required names unchanged, including controller actions, callbacks, and job entry points. Also keep the names of methods created by Rails generators, such as `start_new_session_for`, `terminate_session`, `sign_in_as`, and `sign_out` from the authentication generator, so code that follows the Rails guides keeps working. Unexpected runtime errors alone do not require a bang suffix.

## Class definitions

We prefer compact class syntax over nested module names for clarity and conciseness.

```ruby
# Bad
module My
  module Namespace
    class SomeClass
      # ...
    end
  end
end

# Good
class My::Namespace::SomeClass
  # ...
end
```

Use nested syntax only when you need to define multiple classes within the same module in a single file, or when you need to add module-level code.

Namespace bootstrap code may also use nested syntax when the namespace does not yet exist, such as `module Bookstore` in `config/application.rb`. Compact syntax requires the enclosing namespace to exist already.

## Routing

We prefer using the `resources` syntax to define routes. This ensures we follow standard RESTful conventions. Custom actions within resources are acceptable, but you should avoid defining standalone routes manually.

Application roots and infrastructure endpoints, such as the Rails health check at `/up`, are exceptions. Keep their established paths and route helpers.

```ruby
# Bad
get 'articles', to: 'articles#index'
post 'articles/:id/publish', to: 'articles#publish'

# Good
resources :articles do
  member do
    post :publish
  end
end
```

## Run async operations in jobs

* **Shallow Jobs**: Delegate logic to domain models.
* **Naming**: Use `_later` for methods that enqueue a job, and `_now` for the regular synchronous method.

```ruby
module My::Model::Processing
  extend ActiveSupport::Concern

  included do
    after_create_commit :process_later
  end

  def process_later
    My::Model::ProcessJob.perform_later(self)
  end

  def process_now
    # ...
  end
end

class My::Model::ProcessJob < ApplicationJob
  def perform(model)
    model.process_now
  end
end
```
 
