defmodule Aurora.Ctxx.Repo.Migrations.CreateProductTransaction do
  use Ecto.Migration

  def change do
    create table "product_transactions" do
      add :quantity, :numeric, precision: 14, scale: 6
      add :unit_cost, :numeric, precision: 14, scale: 6
      add :product_id, references("products")
      timestamps()
    end
  end
end
