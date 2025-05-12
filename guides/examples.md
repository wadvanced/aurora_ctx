# Examples

Examples of using Aurora.Ctx in common scenarios.

## Basic CRUD Operations

Basic context setup and standard database operations.

```elixir
defmodule MyApp.Inventory do
  use Aurora.Ctx,
    schema_module: MyApp.Inventory.Product,
    repo_module: MyApp.Repo
end

# Usage examples
alias MyApp.Inventory

# Create a product
{:ok, product} = Inventory.create_product(%{
  name: "Premium Widget",
  price: Decimal.new("29.99")
})

# List products with sorting
products = Inventory.list_products(order_by: [desc: :inserted_at])

# Get product with preloaded associations
{:ok, product} = Inventory.get_product(1, preload: [:category, :supplier])

# Update a product
{:ok, updated} = Inventory.update_product(product, %{price: Decimal.new("39.99")})

# Delete a product
{:ok, _deleted} = Inventory.delete_product(product)
```

## Query Usage

More complex database operations using query options.

### Custom Query Options

Combining filtering, preloading, and sorting in queries.

```elixir
# List active products with preloaded categories
products = Inventory.list_products(
  where: [status: "active"],
  preload: [:category],
  order_by: [asc: :name],
  limit: 10
)

# Get a product with specific preloads
product = Inventory.get_product!(1, 
  preload: [
    category: [:parent_category],
    reviews: [:user]
  ]
)
```

### Working with Changesets

Data validation and form handling with changesets.

```elixir
# Create a changeset for a new product
changeset = Inventory.change_product(%Product{})

# Create a changeset with attributes
changeset = Inventory.change_product(%Product{}, %{
  name: "New Widget",
  price: "19.99"
})

# Working with forms in Phoenix
def new(conn, _params) do
  changeset = Inventory.change_product(%Product{})
  render(conn, "new.html", changeset: changeset)
end

def create(conn, %{"product" => product_params}) do
  case Inventory.create_product(product_params) do
    {:ok, product} -> 
      redirect(to: Routes.product_path(conn, :show, product))
    {:error, changeset} ->
      render(conn, "new.html", changeset: changeset)
  end
end
```

## Query Options

Available options for customizing database queries.

### Filtering

Filter query results using different conditions.

```elixir
# Multiple conditions
products = Inventory.list_products(
  where: [
    status: "active",
    category_id: 1
  ]
)

# Comparison operators
products = Inventory.list_products(
  where: [
    {:price, :gt, Decimal.new("100.00")},
    {:stock_level, :le, 5}
  ]
)

# Range queries
products = Inventory.list_products(
  where: {:price, :between, Decimal.new("10.00"), Decimal.new("50.00")}
)

# OR conditions
products = Inventory.list_products(
  where: [status: "active"],
  or_where: [status: "pending_review"]
)
```

### Sorting

Order query results with various sorting strategies.

```elixir
# Multiple sort fields
products = Inventory.list_products(
  order_by: [
    asc: :category_id,
    desc: :price,
    asc: :name
  ]
)

# Null handling
products = Inventory.list_products(
  order_by: [
    asc_nulls_last: :discontinued_at,
    desc_nulls_first: :updated_at
  ]
)
```

### Controlled Pagination

Implement and navigate through paginated results. Results are wrapped in an `Aurora.Ctx.Pagination` struct that provides additional metadata and navigation helpers.

```elixir
# Basic pagination
page1 = Inventory.list_products_paginated(
  paginate: %{page: 1, per_page: 20}
)

# Access pagination info
IO.puts "Total entries: #{page1.entries_count}"
IO.puts "Total pages: #{page1.pages_count}"
IO.puts "Current page: #{page1.page}"

# Navigate through pages
next_page = Inventory.next_products_page(page1)
prev_page = Inventory.previous_products_page(next_page)
page5 = Inventory.to_products_page(page1, 5)

# Combine with other options
filtered_page = Inventory.list_products_paginated(
  where: [category_id: 1],
  order_by: [desc: :inserted_at],
  paginate: %{page: 1, per_page: 10}
)
```

### Preloading Associates

Load associated data with simple and nested preloads.

```elixir
# Nested preloads
product = Inventory.get_product!(1,
  preload: [
    category: [:parent_category, :subcategories],
    reviews: [:user, comments: [:user]],
    supplier: [:address, :contacts]
  ]
)

# Filtered preloads with custom queries
products = Inventory.list_products(
  preload: [
    reviews: from(r in Review, where: r.rating > 3)
  ]
)
```

### Working with Transactions

Combine multiple database operations in transactions.

```elixir
alias Ecto.Multi
alias MyApp.{Inventory, Orders}

# Complex multi-operation transaction
def create_order_with_inventory_update(attrs) do
  Multi.new()
  |> Multi.run(:product, fn repo, _ ->
    Inventory.get_product(attrs.product_id)
  end)
  |> Multi.run(:check_stock, fn _repo, %{product: product} ->
    if product.stock >= attrs.quantity do
      {:ok, product}
    else
      {:error, :insufficient_stock}
    end
  end)
  |> Multi.run(:order, fn repo, %{product: product} ->
    Orders.create_order(attrs)
  end)
  |> Multi.run(:update_inventory, fn repo, %{product: product, order: order} ->
    Inventory.update_product(product, %{
      stock: product.stock - order.quantity
    })
  end)
  |> MyApp.Repo.transaction()
end

# Usage
case create_order_with_inventory_update(%{product_id: 1, quantity: 5}) do
  {:ok, %{order: order, product: product}} ->
    {:ok, order}
  {:error, failed_operation, failed_value, changes_so_far} ->
    {:error, :order_creation_failed}
end
```

### Custom Changesets

Configure and use custom changeset functions.

```elixir
# Using custom changeset functions
defmodule MyApp.Inventory do
  use Aurora.Ctx,
    schema_module: MyApp.Inventory.Product,
    repo_module: MyApp.Repo,
    update_changeset_function: :custom_changeset,
    create_changeset: :create_changeset

  # Your additional context functions...
end

# Schema with multiple changeset functions
defmodule MyApp.Inventory.Product do
  use Ecto.Schema
  import Ecto.Changeset

  schema "products" do
    field :name, :string
    field :price, :decimal
    field :status, :string
    timestamps()
  end

  def create_changeset(product, attrs) do
    product
    |> cast(attrs, [:name, :price])
    |> validate_required([:name, :price])
    |> validate_number(:price, greater_than: 0)
  end

  def custom_changeset(product, attrs) do
    product
    |> cast(attrs, [:name, :price, :status])
    |> validate_required([:status])
    |> validate_inclusion(:status, ["active", "inactive"])
  end
end

# Usage
product = Inventory.new_product()
changeset = Inventory.change_product(product, %{name: "New Product"})
```

For more examples and use cases, check the test files in the [GitHub repository](https://github.com/wadvanced/aurora_ctx).
