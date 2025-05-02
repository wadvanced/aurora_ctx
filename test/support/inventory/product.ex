defmodule Aurora.Ctx.Test.Support.Inventory.Product do
  @moduledoc """
  Represents a product in the inventory.

  This schema corresponds to the `products` table and includes fields
  such as quantities, prices, dimensions, and status.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias Aurora.Ctx.Test.Support.Inventory.ProductTransaction

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

    has_many(:product_transactions, ProductTransaction)

    timestamps()
  end

  @doc """
  Generates a changeset for a product schema.
  """
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
end
