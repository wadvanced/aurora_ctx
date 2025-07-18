# Overview

Aurora.Ctx is a code generation library that implements the Context pattern in Phoenix applications. It automatically generates standardized database interaction functions following Phoenix's architectural guidelines, while maintaining full compatibility with Ecto's query composition and changesets. The library supports both standard CRUD operations and advanced query features like filtering, sorting, and pagination.

## Key Benefits

- **Reduced Boilerplate**: Automatically generates common database access functions
- **Consistent API**: Ensures uniform function names and patterns across contexts
- **Type Safety**: All generated functions include proper typespecs
- **Flexible**: Supports customization through options and hooks
- **Maintainable**: Less code to maintain, centralized logic

## Getting Started

Add `aurora_ctx` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:aurora_ctx, "~> 0.1.4"}
  ]
end
```

## Basic Usage

### Creating an Ecto Schema

> **Tip**: Consider using [TypedEctoSchema](https://hexdocs.pm/typed_ecto_schema) to reduce boilerplate in your schema definitions and add compile-time type checking.

Let's start with a typical Ecto schema definition that we'll use throughout this overview:

```elixir
defmodule MyApp.Inventory.Product do
  use Ecto.Schema
  
  schema "products" do
    field :name, :string
    field :price, :decimal
    
    timestamps()
  end

  def changeset(product, attrs) do
    product
    |> cast(attrs, [:name, :price])
    |> validate_required([:name, :price])
  end
end
```

### Traditional Context Approach

Without Aurora.Ctx, you would typically write a context module with all the CRUD operations manually:

```elixir
defmodule MyApp.Inventory do
  import Ecto.Query
  alias MyApp.Repo
  alias MyApp.Inventory.Product

  def list_products do
    Product |> from() |> Repo.all()
  end

  def get_product(id) do
    Product |> Repo.get(id)
  end

  def get_product!(id) do
    Product |> Repo.get!(id)
  end

  def create_product(attrs) do
    %Product{}
    |> Product.changeset(attrs)
    |> Repo.insert()
  end

  def update_product(%Product{} = product, attrs) do
    product
    |> Product.changeset(attrs)
    |> Repo.update()
  end

  def delete_product(%Product{} = product) do
    Repo.delete(product)
  end

  def change_product(%Product{} = product, attrs \\ %{}) do
    Product.changeset(product, attrs)
  end
end
```

### Context Generation with Aurora.Ctx

With Aurora.Ctx, the same functionality can be achieved with just a few lines of code:

```elixir
defmodule MyApp.Inventory do
  use Aurora.Ctx

  # The repository will default to MyApp.Repo  
  ctx_register_schema(MyApp.Inventory.Product)
end
```

Now you can use the context just like the traditional approach:

```elixir
# List all products
products = Inventory.list_products()

# Get a specific product
product = Inventory.get_product!(1)

# Create a new product
{:ok, product} = Inventory.create_product(%{name: "Widget", price: 19.99})

# Update a product
{:ok, product} = Inventory.update_product(product, %{price: 29.99})

# Delete a product
{:ok, _deleted} = Inventory.delete_product(product)
```

### Function Customization

Aurora.Ctx respects existing function definitions. You can provide custom implementations for specific operations while letting Aurora.Ctx generate the rest. Functions can be defined anywhere in the module:

```elixir
defmodule MyApp.Inventory do
  use Aurora.Ctx
  ctx_register_schema(MyApp.Inventory.Product)

  def list_products do
    # Custom implementation with specific business logic
    MyApp.Inventory.Product
    |> where([p], p.active == true)
    |> order_by([p], [desc: p.inserted_at])
    |> MyApp.Repo.all()
  end
end
```

### Changeset Customization

Aurora.Ctx provides several options for customizing which changeset functions are used:

```elixir
defmodule MyApp.Inventory do
  use Aurora.Ctx

  # Default changeset for all operations
  ctx_register_schema(Product, changeset: :custom_changeset)

  # Separate changesets for create/update
  ctx_register_schema(Product,
    create_changeset: :creation_changeset,
    update_changeset: &MyCustomProductChangeset.update_changeset/2
  )
end
```

The priority for selecting changeset functions is:
1. Operation-specific changeset (create_changeset/update_changeset)
2. Default changeset specified with :changeset option
3. Standard "changeset/2" function in the schema

## Generated Functions

For each schema, the following functions are automatically generated:

### List Functions
- `list_*(opts \\ nil)` - List all records with optional filtering/sorting
- `list_*_paginated(opts \\ %{})` - List records with pagination and options
- `count_*(opts \\ nil)` - Count records with optional filtering

### Pagination Functions
- `to_*_page(pagination, page_number)` - Navigates to the specified page number
- `next_*_page(pagination)` - Advances to the next page of results
- `previous_*_page(pagination)` - Goes back to the previous page of results

### Create Functions
- `create_*(attrs \\ %{})` - Create a record with optional attributes
- `create_*!(attrs \\ %{})` - Create a record with optional attributes (raises on error)

### Get Functions
- `get_*(id, opts \\ [])` - Get a record by ID with optional preloads
- `get_*!(id, opts \\ [])` - Get a record by ID with optional preloads (raises if not found)
- `get_*_by(clauses, opts \\ [])` - Get a record by clauses and query options (raises if found more than one)
- `get_*_by!(clauses), opts \\ [])` - Get a record by clauses and query options (raises if not found, or if more than one)

### Delete Functions
- `delete_*(entity)` - Delete the given record
- `delete_*!(entity)` - Delete the given record (raises on error)

### Change Functions
- `change_*(entity_or_changeset, attrs \\ %{})` - Create a changeset from an entity or existing changeset with optional attributes

### Update Functions
- `update_*(entity_or_changeset)` - Update a record from an entity or changeset
- `update_*(entity_or_changeset, attrs)` - Update a record with attributes, accepts entity or changeset
- `update_*!(entity_or_changeset)` - Update a record from an entity or changeset (raises on error)
- `update_*!(entity_or_changeset, attrs)` - Update a record with attributes, accepts entity or changeset (raises on error)

### New Functions
- `new_*()` - Initialize a new struct
- `new_*(attrs)` - Initialize a new struct with attributes
- `new_*(attrs, opts)` - Initialize a new struct with attributes and options

Check the [Functions](functions.html) guide for detailed documentation of each function.

## Direct Core Usage

Sometimes you may want to use the core operations directly without generating context functions. This approach is particularly useful in scenarios such as:

- When working with dynamic schemas determined at runtime
- Building generic admin interfaces or APIs that handle multiple schemas
- Creating reusable modules that work with any schema
- Testing and prototyping before defining your final context structure

Here's how to use the core module directly:

```elixir
alias Aurora.Ctx.Core

# List all records
products = Core.list(MyApp.Repo, MyApp.Inventory.Product)

# List with filtering and sorting
products = Core.list(MyApp.Repo, MyApp.Inventory.Product,
  where: [status: :active],
  order_by: [desc: :inserted_at],
  preload: [:category]
)

# Paginated listing
page = Core.list_paginated(MyApp.Repo, MyApp.Inventory.Product,
  paginate: %{page: 1, per_page: 20}
)

# Create a record
{:ok, product} = Core.create(MyApp.Repo, MyApp.Inventory.Product, %{
  name: "Widget",
  price: 19.99
})

# Update a record
{:ok, product} = Core.update(MyApp.Repo, product, %{price: 29.99})

# Delete a record
{:ok, _deleted} = Core.delete(MyApp.Repo, product)
```

### Context vs Direct Core Usage

While using the Core module directly provides flexibility, using proper contexts has several advantages:

1. **Encapsulation**: Contexts hide implementation details and provide a cleaner API
2. **Business Logic**: Contexts are the ideal place to add business rules and validations
3. **Consistency**: Generated functions ensure consistent naming and behavior across your app
4. **Documentation**: Function names in contexts are more descriptive of their business purpose
5. **Maintainability**: Changes to database operations can be centralized in contexts

Consider using proper contexts for most application code, and reserve direct Core usage for special cases where flexibility is more important than the benefits listed above.
