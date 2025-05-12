defmodule Aurora.Ctx.Test.Cases.SingleSchemaTest do
  use Aurora.Ctx.Test.RepoCase

  alias Aurora.Ctx.Test.Support.Inventory.Product

  defmodule Inventory do
    use Aurora.Ctx

    @ctx_repo_module Aurora.Ctx.Repo

    ctx_register_schema(Product)
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

  test "Test create function" do
    context = __MODULE__.Inventory

    assert(
      %{"reference" => "item_001", "name" => "This is item 001", "cost" => 11.12}
      |> context.create_product()
      |> elem(0)
      |> Kernel.==(:ok),
      "Failed to insert product"
    )
  end

  test "Test get_product functions" do
    context = __MODULE__.Inventory

    items = create_sample_products(3)

    assert(items.id_1.id |> context.get_product() |> Map.get(:reference) == "item_1")
    assert(items.id_2.id |> context.get_product!() |> Map.get(:reference) == "item_2")
    assert(items.id_3.id |> context.get_product!() |> Map.get(:reference) != "item_2")
    assert(context.get_product(1005) == nil)
    assert_raise(Ecto.NoResultsError, fn -> context.get_product!(1005) end)
  end

  test "Test delete_product functions" do
    context = __MODULE__.Inventory

    items = create_sample_products(3)

    assert(
      items.id_2
      |> context.delete_product()
      |> elem(0)
      |> Kernel.==(:ok)
    )

    assert_raise(Ecto.StaleEntryError, fn -> context.delete_product(items.id_2) end)

    assert(
      items.id_3
      |> context.delete_product!()
      |> Map.get(:reference)
      |> Kernel.==("item_3")
    )

    assert_raise(Ecto.StaleEntryError, fn -> context.delete_product(items.id_3) end)
  end

  test "Test update_product function" do
    context = __MODULE__.Inventory

    items = create_sample_products(2)

    assert(
      items.id_1
      |> context.update_product(%{description: "FIRST UPDATE test item_1"})
      |> elem(1)
      |> Map.get(:description)
      |> Kernel.==("FIRST UPDATE test item_1")
    )

    assert(
      items.id_1
      |> context.update_product(%{description: "SECOND UPDATE test item_1", cost: -1})
      |> elem(0)
      |> Kernel.==(:error)
    )

    context.delete_product(items.id_2)

    assert_raise(Ecto.StaleEntryError, fn ->
      context.update_product(items.id_2, %{description: "FIRST UPDATE test item_2"})
    end)
  end

  test "Test new function" do
    context = __MODULE__.Inventory

    item_1 = context.new_product()

    item_1
    |> tap(&assert(&1.name == nil))
    |> tap(&assert(&1.product_transactions.__struct__ == Ecto.Association.NotLoaded))

    %{name: "First name", reference: "item_chg_01", description: "The item"}
    |> context.new_product()
    |> tap(&assert(&1.name == "First name"))
    |> tap(&assert(&1.product_transactions.__struct__ == Ecto.Association.NotLoaded))

    [preload: :product_transactions]
    |> context.new_product()
    |> tap(&assert(&1.name == nil))
    |> tap(&assert(&1.product_transactions == []))

    %{name: "First name", reference: "item_chg_01", description: "The item"}
    |> context.new_product(preload: :product_transactions)
    |> tap(&assert(&1.name == "First name"))
    |> tap(&assert(&1.product_transactions == []))
  end

  test "Test change function" do
    context = __MODULE__.Inventory

    item_1 = context.new_product()

    item_1
    |> context.change_product()
    |> tap(&assert(Ecto.Changeset.get_field(&1, :reference) == nil))
    |> context.change_product(%{reference: "item_chg_01"})
    |> tap(&assert(Ecto.Changeset.get_field(&1, :reference) == "item_chg_01"))
  end

  test "Test list function" do
    context = __MODULE__.Inventory

    items = create_sample_products(100)

    assert(Enum.count(context.list_products()) == Enum.count(items))
  end

  test "Test list filter functionality - where and or_where" do
    context = __MODULE__.Inventory
    create_sample_products(100)

    assert([where: {:reference, "item_001"}] |> context.list_products() |> Enum.count() == 1)

    assert([where: {:reference, :eq, "item_090"}] |> context.list_products() |> Enum.count() == 1)

    assert(
      [where: [{:reference, :gt, "item_090"}]] |> context.list_products() |> Enum.count() == 10
    )

    assert(
      [where: [{:reference, :ge, "item_090"}]] |> context.list_products() |> Enum.count() == 11
    )

    assert(
      [where: [{:reference, :lt, "item_090"}]] |> context.list_products() |> Enum.count() == 89
    )

    assert(
      [where: [{:reference, :le, "item_090"}]] |> context.list_products() |> Enum.count() == 90
    )

    assert(
      [where: {:reference, :between, "item_090", "item_095"}]
      |> context.list_products()
      |> Enum.count() == 6
    )

    assert(
      [
        where: {:reference, :between, "item_090", "item_095"},
        or_where: {:reference, :eq, "item_001"}
      ]
      |> context.list_products()
      |> Enum.count() == 7
    )
  end

  test "Test list bare pagination" do
    context = __MODULE__.Inventory
    create_sample_products(100)

    assert(
      [paginate: %{page: 1, per_page: 10}]
      |> context.list_products()
      |> Enum.count() == 10
    )
  end

  test "Test bare count" do
    context = __MODULE__.Inventory
    create_sample_products(100)

    assert(context.count_products(paginate: %{page: 1, per_page: 10}) == 100)

    assert(
      context.count_products(
        paginate: %{page: 1, per_page: 10},
        where: {:reference, :between, "item_005", "item_015"}
      ) == 11
    )
  end

  test "Test List pagination " do
    context = __MODULE__.Inventory
    create_sample_products(100)

    [paginate: %{per_page: 5}]
    |> context.list_products_paginated()
    |> tap(&(assert(&1.entries_count) == 100))
    |> tap(&(assert(&1.pages_count) == 10))
    |> tap(&assert(Enum.count(&1.entries) == 5))
    |> tap(&assert(List.first(&1.entries).reference == "item_001"))
    |> tap(&assert(List.last(&1.entries).reference == "item_005"))
    |> context.next_products_page()
    |> tap(&assert(Enum.count(&1.entries) == 5))
    |> tap(&assert(List.first(&1.entries).reference == "item_006"))
    |> tap(&assert(List.last(&1.entries).reference == "item_010"))
    |> context.previous_products_page()
    |> tap(&assert(Enum.count(&1.entries) == 5))
    |> tap(&assert(List.first(&1.entries).reference == "item_001"))
    |> tap(&assert(List.last(&1.entries).reference == "item_005"))
    ## Should stay in the same page since there are only
    |> context.to_products_page(30)
    |> tap(&assert(Enum.count(&1.entries) == 5))
    |> tap(&assert(List.first(&1.entries).reference == "item_001"))
    |> tap(&assert(List.last(&1.entries).reference == "item_005"))
    |> context.to_products_page(11)
    |> tap(&assert(Enum.count(&1.entries) == 5))
    |> tap(&assert(List.first(&1.entries).reference == "item_051"))
    |> tap(&assert(List.last(&1.entries).reference == "item_055"))
  end

  test "Test list sorting" do
    create_sample_products(100)
    context = __MODULE__.Inventory

    [order_by: [asc: :reference]]
    |> context.list_products()
    |> tap(&assert(List.first(&1).reference == "item_001"))

    [order_by: [:reference, desc: :description]]
    |> context.list_products()
    |> tap(&assert(List.first(&1).reference == "item_001"))

    [order_by: [desc: :reference]]
    |> context.list_products()
    |> tap(&assert(List.first(&1).reference == "item_100"))
  end
end
