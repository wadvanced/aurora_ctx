defmodule Aurora.Ctxx.Repo.Migrations.CreateProduct do
  use Ecto.Migration

  def change do
    execute "create extension if not exists \"uuid-ossp\""

    create table "products", comment: "Represents an inventory item" do
      add :reference, :string, size: 30
      add :name, :string
      add :description, :text
      add :cost, :numeric, precision: 14, scale: 6
      add :list_price, :numeric, precision: 12, scale: 2
      add :deleted, :boolean
      add :inactive, :boolean
      timestamps()
    end

    create index "products", [:reference], unique: true
  end
end
