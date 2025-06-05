# Generated Functions Reference

This guide details all the functions that Aurora.Ctx generates for your context modules. To illustrate the generated artifacts, we use, as an example, a schema module named 'Product' that has a table named 'products'.

## List Functions

Functions to fetch and filter collections of records from the database.

```elixir
list_products()                # Returns [%Product{}]
list_products(opts)            # Returns [%Product{}] with filtering/sorting
list_products_paginated()      # Returns %Pagination{} with default options
list_products_paginated(opts)  # Returns %Pagination{} with custom options
count_products()               # Returns total count of records
count_products(opts)           # Returns filtered count of records
```

### Example
```elixir
# Get active products sorted by price
products = list_products(
  where: [status: :active],
  order_by: [asc: :price]
)
```

The `opts` parameter supports:
- `:preload` - Associations to preload
- `:where` - Filter conditions (equality, comparison, range)
- `:or_where` - Alternative filter conditions combined with OR
- `:order_by` - Sorting specification
- `:paginate` - Pagination options (page, per_page)
- `:limit` - Maximum number of records to return

### Configuration

Default pagination settings can be configured in your `config.exs`:

```elixir
config :aurora_ctx,
  paginate: %{
    page: 1,
    per_page: 40  # default if not specified
  }
```

### Count Functions

The count functions support the same filtering options as list functions:

```elixir
# Get total count
total = count_products()

# Get filtered count
active_count = count_products(where: [status: :active])
```

## Pagination Functions

Functions to navigate through large datasets efficiently. See `Aurora.Ctx.Pagination` module for the pagination implementation details.

```elixir
to_products_page(pagination, page)     # Returns %Pagination{} for specific page
next_products_page(pagination)         # Returns %Pagination{} for next page
previous_products_page(pagination)     # Returns %Pagination{} for previous page
```

### Example
```elixir
# Get paginated results
page = list_products_paginated(paginate: %{page: 1, per_page: 20})

# Navigate pages
next_page = next_products_page(page)
prev_page = previous_products_page(page)
page5 = to_products_page(page, 5)
```

## Get Functions

Functions to retrieve individual records by their primary key.

```elixir
get_product(id)                # Returns %Product{} or nil
get_product(id, opts)          # Returns %Product{} or nil with preloads
get_product!(id)               # Returns %Product{} or raises Ecto.NoResultsError
get_product!(id, opts)         # Returns %Product{} or raises, with given options
```

### Example
```elixir
# Get product with associated category
product = get_product!(1, preload: [:category])
```

## Create Functions

Functions to insert new records into the database.

```elixir
create_product()               # Returns {:ok, %Product{}} with defaults
create_product(attrs)          # Returns {:ok, %Product{}} or {:error, changeset}
create_product!()              # Returns %Product{} or raises errors
create_product!(attrs)         # Returns %Product{} or raises errors
```

You can customize which changeset function is used for creation by providing the `:create_changeset` option when registering the schema.

### Example
```elixir
{:ok, product} = create_product(%{
  name: "Widget Pro",
  price: Decimal.new("29.99")
})

# Using a custom create changeset
defmodule MyApp.Inventory do
  use Aurora.Ctx
  ctx_register_schema(Product, create_changeset: :create_changeset)
end
```

## Update Functions

Functions to modify existing records in the database.

```elixir
update_product(entity)           # Returns {:ok, %Product{}} with no changes
update_product(entity, attrs)    # Returns {:ok, %Product{}} or {:error, changeset}
update_product(changeset)        # Returns {:ok, %Product{}} or {:error, changeset}
update_product(changeset, attrs) # Returns {:ok, %Product{}} or {:error, changeset}
```

The function accepts either:
- An entity and optional attributes to apply changes
- A pre-built changeset to validate and persist
- A pre-built changeset and additional attributes to merge

> **Note**: When using a pre-built changeset, it will be re-validated using the schema's defined `:update_changeset` function (or `:changeset` if not specified).

You can use a custom update changeset function by providing the `:update_changeset` option when registering the schema.

### Example
```elixir
# Using entity and attributes
{:ok, updated} = update_product(product, %{price: Decimal.new("39.99")})

# Using a pre-built changeset
changeset = change_product(product, %{price: Decimal.new("39.99")})
{:ok, updated} = update_product(changeset)

# Using a changeset with additional attributes
{:ok, updated} = 
  product
  |> change_product()
  |> update_product(%{price: Decimal.new("39.99")})

# Using a custom update changeset
defmodule MyApp.Inventory do
  use Aurora.Ctx
  ctx_register_schema(Product, update_changeset: :custom_update_changeset)
end
```

## Delete Functions

Functions to remove records from the database.

```elixir
delete_product(entity)         # Returns {:ok, %Product{}} or {:error, changeset}
delete_product!(entity)        # Returns %Product{} or raises
```

### Example
```elixir
{:ok, deleted} = delete_product(product)
```

## Change Functions

Functions to prepare and validate changes before persisting them.

```elixir
change_product(entity)               # Returns %Ecto.Changeset{} with no changes
change_product(entity, attrs)        # Returns %Ecto.Changeset{} with changes
change_product(changeset)            # Returns %Ecto.Changeset{} with no changes
change_product(changeset, attrs)     # Returns %Ecto.Changeset{} with changes
```

The function accepts either:
- An entity and optional attributes to apply changes
- An existing changeset and optional attributes to merge changes

> **Note**: When using a pre-built changeset, it will be re-validated using the schema's defined `:changeset` function (or the default changeset function if not specified).

You can customize which changeset function is used by providing the `:changeset` option when registering the schema.

### Example
```elixir
# Using entity
changeset = change_product(product, %{price: Decimal.new("49.99")})

# Using existing changeset
updated_changeset = 
  product
  |> change_product(%{name: "Widget Pro"})
  |> change_product(%{price: Decimal.new("49.99")})

# Using custom changeset function
defmodule MyApp.Inventory do
  use Aurora.Ctx
  ctx_register_schema(Product, changeset: :custom_changeset)
end
```

## New Functions

Functions to create new struct instances in memory.

```elixir
new_product()                  # Returns %Product{} struct
new_product(attrs)             # Returns %Product{} with attributes
new_product(attrs, opts)       # Returns %Product{} with attributes and options applied
```

The `opts` parameter supports:
- `:preload` - Associations to preload when creating the struct

### Example
```elixir
# Basic usage
product = new_product(%{name: "Widget Pro", price: Decimal.new("29.99")})

# With preloaded associations
product = new_product(
  %{name: "Widget Pro", price: Decimal.new("29.99")},
  preload: [:category, :variants]
)
```

> **Note**: The `:changeset` option when registering a schema sets the default changeset function for all operations. This default is used for create and update operations unless explicitly overridden by `:create_changeset` or `:update_changeset` respectively.

## Query Options

The following options are available for list, get, and count functions:

### Where Conditions
```elixir
# Basic equality
where: [status: :active]
where: {:status, :active}

# Comparisons
where: {:price, :greater_than, 100}      # or :gt
where: {:price, :greater_equal_than, 100} # or :ge
where: {:price, :less_than, 200}         # or :lt
where: {:price, :less_equal_than, 200}   # or :le
where: {:price, :equal_to, 150}          # or :eq

# Ranges
where: {:price, :between, 100, 200}

# Multiple conditions (AND)
where: [
  status: :active,
  {:price, :greater_than, 100}
]

# OR conditions
where: [status: :active],
or_where: [status: :pending]
```

### Preloading
```elixir
# Basic preloads
preload: [:category]

# Nested preloads
preload: [
  category: [:parent_category],
  reviews: [:user, comments: [:user]]
]

# With query customization
preload: [
  reviews: from(r in Review, where: r.rating > 3)
]
```

### Sorting
```elixir
# Basic sorting
order_by: :inserted_at                 # asc
order_by: {:desc, :price}             # desc

# Null handling
order_by: {:asc_nulls_last, :ended_at}
order_by: {:desc_nulls_first, :priority}

# Multiple fields
order_by: [
  {:desc, :priority},
  {:asc, :name}
]
```

### Query Exclusions

You can exclude specific query clauses when needed:

```elixir
# Exclude specific clauses
products = list_products(
  where: [status: :active],
  exclude: :where  # Removes where clause
)

# Exclude multiple clauses
products = list_products(
  where: [status: :active],
  order_by: [desc: :inserted_at],
  exclude: [:where, :order_by]
)
```

### Pagination
```elixir
# Basic pagination
paginate: %{page: 1, per_page: 20}
```

For implementation examples, check out the [Examples](examples.html) guide.
