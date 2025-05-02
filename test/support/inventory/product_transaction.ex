defmodule Aurora.Ctx.Test.Support.Inventory.ProductTransaction do
  @moduledoc """
  Represents a transaction for a product in the inventory.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Aurora.Ctx.Test.Support.Inventory.Product

  @type t :: %__MODULE__{
          id: integer,
          quantity: Decimal.t(),
          unit_cost: Decimal.t(),
          product_id: integer | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "product_transactions" do
    field(:quantity, :decimal)
    field(:unit_cost, :decimal)

    belongs_to(:product, Product)

    timestamps()
  end

  @doc """
  Creates a changeset for a product transaction.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(product_transaction, attrs) do
    product_transaction
    |> cast(attrs, [:quantity, :unit_cost, :product_id])
    |> validate_required([:quantity, :unit_cost, :product_id])
    |> validate_number(:cost, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:product_id)
  end
end
