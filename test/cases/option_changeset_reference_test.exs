defmodule Aurora.Ctx.Test.Cases.OptionChangesetReferenceTest do
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
      field(:deleted, :boolean)

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

    @spec create_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
    def create_changeset(product, attrs) do
      product
      |> cast(attrs, [
        :reference,
        :name,
        :cost
      ])
      |> put_change(:deleted, false)
      |> validate_required([:name])
      |> validate_length(:reference, max: 30)
      |> validate_number(:cost, greater_than_or_equal_to: 0)
    end

    @spec update_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
    def update_changeset(product, attrs) do
      product
      |> cast(attrs, [
        :description,
        :list_price
      ])
      |> validate_number(:list_price, greater_than_or_equal_to: 0)
    end
  end

  defmodule Inventory do
    use Aurora.Ctx

    alias Inventory.Product

    @ctx_repo_module Aurora.Ctx.Repo

    ctx_register_schema(Product,
      changeset: &Inventory.Product.changeset/2,
      create_changeset: &Inventory.Product.create_changeset/2,
      update_changeset: &Inventory.Product.update_changeset/2
    )
  end

  test "Test changeset functions" do
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
    |> tap(&assert(&1.description == nil))
    |> tap(&assert(&1.list_price == nil))
    |> tap(&assert(&1.deleted == false))
    |> tap(&assert(&1.cost == Decimal.new("11.12")))
    |> context.update_product(%{description: "Item to be the first one", name: "New Item 001"})
    |> tap(&(assert(elem(&1, 0)) == :ok))
    |> elem(1)
    |> tap(&assert(&1.reference == "item_001"))
    |> tap(&assert(&1.description == "Item to be the first one"))
    |> tap(&refute(&1.name == "New Item 001"))
    |> context.change_product(%{description: "Item to be the second one"})
    |> context.update_product()
    |> tap(&(assert(elem(&1, 0)) == :ok))
    |> elem(1)
    |> tap(&assert(&1.description == "Item to be the second one"))
  end
end
