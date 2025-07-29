<p align="center">
  <picture>
    <img src="./guides/images/aurora_ctx-logo.svg" height="200"/>
  </picture>
</p>

# Aurora.Ctx

A macro set for automatically generating CRUD operations in Elixir context modules from Ecto schemas. Aurora.Ctx provides:

- Automatic CRUD function generation from Ecto schemas
- Built-in pagination with navigation helpers
- Advanced query building with filters and sorting
- Flexible preloading of associations
- Customizable changeset functions for create/update operations
- Safe and raising versions of operations
- Full Ecto compatibility and query composition

## Installation

[available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `aurora_ctx` to your list of dependencies in `mix.exs`:

```elixir 
def deps do
  [
    {:aurora_ctx, "~> 0.1.5"}
  ]
end
```

## Usage

Add Aurora.Ctx to your context module and register your schemas:

```elixir
defmodule MyApp.Inventory do
  use Aurora.Ctx

  # Basic usage with default repo
  ctx_register_schema(Product)

  # With custom options
  ctx_register_schema(Category, MyCustomRepo,
    update_changeset: :custom_changeset,
    create_changeset: :creation_changeset
)
end
```

### Generated Functions

For a schema named `Product` with source "products", the following functions are automatically generated:

```elixir
# List operations with advanced filtering
list_products()                    # List all products
list_products(                     # List with filters and sorting
  where: [status: :active],
  order_by: [desc: :inserted_at],
  preload: [:category]
)

# Pagination with navigation
page = list_products_paginated(
  paginate: %{page: 1, per_page: 20}
)
next_page = next_products_page(page)
prev_page = previous_products_page(page)

# Create with custom changeset
create_product(%{name: "Item"})    # Uses default or specified changeset
create_product!(%{name: "Item"})   # Raising version

# Read with preloads
get_product(1, preload: [:category, reviews: [:user]])
get_product!(1)                    # Raising version

# Update with custom changeset
update_product(product, attrs)     # Uses default or specified changeset
change_product(product)            # Get changeset for forms

# Delete operations
delete_product(product)            # Returns {:ok, struct} or {:error, changeset}
delete_product!(product)           # Raising version
```

## Documentation 

For detailed usage examples and API reference, please see:

- [HexDocs Documentation](https://hexdocs.pm/aurora_ctx)
- [GitHub Repository](https://github.com/wadvanced/aurora_ctx)

