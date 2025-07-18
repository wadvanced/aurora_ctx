defmodule Aurora.Ctx.Test.Cases.OptionUpdateChangesetReferenceTest do
  use Aurora.Ctx.Test.RepoCase

  alias Aurora.Ctx.Test.Support.Inventory.Product

  defmodule Inventory.Product do
    use Ecto.Schema
    import Ecto.Changeset

    @type t :: %__MODULE__{
            reference: String.t() | nil,
            name: String.t() | nil,
            description: String.t() | nil,
            cost: Decimal.t() | nil,
            list_price: Decimal.t() | nil,
            deleted: boolean() | nil,
            inserted_at: DateTime.t() | nil,
            updated_at: DateTime.t() | nil
          }

    schema "products" do
      field(:reference, :string)
      field(:name, :string)
      field(:description, :string)
      field(:cost, :decimal)
      field(:list_price, :decimal)
      field(:deleted, :boolean, default: false)

      timestamps()
    end

    @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
    def changeset(product, attrs) do
      product
      |> cast(attrs, [
        :reference,
        :name,
        :description,
        :cost,
        :list_price,
        :deleted
      ])
      |> validate_required([:name])
      |> validate_length(:reference, max: 30)
      |> validate_number(:cost, greater_than_or_equal_to: 0)
    end

    @spec update_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
    def update_changeset(product, attrs) do
      product
      |> cast(attrs, [
        :description,
        :list_price,
        :deleted
      ])
      |> validate_number(:list_price, greater_than_or_equal_to: 0)
    end
  end

  defmodule Inventory do
    use Aurora.Ctx

    alias Inventory.Product

    @ctx_repo_module Aurora.Ctx.Repo

    ctx_register_schema(Product, update_changeset: &Inventory.Product.update_changeset/2)
  end

  test "Test function creations" do
    existing_functions =
      :functions
      |> __MODULE__.Inventory.__info__()
      |> Enum.map(&{&1 |> elem(0) |> to_string(), elem(&1, 1)})

    Product
    |> Aurora.Ctx.implementable_functions()
    |> Enum.map(&{&1.name, &1.arity})
    |> Enum.each(&assert(&1 in existing_functions))
  end

  test "Test update changeset function" do
    context = __MODULE__.Inventory

    %{
      "reference" => "item_001",
      "name" => "Item 001",
      "description" => "An Item to be the first",
      "cost" => 11.12
    }
    |> context.create_product!()
    |> tap(&assert(&1.reference == "item_001"))
    |> tap(&assert(&1.name == "Item 001"))
    |> tap(&assert(&1.description == "An Item to be the first"))
    |> tap(&assert(&1.cost == Decimal.new("11.12")))
    |> context.update_product(%{description: "Item to be the first one", name: "New Item 001"})
    |> tap(&(assert(elem(&1, 0)) == :ok))
    |> elem(1)
    |> tap(&assert(&1.reference == "item_001"))
    |> tap(&assert(&1.description == "Item to be the first one"))
    |> tap(&refute(&1.name == "New Item 001"))
  end
end
