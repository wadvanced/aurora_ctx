# Aurora.Ctx

A powerful DSL for automatically generating CRUD operations in Elixir context modules from Ecto schemas. Aurora.Ctx provides:

- Automatic CRUD function generation from Ecto schemas
- Built-in pagination support
- Advanced query building with filters and sorting
- Flexible preloading of associations
- Customizable changeset functions

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `aurora_ctx` to your list of dependencies in `mix.exs`:

```elixir 
def deps do
  [
    {:aurora_ctx, "~> 0.1.0"}
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
    changeset_function: :custom_changeset,
    create_changeset_function: :creation_changeset
)
end
```

### Generated Functions

For a schema named `Product` with source "products", the following functions are automatically generated:

```elixir
# List operations
list_products()                    # List all products
list_products(opts)                # List with opts
list_products_paginated()          # List products with pagination
list_products_paginated(opts)      # List with pagination options
count_products()                   # Count total products
count_products(opts)               # Count with filters

# Create operations
create_product(%{name: "Item"})    # Create with attributes
create_product!(%{name: "Item"})   # Create with raising version
create_product()                   # Create with empty attributes
create_product!()                  # Create empty with raising version

# Read operations
get_product(1)                     # Get by ID
get_product!(1)                    # Get by ID (raises if not found)
get_product(1, preload: [:items])  # Get by ID with preloads
get_product!(1, preload: [:items]) # Get by ID with preloads (raises)

# Update operations
update_product(product, attrs)     # Update existing product
update_product(product)            # Update without new attributes
change_product(product, attrs)     # Create a changeset
change_product(product)            # Create changeset without attrs

# Delete operations
delete_product(product)            # Delete a product
delete_product!(product)           # Delete (raises on error)

# Initialize operations
new_product()                      # Create new struct
new_product(attrs)                 # Create with attributes
new_product(attrs, opts)           # Create with attributes and options
```

## Documentation 

For detailed usage examples and API reference, please see:

- [HexDocs Documentation](https://hexdocs.pm/aurora_ctx)
- [GitHub Repository](https://github.com/user/aurora_ctx)

