[![CI](https://github.com/wadvanced/aurora_ctx/actions/workflows/ci.yml/badge.svg)](https://github.com/wadvanced/aurora_ctx/actions/workflows/ci.yml)
[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-%23FE5196?logo=conventionalcommits&logoColor=white)](https://conventionalcommits.org)
[![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/aurora_ctx/)
[![Hex.pm](https://img.shields.io/hexpm/v/aurora_ctx.svg)](https://hex.pm/packages/aurora_ctx)
[![License](https://img.shields.io/hexpm/l/aurora_ctx.svg)](https://github.com/wadvanced/aurora_ctx/blob/main/LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/wadvanced/aurora_ctx.svg)](https://github.com/wadvanced/aurora_ctx/commits/main)
[![Total Downloads](https://img.shields.io/hexpm/dt/aurora_ctx.svg)](https://hex.pm/packages/aurora_ctx)

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

[Available in Hex](https://hex.pm/packages/aurora_ctx), the package can be installed
by adding `aurora_ctx` to your list of dependencies in `mix.exs`:

```elixir 
def deps do
  [
    {:aurora_ctx, "~> 0.1.10"}
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

For a schema named `Product` with table name: "products", several functions are automatically generated, 
as shown in the examples:

```elixir
# List operations with advanced filtering
list_products()                    # List all products
list_products(                     # List with filters and sorting
  where: [status: :active],
  order_by: [desc: :inserted_at],
  preload: [:category]
)
count_products()                  # Count all products

# Pagination with navigation
page = list_products_paginated(
  paginate: %{page: 1, per_page: 20}
)
next_page = next_products_page(page)
prev_page = previous_products_page(page)

# Create with custom changeset
create_product(%{name: "Item"})    # Uses default or specified changeset
create_product!(%{name: "Item"})   # Raise on error version

# Read single records
get_product(1, preload: [:category, reviews: [:user]])
get_product!(1)                       # Raise on error version
get_product_by(reference: "item_001") # Get record by using a filter

# Update with custom changeset
update_product(product, attrs)     # Uses default or specified changeset
change_product(product)            # Get changeset for forms

# Delete operations
delete_product(product)            # Returns {:ok, struct} or {:error, changeset}
delete_product!(product)           # Raise on error version

# New operation with preload
new_product(preload: :product_transactions) # Returns a Product schema with product_transactions []

```

## Documentation 

For detailed usage examples and API reference, please see:

- [Documentation](https://hexdocs.pm/aurora_ctx)
- [GitHub Repository](https://github.com/wadvanced/aurora_ctx)
- [Tests](https://github.com/wadvanced/aurora_ctx/tree/main/test)

## Want to contribute?

Read the [guidelines.](https://github.com/wadvanced/aurora_ctx/blob/main/CONTRIBUTING.md)
