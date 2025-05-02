# Generated Functions Reference

This guide details all the functions that Aurora.Ctx generates for your context modules.

## List Functions

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

## Get Functions

```elixir
get_product(id)                # Returns %Product{} or nil
get_product(id, opts)          # Returns %Product{} or nil with preloads
get_product!(id)               # Returns %Product{} or raises Ecto.NoResultsError
get_product!(id, opts)         # Returns %Product{} or raises, with preloads
```

### Example
```elixir
# Get product with associated category
product = get_product!(1, preload: [:category])
```

## Create Functions

```elixir
create_product()               # Returns {:ok, %Product{}} with defaults
create_product(attrs)          # Returns {:ok, %Product{}} or {:error, changeset}
create_product!()              # Returns %Product{} or raises
create_product!(attrs)         # Returns %Product{} or raises
```

### Example
```elixir
{:ok, product} = create_product(%{
  name: "Widget Pro",
  price: Decimal.new("29.99")
})
```

## Update Functions

```elixir
update_product(entity)         # Returns {:ok, %Product{}} with no changes
update_product(entity, attrs)  # Returns {:ok, %Product{}} or {:error, changeset}
```

### Example
```elixir
{:ok, updated} = update_product(product, %{price: Decimal.new("39.99")})
```

## Delete Functions

```elixir
delete_product(entity)         # Returns {:ok, %Product{}} or {:error, changeset}
delete_product!(entity)        # Returns %Product{} or raises
```

### Example
```elixir
{:ok, deleted} = delete_product(product)
```

## Change Functions

```elixir
change_product(entity)         # Returns %Ecto.Changeset{} with no changes
change_product(entity, attrs)  # Returns %Ecto.Changeset{} with changes
```

### Example
```elixir
changeset = change_product(product, %{price: Decimal.new("49.99")})
```

## New Functions

```elixir
new_product()                  # Returns %Product{} struct
new_product(attrs)             # Returns %Product{} with attributes
new_product(attrs, opts)       # Returns %Product{} with attributes and preloads
```

### Example
```elixir
product = new_product(%{name: "Widget Pro", price: Decimal.new("29.99")})
```

## Query Options

### Where Conditions
```elixir
# Simple equality
where: [status: :active]

# Comparisons
where: {:price, :greater_than, 100}
where: {:price, :less_than, 200}
where: {:date, :greater_equal_than, ~D[2023-01-01]}

# Ranges
where: {:price, :between, 100, 200}

# Multiple conditions
where: [status: :active, price: {:greater_than, 100}]
```

### Sorting
```elixir
# Simple sort
order_by: :inserted_at           # ascending
order_by: {:desc, :inserted_at}  # descending

# Multiple fields
order_by: [{:desc, :inserted_at}, {:asc, :name}]
```

### Pagination
```elixir
# Default pagination
paginate: %{page: 1, per_page: 20}
```

For implementation examples, check out the [Examples](examples.html) guide.
